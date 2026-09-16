-- ============================================================================
-- OGURA PHASE 7: CHECKOUT & AUTHORITATIVE QUOTE ENGINE
-- Migration: 20260915000006_ogura_p7_checkout_authoritative_quote.sql
-- Invariants:
-- 1. Server-authoritative pricing (product_variants.price_paise) in integer paise
-- 2. Shipping tariff: Free for subtotal >= 299900 paise (₹2,999); else 9900 paise (₹99)
-- 3. Multi-seller: Single parent-level shipping charge
-- 4. Customer-facing tax: 0 incremental tax (catalog prices are GST-inclusive)
-- 5. Discount: 0 paise (no active promotion engine in MVP)
-- 6. Atomic coordination with Phase 6 inventory reservation
-- 7. Immutability of quote financial values
-- ============================================================================

-- 1. IMMUTABILITY TRIGGER FOR CHECKOUT QUOTES
CREATE OR REPLACE FUNCTION public.enforce_quote_immutability()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'forbidden: checkout quotes cannot be deleted'
            USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Prevent alteration of financial terms or ownership
        IF OLD.user_id IS DISTINCT FROM NEW.user_id OR
           OLD.subtotal_paise != NEW.subtotal_paise OR
           OLD.discount_paise != NEW.discount_paise OR
           OLD.shipping_fee_paise != NEW.shipping_fee_paise OR
           OLD.tax_paise != NEW.tax_paise OR
           OLD.total_payable_paise != NEW.total_payable_paise THEN
            RAISE EXCEPTION 'financial_values_immutable: financial amounts and ownership on checkout_quotes cannot be altered'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_quote_immutability ON public.checkout_quotes;
CREATE TRIGGER trg_enforce_quote_immutability
BEFORE UPDATE OR DELETE ON public.checkout_quotes
FOR EACH ROW EXECUTE FUNCTION public.enforce_quote_immutability();


