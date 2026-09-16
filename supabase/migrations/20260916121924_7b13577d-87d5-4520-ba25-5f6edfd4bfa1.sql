-- OGURA P8: ORDER CREATION, SELLER SUB-ORDERS & PAYMENT STATE ENGINE
-- Source: 20260915000007_ogura_p8_order_seller_suborders_payment.sql (applied verbatim)

CREATE OR REPLACE FUNCTION public.enforce_order_immutability()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'forbidden: orders cannot be deleted'
            USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.user_id IS DISTINCT FROM NEW.user_id OR
           OLD.order_number IS DISTINCT FROM NEW.order_number OR
           OLD.quote_id IS DISTINCT FROM NEW.quote_id OR
           OLD.subtotal_paise != NEW.subtotal_paise OR
           OLD.discount_paise != NEW.discount_paise OR
           OLD.shipping_fee_paise != NEW.shipping_fee_paise OR
           OLD.tax_paise != NEW.tax_paise OR
           OLD.total_amount_paise != NEW.total_amount_paise THEN
            RAISE EXCEPTION 'financial_values_immutable: order financial amounts and core identity cannot be altered'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_order_immutability ON public.orders;
CREATE TRIGGER trg_enforce_order_immutability
BEFORE UPDATE OR DELETE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.enforce_order_immutability();

CREATE OR REPLACE FUNCTION public.enforce_sub_order_immutability()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'forbidden: seller sub-orders cannot be deleted'
            USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.order_id IS DISTINCT FROM NEW.order_id OR
           OLD.seller_id IS DISTINCT FROM NEW.seller_id OR
           OLD.sub_order_number IS DISTINCT FROM NEW.sub_order_number OR
           OLD.subtotal_paise != NEW.subtotal_paise OR
           OLD.discount_paise != NEW.discount_paise OR
           OLD.tax_paise != NEW.tax_paise OR
           OLD.total_amount_paise != NEW.total_amount_paise THEN
            RAISE EXCEPTION 'financial_values_immutable: seller sub-order core financial values cannot be altered'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_sub_order_immutability ON public.seller_sub_orders;
CREATE TRIGGER trg_enforce_sub_order_immutability
BEFORE UPDATE OR DELETE ON public.seller_sub_orders
FOR EACH ROW EXECUTE FUNCTION public.enforce_sub_order_immutability();

CREATE OR REPLACE FUNCTION public.enforce_order_item_immutability()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        RAISE EXCEPTION 'forbidden: historical order items are immutable'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_order_item_immutability ON public.order_items;
CREATE TRIGGER trg_enforce_order_item_immutability
BEFORE UPDATE OR DELETE ON public.order_items
FOR EACH ROW EXECUTE FUNCTION public.enforce_order_item_immutability();

