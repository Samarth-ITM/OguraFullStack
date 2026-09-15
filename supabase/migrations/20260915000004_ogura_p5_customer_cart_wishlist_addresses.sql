-- OGURA PHASE 5: CUSTOMER CART, WISHLIST & PERSISTENT ADDRESSES FOUNDATION
-- Migration: 20260915000004_ogura_p5_customer_cart_wishlist_addresses.sql

-- ============================================================================
-- 1. ADDRESS INTEGRITY & DEFAULT ADDRESS INVARIANT
-- ============================================================================

-- 1.1 Unique Partial Index: Guarantees at most ONE active default address per customer
CREATE UNIQUE INDEX IF NOT EXISTS uq_customer_single_default_address 
ON public.customer_addresses (user_id) 
WHERE is_default = true AND is_active = true;

-- -- 1.2 Default Address Maintenance: BEFORE Trigger Function
CREATE OR REPLACE FUNCTION public.maintain_customer_default_address_before()
RETURNS TRIGGER AS $$
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.user_id IS NULL THEN
            NEW.user_id := auth.uid();
        END IF;

        IF NEW.is_active = false THEN
            NEW.is_default := false;
        END IF;

        -- If customer has no other active default address, this address becomes default
        IF NEW.is_active = true AND (NEW.is_default = true OR NOT EXISTS (
            SELECT 1 FROM public.customer_addresses 
            WHERE user_id = NEW.user_id 
              AND is_active = true 
              AND is_default = true
        )) THEN
            NEW.is_default := true;
            -- Demote any other active default address prior to insert to prevent index collision
            UPDATE public.customer_addresses
            SET is_default = false
            WHERE user_id = NEW.user_id 
              AND is_default = true 
              AND is_active = true;
        END IF;

    ELSIF TG_OP = 'UPDATE' THEN
        -- If deactivated, force is_default to false
        IF NEW.is_active = false THEN
            NEW.is_default := false;
        END IF;

        -- If explicitly promoted to active default, demote others prior to update
        IF NEW.is_default = true AND NEW.is_active = true AND (OLD.is_default = false OR OLD.is_active = false) THEN
            UPDATE public.customer_addresses
            SET is_default = false
            WHERE user_id = NEW.user_id 
              AND id != NEW.id 
              AND is_default = true 
              AND is_active = true;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_maintain_customer_default_address ON public.customer_addresses;
DROP TRIGGER IF EXISTS trg_maintain_customer_default_address_before ON public.customer_addresses;
CREATE TRIGGER trg_maintain_customer_default_address_before
BEFORE INSERT OR UPDATE OF is_default, is_active ON public.customer_addresses
FOR EACH ROW EXECUTE FUNCTION public.maintain_customer_default_address_before();

-- 1.2b Default Address Maintenance: AFTER Trigger Function (Re-promotes when active default is unset or deleted)
CREATE OR REPLACE FUNCTION public.maintain_customer_default_address_after()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_was_default_active BOOLEAN;
BEGIN
    IF pg_trigger_depth() > 1 THEN
        IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        v_user_id := OLD.user_id;
        v_was_default_active := (OLD.is_default = true AND OLD.is_active = true);
    ELSE
        v_user_id := NEW.user_id;
        v_was_default_active := (OLD.is_default = true AND OLD.is_active = true AND (NEW.is_default = false OR NEW.is_active = false));
    END IF;

    IF v_was_default_active THEN
        -- Check if another active default already exists
        IF NOT EXISTS (
            SELECT 1 FROM public.customer_addresses
            WHERE user_id = v_user_id
              AND is_active = true
              AND is_default = true
        ) THEN
            -- Promote the most recently updated active address
            UPDATE public.customer_addresses
            SET is_default = true
            WHERE id = (
                SELECT id FROM public.customer_addresses
                WHERE user_id = v_user_id
                  AND is_active = true
                ORDER BY updated_at DESC, created_at DESC
                LIMIT 1
            );
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_maintain_customer_default_address_delete ON public.customer_addresses;
DROP TRIGGER IF EXISTS trg_maintain_customer_default_address_after ON public.customer_addresses;
CREATE TRIGGER trg_maintain_customer_default_address_after
AFTER UPDATE OF is_default, is_active OR DELETE ON public.customer_addresses
FOR EACH ROW EXECUTE FUNCTION public.maintain_customer_default_address_after();

-- 1.3 Address Promotion RPC
CREATE OR REPLACE FUNCTION public.set_default_customer_address(p_address_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'unauthenticated: user must be signed in' USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.customer_addresses
        WHERE id = p_address_id AND user_id = v_caller_id AND is_active = true
    ) THEN
        RAISE EXCEPTION 'address_not_found: address does not exist or does not belong to caller';
    END IF;

    UPDATE public.customer_addresses
    SET is_default = true,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_address_id AND user_id = v_caller_id;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- ============================================================================
-- 2. PERSISTENT CUSTOMER CART ENGINE & GUEST MERGE
-- ============================================================================

