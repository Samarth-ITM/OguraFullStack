-- ==============================================================================
-- OGURA — FORWARD MIGRATION: RED-TEAM AUDIT DEFECT CORRECTIONS
-- Migration ID: 20260916000001_ogura_rigorous_redteam_corrections
-- Authoritative, idempotent forward migration addressing DEFECT-01, DEFECT-02, DEFECT-03
-- ==============================================================================

-- ==============================================================================
-- SECTION 1: DEFECT-01 (HIGH) — PAYMENT CONFIRMATION SAFE FOR SERVICE-ROLE & ADMIN
-- ==============================================================================
-- Replaces caller-dependent clear_customer_cart() with targeted deletion
-- against the order owner's cart. Works for service-role/webhook (auth.uid() IS NULL),
-- admin confirmation (preserves admin cart), and preserves tenant cart isolation.

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

    -- 1. Fetch order
    SELECT id, user_id, quote_id, order_number, status, total_amount_paise
    INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'order_not_found: order % does not exist', p_order_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Security check
    IF v_caller_id IS NOT NULL AND v_order.user_id IS NOT NULL AND v_caller_id != v_order.user_id THEN
        IF NOT (public.has_role('admin_super') OR public.has_role('admin_support') OR public.has_role('admin_finance')) THEN
            RAISE EXCEPTION 'forbidden: cannot confirm payment for another customer order'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Idempotency: If already confirmed, return current state safely
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

    -- 2. Atomically consume P6 inventory reservations
    -- P6 validates expiration under row lock. If reservations expired, throws error and rolls back!
    IF v_order.quote_id IS NOT NULL THEN
        v_consumed_count := public.consume_quote_reservations(v_order.quote_id);
    END IF;

    IF v_consumed_count IS NULL OR v_consumed_count = 0 THEN
        RAISE EXCEPTION 'cannot_confirm_order_without_consumed_reservations: no active reservations were found or consumed for order %', p_order_id
            USING ERRCODE = '55000';
    END IF;

    -- 3. Update payment transaction to captured
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

    -- 4. Update quote status to paid
    IF v_order.quote_id IS NOT NULL THEN
        UPDATE public.checkout_quotes
        SET status = 'paid'::checkout_quote_status
        WHERE id = v_order.quote_id;
    END IF;

    -- 5. Update order status to confirmed
    UPDATE public.orders
    SET status = 'confirmed'::order_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_order_id;

    -- 6. Partition items into seller_sub_orders and snapshot order_items (Authoritative Post-Payment Creation)
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

        -- Calculate seller subtotal
        SELECT COALESCE(SUM(ir.quantity * pv.price_paise), 0)
        INTO v_seller_subtotal
        FROM public.inventory_reservations ir
        JOIN public.product_variants pv ON ir.variant_id = pv.id
        JOIN public.products p ON pv.product_id = p.id
        WHERE ir.quote_id = v_order.quote_id AND p.seller_id = v_seller.seller_id;

        -- Insert seller sub-order (net_seller_payable_paise = subtotal - discount)
        INSERT INTO public.seller_sub_orders (
            id, sub_order_number, order_id, seller_id, subtotal_paise, discount_paise,
            tax_paise, total_amount_paise, commission_paise, tcs_paise, tds_paise,
            logistics_deduction_paise, net_seller_payable_paise, status
        ) VALUES (
            v_sub_order_id, v_sub_order_number, p_order_id, v_seller.seller_id,
            v_seller_subtotal, 0, 0, v_seller_subtotal,
            0, 0, 0, 0, v_seller_subtotal, 'pending_acceptance'::sub_order_status
        );

        -- Insert snapshot order items for this seller
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

    -- 7. Log status history
    INSERT INTO public.order_status_history (
        order_id, from_status, to_status, actor_id, notes
    ) VALUES (
        p_order_id, 'placed', 'confirmed', v_caller_id, 'Payment successfully captured; sub-orders created; inventory consumed'
    );

    -- 8. Clear active customer cart (Targeted to the order owner's cart)
    IF v_order.user_id IS NOT NULL THEN
        DELETE FROM public.cart_lines
        WHERE cart_id IN (
            SELECT id FROM public.carts WHERE user_id = v_order.user_id
        );
        UPDATE public.carts
        SET updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_order.user_id;
    END IF;

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

GRANT EXECUTE ON FUNCTION public.confirm_order_payment(UUID, VARCHAR, VARCHAR) TO authenticated;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.confirm_order_payment(UUID, VARCHAR, VARCHAR) TO service_role';
    END IF;
END $$;

-- ==============================================================================
-- SECTION 2: DEFECT-02 (HIGH) — AUTHORITATIVE SUB-ORDER STATUS TRANSITION PROTECTION
-- ==============================================================================
-- Enforces authoritative state-machine rules at the table level (trigger) so that
-- direct SQL mutations by sellers cannot regress dispatched sub-orders (e.g. to packed),
-- cannot alter terminal delivered or cancelled sub-orders, cannot revert to pending_acceptance,
-- and cannot skip dispatch to force delivered.

CREATE OR REPLACE FUNCTION public.enforce_sub_order_immutability()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'forbidden: seller sub-orders cannot be deleted'
            USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- 1. Financial & core structural immutability
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

        -- 2. Authoritative State-Machine Transition Guardrails
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            -- Terminal states cannot transition to anything
            IF OLD.status = 'delivered'::sub_order_status THEN
                RAISE EXCEPTION 'invalid_sub_order_transition: delivered sub-order is terminal and cannot be modified'
                    USING ERRCODE = '22023';
            END IF;

            IF OLD.status = 'cancelled'::sub_order_status THEN
                RAISE EXCEPTION 'invalid_sub_order_transition: cancelled sub-order is terminal and cannot be modified'
                    USING ERRCODE = '22023';
            END IF;

            -- Dispatched cannot regress to pre-dispatch states or be cancelled
            IF OLD.status = 'dispatched'::sub_order_status THEN
                IF NEW.status != 'delivered'::sub_order_status THEN
                    RAISE EXCEPTION 'invalid_sub_order_transition: dispatched sub-order cannot regress to %', NEW.status
                        USING ERRCODE = '22023';
                END IF;
            END IF;

            -- Cannot revert to pending_acceptance from any other status
            IF NEW.status = 'pending_acceptance'::sub_order_status THEN
                RAISE EXCEPTION 'invalid_sub_order_transition: cannot revert sub-order to pending_acceptance'
                    USING ERRCODE = '22023';
            END IF;

            -- Delivery can only be achieved from dispatched
            IF NEW.status = 'delivered'::sub_order_status AND OLD.status != 'dispatched'::sub_order_status THEN
                RAISE EXCEPTION 'invalid_sub_order_transition: sub-order must be dispatched before being marked delivered'
                    USING ERRCODE = '22023';
            END IF;

            -- Pre-dispatch regression rules
            IF OLD.status = 'packed'::sub_order_status AND NEW.status IN ('accepted'::sub_order_status, 'in_crafting'::sub_order_status) THEN
                RAISE EXCEPTION 'invalid_sub_order_transition: packed sub-order cannot regress to %', NEW.status
                    USING ERRCODE = '22023';
            END IF;

            IF OLD.status = 'in_crafting'::sub_order_status AND NEW.status = 'accepted'::sub_order_status THEN
                RAISE EXCEPTION 'invalid_sub_order_transition: in_crafting sub-order cannot regress to %', NEW.status
                    USING ERRCODE = '22023';
            END IF;

            IF OLD.status = 'ready_for_pickup'::sub_order_status AND NEW.status IN ('accepted'::sub_order_status, 'in_crafting'::sub_order_status, 'packed'::sub_order_status) THEN
                RAISE EXCEPTION 'invalid_sub_order_transition: ready_for_pickup sub-order cannot regress to %', NEW.status
                    USING ERRCODE = '22023';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_sub_order_immutability ON public.seller_sub_orders;
CREATE TRIGGER trg_enforce_sub_order_immutability
BEFORE UPDATE OR DELETE ON public.seller_sub_orders
FOR EACH ROW EXECUTE FUNCTION public.enforce_sub_order_immutability();

-- ==============================================================================
-- SECTION 3: DEFECT-03 (MEDIUM) — SELLER PRIVATE DATA LEAK PROTECTION
-- ==============================================================================
-- Removes public/anonymous direct read access to public.sellers base table.
-- Confines public.sellers SELECT access strictly to:
--   1. The seller owner (user_id = auth.uid())
--   2. Authorized administrative roles (admin_super, admin_finance, admin_catalog, admin_viewer)
-- Public catalog lookups and directories access ONLY the authoritative public projection:
--   public.public_sellers view (id, business_name, seller_slug)
-- which exposes zero GSTIN, PAN, commission rates, bank accounts, or KYC documents.

DROP POLICY IF EXISTS p_sellers_read ON public.sellers;
CREATE POLICY p_sellers_read ON public.sellers FOR SELECT
USING (
    user_id = auth.uid()
    OR public.has_role('admin_super'::user_role_type)
    OR public.has_role('admin_finance'::user_role_type)
    OR public.has_role('admin_catalog'::user_role_type)
    OR public.has_role('admin_viewer'::user_role_type)
);

-- Ensure public_sellers view is explicitly accessible to public / anon / authenticated
CREATE OR REPLACE VIEW public.public_sellers AS
SELECT
    id,
    business_name,
    seller_slug
FROM public.sellers
WHERE status = 'active'::seller_status;

GRANT SELECT ON public.public_sellers TO anon;
GRANT SELECT ON public.public_sellers TO authenticated;