CREATE OR REPLACE FUNCTION public.create_order_from_quote(p_quote_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_quote RECORD;
    v_existing_order RECORD;
    v_order_id UUID;
    v_order_number VARCHAR(50);
    v_payment_id UUID;
    v_gateway_order_id VARCHAR(100);
    v_res_count INTEGER;
    v_seller RECORD;
    v_sub_order_id UUID;
    v_sub_order_number VARCHAR(60);
    v_seller_subtotal BIGINT;
    v_item RECORD;
    v_seller_seq INTEGER := 1;
    v_sub_orders_json JSONB := '[]'::jsonb;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'unauthorized: must be authenticated to create an order'
            USING ERRCODE = '42501';
    END IF;

    SELECT id, user_id, subtotal_paise, discount_paise, shipping_fee_paise,
           tax_paise, total_payable_paise, shipping_address, status, expires_at
    INTO v_quote
    FROM public.checkout_quotes
    WHERE id = p_quote_id
    FOR UPDATE;

    IF v_quote.id IS NULL THEN
        RAISE EXCEPTION 'quote_not_found: checkout quote % does not exist', p_quote_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_quote.user_id != v_user_id THEN
        IF NOT (public.has_role('admin_super') OR public.has_role('admin_support')) THEN
            RAISE EXCEPTION 'forbidden: cannot create order from another customer quote'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_quote.shipping_address IS NULL OR v_quote.shipping_address = 'null'::jsonb OR v_quote.shipping_address = '{}'::jsonb THEN
        RAISE EXCEPTION 'missing_shipping_address: checkout quote must have a valid shipping address'
            USING ERRCODE = '55000';
    END IF;

    IF v_quote.status != 'pending'::checkout_quote_status THEN
        RAISE EXCEPTION 'invalid_quote_status: quote is in % status and cannot be converted to order', v_quote.status
            USING ERRCODE = '55000';
    END IF;

    IF v_quote.expires_at <= CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'quote_expired: quote expired at %', v_quote.expires_at
            USING ERRCODE = '55000';
    END IF;

    SELECT id, order_number, status, total_amount_paise INTO v_existing_order
    FROM public.orders
    WHERE quote_id = p_quote_id;

    IF v_existing_order.id IS NOT NULL THEN
        SELECT id, gateway_order_id INTO v_payment_id, v_gateway_order_id
        FROM public.payment_transactions
        WHERE order_id = v_existing_order.id
        ORDER BY created_at DESC LIMIT 1;

        RETURN jsonb_build_object(
            'order_id', v_existing_order.id,
            'order_number', v_existing_order.order_number,
            'status', v_existing_order.status,
            'total_amount_paise', v_existing_order.total_amount_paise,
            'payment_id', v_payment_id,
            'gateway_order_id', v_gateway_order_id,
            'is_existing', true
        );
    END IF;

    SELECT count(*) INTO v_res_count
    FROM public.inventory_reservations
    WHERE quote_id = p_quote_id
      AND status = 'held'::inventory_reservation_status
      AND expires_at > CURRENT_TIMESTAMP;

    IF v_res_count = 0 THEN
        RAISE EXCEPTION 'no_active_reservations: quote has no valid unexpired inventory reservations'
            USING ERRCODE = '55000';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.inventory_reservations
        WHERE quote_id = p_quote_id
          AND (status != 'held'::inventory_reservation_status OR expires_at <= CURRENT_TIMESTAMP)
    ) THEN
        RAISE EXCEPTION 'quote_has_expired_or_invalid_reservations: quote has expired or invalid reservations'
            USING ERRCODE = '55000';
    END IF;

    v_order_id := gen_random_uuid();
    v_order_number := 'OG-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDD') || '-' || upper(substr(replace(v_order_id::text, '-', ''), 1, 8));

    INSERT INTO public.orders (
        id, order_number, user_id, quote_id, subtotal_paise, discount_paise,
        shipping_fee_paise, tax_paise, total_amount_paise, shipping_address, status
    ) VALUES (
        v_order_id, v_order_number, v_user_id, p_quote_id, v_quote.subtotal_paise, v_quote.discount_paise,
        v_quote.shipping_fee_paise, v_quote.tax_paise, v_quote.total_payable_paise, v_quote.shipping_address, 'placed'::order_status
    );

    v_payment_id := gen_random_uuid();
    v_gateway_order_id := 'order_' || replace(v_payment_id::text, '-', '');

    INSERT INTO public.payment_transactions (
        id, order_id, gateway, gateway_order_id, amount_paise, currency, status
    ) VALUES (
        v_payment_id, v_order_id, 'razorpay', v_gateway_order_id, v_quote.total_payable_paise, 'INR', 'initiated'::payment_transaction_status
    );

    INSERT INTO public.order_status_history (
        order_id, from_status, to_status, actor_id, notes
    ) VALUES (
        v_order_id, NULL, 'placed', v_user_id, 'Order created from checkout quote; awaiting payment'
    );

    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'order_number', v_order_number,
        'user_id', v_user_id,
        'quote_id', p_quote_id,
        'subtotal_paise', v_quote.subtotal_paise,
        'discount_paise', v_quote.discount_paise,
        'shipping_fee_paise', v_quote.shipping_fee_paise,
        'tax_paise', v_quote.tax_paise,
        'total_amount_paise', v_quote.total_payable_paise,
        'status', 'placed',
        'sub_orders', '[]'::jsonb,
        'payment', jsonb_build_object(
            'payment_id', v_payment_id,
            'gateway', 'razorpay',
            'gateway_order_id', v_gateway_order_id,
            'amount_paise', v_quote.total_payable_paise,
            'status', 'initiated'
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.confirm_order_payment(
    p_order_id UUID,
    p_gateway_payment_id VARCHAR,
    p_gateway_signature VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_order RECORD;
    v_payment RECORD;
    v_consumed_count INTEGER;
    v_seller RECORD;
    v_sub_order_id UUID;
    v_sub_order_number VARCHAR(60);
    v_seller_subtotal BIGINT;
    v_item RECORD;
    v_seller_seq INTEGER := 1;
    v_sub_orders_json JSONB := '[]'::jsonb;
BEGIN
    v_caller_id := auth.uid();

    SELECT id, user_id, quote_id, order_number, status, total_amount_paise
    INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'order_not_found: order % does not exist', p_order_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_caller_id IS NOT NULL AND v_order.user_id IS NOT NULL AND v_caller_id != v_order.user_id THEN
        IF NOT (public.has_role('admin_super') OR public.has_role('admin_support') OR public.has_role('admin_finance')) THEN
            RAISE EXCEPTION 'forbidden: cannot confirm payment for another customer order'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_order.status = 'confirmed'::order_status THEN
        SELECT id, gateway_payment_id, status INTO v_payment
        FROM public.payment_transactions
        WHERE order_id = p_order_id
        ORDER BY created_at DESC LIMIT 1;

        SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'sub_order_id', sso.id,
            'sub_order_number', sso.sub_order_number,
            'seller_id', sso.seller_id,
            'subtotal_paise', sso.subtotal_paise
        )), '[]'::jsonb)
        INTO v_sub_orders_json
        FROM public.seller_sub_orders sso
        WHERE sso.order_id = p_order_id;

        RETURN jsonb_build_object(
            'order_id', v_order.id,
            'order_number', v_order.order_number,
            'status', 'confirmed',
            'payment_status', v_payment.status,
            'sub_orders', v_sub_orders_json,
            'is_idempotent', true
        );
    END IF;

    IF v_order.status != 'placed'::order_status THEN
        RAISE EXCEPTION 'invalid_order_status: cannot confirm payment for order in % status', v_order.status
            USING ERRCODE = '55000';
    END IF;

    IF v_order.quote_id IS NOT NULL THEN
        v_consumed_count := public.consume_quote_reservations(v_order.quote_id);
    END IF;

    IF v_consumed_count IS NULL OR v_consumed_count = 0 THEN
        RAISE EXCEPTION 'cannot_confirm_order_without_consumed_reservations: no active reservations were found or consumed for order %', p_order_id
            USING ERRCODE = '55000';
    END IF;

    SELECT id, status INTO v_payment
    FROM public.payment_transactions
    WHERE order_id = p_order_id
    ORDER BY created_at DESC LIMIT 1
    FOR UPDATE;

    IF v_payment.id IS NOT NULL THEN
        UPDATE public.payment_transactions
        SET gateway_payment_id = p_gateway_payment_id,
            gateway_signature = p_gateway_signature,
            status = 'captured'::payment_transaction_status,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_payment.id;
    END IF;

    IF v_order.quote_id IS NOT NULL THEN
        UPDATE public.checkout_quotes
        SET status = 'paid'::checkout_quote_status
        WHERE id = v_order.quote_id;
    END IF;

    UPDATE public.orders
    SET status = 'confirmed'::order_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_order_id;

    FOR v_seller IN
        SELECT DISTINCT p.seller_id
        FROM public.inventory_reservations ir
        JOIN public.product_variants pv ON ir.variant_id = pv.id
        JOIN public.products p ON pv.product_id = p.id
        WHERE ir.quote_id = v_order.quote_id
    LOOP
        v_sub_order_id := gen_random_uuid();
        v_sub_order_number := v_order.order_number || '-S' || v_seller_seq;
        v_seller_seq := v_seller_seq + 1;

        SELECT COALESCE(SUM(ir.quantity * pv.price_paise), 0)
        INTO v_seller_subtotal
        FROM public.inventory_reservations ir
        JOIN public.product_variants pv ON ir.variant_id = pv.id
        JOIN public.products p ON pv.product_id = p.id
        WHERE ir.quote_id = v_order.quote_id AND p.seller_id = v_seller.seller_id;

        INSERT INTO public.seller_sub_orders (
            id, sub_order_number, order_id, seller_id, subtotal_paise, discount_paise,
            tax_paise, total_amount_paise, commission_paise, tcs_paise, tds_paise,
            logistics_deduction_paise, net_seller_payable_paise, status
        ) VALUES (
            v_sub_order_id, v_sub_order_number, p_order_id, v_seller.seller_id,
            v_seller_subtotal, 0, 0, v_seller_subtotal,
            0, 0, 0, 0, v_seller_subtotal, 'pending_acceptance'::sub_order_status
        );

        FOR v_item IN
            SELECT ir.variant_id, ir.quantity, pv.price_paise, pv.sku, pv.size, pv.color, p.title
            FROM public.inventory_reservations ir
            JOIN public.product_variants pv ON ir.variant_id = pv.id
            JOIN public.products p ON pv.product_id = p.id
            WHERE ir.quote_id = v_order.quote_id AND p.seller_id = v_seller.seller_id
        LOOP
            INSERT INTO public.order_items (
                sub_order_id, variant_id, product_title, variant_sku,
                size, color, unit_price_paise, quantity, total_price_paise
            ) VALUES (
                v_sub_order_id, v_item.variant_id, v_item.title, v_item.sku,
                v_item.size, v_item.color, v_item.price_paise, v_item.quantity,
                (v_item.price_paise * v_item.quantity)
            );
        END LOOP;

        v_sub_orders_json := v_sub_orders_json || jsonb_build_object(
            'sub_order_id', v_sub_order_id,
            'sub_order_number', v_sub_order_number,
            'seller_id', v_seller.seller_id,
            'subtotal_paise', v_seller_subtotal
        );
    END LOOP;

    INSERT INTO public.order_status_history (
        order_id, from_status, to_status, actor_id, notes
    ) VALUES (
        p_order_id, 'placed', 'confirmed', v_caller_id, 'Payment successfully captured; sub-orders created; inventory consumed'
    );

    PERFORM public.clear_customer_cart();

    RETURN jsonb_build_object(
        'order_id', p_order_id,
        'order_number', v_order.order_number,
        'status', 'confirmed',
        'payment_status', 'captured',
        'consumed_reservations', v_consumed_count,
        'sub_orders', v_sub_orders_json
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.record_payment_failure(
    p_order_id UUID,
    p_error_code VARCHAR,
    p_error_description TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_order RECORD;
    v_payment RECORD;
BEGIN
    v_caller_id := auth.uid();

    SELECT id, user_id, status INTO v_order
    FROM public.orders WHERE id = p_order_id;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'order_not_found: order % does not exist', p_order_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_caller_id IS NOT NULL AND v_order.user_id IS NOT NULL AND v_caller_id != v_order.user_id THEN
        IF NOT (public.has_role('admin_super') OR public.has_role('admin_support') OR public.has_role('admin_finance')) THEN
            RAISE EXCEPTION 'forbidden: cannot record payment failure for another customer order'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_order.status = 'confirmed'::order_status THEN
        RAISE EXCEPTION 'cannot_fail_confirmed_order: order % is already confirmed and paid', p_order_id
            USING ERRCODE = '55000';
    END IF;

    SELECT id INTO v_payment
    FROM public.payment_transactions
    WHERE order_id = p_order_id
    ORDER BY created_at DESC LIMIT 1
    FOR UPDATE;

    IF v_payment.id IS NOT NULL THEN
        UPDATE public.payment_transactions
        SET status = 'failed'::payment_transaction_status,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_payment.id;
    END IF;

    INSERT INTO public.order_status_history (
        order_id, from_status, to_status, actor_id, notes
    ) VALUES (
        p_order_id, v_order.status::text, 'payment_failed', v_caller_id,
        coalesce(p_error_code, '') || ': ' || coalesce(p_error_description, '')
    );

    RETURN jsonb_build_object(
        'order_id', p_order_id,
        'order_status', v_order.status,
        'payment_status', 'failed'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.cancel_order(
    p_order_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_order RECORD;
BEGIN
    v_caller_id := auth.uid();

    SELECT id, user_id, quote_id, status
    INTO v_order
    FROM public.orders
    WHERE id = p_order_id;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'order_not_found: order % does not exist', p_order_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_caller_id IS NOT NULL AND v_order.user_id IS NOT NULL AND v_caller_id != v_order.user_id THEN
        IF NOT (public.has_role('admin_super') OR public.has_role('admin_support')) THEN
            RAISE EXCEPTION 'forbidden: cannot cancel another customer order'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_order.status = 'cancelled'::order_status THEN
        RETURN true;
    END IF;

    IF v_order.status != 'placed'::order_status THEN
        RAISE EXCEPTION 'cannot_cancel_order: only placed orders can be cancelled directly; confirmed orders require refund processing'
            USING ERRCODE = '55000';
    END IF;

    IF v_order.quote_id IS NOT NULL THEN
        PERFORM public.release_quote_reservations(v_order.quote_id);
    END IF;

    UPDATE public.seller_sub_orders
    SET status = 'cancelled'::sub_order_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE order_id = p_order_id;

    UPDATE public.orders
    SET status = 'cancelled'::order_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_order_id;

    INSERT INTO public.order_status_history (
        order_id, from_status, to_status, actor_id, notes
    ) VALUES (
        p_order_id, v_order.status::text, 'cancelled', v_caller_id, p_reason
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.get_order_details(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_order RECORD;
    v_is_seller BOOLEAN;
    v_seller_id UUID;
    v_sub_orders JSONB := '[]'::jsonb;
    v_payment JSONB;
BEGIN
    v_caller_id := auth.uid();

    SELECT id, order_number, user_id, quote_id, subtotal_paise, discount_paise,
           shipping_fee_paise, tax_paise, total_amount_paise, shipping_address,
           status, created_at, updated_at
    INTO v_order
    FROM public.orders
    WHERE id = p_order_id;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'order_not_found: order % does not exist', p_order_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_caller_id IS NOT NULL AND v_order.user_id = v_caller_id THEN
        SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'sub_order_id', sso.id,
            'sub_order_number', sso.sub_order_number,
            'seller_id', sso.seller_id,
            'seller_name', s.business_name,
            'subtotal_paise', sso.subtotal_paise,
            'status', sso.status,
            'items', (
                SELECT jsonb_agg(jsonb_build_object(
                    'item_id', oi.id,
                    'product_title', oi.product_title,
                    'sku', oi.variant_sku,
                    'size', oi.size,
                    'color', oi.color,
                    'unit_price_paise', oi.unit_price_paise,
                    'quantity', oi.quantity,
                    'total_price_paise', oi.total_price_paise
                ))
                FROM public.order_items oi
                WHERE oi.sub_order_id = sso.id
            )
        )), '[]'::jsonb)
        INTO v_sub_orders
        FROM public.seller_sub_orders sso
        JOIN public.sellers s ON sso.seller_id = s.id
        WHERE sso.order_id = p_order_id;

    ELSE
        SELECT id INTO v_seller_id FROM public.sellers WHERE user_id = v_caller_id;

        IF v_seller_id IS NOT NULL THEN
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'sub_order_id', sso.id,
                'sub_order_number', sso.sub_order_number,
                'seller_id', sso.seller_id,
                'seller_name', s.business_name,
                'subtotal_paise', sso.subtotal_paise,
                'net_seller_payable_paise', sso.net_seller_payable_paise,
                'status', sso.status,
                'items', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'item_id', oi.id,
                        'product_title', oi.product_title,
                        'sku', oi.variant_sku,
                        'size', oi.size,
                        'color', oi.color,
                        'unit_price_paise', oi.unit_price_paise,
                        'quantity', oi.quantity,
                        'total_price_paise', oi.total_price_paise
                    ))
                    FROM public.order_items oi
                    WHERE oi.sub_order_id = sso.id
                )
            )), '[]'::jsonb)
            INTO v_sub_orders
            FROM public.seller_sub_orders sso
            JOIN public.sellers s ON sso.seller_id = s.id
            WHERE sso.order_id = p_order_id AND sso.seller_id = v_seller_id;

            IF jsonb_array_length(v_sub_orders) = 0 THEN
                RAISE EXCEPTION 'forbidden: seller has no sub-orders on this order'
                    USING ERRCODE = '42501';
            END IF;

        ELSIF public.has_role('admin_super') OR public.has_role('admin_support') OR public.has_role('admin_finance') THEN
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'sub_order_id', sso.id,
                'sub_order_number', sso.sub_order_number,
                'seller_id', sso.seller_id,
                'seller_name', s.business_name,
                'subtotal_paise', sso.subtotal_paise,
                'status', sso.status,
                'items', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'item_id', oi.id,
                        'product_title', oi.product_title,
                        'sku', oi.variant_sku,
                        'size', oi.size,
                        'color', oi.color,
                        'unit_price_paise', oi.unit_price_paise,
                        'quantity', oi.quantity,
                        'total_price_paise', oi.total_price_paise
                    ))
                    FROM public.order_items oi
                    WHERE oi.sub_order_id = sso.id
                )
            )), '[]'::jsonb)
            INTO v_sub_orders
            FROM public.seller_sub_orders sso
            JOIN public.sellers s ON sso.seller_id = s.id
            WHERE sso.order_id = p_order_id;
        ELSE
            RAISE EXCEPTION 'forbidden: cannot access this order'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT jsonb_build_object(
        'payment_id', pt.id,
        'gateway', pt.gateway,
        'gateway_order_id', pt.gateway_order_id,
        'gateway_payment_id', pt.gateway_payment_id,
        'amount_paise', pt.amount_paise,
        'status', pt.status
    ) INTO v_payment
    FROM public.payment_transactions pt
    WHERE pt.order_id = p_order_id
    ORDER BY pt.created_at DESC LIMIT 1;

    RETURN jsonb_build_object(
        'order_id', v_order.id,
        'order_number', v_order.order_number,
        'user_id', v_order.user_id,
        'subtotal_paise', v_order.subtotal_paise,
        'discount_paise', v_order.discount_paise,
        'shipping_fee_paise', v_order.shipping_fee_paise,
        'tax_paise', v_order.tax_paise,
        'total_amount_paise', v_order.total_amount_paise,
        'shipping_address', v_order.shipping_address,
        'status', v_order.status,
        'created_at', v_order.created_at,
        'sub_orders', v_sub_orders,
        'payment', v_payment
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_unique_quote ON public.orders (quote_id) WHERE quote_id IS NOT NULL;

GRANT SELECT ON public.orders TO authenticated;
GRANT SELECT ON public.seller_sub_orders TO authenticated;
GRANT SELECT ON public.order_items TO authenticated;
GRANT SELECT ON public.payment_transactions TO authenticated;
GRANT SELECT ON public.sellers TO authenticated;
GRANT SELECT ON public.profiles TO authenticated;
GRANT SELECT ON public.checkout_quotes TO authenticated;
GRANT SELECT ON public.inventory_reservations TO authenticated;
GRANT SELECT ON public.products TO authenticated, anon;
GRANT SELECT ON public.product_variants TO authenticated, anon;
GRANT SELECT ON public.inventory_items TO authenticated;
GRANT SELECT ON public.carts TO authenticated;
GRANT SELECT ON public.cart_lines TO authenticated;
GRANT SELECT ON public.customer_addresses TO authenticated;

GRANT EXECUTE ON FUNCTION public.create_order_from_quote(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_order_payment(UUID, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_payment_failure(UUID, VARCHAR, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_order(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_order_details(UUID) TO authenticated;