-- 2.1 Get or Create Authenticated Customer Cart
CREATE OR REPLACE FUNCTION public.get_or_create_customer_cart()
RETURNS UUID AS $$
DECLARE
    v_caller_id UUID;
    v_cart_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'unauthenticated: user must be signed in' USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_cart_id
    FROM public.carts
    WHERE user_id = v_caller_id;

    IF v_cart_id IS NULL THEN
        INSERT INTO public.carts (user_id)
        VALUES (v_caller_id)
        ON CONFLICT (user_id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
        RETURNING id INTO v_cart_id;
    END IF;

    RETURN v_cart_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 2.2 Read Customer Cart Projection RPC (Authoritative pricing from catalog)
CREATE OR REPLACE FUNCTION public.get_customer_cart()
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_cart_id UUID;
    v_cart_updated_at TIMESTAMPTZ;
    v_lines JSONB;
    v_subtotal BIGINT := 0;
    v_items_count INTEGER := 0;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'unauthenticated: user must be signed in' USING ERRCODE = '42501';
    END IF;

    SELECT id, updated_at INTO v_cart_id, v_cart_updated_at
    FROM public.carts
    WHERE user_id = v_caller_id;

    IF v_cart_id IS NULL THEN
        RETURN jsonb_build_object(
            'cart_id', NULL,
            'items_count', 0,
            'subtotal_paise', 0,
            'lines', '[]'::jsonb
        );
    END IF;

    SELECT 
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'line_id', cl.id,
                'variant_id', pv.id,
                'product_id', p.id,
                'title', p.title,
                'slug', p.slug,
                'sku', pv.sku,
                'size', pv.size,
                'color', pv.color,
                'color_hex', pv.color_hex,
                'quantity', cl.quantity,
                'price_paise', pv.price_paise,
                'compare_at_price_paise', pv.compare_at_price_paise,
                'is_made_to_order', p.is_made_to_order,
                'primary_image_url', (
                    SELECT asset_url FROM public.media_assets ma 
                    WHERE ma.product_id = p.id AND ma.is_primary = true 
                    LIMIT 1
                ),
                'stock_quantity', pv.stock_quantity
            ) ORDER BY cl.created_at ASC
        ), '[]'::jsonb),
        COALESCE(SUM(pv.price_paise * cl.quantity), 0),
        COALESCE(SUM(cl.quantity), 0)
    INTO v_lines, v_subtotal, v_items_count
    FROM public.cart_lines cl
    JOIN public.product_variants pv ON cl.variant_id = pv.id
    JOIN public.products p ON pv.product_id = p.id
    WHERE cl.cart_id = v_cart_id;

    RETURN jsonb_build_object(
        'cart_id', v_cart_id,
        'updated_at', v_cart_updated_at,
        'items_count', v_items_count,
        'subtotal_paise', v_subtotal,
        'lines', v_lines
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 2.3 Add to Customer Cart RPC
CREATE OR REPLACE FUNCTION public.add_to_customer_cart(
    p_variant_id UUID,
    p_quantity INTEGER DEFAULT 1
)
RETURNS UUID AS $$
DECLARE
    v_cart_id UUID;
    v_line_id UUID;
    v_safe_qty INTEGER;
BEGIN
    IF p_quantity < 1 THEN
        RAISE EXCEPTION 'invalid_quantity: quantity must be at least 1';
    END IF;
    v_safe_qty := LEAST(10, p_quantity);

    IF NOT EXISTS (SELECT 1 FROM public.product_variants WHERE id = p_variant_id) THEN
        RAISE EXCEPTION 'variant_not_found: product variant % does not exist', p_variant_id;
    END IF;

    v_cart_id := public.get_or_create_customer_cart();

    -- Insert or add quantity up to max 10
    INSERT INTO public.cart_lines (cart_id, variant_id, quantity)
    VALUES (v_cart_id, p_variant_id, v_safe_qty)
    ON CONFLICT (cart_id, variant_id) DO UPDATE
    SET quantity = LEAST(10, public.cart_lines.quantity + v_safe_qty),
        updated_at = CURRENT_TIMESTAMP
    RETURNING id INTO v_line_id;

    UPDATE public.carts SET updated_at = CURRENT_TIMESTAMP WHERE id = v_cart_id;

    RETURN v_line_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 2.4 Update Cart Line Quantity RPC
CREATE OR REPLACE FUNCTION public.update_cart_line_quantity(
    p_line_id UUID,
    p_quantity INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_cart_id UUID;
BEGIN
    SELECT cart_id INTO v_cart_id
    FROM public.cart_lines
    WHERE id = p_line_id;

    IF v_cart_id IS NULL THEN
        RAISE EXCEPTION 'line_not_found: cart line does not exist';
    END IF;

    -- Verify caller owns this cart
    IF NOT EXISTS (
        SELECT 1 FROM public.carts 
        WHERE id = v_cart_id AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'insufficient_privilege: cannot mutate cart line of another customer'
            USING ERRCODE = '42501';
    END IF;

    IF p_quantity <= 0 THEN
        DELETE FROM public.cart_lines WHERE id = p_line_id;
    ELSE
        UPDATE public.cart_lines
        SET quantity = LEAST(10, p_quantity),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_line_id;
    END IF;

    UPDATE public.carts SET updated_at = CURRENT_TIMESTAMP WHERE id = v_cart_id;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 2.5 Remove Cart Line RPC
CREATE OR REPLACE FUNCTION public.remove_cart_line(p_line_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.update_cart_line_quantity(p_line_id, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 2.6 Clear Customer Cart RPC
CREATE OR REPLACE FUNCTION public.clear_customer_cart()
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_cart_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'unauthenticated: user must be signed in' USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_cart_id FROM public.carts WHERE user_id = v_caller_id;

    IF v_cart_id IS NOT NULL THEN
        DELETE FROM public.cart_lines WHERE cart_id = v_cart_id;
        UPDATE public.carts SET updated_at = CURRENT_TIMESTAMP WHERE id = v_cart_id;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 2.7 Guest Cart -> Authenticated Cart Merge RPC (Idempotent & Deterministic)
CREATE OR REPLACE FUNCTION public.merge_guest_cart(p_session_id VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_guest_cart_id UUID;
    v_customer_cart_id UUID;
    r_guest_line RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'unauthenticated: caller must be authenticated to merge guest cart'
            USING ERRCODE = '42501';
    END IF;

    IF p_session_id IS NULL OR TRIM(p_session_id) = '' THEN
        RETURN true; -- No guest session provided; safe no-op
    END IF;

    -- Find unassigned guest cart
    SELECT id INTO v_guest_cart_id
    FROM public.carts
    WHERE session_id = p_session_id AND user_id IS NULL;

    IF v_guest_cart_id IS NULL THEN
        RETURN true; -- Already merged or empty; idempotent completion
    END IF;

    -- Obtain or create customer's persistent cart
    v_customer_cart_id := public.get_or_create_customer_cart();

    -- Merge each guest line into customer cart with LEAST(10, existing + guest)
    FOR r_guest_line IN (
        SELECT variant_id, quantity 
        FROM public.cart_lines 
        WHERE cart_id = v_guest_cart_id
    ) LOOP
        INSERT INTO public.cart_lines (cart_id, variant_id, quantity)
        VALUES (v_customer_cart_id, r_guest_line.variant_id, LEAST(10, r_guest_line.quantity))
        ON CONFLICT (cart_id, variant_id) DO UPDATE
        SET quantity = LEAST(10, public.cart_lines.quantity + r_guest_line.quantity),
            updated_at = CURRENT_TIMESTAMP;
    END LOOP;

    -- Cleanup guest cart (cascades lines)
    DELETE FROM public.carts WHERE id = v_guest_cart_id;

    UPDATE public.carts SET updated_at = CURRENT_TIMESTAMP WHERE id = v_customer_cart_id;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- ============================================================================
-- 3. PERSISTENT CUSTOMER WISHLIST ENGINE
-- ============================================================================

-- 3.1 Toggle Wishlist Item RPC
CREATE OR REPLACE FUNCTION public.toggle_wishlist_item(p_product_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_exists BOOLEAN;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'unauthenticated: user must be signed in to modify wishlist'
            USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.products WHERE id = p_product_id) THEN
        RAISE EXCEPTION 'product_not_found: product % does not exist', p_product_id;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.customer_wishlist
        WHERE user_id = v_caller_id AND product_id = p_product_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM public.customer_wishlist
        WHERE user_id = v_caller_id AND product_id = p_product_id;
        RETURN false; -- Removed
    ELSE
        INSERT INTO public.customer_wishlist (user_id, product_id)
        VALUES (v_caller_id, p_product_id)
        ON CONFLICT (user_id, product_id) DO NOTHING;
        RETURN true; -- Added
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 3.2 Read Customer Wishlist Projection RPC
CREATE OR REPLACE FUNCTION public.get_customer_wishlist()
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_result JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'unauthenticated: user must be signed in' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'product_id', p.id,
            'title', p.title,
            'slug', p.slug,
            'brand_name', b.name,
            'brand_slug', b.slug,
            'min_price_paise', (SELECT MIN(price_paise) FROM public.product_variants pv WHERE pv.product_id = p.id),
            'max_price_paise', (SELECT MAX(price_paise) FROM public.product_variants pv WHERE pv.product_id = p.id),
            'primary_image_url', (
                SELECT asset_url FROM public.media_assets ma 
                WHERE ma.product_id = p.id AND ma.is_primary = true 
                LIMIT 1
            ),
            'added_at', cw.created_at
        ) ORDER BY cw.created_at DESC
    ), '[]'::jsonb)
    INTO v_result
    FROM public.customer_wishlist cw
    JOIN public.products p ON cw.product_id = p.id
    JOIN public.brands b ON p.brand_id = b.id
    WHERE cw.user_id = v_caller_id;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- ============================================================================
-- 4. GRANTS
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.maintain_customer_default_address_before() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.maintain_customer_default_address_after() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.set_default_customer_address(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_customer_cart() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_customer_cart() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_to_customer_cart(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_cart_line_quantity(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_cart_line(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_customer_cart() TO authenticated;
GRANT EXECUTE ON FUNCTION public.merge_guest_cart(VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_wishlist_item(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_customer_wishlist() TO authenticated;