-- 2. CREATE CHECKOUT QUOTE (ATOMIC QUOTE + P6 RESERVATION)
CREATE OR REPLACE FUNCTION public.create_checkout_quote(
    p_address_id UUID DEFAULT NULL,
    p_custom_address JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_cart_id UUID;
    v_quote_id UUID;
    v_subtotal_paise BIGINT := 0;
    v_discount_paise BIGINT := 0;
    v_shipping_fee_paise BIGINT := 0;
    v_tax_paise BIGINT := 0;
    v_total_payable_paise BIGINT := 0;
    v_shipping_address JSONB;
    v_expires_at TIMESTAMPTZ;
    v_line RECORD;
    v_items_count INTEGER := 0;
    v_items_jsonb JSONB := '[]'::jsonb;
    v_quote_items_details JSONB := '[]'::jsonb;
    v_reservation_results JSONB;
    v_prev_quote RECORD;
BEGIN
    -- 1. Derive authenticated customer
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'unauthorized: must be authenticated to create checkout quote'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Fetch customer's active cart
    SELECT id INTO v_cart_id
    FROM public.carts
    WHERE user_id = v_user_id;

    IF v_cart_id IS NULL THEN
        RAISE EXCEPTION 'cart_not_found: no active cart found for customer'
            USING ERRCODE = 'P0002';
    END IF;

    -- 3. Resolve and validate shipping address
    IF p_address_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'id', id,
            'full_name', full_name,
            'phone', phone,
            'line1', line1,
            'line2', line2,
            'city', city,
            'state', state,
            'pincode', pincode,
            'country', country
        ) INTO v_shipping_address
        FROM public.customer_addresses
        WHERE id = p_address_id AND user_id = v_user_id AND is_active = true;

        IF v_shipping_address IS NULL THEN
            RAISE EXCEPTION 'address_not_found: shipping address not found or does not belong to customer'
                USING ERRCODE = '42501';
        END IF;
    ELSIF p_custom_address IS NOT NULL AND 
          p_custom_address ? 'line1' AND 
          p_custom_address ? 'city' AND 
          (p_custom_address ? 'pincode' OR p_custom_address ? 'postal_code') THEN
        v_shipping_address := p_custom_address;
    ELSE
        -- Fallback to customer's default address
        SELECT jsonb_build_object(
            'id', id,
            'full_name', full_name,
            'phone', phone,
            'line1', line1,
            'line2', line2,
            'city', city,
            'state', state,
            'pincode', pincode,
            'country', country
        ) INTO v_shipping_address
        FROM public.customer_addresses
        WHERE user_id = v_user_id AND is_default = true AND is_active = true;

        IF v_shipping_address IS NULL THEN
            RAISE EXCEPTION 'missing_address: a valid shipping address is required for checkout'
                USING ERRCODE = '22000';
        END IF;
    END IF;

    -- 4. Validate cart lines & calculate authoritative pricing
    FOR v_line IN
        SELECT cl.id AS line_id,
               cl.variant_id,
               cl.quantity,
               pv.price_paise,
               pv.sku,
               pv.size,
               pv.color,
               p.id AS product_id,
               p.title,
               p.status AS product_status,
               p.is_made_to_order,
               s.id AS seller_id,
               s.business_name AS seller_name,
               s.status AS seller_status
        FROM public.cart_lines cl
        JOIN public.product_variants pv ON cl.variant_id = pv.id
        JOIN public.products p ON pv.product_id = p.id
        JOIN public.sellers s ON p.seller_id = s.id
        WHERE cl.cart_id = v_cart_id
        ORDER BY cl.created_at ASC
    LOOP
        v_items_count := v_items_count + 1;

        -- Validate quantity bounds [1..10]
        IF v_line.quantity < 1 OR v_line.quantity > 10 THEN
            RAISE EXCEPTION 'invalid_quantity: quantity for variant % must be between 1 and 10', v_line.variant_id
                USING ERRCODE = '22003';
        END IF;

        -- Validate product lifecycle status
        IF v_line.product_status != 'live'::product_status THEN
            RAISE EXCEPTION 'product_unavailable: product "%" is not live or available for purchase', v_line.title
                USING ERRCODE = '55000';
        END IF;

        -- Validate seller lifecycle status
        IF v_line.seller_status != 'active'::seller_status THEN
            RAISE EXCEPTION 'seller_inactive: seller for product "%" is not active', v_line.title
                USING ERRCODE = '55000';
        END IF;

        -- Accumulate subtotal using database authoritative price
        v_subtotal_paise := v_subtotal_paise + (v_line.quantity * v_line.price_paise);

        -- Build P6 reservation payload
        v_items_jsonb := v_items_jsonb || jsonb_build_object(
            'variant_id', v_line.variant_id,
            'quantity', v_line.quantity
        );

        -- Item details for quote response
        v_quote_items_details := v_quote_items_details || jsonb_build_object(
            'line_id', v_line.line_id,
            'product_id', v_line.product_id,
            'title', v_line.title,
            'variant_id', v_line.variant_id,
            'sku', v_line.sku,
            'size', v_line.size,
            'color', v_line.color,
            'price_paise', v_line.price_paise,
            'quantity', v_line.quantity,
            'line_total_paise', (v_line.quantity * v_line.price_paise),
            'seller_id', v_line.seller_id,
            'seller_name', v_line.seller_name,
            'is_made_to_order', v_line.is_made_to_order
        );
    END LOOP;

    IF v_items_count = 0 THEN
        RAISE EXCEPTION 'empty_cart: cannot create checkout quote for an empty cart'
            USING ERRCODE = '22000';
    END IF;

    -- 5. Calculate authoritative shipping tariff
    -- Threshold: ₹2,999 = 299900 paise
    -- Subtotal >= 299900 -> Free shipping (0)
    -- Subtotal < 299900 -> Standard shipping = ₹99 (9900 paise)
    IF v_subtotal_paise >= 299900 THEN
        v_shipping_fee_paise := 0;
    ELSE
        v_shipping_fee_paise := 9900;
    END IF;

    -- 6. Financial summary
    v_discount_paise := 0; -- No active promo code engine in MVP
    v_tax_paise := 0;      -- Catalog prices are GST-inclusive, 0 incremental tax
    v_total_payable_paise := v_subtotal_paise - v_discount_paise + v_shipping_fee_paise + v_tax_paise;

    -- Authoritative 15-minute checkout TTL
    v_expires_at := CURRENT_TIMESTAMP + INTERVAL '15 minutes';
    v_quote_id := gen_random_uuid();

    -- 7. Supersede any existing pending quotes for this customer
    FOR v_prev_quote IN
        SELECT id FROM public.checkout_quotes
        WHERE user_id = v_user_id AND status = 'pending'::checkout_quote_status
    LOOP
        PERFORM public.release_quote_reservations(v_prev_quote.id);
        UPDATE public.checkout_quotes
        SET status = 'cancelled'::checkout_quote_status,
            expires_at = CURRENT_TIMESTAMP
        WHERE id = v_prev_quote.id;
    END LOOP;

    -- 8. Insert new authoritative quote
    INSERT INTO public.checkout_quotes (
        id, user_id, subtotal_paise, discount_paise, shipping_fee_paise,
        tax_paise, total_payable_paise, shipping_address, status, expires_at
    ) VALUES (
        v_quote_id, v_user_id, v_subtotal_paise, v_discount_paise, v_shipping_fee_paise,
        v_tax_paise, v_total_payable_paise, v_shipping_address, 'pending'::checkout_quote_status, v_expires_at
    );

    -- 9. Atomically invoke Phase 6 inventory reservation
    -- If this fails (e.g. insufficient inventory), exception rolls back entire transaction
    v_reservation_results := public.reserve_inventory_for_quote(v_quote_id, v_items_jsonb);

    -- 10. Return server-authoritative checkout quote structure
    RETURN jsonb_build_object(
        'quote_id', v_quote_id,
        'user_id', v_user_id,
        'subtotal_paise', v_subtotal_paise,
        'discount_paise', v_discount_paise,
        'shipping_fee_paise', v_shipping_fee_paise,
        'tax_paise', v_tax_paise,
        'total_payable_paise', v_total_payable_paise,
        'shipping_address', v_shipping_address,
        'status', 'pending',
        'expires_at', v_expires_at,
        'items', v_quote_items_details,
        'reservations', v_reservation_results
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 3. GET CHECKOUT QUOTE
CREATE OR REPLACE FUNCTION public.get_checkout_quote(p_quote_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_quote RECORD;
    v_items JSONB := '[]'::jsonb;
BEGIN
    v_user_id := auth.uid();

    SELECT id, user_id, subtotal_paise, discount_paise, shipping_fee_paise,
           tax_paise, total_payable_paise, shipping_address, status, expires_at, created_at
    INTO v_quote
    FROM public.checkout_quotes
    WHERE id = p_quote_id;

    IF v_quote.id IS NULL THEN
        RAISE EXCEPTION 'quote_not_found: checkout quote % does not exist', p_quote_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Security: Quote belongs to caller or admin/support
    IF v_user_id IS NOT NULL AND v_quote.user_id IS NOT NULL AND v_user_id != v_quote.user_id THEN
        IF NOT (public.has_role('admin_super') OR public.has_role('admin_support') OR public.has_role('admin_catalog')) THEN
            RAISE EXCEPTION 'forbidden: cannot access another customer checkout quote'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Eager expiration check: If past expiry and still pending, mark expired & release holds
    IF v_quote.status = 'pending'::checkout_quote_status AND v_quote.expires_at <= CURRENT_TIMESTAMP THEN
        PERFORM public.release_quote_reservations(p_quote_id);
        UPDATE public.checkout_quotes
        SET status = 'expired'::checkout_quote_status
        WHERE id = p_quote_id;
        v_quote.status := 'expired'::checkout_quote_status;
    END IF;

    -- Assemble items from active/held reservations linked to quote
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'reservation_id', ir.id,
        'variant_id', ir.variant_id,
        'sku', pv.sku,
        'size', pv.size,
        'color', pv.color,
        'title', p.title,
        'seller_id', p.seller_id,
        'seller_name', s.business_name,
        'quantity', ir.quantity,
        'price_paise', pv.price_paise,
        'line_total_paise', (ir.quantity * pv.price_paise),
        'status', ir.status
    )), '[]'::jsonb)
    INTO v_items
    FROM public.inventory_reservations ir
    JOIN public.product_variants pv ON ir.variant_id = pv.id
    JOIN public.products p ON pv.product_id = p.id
    JOIN public.sellers s ON p.seller_id = s.id
    WHERE ir.quote_id = p_quote_id;

    RETURN jsonb_build_object(
        'quote_id', v_quote.id,
        'user_id', v_quote.user_id,
        'subtotal_paise', v_quote.subtotal_paise,
        'discount_paise', v_quote.discount_paise,
        'shipping_fee_paise', v_quote.shipping_fee_paise,
        'tax_paise', v_quote.tax_paise,
        'total_payable_paise', v_quote.total_payable_paise,
        'shipping_address', v_quote.shipping_address,
        'status', v_quote.status,
        'expires_at', v_quote.expires_at,
        'created_at', v_quote.created_at,
        'items', v_items
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 4. CANCEL CHECKOUT QUOTE
CREATE OR REPLACE FUNCTION public.cancel_checkout_quote(p_quote_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
    v_quote_user_id UUID;
    v_status checkout_quote_status;
BEGIN
    v_user_id := auth.uid();

    SELECT user_id, status
    INTO v_quote_user_id, v_status
    FROM public.checkout_quotes
    WHERE id = p_quote_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'quote_not_found: checkout quote % does not exist', p_quote_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Security: Only owner or admin can cancel
    IF v_user_id IS NOT NULL AND v_quote_user_id IS NOT NULL AND v_user_id != v_quote_user_id THEN
        IF NOT (public.has_role('admin_super') OR public.has_role('admin_support')) THEN
            RAISE EXCEPTION 'forbidden: cannot cancel another customer quote'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_status != 'pending'::checkout_quote_status THEN
        RETURN false;
    END IF;

    -- Release reservations and update status
    PERFORM public.release_quote_reservations(p_quote_id);

    UPDATE public.checkout_quotes
    SET status = 'cancelled'::checkout_quote_status,
        expires_at = CURRENT_TIMESTAMP
    WHERE id = p_quote_id;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 5. GRANTS
GRANT EXECUTE ON FUNCTION public.create_checkout_quote(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_checkout_quote(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_checkout_quote(UUID) TO authenticated;
