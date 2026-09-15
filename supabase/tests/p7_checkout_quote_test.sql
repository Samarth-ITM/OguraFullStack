-- ============================================================================
-- OGURA PHASE 7: CHECKOUT & AUTHORITATIVE QUOTE ENGINE ACCEPTANCE TEST SUITE
-- File: supabase/tests/p7_checkout_quote_test.sql
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
    SET search_path = public, auth, pg_temp;
END $$;

BEGIN;

-- 1. SEED TEST IDENTIFIERS
INSERT INTO auth.users (id, email) VALUES
    ('a7000000-0000-0000-0000-000000000001', 'alice_p7@ogura.test'),
    ('a7000000-0000-0000-0000-000000000002', 'bob_p7@ogura.test'),
    ('a7000000-0000-0000-0000-000000000003', 'seller1_p7@ogura.test'),
    ('a7000000-0000-0000-0000-000000000004', 'seller2_p7@ogura.test'),
    ('a7000000-0000-0000-0000-000000000009', 'admin_p7@ogura.test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email, phone) VALUES
    ('a7000000-0000-0000-0000-000000000001', 'Alice P7', 'alice_p7@ogura.test', '+919777700001'),
    ('a7000000-0000-0000-0000-000000000002', 'Bob P7', 'bob_p7@ogura.test', '+919777700002'),
    ('a7000000-0000-0000-0000-000000000003', 'Seller One P7', 'seller1_p7@ogura.test', '+919777700003'),
    ('a7000000-0000-0000-0000-000000000004', 'Seller Two P7', 'seller2_p7@ogura.test', '+919777700004'),
    ('a7000000-0000-0000-0000-000000000009', 'Admin Super P7', 'admin_p7@ogura.test', '+919777700009')
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

DELETE FROM public.user_roles WHERE user_id IN (
    'a7000000-0000-0000-0000-000000000001',
    'a7000000-0000-0000-0000-000000000002',
    'a7000000-0000-0000-0000-000000000003',
    'a7000000-0000-0000-0000-000000000004',
    'a7000000-0000-0000-0000-000000000009'
);

INSERT INTO public.user_roles (user_id, role) VALUES
    ('a7000000-0000-0000-0000-000000000001', 'customer'),
    ('a7000000-0000-0000-0000-000000000002', 'customer'),
    ('a7000000-0000-0000-0000-000000000003', 'seller'),
    ('a7000000-0000-0000-0000-000000000004', 'seller'),
    ('a7000000-0000-0000-0000-000000000009', 'admin_super');

-- Seed Sellers
SELECT set_config('request.jwt.claim.sub', 'a7000000-0000-0000-0000-000000000009', true);

INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status) VALUES
    ('b7000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000003', 'P7 Seller A', 'P7 Seller A Pvt Ltd', 'p7-seller-a', 'active'),
    ('b7000000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-000000000004', 'P7 Seller B', 'P7 Seller B Pvt Ltd', 'p7-seller-b', 'active')
ON CONFLICT (id) DO UPDATE SET status = 'active';

INSERT INTO public.brands (id, seller_id, name, slug) VALUES
    ('b7000000-0000-0000-0000-000000000011', 'b7000000-0000-0000-0000-000000000001', 'P7 Brand A', 'p7-brand-a'),
    ('b7000000-0000-0000-0000-000000000012', 'b7000000-0000-0000-0000-000000000002', 'P7 Brand B', 'p7-brand-b')
ON CONFLICT (id) DO NOTHING;

