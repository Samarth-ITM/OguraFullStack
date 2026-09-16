-- ============================================================================
-- OGURA PHASE 5 CRITICAL TEST SUITE: CART, WISHLIST & ADDRESSES FOUNDATION
-- File: supabase/tests/p5_customer_cart_wishlist_addresses_test.sql
-- ============================================================================

-- 0. Ensure test roles and schema permissions
DO $$ BEGIN
    CREATE ROLE authenticated NOLOGIN;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE ROLE anon NOLOGIN;
EXCEPTION WHEN duplicate_object THEN null; END $$;

GRANT USAGE ON SCHEMA public, auth TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO authenticated, anon;

BEGIN;

-- Clean up existing P5 test fixtures
DELETE FROM public.cart_lines WHERE cart_id IN (
    SELECT id FROM public.carts WHERE session_id IN ('guest_session_p5_1', 'guest_session_p5_2')
    OR user_id IN ('a5000000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000002')
);
DELETE FROM public.carts WHERE session_id IN ('guest_session_p5_1', 'guest_session_p5_2')
    OR user_id IN ('a5000000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000002');
DELETE FROM public.customer_wishlist WHERE user_id IN ('a5000000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000002');
DELETE FROM public.customer_addresses WHERE user_id IN ('a5000000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000002');

DELETE FROM public.product_variants WHERE sku LIKE 'SKU-P5-%';
DELETE FROM public.products WHERE slug = 'p5-silk-evening-dress';
DELETE FROM public.brands WHERE slug = 'p5-haute-couture';
DELETE FROM public.sellers WHERE seller_slug = 'p5-seller-atelier';

-- Seed P5 Auth Users
INSERT INTO auth.users (id, email) VALUES
    ('a5000000-0000-0000-0000-000000000001', 'customer_alpha_p5@ogura.test'),
    ('a5000000-0000-0000-0000-000000000002', 'customer_beta_p5@ogura.test'),
    ('a5000000-0000-0000-0000-000000000003', 'seller_charlie_p5@ogura.test'),
    ('a5000000-0000-0000-0000-000000000009', 'admin_super_p5@ogura.test')
ON CONFLICT (id) DO NOTHING;

-- Seed Profiles
INSERT INTO public.profiles (id, full_name, email, phone) VALUES
    ('a5000000-0000-0000-0000-000000000001', 'Customer Alpha', 'customer_alpha_p5@ogura.test', '+919777700001'),
    ('a5000000-0000-0000-0000-000000000002', 'Customer Beta', 'customer_beta_p5@ogura.test', '+919777700002'),
    ('a5000000-0000-0000-0000-000000000003', 'Seller Charlie', 'seller_charlie_p5@ogura.test', '+919777700003'),
    ('a5000000-0000-0000-0000-000000000009', 'Admin Super P5', 'admin_super_p5@ogura.test', '+919777700009')
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

-- Seed Roles
DELETE FROM public.user_roles WHERE user_id IN (
    'a5000000-0000-0000-0000-000000000001',
    'a5000000-0000-0000-0000-000000000002',
    'a5000000-0000-0000-0000-000000000003',
    'a5000000-0000-0000-0000-000000000009'
);

INSERT INTO public.user_roles (user_id, role) VALUES
    ('a5000000-0000-0000-0000-000000000001', 'customer'),
    ('a5000000-0000-0000-0000-000000000002', 'customer'),
    ('a5000000-0000-0000-0000-000000000003', 'seller'),
    ('a5000000-0000-0000-0000-000000000009', 'admin_super');

-- Seed Catalog Hierarchy for Test Products
INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status)
VALUES (
    'b5000000-0000-0000-0000-000000000001',
    'a5000000-0000-0000-0000-000000000003',
    'P5 Charlie Atelier',
    'P5 Charlie Atelier LLP',
    'p5-seller-atelier',
    'active'
);

