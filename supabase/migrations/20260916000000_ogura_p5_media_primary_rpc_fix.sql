-- ============================================================================
-- OGURA FORWARD CORRECTIVE MIGRATION: P5 MEDIA & INVENTORY RPC REPAIR
-- File: supabase/migrations/20260916000000_ogura_p5_media_primary_rpc_fix.sql
-- 
-- Phase: Post-P10 Forward Corrective Patch (Discovered during P11 Integration Audit)
-- Target Functions:
--   1. public.get_customer_cart()
--   2. public.get_customer_wishlist()
--
-- Defects Repaired:
--   1. Defect #1 (Media Primary Imagery):
--      Both functions contained an invalid column predicate:
--        ma.is_primary = true
--      Table public.media_assets designates primary imagery via:
--        ma.slot_role = 'primary'::public.media_slot_role
--      This caused runtime SQLSTATE 42703 ('column ma.is_primary does not exist').
--
--   2. Defect #2 (Product Variant Stock Column):
--      public.get_customer_cart() referenced nonexistent column:
--        pv.stock_quantity
--      Authoritative inventory is maintained in public.inventory_items (quantity_on_hand,
--      quantity_reserved). Available stock is derived via:
--        CASE
--          WHEN p.is_made_to_order IS TRUE THEN 999999
--          ELSE GREATEST(COALESCE(ii.quantity_on_hand, 0) - COALESCE(ii.quantity_reserved, 0), 0)
--        END
--      joined via:
--        LEFT JOIN public.inventory_items ii ON ii.variant_id = cl.variant_id
--
-- Invariants Preserved:
--   - P1–P10 migration files remain 100% frozen and historically immutable.
--   - Function signatures, return types, SECURITY DEFINER, search_path,
--     authorization checks, and output JSON structures remain identical.
--   - Zero changes to product pricing, cart quantity rules, or table schemas.
-- ============================================================================

-- 1. Correct public.get_customer_cart()
CREATE OR REPLACE FUNCTION public.get_customer_cart()
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
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
                    WHERE ma.product_id = p.id AND ma.slot_role = 'primary'::public.media_slot_role
                    LIMIT 1
                ),
                'stock_quantity', CASE
                    WHEN p.is_made_to_order IS TRUE THEN 999999
                    ELSE GREATEST(COALESCE(ii.quantity_on_hand, 0) - COALESCE(ii.quantity_reserved, 0), 0)
                END
            ) ORDER BY cl.created_at ASC
        ), '[]'::jsonb),
        COALESCE(SUM(pv.price_paise * cl.quantity), 0),
        COALESCE(SUM(cl.quantity), 0)
    INTO v_lines, v_subtotal, v_items_count
    FROM public.cart_lines cl
    JOIN public.product_variants pv ON cl.variant_id = pv.id
    JOIN public.products p ON pv.product_id = p.id
    LEFT JOIN public.inventory_items ii ON ii.variant_id = cl.variant_id
    WHERE cl.cart_id = v_cart_id;

    RETURN jsonb_build_object(
        'cart_id', v_cart_id,
        'updated_at', v_cart_updated_at,
        'items_count', v_items_count,
        'subtotal_paise', v_subtotal,
        'lines', v_lines
    );
END;
$$;

-- 2. Correct public.get_customer_wishlist()
CREATE OR REPLACE FUNCTION public.get_customer_wishlist()
RETURNS JSONB
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
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
                WHERE ma.product_id = p.id AND ma.slot_role = 'primary'::public.media_slot_role
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
$$;

-- 3. Ensure permissions are intact
GRANT EXECUTE ON FUNCTION public.get_customer_cart() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_customer_wishlist() TO authenticated;
