-- ============================================================================
-- OGURA P5 FORWARD CORRECTION TEST SUITE: DEFECT #2 & DEFECT #1 VERIFICATION
-- File: supabase/tests/p5_defect2_stock_quantity_test.sql
-- ============================================================================

BEGIN;

-- Setup test isolated roles if not exist
DO $$ BEGIN
    CREATE ROLE authenticated NOLOGIN;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE ROLE anon NOLOGIN;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 1. Test Users & Profiles
INSERT INTO auth.users (id, email) VALUES
    ('f5000000-0000-0000-0000-000000000001', 'user_a@p5fix.test'),
    ('f5000000-0000-0000-0000-000000000002', 'user_b@p5fix.test'),
    ('f5000000-0000-0000-0000-000000000003', 'seller@p5fix.test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email, phone) VALUES
    ('f5000000-0000-0000-0000-000000000001', 'User A P5Fix', 'user_a@p5fix.test', '+919999880001'),
    ('f5000000-0000-0000-0000-000000000002', 'User B P5Fix', 'user_b@p5fix.test', '+919999880002'),
    ('f5000000-0000-0000-0000-000000000003', 'Seller P5Fix', 'seller@p5fix.test', '+919999880003')
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

INSERT INTO public.user_roles (user_id, role) VALUES
    ('f5000000-0000-0000-0000-000000000001', 'customer'),
    ('f5000000-0000-0000-0000-000000000002', 'customer'),
    ('f5000000-0000-0000-0000-000000000003', 'seller')
ON CONFLICT (user_id, role) DO NOTHING;

-- 2. Test Catalog Hierarchy
INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status)
VALUES (
    'f5000000-0000-0000-0000-000000000010',
    'f5000000-0000-0000-0000-000000000003',
    'P5Fix Atelier',
    'P5Fix Atelier LLP',
    'p5fix-atelier',
    'active'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.brands (id, seller_id, name, slug)
VALUES (
    'f5000000-0000-0000-0000-000000000020',
    'f5000000-0000-0000-0000-000000000010',
    'P5Fix Brand',
    'p5fix-brand'
) ON CONFLICT (id) DO NOTHING;

-- Standard product (ready to wear)
INSERT INTO public.products (
    id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order
) VALUES (
    'f5000000-0000-0000-0000-000000000030',
    'f5000000-0000-0000-0000-000000000010',
    'f5000000-0000-0000-0000-000000000020',
    (SELECT id FROM public.categories WHERE slug = 'clothing'),
    (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
    'P5Fix Silk Dress',
    'p5fix-silk-dress',
    'live',
    false
) ON CONFLICT (id) DO NOTHING;

-- MTO product
INSERT INTO public.products (
    id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order
) VALUES (
    'f5000000-0000-0000-0000-000000000031',
    'f5000000-0000-0000-0000-000000000010',
    'f5000000-0000-0000-0000-000000000020',
    (SELECT id FROM public.categories WHERE slug = 'clothing'),
    (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
    'P5Fix Bespoke Gown',
    'p5fix-bespoke-gown',
    'live',
    true
) ON CONFLICT (id) DO NOTHING;

-- Product media with primary slot role
INSERT INTO public.media_assets (
    id, product_id, slot_role, asset_url, sort_order
) VALUES (
    'f5000000-0000-0000-0000-000000000040',
    'f5000000-0000-0000-0000-000000000030',
    'primary'::public.media_slot_role,
    'https://ogura.test/media/p5fix-silk-dress-primary.webp',
    1
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.media_assets (
    id, product_id, slot_role, asset_url, sort_order
) VALUES (
    'f5000000-0000-0000-0000-000000000041',
    'f5000000-0000-0000-0000-000000000031',
    'primary'::public.media_slot_role,
    'https://ogura.test/media/p5fix-bespoke-gown-primary.webp',
    1
) ON CONFLICT (id) DO NOTHING;

-- Variants
-- V1: Normal stocked variant (15 on hand, 0 reserved -> 15 available)
INSERT INTO public.product_variants (
    id, product_id, sku, size, color, color_hex, price_paise, compare_at_price_paise
) VALUES (
    'f5000000-0000-0000-0000-000000000051',
    'f5000000-0000-0000-0000-000000000030',
    'SKU-P5FIX-V1', 'S', 'Ivory', '#FFFFF0', 2500000, 3000000
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.inventory_items (
    id, variant_id, quantity_on_hand, quantity_reserved
) VALUES (
    'f5000000-0000-0000-0000-000000000061',
    'f5000000-0000-0000-0000-000000000051',
    15, 0
) ON CONFLICT (variant_id) DO UPDATE SET quantity_on_hand = 15, quantity_reserved = 0;

-- V2: Partially reserved variant (15 on hand, 4 reserved -> 11 available)
INSERT INTO public.product_variants (
    id, product_id, sku, size, color, color_hex, price_paise, compare_at_price_paise
) VALUES (
    'f5000000-0000-0000-0000-000000000052',
    'f5000000-0000-0000-0000-000000000030',
    'SKU-P5FIX-V2', 'M', 'Ivory', '#FFFFF0', 2500000, 3000000
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.inventory_items (
    id, variant_id, quantity_on_hand, quantity_reserved
) VALUES (
    'f5000000-0000-0000-0000-000000000062',
    'f5000000-0000-0000-0000-000000000052',
    15, 4
) ON CONFLICT (variant_id) DO UPDATE SET quantity_on_hand = 15, quantity_reserved = 4;

-- V3: Fully reserved variant (5 on hand, 5 reserved -> 0 available)
INSERT INTO public.product_variants (
    id, product_id, sku, size, color, color_hex, price_paise, compare_at_price_paise
) VALUES (
    'f5000000-0000-0000-0000-000000000053',
    'f5000000-0000-0000-0000-000000000030',
    'SKU-P5FIX-V3', 'L', 'Ivory', '#FFFFF0', 2500000, 3000000
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.inventory_items (
    id, variant_id, quantity_on_hand, quantity_reserved
) VALUES (
    'f5000000-0000-0000-0000-000000000063',
    'f5000000-0000-0000-0000-000000000053',
    5, 5
) ON CONFLICT (variant_id) DO UPDATE SET quantity_on_hand = 5, quantity_reserved = 5;

-- V4: Standard variant with NO inventory_items row -> 0 available
INSERT INTO public.product_variants (
    id, product_id, sku, size, color, color_hex, price_paise, compare_at_price_paise
) VALUES (
    'f5000000-0000-0000-0000-000000000054',
    'f5000000-0000-0000-0000-000000000030',
    'SKU-P5FIX-V4', 'XL', 'Ivory', '#FFFFF0', 2500000, 3000000
) ON CONFLICT (id) DO NOTHING;

DELETE FROM public.inventory_items WHERE variant_id = 'f5000000-0000-0000-0000-000000000054';

-- V5: Made-to-order variant with NO inventory_items row -> 999999 available
INSERT INTO public.product_variants (
    id, product_id, sku, size, color, color_hex, price_paise, compare_at_price_paise
) VALUES (
    'f5000000-0000-0000-0000-000000000055',
    'f5000000-0000-0000-0000-000000000031',
    'SKU-P5FIX-V5-MTO', 'Custom', 'Gold', '#FFD700', 7500000, 9000000
) ON CONFLICT (id) DO NOTHING;

DELETE FROM public.inventory_items WHERE variant_id = 'f5000000-0000-0000-0000-000000000055';

-- ============================================================================
-- EXECUTE ASSERTIONS
-- ============================================================================
CREATE OR REPLACE FUNCTION pg_temp.get_line_for_variant(p_cart JSONB, p_variant_id UUID)
RETURNS JSONB AS $$
    SELECT elem
    FROM jsonb_array_elements(p_cart->'lines') AS elem
    WHERE (elem->>'variant_id')::UUID = p_variant_id
    LIMIT 1;
$$ LANGUAGE sql;

DO $$
DECLARE
    v_cart_res JSONB;
    v_line JSONB;
    v_wish_res JSONB;
    v_line_id UUID;
    v_threw BOOLEAN;
    v_stock INTEGER;
BEGIN
    -- ------------------------------------------------------------------------
    -- TEST I: Unauthenticated request rejected with SQLSTATE 42501
    -- ------------------------------------------------------------------------
    v_threw := false;
    BEGIN
        PERFORM set_config('request.jwt.claim.sub', '', true);
        PERFORM public.get_customer_cart();
    EXCEPTION WHEN SQLSTATE '42501' THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'TEST I FAIL: Unauthenticated get_customer_cart did not throw 42501';
    END IF;
    RAISE NOTICE 'TEST I PASS: Unauthenticated call rejected with 42501';

    -- ------------------------------------------------------------------------
    -- TEST F: Empty cart succeeds for customer with no cart row
    -- ------------------------------------------------------------------------
    PERFORM set_config('request.jwt.claim.sub', 'f5000000-0000-0000-0000-000000000001', true);
    v_cart_res := public.get_customer_cart();
    IF (v_cart_res->>'items_count')::INTEGER != 0 OR jsonb_array_length(v_cart_res->'lines') != 0 THEN
        RAISE EXCEPTION 'TEST F FAIL: Expected empty cart for new customer, got %', v_cart_res;
    END IF;
    RAISE NOTICE 'TEST F PASS: Empty cart succeeds';

    -- ------------------------------------------------------------------------
    -- TEST A: Cart with normal stocked variant (15 on-hand, 0 reserved -> 15)
    -- ------------------------------------------------------------------------
    v_line_id := public.add_to_customer_cart('f5000000-0000-0000-0000-000000000051', 2);
    v_cart_res := public.get_customer_cart();
    v_line := pg_temp.get_line_for_variant(v_cart_res, 'f5000000-0000-0000-0000-000000000051');
    v_stock := (v_line->>'stock_quantity')::INTEGER;
    IF v_stock != 15 THEN
        RAISE EXCEPTION 'TEST A FAIL: Expected stock_quantity 15 for normal variant, got %', v_stock;
    END IF;
    -- Verify primary image URL preserved
    IF (v_line->>'primary_image_url') != 'https://ogura.test/media/p5fix-silk-dress-primary.webp' THEN
        RAISE EXCEPTION 'TEST A FAIL: Expected primary_image_url preserved, got %', v_line->>'primary_image_url';
    END IF;
    RAISE NOTICE 'TEST A PASS: Normal stocked variant returns available stock = 15 and primary_image_url';

    -- ------------------------------------------------------------------------
    -- TEST B: Cart with reserved inventory (15 on-hand, 4 reserved -> 11)
    -- ------------------------------------------------------------------------
    PERFORM public.add_to_customer_cart('f5000000-0000-0000-0000-000000000052', 1);
    v_cart_res := public.get_customer_cart();
    v_line := pg_temp.get_line_for_variant(v_cart_res, 'f5000000-0000-0000-0000-000000000052');
    v_stock := (v_line->>'stock_quantity')::INTEGER;
    IF v_stock != 11 THEN
        RAISE EXCEPTION 'TEST B FAIL: Expected stock_quantity 11 (15-4) for reserved variant, got %', v_stock;
    END IF;
    RAISE NOTICE 'TEST B PASS: Partially reserved inventory returns available stock = 11';

    -- ------------------------------------------------------------------------
    -- TEST C: Cart with zero available inventory (5 on-hand, 5 reserved -> 0)
    -- ------------------------------------------------------------------------
    PERFORM public.add_to_customer_cart('f5000000-0000-0000-0000-000000000053', 1);
    v_cart_res := public.get_customer_cart();
    v_line := pg_temp.get_line_for_variant(v_cart_res, 'f5000000-0000-0000-0000-000000000053');
    v_stock := (v_line->>'stock_quantity')::INTEGER;
    IF v_stock != 0 THEN
        RAISE EXCEPTION 'TEST C FAIL: Expected stock_quantity 0 for zero available stock, got %', v_stock;
    END IF;
    RAISE NOTICE 'TEST C PASS: Zero available inventory returns stock = 0';

    -- ------------------------------------------------------------------------
    -- TEST D: Cart with no inventory_items row
    --   D1: Non-MTO without inventory_items -> 0
    --   D2: MTO without inventory_items -> 999999
    -- ------------------------------------------------------------------------
    PERFORM public.add_to_customer_cart('f5000000-0000-0000-0000-000000000054', 1);
    PERFORM public.add_to_customer_cart('f5000000-0000-0000-0000-000000000055', 1);
    v_cart_res := public.get_customer_cart();
    
    -- V4 (Non-MTO, no inventory_items)
    v_line := pg_temp.get_line_for_variant(v_cart_res, 'f5000000-0000-0000-0000-000000000054');
    v_stock := (v_line->>'stock_quantity')::INTEGER;
    IF v_stock != 0 THEN
        RAISE EXCEPTION 'TEST D1 FAIL: Expected 0 for non-MTO variant without inventory row, got %', v_stock;
    END IF;
    
    -- V5 (MTO, no inventory_items)
    v_line := pg_temp.get_line_for_variant(v_cart_res, 'f5000000-0000-0000-0000-000000000055');
    v_stock := (v_line->>'stock_quantity')::INTEGER;
    IF v_stock != 999999 THEN
        RAISE EXCEPTION 'TEST D2 FAIL: Expected 999999 for MTO variant, got %', v_stock;
    END IF;
    IF (v_line->>'is_made_to_order')::BOOLEAN != true THEN
        RAISE EXCEPTION 'TEST D2 FAIL: Expected is_made_to_order true, got %', v_line->>'is_made_to_order';
    END IF;
    RAISE NOTICE 'TEST D PASS: Non-MTO without inventory returns 0; MTO returns 999999';

    -- ------------------------------------------------------------------------
    -- TEST E: Cart with multiple variants (every line returns independently)
    -- ------------------------------------------------------------------------
    IF jsonb_array_length(v_cart_res->'lines') != 5 THEN
        RAISE EXCEPTION 'TEST E FAIL: Expected 5 distinct cart lines, got %', jsonb_array_length(v_cart_res->'lines');
    END IF;
    IF (v_cart_res->>'items_count')::INTEGER != (2 + 1 + 1 + 1 + 1) THEN
        RAISE EXCEPTION 'TEST E FAIL: Expected total items_count 6, got %', v_cart_res->>'items_count';
    END IF;
    RAISE NOTICE 'TEST E PASS: Multi-variant cart returns all 5 lines with correct individual stock';

    -- ------------------------------------------------------------------------
    -- TEST G: Wishlist still succeeds and returns primary image
    -- ------------------------------------------------------------------------
    PERFORM public.toggle_wishlist_item('f5000000-0000-0000-0000-000000000030');
    v_wish_res := public.get_customer_wishlist();
    IF jsonb_array_length(v_wish_res) != 1 THEN
        RAISE EXCEPTION 'TEST G FAIL: Expected 1 wishlist item, got %', v_wish_res;
    END IF;
    IF (v_wish_res->0->>'primary_image_url') != 'https://ogura.test/media/p5fix-silk-dress-primary.webp' THEN
        RAISE EXCEPTION 'TEST G FAIL: Expected primary image in wishlist, got %', v_wish_res->0->>'primary_image_url';
    END IF;
    RAISE NOTICE 'TEST G PASS: get_customer_wishlist succeeds with primary_image_url';

    -- ------------------------------------------------------------------------
    -- TEST H: Ownership isolation (Customer B cannot see Customer A cart)
    -- ------------------------------------------------------------------------
    PERFORM set_config('request.jwt.claim.sub', 'f5000000-0000-0000-0000-000000000002', true);
    v_cart_res := public.get_customer_cart();
    IF (v_cart_res->>'items_count')::INTEGER != 0 OR jsonb_array_length(v_cart_res->'lines') != 0 THEN
        RAISE EXCEPTION 'TEST H FAIL: Customer B saw Customer A cart items: %', v_cart_res;
    END IF;
    RAISE NOTICE 'TEST H PASS: Ownership isolation verified (Customer B has empty cart)';

    -- ------------------------------------------------------------------------
    -- TEST J: Existing cart mutations (add / update / remove)
    -- ------------------------------------------------------------------------
    PERFORM set_config('request.jwt.claim.sub', 'f5000000-0000-0000-0000-000000000001', true);
    -- Update line quantity to 4
    PERFORM public.update_cart_line_quantity(v_line_id, 4);
    v_cart_res := public.get_customer_cart();
    v_line := pg_temp.get_line_for_variant(v_cart_res, 'f5000000-0000-0000-0000-000000000051');
    IF (v_line->>'quantity')::INTEGER != 4 THEN
        RAISE EXCEPTION 'TEST J FAIL: update_cart_line_quantity did not update quantity to 4, got %', v_line->>'quantity';
    END IF;
    -- Remove line (quantity 0)
    PERFORM public.update_cart_line_quantity(v_line_id, 0);
    v_cart_res := public.get_customer_cart();
    v_line := pg_temp.get_line_for_variant(v_cart_res, 'f5000000-0000-0000-0000-000000000051');
    IF v_line IS NOT NULL THEN
        RAISE EXCEPTION 'TEST J FAIL: line was not removed when quantity updated to 0';
    END IF;
    IF jsonb_array_length(v_cart_res->'lines') != 4 THEN
        RAISE EXCEPTION 'TEST J FAIL: expected 4 remaining lines, got %', jsonb_array_length(v_cart_res->'lines');
    END IF;
    RAISE NOTICE 'TEST J PASS: Cart mutation functions (add/update/remove) fully functional';

END $$;

ROLLBACK;