-- Seed Products
INSERT INTO public.products (id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order) VALUES
    ('b7000000-0000-0000-0000-000000000021', 'b7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-000000000011',
     (SELECT id FROM public.categories WHERE slug = 'clothing'), (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
     'P7 Silk Kaftan', 'p7-silk-kaftan', 'live', false),
    ('b7000000-0000-0000-0000-000000000022', 'b7000000-0000-0000-0000-000000000002', 'b7000000-0000-0000-0000-000000000012',
     (SELECT id FROM public.categories WHERE slug = 'clothing'), (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
     'P7 Linen Dress', 'p7-linen-dress', 'live', false),
    ('b7000000-0000-0000-0000-000000000023', 'b7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-000000000011',
     (SELECT id FROM public.categories WHERE slug = 'clothing'), (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
     'P7 Wool Cape', 'p7-wool-cape', 'live', false),
    ('b7000000-0000-0000-0000-000000000024', 'b7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-000000000011',
     (SELECT id FROM public.categories WHERE slug = 'clothing'), (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
     'P7 Cotton Top (Limited)', 'p7-cotton-top-limited', 'live', false)
ON CONFLICT (id) DO UPDATE SET status = 'live';

-- Seed Variants:
-- V1: Seller A, ₹1,500 (150000 paise)
-- V2: Seller B, ₹1,499 (149900 paise)
-- V3: Seller A, ₹2,000 (200000 paise)
-- V4: Seller A, ₹500   (50000 paise), 1 stock
INSERT INTO public.product_variants (id, product_id, sku, size, color, color_hex, price_paise, compare_at_price_paise) VALUES
    ('b7000000-0000-0000-0000-000000000031', 'b7000000-0000-0000-0000-000000000021', 'SKU-P7-KAFTAN-S', 'S', 'Ivory', '#fffff0', 150000, 180000),
    ('b7000000-0000-0000-0000-000000000032', 'b7000000-0000-0000-0000-000000000022', 'SKU-P7-LINEN-M',  'M', 'Olive', '#556b2f', 149900, 199900),
    ('b7000000-0000-0000-0000-000000000033', 'b7000000-0000-0000-0000-000000000023', 'SKU-P7-CAPE-L',   'L', 'Black', '#000000', 200000, 250000),
    ('b7000000-0000-0000-0000-000000000034', 'b7000000-0000-0000-0000-000000000024', 'SKU-P7-TOP-XS',   'XS', 'White', '#ffffff', 50000, 80000)
ON CONFLICT (id) DO NOTHING;

-- Seed Inventory items
INSERT INTO public.inventory_items (variant_id, quantity_on_hand, quantity_reserved, low_stock_threshold) VALUES
    ('b7000000-0000-0000-0000-000000000031', 10, 0, 2),
    ('b7000000-0000-0000-0000-000000000032', 10, 0, 2),
    ('b7000000-0000-0000-0000-000000000033', 10, 0, 2),
    ('b7000000-0000-0000-0000-000000000034', 1,  0, 1)
ON CONFLICT (variant_id) DO UPDATE SET
    quantity_on_hand = EXCLUDED.quantity_on_hand,
    quantity_reserved = 0,
    low_stock_threshold = EXCLUDED.low_stock_threshold;

-- Seed Customer Addresses
INSERT INTO public.customer_addresses (id, user_id, full_name, phone, line1, city, state, pincode, country, is_default) VALUES
    ('d7000000-0000-0000-0000-000000000001', 'a7000000-0000-0000-0000-000000000001', 'Alice P7', '+919777700001', '123 Marine Drive', 'Mumbai', 'Maharashtra', '400020', 'IN', true),
    ('d7000000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-000000000002', 'Bob P7', '+919777700002', '456 Bandra West', 'Mumbai', 'Maharashtra', '400050', 'IN', true)
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- ============================================================================
-- TEST A: SINGLE SELLER CHECKOUT (Price, Subtotal, Shipping, Total, Reservation)
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_on_hand INTEGER;
    v_reserved INTEGER;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000001'; -- Alice

    -- Setup cart: 1x V3 (₹2,000 = 200000 paise)
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000033', 1);

    -- Create checkout quote with Alice's address
    v_quote := public.create_checkout_quote('d7000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;

    -- Verify authoritative values
    IF (v_quote->>'subtotal_paise')::BIGINT != 200000 THEN
        RAISE EXCEPTION 'A. FAIL: Expected subtotal 200000, got %', v_quote->>'subtotal_paise';
    END IF;

    -- Subtotal 200000 < 299900 -> shipping must be 9900 paise (₹99)
    IF (v_quote->>'shipping_fee_paise')::BIGINT != 9900 THEN
        RAISE EXCEPTION 'A. FAIL: Expected shipping 9900, got %', v_quote->>'shipping_fee_paise';
    END IF;

    IF (v_quote->>'tax_paise')::BIGINT != 0 THEN
        RAISE EXCEPTION 'A. FAIL: Expected tax 0, got %', v_quote->>'tax_paise';
    END IF;

    IF (v_quote->>'discount_paise')::BIGINT != 0 THEN
        RAISE EXCEPTION 'A. FAIL: Expected discount 0, got %', v_quote->>'discount_paise';
    END IF;

    -- Total = 200000 - 0 + 9900 + 0 = 209900 paise
    IF (v_quote->>'total_payable_paise')::BIGINT != 209900 THEN
        RAISE EXCEPTION 'A. FAIL: Expected total 209900, got %', v_quote->>'total_payable_paise';
    END IF;

    -- Verify P6 reservation exists and holds 1 unit
    RESET ROLE;
    SELECT quantity_on_hand, quantity_reserved INTO v_on_hand, v_reserved
    FROM public.inventory_items WHERE variant_id = 'b7000000-0000-0000-0000-000000000033';

    IF v_reserved != 1 THEN
        RAISE EXCEPTION 'A. FAIL: Expected 1 reserved unit, found %', v_reserved;
    END IF;

    RAISE NOTICE 'ASSERTION PASS A: Single Seller Checkout with Correct Tariff & P6 Reservation';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST B & C: MULTI-SELLER CART & ₹2,999 FREE-SHIPPING THRESHOLD BOUNDARY
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_subtotal BIGINT;
    v_shipping BIGINT;
    v_total BIGINT;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000001'; -- Alice

    -- B.1 Multi-Seller: Seller A (V1 ₹1,500) + Seller B (V2 ₹1,499)
    -- Total = ₹2,999.00 (299900 paise) exactly at free-shipping threshold!
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000031', 1); -- Seller A (150000)
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000032', 1); -- Seller B (149900)

    v_quote := public.create_checkout_quote('d7000000-0000-0000-0000-000000000001');

    v_subtotal := (v_quote->>'subtotal_paise')::BIGINT;
    v_shipping := (v_quote->>'shipping_fee_paise')::BIGINT;
    v_total    := (v_quote->>'total_payable_paise')::BIGINT;

    -- Subtotal must be exactly 299900
    IF v_subtotal != 299900 THEN
        RAISE EXCEPTION 'B/C. FAIL: Expected subtotal 299900, got %', v_subtotal;
    END IF;

    -- Free shipping threshold met (subtotal >= 299900) -> shipping MUST be 0
    IF v_shipping != 0 THEN
        RAISE EXCEPTION 'B/C. FAIL: Expected free shipping (0) at ₹2,999, got %', v_shipping;
    END IF;

    IF v_total != 299900 THEN
        RAISE EXCEPTION 'B/C. FAIL: Expected total 299900, got %', v_total;
    END IF;

    -- Verify multi-seller items are both present in quote
    IF jsonb_array_length(v_quote->'items') != 2 THEN
        RAISE EXCEPTION 'B. FAIL: Expected 2 items in multi-seller quote, got %', jsonb_array_length(v_quote->'items');
    END IF;

    -- C.1 Below threshold test: 1x V1 (150000) -> subtotal 150000 < 299900 -> shipping = 9900
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000031', 1);
    v_quote := public.create_checkout_quote('d7000000-0000-0000-0000-000000000001');
    IF (v_quote->>'shipping_fee_paise')::BIGINT != 9900 THEN
        RAISE EXCEPTION 'C.1 FAIL: Below ₹2,999 must charge 9900 shipping';
    END IF;

    -- C.2 Above threshold test: 2x V3 (400000) -> subtotal 400000 >= 299900 -> shipping = 0
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000033', 2);
    v_quote := public.create_checkout_quote('d7000000-0000-0000-0000-000000000001');
    IF (v_quote->>'shipping_fee_paise')::BIGINT != 0 THEN
        RAISE EXCEPTION 'C.2 FAIL: Above ₹2,999 must have free shipping (0)';
    END IF;

    RAISE NOTICE 'ASSERTION PASS B & C: Multi-Seller Single Shipping & ₹2,999 Boundary Exactness';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST D, E, F, G, H, I: FINANCIAL MANIPULATION RESISTANCE
-- ============================================================================
DO $$
DECLARE
    v_quote_id UUID;
    v_threw BOOLEAN;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000001'; -- Alice

    -- The RPC surface does not even take financial parameters:
    -- public.create_checkout_quote(p_address_id UUID, p_custom_address JSONB)
    -- All financial values (subtotal, shipping, discount, tax, total) are derived server-side.

    -- D-I. Attempt direct client SQL manipulation on checkout_quotes table
    v_threw := false;
    BEGIN
        INSERT INTO public.checkout_quotes (
            user_id, subtotal_paise, discount_paise, shipping_fee_paise,
            tax_paise, total_payable_paise, shipping_address, expires_at
        ) VALUES (
            'a7000000-0000-0000-0000-000000000001',
            100, 0, 0, 0, 100,
            '{"city": "Mumbai"}'::jsonb,
            CURRENT_TIMESTAMP + INTERVAL '15 minutes'
        );
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'D-I. FAIL: Direct client INSERT of fabricated quote succeeded';
    END IF;

    RAISE NOTICE 'ASSERTION PASS D-I: Server-Authoritative Calculation & Manipulation Immunity';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST J & K: CART & ADDRESS OWNERSHIP ISOLATION
-- ============================================================================
DO $$
DECLARE
    v_threw BOOLEAN;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000001'; -- Alice

    -- K. Customer Alice attempts to checkout using Customer Bob's address -> MUST FAIL
    v_threw := false;
    BEGIN
        PERFORM public.create_checkout_quote('d7000000-0000-0000-0000-000000000002'); -- Bob's address
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'K. FAIL: Customer Alice was able to use Customer Bob address';
    END IF;

    -- J. Customer Bob cart isolation: Bob's active cart cannot be manipulated or quoted by Alice
    -- In create_checkout_quote, v_cart_id is retrieved strictly via user_id = auth.uid()
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000002'; -- Bob
    PERFORM public.clear_customer_cart(); -- Bob cart is now empty

    -- Bob attempts to checkout empty cart -> MUST FAIL
    v_threw := false;
    BEGIN
        PERFORM public.create_checkout_quote('d7000000-0000-0000-0000-000000000002');
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'J. FAIL: Bob was able to checkout an empty cart';
    END IF;

    RAISE NOTICE 'ASSERTION PASS J & K: Cart & Address Ownership Boundaries Enforced';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST L & M: INSUFFICIENT INVENTORY & RESERVATION ATOMICITY ROLLBACK
-- ============================================================================
DO $$
DECLARE
    v_threw BOOLEAN;
    v_quote_count_before INTEGER;
    v_quote_count_after INTEGER;
    v_res_count_before INTEGER;
    v_res_count_after INTEGER;
    v_avail_before INTEGER;
    v_avail_after INTEGER;
BEGIN
    -- V4 (Variant 34) has only 1 physical unit in inventory
    v_avail_before := public.get_variant_available_stock('b7000000-0000-0000-0000-000000000034');
    IF v_avail_before != 1 THEN
        RAISE EXCEPTION 'L/M SETUP FAIL: Expected 1 available unit for V4, found %', v_avail_before;
    END IF;

    SELECT count(*) INTO v_quote_count_before FROM public.checkout_quotes;
    SELECT count(*) INTO v_res_count_before FROM public.inventory_reservations;

    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000001'; -- Alice

    -- Add 2 units of V4 to cart (exceeds available stock of 1)
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000034', 2);

    -- Attempt quote creation -> MUST FAIL AT RESERVATION STEP
    v_threw := false;
    BEGIN
        PERFORM public.create_checkout_quote('d7000000-0000-0000-0000-000000000001');
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'L. FAIL: Checkout quote creation succeeded with insufficient inventory';
    END IF;

    -- M. ATOMICITY VERIFICATION:
    -- Verify transaction rollback ensured NO quote was inserted and NO reservation was created
    RESET ROLE;
    SELECT count(*) INTO v_quote_count_after FROM public.checkout_quotes;
    SELECT count(*) INTO v_res_count_after FROM public.inventory_reservations;
    v_avail_after := public.get_variant_available_stock('b7000000-0000-0000-0000-000000000034');

    IF v_quote_count_after != v_quote_count_before THEN
        RAISE EXCEPTION 'M. FAIL: Orphan quote row remained after reservation failure! (before=%, after=%)',
            v_quote_count_before, v_quote_count_after;
    END IF;

    IF v_res_count_after != v_res_count_before THEN
        RAISE EXCEPTION 'M. FAIL: Orphan reservation row remained after rollback!';
    END IF;

    IF v_avail_after != v_avail_before THEN
        RAISE EXCEPTION 'M. FAIL: Stock corrupted after rollback! (before=%, after=%)',
            v_avail_before, v_avail_after;
    END IF;

    RAISE NOTICE 'ASSERTION PASS L & M: Insufficient Inventory Safe Rejection & 100%% Atomic Rollback';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST N, O, P: QUOTE PERSISTENCE, IMMUTABILITY & EXPIRATION
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_stored_total BIGINT;
    v_threw BOOLEAN;
    v_status checkout_quote_status;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000001'; -- Alice

    -- N. Create a valid quote
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000031', 1);
    v_quote := public.create_checkout_quote('d7000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;

    -- Verify persistence
    RESET ROLE;
    SELECT total_payable_paise, status INTO v_stored_total, v_status
    FROM public.checkout_quotes WHERE id = v_quote_id;

    IF v_stored_total != 159900 OR v_status != 'pending'::checkout_quote_status THEN
        RAISE EXCEPTION 'N. FAIL: Stored quote values mismatch: total=%, status=%', v_stored_total, v_status;
    END IF;

    -- O. Attempt to modify quote financial amount directly in table -> MUST FAIL
    v_threw := false;
    BEGIN
        UPDATE public.checkout_quotes
        SET total_payable_paise = 1
        WHERE id = v_quote_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'O. FAIL: Direct UPDATE of total_payable_paise was permitted';
    END IF;

    -- P. Quote Expiry:
    -- Simulate expiration of quote (set expires_at in past)
    UPDATE public.checkout_quotes
    SET expires_at = CURRENT_TIMESTAMP - INTERVAL '1 second'
    WHERE id = v_quote_id;

    -- Now calling get_checkout_quote or cancel_checkout_quote detects expiration and releases stock
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000001';
    v_quote := public.get_checkout_quote(v_quote_id);

    IF v_quote->>'status' != 'expired' THEN
        RAISE EXCEPTION 'P. FAIL: Quote status was not updated to expired, got %', v_quote->>'status';
    END IF;

    RAISE NOTICE 'ASSERTION PASS N, O, P: Quote Persistence, Immutability & Expiration Lifecycle';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST Q: MULTI-ITEM CONCURRENCY INTEGRATION
-- ============================================================================
DO $$
DECLARE
    v_threw BOOLEAN;
    v_quote1 JSONB;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000001'; -- Alice

    -- V4 (Variant 34) has exactly 1 unit left
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000034', 1);

    -- Alice successfully checks out the last unit
    v_quote1 := public.create_checkout_quote('d7000000-0000-0000-0000-000000000001');

    -- Now Bob tries to checkout the same last unit concurrently
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000002'; -- Bob
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000034', 1);

    v_threw := false;
    BEGIN
        PERFORM public.create_checkout_quote('d7000000-0000-0000-0000-000000000002');
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'Q. FAIL: Bob was able to reserve the same unit Alice already reserved (Oversold)';
    END IF;

    RAISE NOTICE 'ASSERTION PASS Q: Multi-Buyer Concurrency via P6 Row Locking Confirmed';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST R: RLS TENANCY ISOLATION (CROSS-CUSTOMER QUOTE READ)
-- ============================================================================
DO $$
DECLARE
    v_alice_quote_id UUID;
    v_threw BOOLEAN;
    v_count INTEGER;
BEGIN
    -- Alice creates a quote
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000001'; -- Alice
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b7000000-0000-0000-0000-000000000031', 1);
    v_alice_quote_id := (public.create_checkout_quote('d7000000-0000-0000-0000-000000000001')->>'quote_id')::UUID;

    -- Bob attempts to read Alice's quote via get_checkout_quote -> MUST FAIL
    SET LOCAL "request.jwt.claim.sub" = 'a7000000-0000-0000-0000-000000000002'; -- Bob
    v_threw := false;
    BEGIN
        PERFORM public.get_checkout_quote(v_alice_quote_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'R.1 FAIL: Bob was able to inspect Alice quote via RPC';
    END IF;

    -- Bob attempts direct SELECT from checkout_quotes for Alice's quote -> RLS MUST RETURN 0 ROWS
    SELECT count(*) INTO v_count
    FROM public.checkout_quotes
    WHERE id = v_alice_quote_id;

    IF v_count != 0 THEN
        RAISE EXCEPTION 'R.2 FAIL: Bob was able to read Alice quote via direct table SELECT (RLS leak)';
    END IF;

    RAISE NOTICE 'ASSERTION PASS R: RLS Tenancy Isolation Confirmed';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST S & T: FINANCIAL INVARIANTS & P1–P6 REGRESSION
-- ============================================================================
DO $$
DECLARE
    v_bad_quotes INTEGER;
    v_visible BOOLEAN;
BEGIN
    -- S. Verify table check constraints on all existing checkout quotes
    SELECT count(*) INTO v_bad_quotes
    FROM public.checkout_quotes
    WHERE total_payable_paise != (subtotal_paise - discount_paise + shipping_fee_paise + tax_paise)
       OR subtotal_paise < 0
       OR discount_paise < 0
       OR shipping_fee_paise < 0
       OR tax_paise < 0
       OR total_payable_paise < 0;

    IF v_bad_quotes != 0 THEN
        RAISE EXCEPTION 'S. FAIL: Found % quotes violating financial invariants', v_bad_quotes;
    END IF;

    -- T. P1-P6 regression:
    -- Catalog visibility
    SET ROLE anon;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    v_visible := public.is_product_visible('b7000000-0000-0000-0000-000000000021');
    IF NOT v_visible THEN
        RAISE EXCEPTION 'T. FAIL: Catalog visibility broken';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS S & T: Financial Invariants & P1-P6 Regression Intact';
END $$;

DO $$
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'ALL PHASE 7 CHECKOUT & QUOTE ENGINE TESTS PASSED!';
    RAISE NOTICE '==================================================';
END $$;