INSERT INTO public.brands (id, seller_id, name, slug)
VALUES (
    'b5000000-0000-0000-0000-000000000002',
    'b5000000-0000-0000-0000-000000000001',
    'P5 Haute Couture',
    'p5-haute-couture'
);

INSERT INTO public.products (
    id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order
) VALUES (
    'b5000000-0000-0000-0000-000000000003',
    'b5000000-0000-0000-0000-000000000001',
    'b5000000-0000-0000-0000-000000000002',
    (SELECT id FROM public.categories WHERE slug = 'clothing'),
    (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
    'P5 Silk Evening Dress',
    'p5-silk-evening-dress',
    'live',
    true
);

INSERT INTO public.product_variants (
    id, product_id, sku, size, color, color_hex, price_paise, compare_at_price_paise
) VALUES 
    ('b5000000-0000-0000-0000-000000000004', 'b5000000-0000-0000-0000-000000000003', 'SKU-P5-DR-S-BLK', 'S', 'Black', '#000000', 1250000, 1500000),
    ('b5000000-0000-0000-0000-000000000005', 'b5000000-0000-0000-0000-000000000003', 'SKU-P5-DR-M-BLK', 'M', 'Black', '#000000', 1250000, 1500000);

COMMIT;

-- ============================================================================
-- TEST A & B: CUSTOMER CART OWNERSHIP & TENANCY ISOLATION
-- ============================================================================
DO $$
DECLARE
    v_cart_alpha_id UUID;
    v_cart_beta_id UUID;
    v_line_alpha_id UUID;
    v_count INTEGER;
    v_threw BOOLEAN;
BEGIN
    SET ROLE authenticated;

    -- A.1 Customer Alpha adds variant S to cart
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000001';
    v_line_alpha_id := public.add_to_customer_cart('b5000000-0000-0000-0000-000000000004', 2);

    SELECT id INTO v_cart_alpha_id FROM public.carts WHERE user_id = 'a5000000-0000-0000-0000-000000000001';
    IF v_cart_alpha_id IS NULL THEN
        RAISE EXCEPTION 'A.1 FAIL: Customer Alpha cart not created';
    END IF;

    -- B.1 Customer Beta adds variant M to cart
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000002';
    PERFORM public.add_to_customer_cart('b5000000-0000-0000-0000-000000000005', 1);
    SELECT id INTO v_cart_beta_id FROM public.carts WHERE user_id = 'a5000000-0000-0000-0000-000000000002';

    -- B.2 Customer Beta tries to read Customer Alpha cart lines -> MUST RETURN 0
    SELECT count(*) INTO v_count FROM public.cart_lines WHERE cart_id = v_cart_alpha_id;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'B.2 FAIL: Customer Beta read Customer Alpha cart lines';
    END IF;

    -- B.3 Customer Beta tries to mutate Customer Alpha cart line -> MUST FAIL
    v_threw := false;
    BEGIN
        PERFORM public.update_cart_line_quantity(v_line_alpha_id, 5);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'B.3 FAIL: Customer Beta modified Customer Alpha cart line';
    END IF;

    RAISE NOTICE 'ASSERTION PASS A & B: Customer Identity Isolation & Cart Ownership';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST C & D: CART DUPLICATE PREVENTION & QUANTITY CONSTRAINTS
-- ============================================================================
DO $$
DECLARE
    v_cart_alpha_id UUID;
    v_lines_count INTEGER;
    v_qty INTEGER;
    v_threw BOOLEAN;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000001';

    -- C.1 Add the same variant S again with qty 3
    -- (Customer Alpha currently has qty 2 of variant S)
    PERFORM public.add_to_customer_cart('b5000000-0000-0000-0000-000000000004', 3);

    SELECT id INTO v_cart_alpha_id FROM public.carts WHERE user_id = 'a5000000-0000-0000-0000-000000000001';

    -- Verify only 1 line exists for variant S (NO DUPLICATE)
    SELECT count(*), SUM(quantity) INTO v_lines_count, v_qty
    FROM public.cart_lines 
    WHERE cart_id = v_cart_alpha_id AND variant_id = 'b5000000-0000-0000-0000-000000000004';

    IF v_lines_count != 1 THEN
        RAISE EXCEPTION 'C.1 FAIL: Duplicate cart line created for same variant';
    END IF;

    IF v_qty != 5 THEN
        RAISE EXCEPTION 'C.1 FAIL: Expected merged quantity 5, got %', v_qty;
    END IF;

    -- D.1 Add quantity exceeding limit of 10 -> Capped at 10
    PERFORM public.add_to_customer_cart('b5000000-0000-0000-0000-000000000004', 8);

    SELECT quantity INTO v_qty
    FROM public.cart_lines
    WHERE cart_id = v_cart_alpha_id AND variant_id = 'b5000000-0000-0000-0000-000000000004';

    IF v_qty != 10 THEN
        RAISE EXCEPTION 'D.1 FAIL: Expected capped quantity 10, got %', v_qty;
    END IF;

    -- D.2 Inserting negative or 0 quantity directly must fail check constraint
    v_threw := false;
    BEGIN
        INSERT INTO public.cart_lines (cart_id, variant_id, quantity)
        VALUES (v_cart_alpha_id, 'b5000000-0000-0000-0000-000000000005', 0);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'D.2 FAIL: Quantity 0 was accepted by cart_lines check constraint';
    END IF;

    RAISE NOTICE 'ASSERTION PASS C & D: Cart Duplicate Prevention & Quantity Constraints';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST E & F: GUEST CART MERGE & IDEMPOTENCY
-- ============================================================================
DO $$
DECLARE
    v_guest_cart_id UUID;
    v_cart_alpha_id UUID;
    v_qty_s INTEGER;
    v_qty_m INTEGER;
    v_guest_exists BOOLEAN;
BEGIN
    -- Setup anonymous guest cart with variant S (qty 2) and variant M (qty 4)
    INSERT INTO public.carts (session_id)
    VALUES ('guest_session_p5_1')
    RETURNING id INTO v_guest_cart_id;

    INSERT INTO public.cart_lines (cart_id, variant_id, quantity) VALUES
        (v_guest_cart_id, 'b5000000-0000-0000-0000-000000000004', 2),
        (v_guest_cart_id, 'b5000000-0000-0000-0000-000000000005', 4);

    -- Customer Alpha logs in and merges guest cart
    -- (Customer Alpha currently has variant S with qty 10)
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000001';

    -- E.1 Perform Merge
    PERFORM public.merge_guest_cart('guest_session_p5_1');

    SELECT id INTO v_cart_alpha_id FROM public.carts WHERE user_id = 'a5000000-0000-0000-0000-000000000001';

    -- Verify variant S capped at 10 (10 + 2 -> 10)
    SELECT quantity INTO v_qty_s
    FROM public.cart_lines
    WHERE cart_id = v_cart_alpha_id AND variant_id = 'b5000000-0000-0000-0000-000000000004';
    IF v_qty_s != 10 THEN
        RAISE EXCEPTION 'E.1.a FAIL: Expected variant S qty 10, got %', v_qty_s;
    END IF;

    -- Verify variant M added with qty 4
    SELECT quantity INTO v_qty_m
    FROM public.cart_lines
    WHERE cart_id = v_cart_alpha_id AND variant_id = 'b5000000-0000-0000-0000-000000000005';
    IF v_qty_m != 4 THEN
        RAISE EXCEPTION 'E.1.b FAIL: Expected variant M qty 4, got %', v_qty_m;
    END IF;

    -- Verify guest cart was cleaned up
    SELECT EXISTS (SELECT 1 FROM public.carts WHERE session_id = 'guest_session_p5_1') INTO v_guest_exists;
    IF v_guest_exists THEN
        RAISE EXCEPTION 'E.1.c FAIL: Guest cart was not removed after merge';
    END IF;

    -- F.1 Repeated Merge Call (Idempotency)
    PERFORM public.merge_guest_cart('guest_session_p5_1');

    -- Verify quantities did not double or mutate
    SELECT quantity INTO v_qty_m
    FROM public.cart_lines
    WHERE cart_id = v_cart_alpha_id AND variant_id = 'b5000000-0000-0000-0000-000000000005';
    IF v_qty_m != 4 THEN
        RAISE EXCEPTION 'F.1 FAIL: Repeated merge altered cart quantities (expected 4, got %)', v_qty_m;
    END IF;

    RAISE NOTICE 'ASSERTION PASS E & F: Guest Cart Merge & Idempotency';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST G & H: WISHLIST OWNERSHIP & DUPLICATE PREVENTION
-- ============================================================================
DO $$
DECLARE
    v_added BOOLEAN;
    v_removed BOOLEAN;
    v_count INTEGER;
    v_threw BOOLEAN;
BEGIN
    SET ROLE authenticated;

    -- G.1 Customer Alpha toggles product to wishlist -> ADDED (true)
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000001';
    v_added := public.toggle_wishlist_item('b5000000-0000-0000-0000-000000000003');
    IF NOT v_added THEN
        RAISE EXCEPTION 'G.1 FAIL: Expected true on initial wishlist add';
    END IF;

    -- G.2 Customer Beta cannot read Customer Alpha wishlist
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000002';
    SELECT count(*) INTO v_count FROM public.customer_wishlist WHERE user_id = 'a5000000-0000-0000-0000-000000000001';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'G.2 FAIL: Customer Beta read Customer Alpha wishlist';
    END IF;

    -- H.1 Direct duplicate insert into customer_wishlist MUST fail unique constraint
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000001';
    v_threw := false;
    BEGIN
        INSERT INTO public.customer_wishlist (user_id, product_id)
        VALUES ('a5000000-0000-0000-0000-000000000001', 'b5000000-0000-0000-0000-000000000003');
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'H.1 FAIL: Duplicate wishlist entry was permitted';
    END IF;

    -- G.3 Toggle again -> REMOVED (false)
    v_removed := public.toggle_wishlist_item('b5000000-0000-0000-0000-000000000003');
    IF v_removed THEN
        RAISE EXCEPTION 'G.3 FAIL: Expected false when removing from wishlist';
    END IF;

    RAISE NOTICE 'ASSERTION PASS G & H: Wishlist Ownership & Duplicate Prevention';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST I & J: ADDRESS OWNERSHIP & DEFAULT ADDRESS INVARIANT
-- ============================================================================
DO $$
DECLARE
    v_addr1_id UUID;
    v_addr2_id UUID;
    v_addr3_id UUID;
    v_default_count INTEGER;
    v_is_default_1 BOOLEAN;
    v_is_default_2 BOOLEAN;
    v_count INTEGER;
    v_threw BOOLEAN;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000001';

    -- J.1 Insert first address -> Must automatically become DEFAULT
    INSERT INTO public.customer_addresses (
        full_name, phone, line1, city, state, pincode
    ) VALUES (
        'Alpha Resident', '+919777700001', 'Flat 101, Altamount Road', 'Mumbai', 'Maharashtra', '400026'
    ) RETURNING id, is_default INTO v_addr1_id, v_is_default_1;

    IF NOT v_is_default_1 THEN
        RAISE EXCEPTION 'J.1 FAIL: First active address did not become default automatically';
    END IF;

    -- J.2 Insert second address with is_default = true -> Must demote addr1 and set addr2 default
    INSERT INTO public.customer_addresses (
        full_name, phone, line1, city, state, pincode, is_default
    ) VALUES (
        'Alpha Office', '+919777700001', 'Level 12, BKC Towers', 'Mumbai', 'Maharashtra', '400051', true
    ) RETURNING id, is_default INTO v_addr2_id, v_is_default_2;

    IF NOT v_is_default_2 THEN
        RAISE EXCEPTION 'J.2.a FAIL: Second address not set default';
    END IF;

    SELECT is_default INTO v_is_default_1 FROM public.customer_addresses WHERE id = v_addr1_id;
    IF v_is_default_1 THEN
        RAISE EXCEPTION 'J.2.b FAIL: First address was not demoted from default';
    END IF;

    -- J.3 Verify database invariant: Exactly ONE default address exists
    SELECT count(*) INTO v_default_count 
    FROM public.customer_addresses 
    WHERE user_id = 'a5000000-0000-0000-0000-000000000001' AND is_default = true AND is_active = true;

    IF v_default_count != 1 THEN
        RAISE EXCEPTION 'J.3 FAIL: Expected exactly 1 active default address, found %', v_default_count;
    END IF;

    -- J.4 Deactivate addr2 (the current default) -> Must automatically promote addr1 back to default
    UPDATE public.customer_addresses SET is_active = false WHERE id = v_addr2_id;

    SELECT is_default INTO v_is_default_1 FROM public.customer_addresses WHERE id = v_addr1_id;
    IF NOT v_is_default_1 THEN
        RAISE EXCEPTION 'J.4 FAIL: Remaining active address not promoted when default was deactivated';
    END IF;

    -- I.1 Customer Beta cannot read Customer Alpha addresses
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000002';
    SELECT count(*) INTO v_count FROM public.customer_addresses WHERE user_id = 'a5000000-0000-0000-0000-000000000001';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'I.1 FAIL: Customer Beta read Customer Alpha addresses';
    END IF;

    -- I.2 Customer Beta cannot mutate Customer Alpha address
    UPDATE public.customer_addresses SET line1 = 'Hacked' WHERE id = v_addr1_id;

    -- Check as Customer Alpha that line1 was NOT mutated
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000001';
    SELECT (line1 = 'Hacked') INTO v_threw FROM public.customer_addresses WHERE id = v_addr1_id;
    IF v_threw IS TRUE THEN
        RAISE EXCEPTION 'I.2 FAIL: Customer Beta mutated Customer Alpha address';
    END IF;

    RAISE NOTICE 'ASSERTION PASS I & J: Address Ownership & Single-Default Invariant';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST K & L: SELLER/PUBLIC ISOLATION & P3 VISIBILITY PRESERVATION
-- ============================================================================
DO $$
DECLARE
    v_count INTEGER;
    v_product_id UUID := 'b5000000-0000-0000-0000-000000000003';
    v_seller_id UUID := 'b5000000-0000-0000-0000-000000000001';
    v_visible BOOLEAN;
BEGIN
    -- K.1 Anonymous user has 0 access to customer addresses
    SET ROLE anon;
    SELECT count(*) INTO v_count FROM public.customer_addresses;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'K.1 FAIL: Anonymous user accessed customer addresses';
    END IF;

    -- K.2 Seller Charlie has 0 access to customer addresses
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000003';
    SELECT count(*) INTO v_count FROM public.customer_addresses WHERE user_id = 'a5000000-0000-0000-0000-000000000001';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'K.2 FAIL: Seller accessed Customer Alpha addresses';
    END IF;

    -- L.1 P3 Catalog Visibility check: Live product of active seller is visible to anon
    SET ROLE anon;
    v_visible := public.is_product_visible(v_product_id);
    IF NOT v_visible THEN
        RAISE EXCEPTION 'L.1 FAIL: Active seller live product not visible to anon';
    END IF;

    -- L.2 Suspend seller as admin_super -> product must immediately become hidden
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a5000000-0000-0000-0000-000000000009';
    UPDATE public.sellers SET status = 'suspended' WHERE id = v_seller_id;

    SET ROLE anon;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    v_visible := public.is_product_visible(v_product_id);
    RESET ROLE;

    IF v_visible THEN
        RAISE EXCEPTION 'L.2 FAIL: Suspended seller product still visible through P3 gate';
    END IF;

    RAISE NOTICE 'ASSERTION PASS K & L: Seller/Public Isolation & P3 Visibility Preservation';
END $$;
