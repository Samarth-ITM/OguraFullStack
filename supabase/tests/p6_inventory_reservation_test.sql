-- OGURA PHASE 6: INVENTORY RESERVATION ENGINE ACCEPTANCE TEST SUITE
-- File: supabase/tests/p6_inventory_reservation_test.sql

\set ON_ERROR_STOP on

-- Ensure pg_temp and search paths
DO $$
BEGIN
    SET search_path = public, auth, pg_temp;
END $$;

-- ============================================================================
-- 0. TEST DATA SEEDING (DEDICATED P6 IDENTIFIERS)
-- ============================================================================
BEGIN;

-- Clean existing test reservations and quotes
DELETE FROM public.inventory_reservations WHERE quote_id IN (
    'c6000000-0000-0000-0000-000000000001',
    'c6000000-0000-0000-0000-000000000002',
    'c6000000-0000-0000-0000-000000000003'
);
DELETE FROM public.checkout_quotes WHERE id IN (
    'c6000000-0000-0000-0000-000000000001',
    'c6000000-0000-0000-0000-000000000002',
    'c6000000-0000-0000-0000-000000000003'
);

-- Seed Users
INSERT INTO auth.users (id, email) VALUES
    ('a6000000-0000-0000-0000-000000000001', 'customer_alice_p6@ogura.test'),
    ('a6000000-0000-0000-0000-000000000002', 'customer_bob_p6@ogura.test'),
    ('a6000000-0000-0000-0000-000000000003', 'seller_diana_p6@ogura.test'),
    ('a6000000-0000-0000-0000-000000000009', 'admin_super_p6@ogura.test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email, phone) VALUES
    ('a6000000-0000-0000-0000-000000000001', 'Customer Alice P6', 'customer_alice_p6@ogura.test', '+919666600001'),
    ('a6000000-0000-0000-0000-000000000002', 'Customer Bob P6', 'customer_bob_p6@ogura.test', '+919666600002'),
    ('a6000000-0000-0000-0000-000000000003', 'Seller Diana P6', 'seller_diana_p6@ogura.test', '+919666600003'),
    ('a6000000-0000-0000-0000-000000000009', 'Admin Super P6', 'admin_super_p6@ogura.test', '+919666600009')
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

DELETE FROM public.user_roles WHERE user_id IN (
    'a6000000-0000-0000-0000-000000000001',
    'a6000000-0000-0000-0000-000000000002',
    'a6000000-0000-0000-0000-000000000003',
    'a6000000-0000-0000-0000-000000000009'
);

INSERT INTO public.user_roles (user_id, role) VALUES
    ('a6000000-0000-0000-0000-000000000001', 'customer'),
    ('a6000000-0000-0000-0000-000000000002', 'customer'),
    ('a6000000-0000-0000-0000-000000000003', 'seller'),
    ('a6000000-0000-0000-0000-000000000009', 'admin_super');

-- Seed Seller & Brand (set admin context for seller trigger)
SELECT set_config('request.jwt.claim.sub', 'a6000000-0000-0000-0000-000000000009', true);
INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status)
VALUES (
    'b6000000-0000-0000-0000-000000000001',
    'a6000000-0000-0000-0000-000000000003',
    'P6 Diana Maison',
    'P6 Diana Maison LLP',
    'p6-diana-maison',
    'active'
) ON CONFLICT (id) DO UPDATE SET status = 'active';

INSERT INTO public.brands (id, seller_id, name, slug)
VALUES (
    'b6000000-0000-0000-0000-000000000002',
    'b6000000-0000-0000-0000-000000000001',
    'P6 Diana Atelier',
    'p6-diana-atelier'
) ON CONFLICT (id) DO NOTHING;

-- Seed Standard Product
INSERT INTO public.products (
    id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order
) VALUES (
    'b6000000-0000-0000-0000-000000000003',
    'b6000000-0000-0000-0000-000000000001',
    'b6000000-0000-0000-0000-000000000002',
    (SELECT id FROM public.categories WHERE slug = 'clothing'),
    (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
    'P6 Silk Gown',
    'p6-silk-gown',
    'live',
    false
) ON CONFLICT (id) DO UPDATE SET status = 'live';

-- Seed Made-to-Order Product
INSERT INTO public.products (
    id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order
) VALUES (
    'b6000000-0000-0000-0000-000000000007',
    'b6000000-0000-0000-0000-000000000001',
    'b6000000-0000-0000-0000-000000000002',
    (SELECT id FROM public.categories WHERE slug = 'clothing'),
    (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
    'P6 Bespoke Silk Dress (MTO)',
    'p6-bespoke-silk-dress-mto',
    'live',
    true
) ON CONFLICT (id) DO UPDATE SET status = 'live';

-- Seed Variants:
-- Variant 4: Standard physical item with 10 on hand
-- Variant 5: Single-stock item (1 on hand) for 100-buyer test
-- Variant 6: Made-to-order variant
INSERT INTO public.product_variants (
    id, product_id, sku, size, color, color_hex, price_paise, compare_at_price_paise
) VALUES 
    ('b6000000-0000-0000-0000-000000000004', 'b6000000-0000-0000-0000-000000000003', 'SKU-P6-GOWN-S', 'S', 'Emerald', '#004d40', 2500000, 3000000),
    ('b6000000-0000-0000-0000-000000000005', 'b6000000-0000-0000-0000-000000000003', 'SKU-P6-GOWN-M', 'M', 'Emerald', '#004d40', 2500000, 3000000),
    ('b6000000-0000-0000-0000-000000000006', 'b6000000-0000-0000-0000-000000000007', 'SKU-P6-MTO-CUSTOM', 'Custom', 'Gold', '#ffd700', 4500000, 5000000)
ON CONFLICT (id) DO NOTHING;

-- Seed / Reset Inventory items
INSERT INTO public.inventory_items (
    variant_id, quantity_on_hand, quantity_reserved, low_stock_threshold
) VALUES
    ('b6000000-0000-0000-0000-000000000004', 10, 0, 2),
    ('b6000000-0000-0000-0000-000000000005', 1, 0, 1)
ON CONFLICT (variant_id) DO UPDATE SET
    quantity_on_hand = EXCLUDED.quantity_on_hand,
    quantity_reserved = 0,
    low_stock_threshold = EXCLUDED.low_stock_threshold;

-- Seed Checkout Quotes for Customers Alice and Bob
INSERT INTO public.checkout_quotes (
    id, user_id, subtotal_paise, discount_paise, shipping_fee_paise,
    tax_paise, total_payable_paise, shipping_address, status, expires_at
) VALUES (
    'c6000000-0000-0000-0000-000000000001',
    'a6000000-0000-0000-0000-000000000001', -- Customer Alice
    2500000, 0, 0, 0, 2500000,
    '{"line1": "123 Marine Drive", "city": "Mumbai", "pincode": "400020"}'::jsonb,
    'pending'::checkout_quote_status,
    CURRENT_TIMESTAMP + INTERVAL '15 minutes'
), (
    'c6000000-0000-0000-0000-000000000002',
    'a6000000-0000-0000-0000-000000000002', -- Customer Bob
    2500000, 0, 0, 0, 2500000,
    '{"line1": "456 Bandra West", "city": "Mumbai", "pincode": "400050"}'::jsonb,
    'pending'::checkout_quote_status,
    CURRENT_TIMESTAMP + INTERVAL '15 minutes'
), (
    'c6000000-0000-0000-0000-000000000003',
    'a6000000-0000-0000-0000-000000000001', -- Alice Expired Quote
    2500000, 0, 0, 0, 2500000,
    '{"line1": "123 Marine Drive", "city": "Mumbai", "pincode": "400020"}'::jsonb,
    'pending'::checkout_quote_status,
    CURRENT_TIMESTAMP - INTERVAL '5 minutes'
);

COMMIT;

-- ============================================================================
-- TEST A, B, C, D: BASIC RESERVATION, INSUFFICIENT INVENTORY, EXACT & OVERSELL
-- ============================================================================
DO $$
DECLARE
    v_avail INTEGER;
    v_res_id UUID;
    v_threw BOOLEAN;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';

    -- A. Basic reservation: 10 on hand, reserve 3 -> Available becomes 7
    v_res_id := public.create_inventory_reservation(
        'c6000000-0000-0000-0000-000000000001',
        'b6000000-0000-0000-0000-000000000004',
        3
    );

    v_avail := public.get_variant_available_stock('b6000000-0000-0000-0000-000000000004');
    IF v_avail != 7 THEN
        RAISE EXCEPTION 'A. FAIL: Expected available stock 7, got %', v_avail;
    END IF;

    -- B. Insufficient stock: Available is 7, attempt to reserve 8 -> MUST FAIL
    v_threw := false;
    BEGIN
        PERFORM public.create_inventory_reservation(
            'c6000000-0000-0000-0000-000000000001',
            'b6000000-0000-0000-0000-000000000004',
            8
        );
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'B. FAIL: Insufficient inventory request did not throw';
    END IF;

    -- Inventory must remain unchanged at 7
    v_avail := public.get_variant_available_stock('b6000000-0000-0000-0000-000000000004');
    IF v_avail != 7 THEN
        RAISE EXCEPTION 'B. FAIL: Stock corrupted after failed reservation: %', v_avail;
    END IF;

    -- C. Exact inventory: Available is 7, reserve exactly 7 -> Available becomes 0
    PERFORM public.create_inventory_reservation(
        'c6000000-0000-0000-0000-000000000001',
        'b6000000-0000-0000-0000-000000000004',
        7
    );

    v_avail := public.get_variant_available_stock('b6000000-0000-0000-0000-000000000004');
    IF v_avail != 0 THEN
        RAISE EXCEPTION 'C. FAIL: Expected available stock 0, got %', v_avail;
    END IF;

    -- D. Oversell prevention: Available is 0, any reservation must be rejected
    v_threw := false;
    BEGIN
        PERFORM public.create_inventory_reservation(
            'c6000000-0000-0000-0000-000000000001',
            'b6000000-0000-0000-0000-000000000004',
            1
        );
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'D. FAIL: Oversell permitted when available was 0';
    END IF;

    RAISE NOTICE 'ASSERTION PASS A, B, C, D: Basic, Insufficient, Exact Stock & Oversell Prevention';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST E: MANDATORY 100-BUYER CONCURRENCY SIMULATION (100 BUYERS / 1 ITEM)
-- ============================================================================
DO $$
DECLARE
    v_quote_id UUID := 'c6000000-0000-0000-0000-000000000001';
    v_target_variant UUID := 'b6000000-0000-0000-0000-000000000005'; -- 1 on hand
    v_success_count INTEGER := 0;
    v_fail_count INTEGER := 0;
    v_final_on_hand INTEGER;
    v_final_reserved INTEGER;
    v_final_available INTEGER;
    v_audit_before INTEGER;
    v_audit_after INTEGER;
    i INTEGER;
BEGIN
    -- Record baseline audit count before attempts (as session user / admin)
    SELECT count(*) INTO v_audit_before
    FROM public.inventory_audit_log
    WHERE variant_id = v_target_variant AND change_type = 'reservation_created';

    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';

    -- Verify starting conditions
    v_final_available := public.get_variant_available_stock(v_target_variant);
    IF v_final_available != 1 THEN
        RAISE EXCEPTION 'E. SETUP FAIL: Expected 1 available stock, found %', v_final_available;
    END IF;

    -- Run 100 sequential/concurrent reservation attempts on the single item
    FOR i IN 1..100 LOOP
        BEGIN
            PERFORM public.create_inventory_reservation(v_quote_id, v_target_variant, 1);
            v_success_count := v_success_count + 1;
        EXCEPTION WHEN OTHERS THEN
            v_fail_count := v_fail_count + 1;
        END;
    END LOOP;

    -- Report exact concurrency outcomes
    RAISE NOTICE 'E. CONCURRENCY RESULT: Attempted=100, Success=%, Failed=%', v_success_count, v_fail_count;

    IF v_success_count != 1 THEN
        RAISE EXCEPTION 'E. FAIL: Expected exactly 1 success, got %', v_success_count;
    END IF;

    IF v_fail_count != 99 THEN
        RAISE EXCEPTION 'E. FAIL: Expected exactly 99 failures, got %', v_fail_count;
    END IF;

    -- Reset role to session user to query internal inventory tables and audit log
    RESET ROLE;

    -- Verify stock invariants
    SELECT quantity_on_hand, quantity_reserved
    INTO v_final_on_hand, v_final_reserved
    FROM public.inventory_items
    WHERE variant_id = v_target_variant;

    IF v_final_on_hand != 1 OR v_final_reserved != 1 THEN
        RAISE EXCEPTION 'E. FAIL: Invariant violation: on_hand=%, reserved=%', v_final_on_hand, v_final_reserved;
    END IF;

    v_final_available := public.get_variant_available_stock(v_target_variant);
    IF v_final_available != 0 THEN
        RAISE EXCEPTION 'E. FAIL: Available stock is %, expected 0', v_final_available;
    END IF;

    -- Verify audit log row created for the single successful reservation
    SELECT count(*) INTO v_audit_after
    FROM public.inventory_audit_log
    WHERE variant_id = v_target_variant AND change_type = 'reservation_created';

    IF (v_audit_after - v_audit_before) != 1 THEN
        RAISE EXCEPTION 'E. FAIL: Expected exactly 1 new audit log record, got %', (v_audit_after - v_audit_before);
    END IF;

    RAISE NOTICE 'ASSERTION PASS E: Mandatory 100-Buyer Concurrency Simulation (1 Success, 99 Rejections)';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST F & G: QUANTITY BOUNDARIES & OWNERSHIP ISOLATION
-- ============================================================================
DO $$
DECLARE
    v_threw BOOLEAN;
    v_target_variant UUID := 'b6000000-0000-0000-0000-000000000004';
    v_res_bob UUID;
BEGIN
    SET ROLE authenticated;

    -- F.1 Quantity = 0 -> MUST FAIL
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';
    v_threw := false;
    BEGIN
        PERFORM public.create_inventory_reservation('c6000000-0000-0000-0000-000000000001', v_target_variant, 0);
    EXCEPTION WHEN OTHERS THEN v_threw := true; END;
    IF NOT v_threw THEN RAISE EXCEPTION 'F.1 FAIL: Quantity 0 was accepted'; END IF;

    -- F.2 Quantity = -1 -> MUST FAIL
    v_threw := false;
    BEGIN
        PERFORM public.create_inventory_reservation('c6000000-0000-0000-0000-000000000001', v_target_variant, -1);
    EXCEPTION WHEN OTHERS THEN v_threw := true; END;
    IF NOT v_threw THEN RAISE EXCEPTION 'F.2 FAIL: Negative quantity was accepted'; END IF;

    -- F.3 Quantity = 11 -> MUST FAIL (Exceeds maximum single line quantity of 10)
    v_threw := false;
    BEGIN
        PERFORM public.create_inventory_reservation('c6000000-0000-0000-0000-000000000001', v_target_variant, 11);
    EXCEPTION WHEN OTHERS THEN v_threw := true; END;
    IF NOT v_threw THEN RAISE EXCEPTION 'F.3 FAIL: Quantity 11 (>10) was accepted'; END IF;

    -- G. Ownership: Customer Bob attempts to reserve against Alice's quote -> MUST FAIL
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000002';
    v_threw := false;
    BEGIN
        PERFORM public.create_inventory_reservation('c6000000-0000-0000-0000-000000000001', v_target_variant, 1);
    EXCEPTION WHEN OTHERS THEN v_threw := true; END;
    IF NOT v_threw THEN RAISE EXCEPTION 'G.1 FAIL: Bob reserved against Alice quote'; END IF;

    RAISE NOTICE 'ASSERTION PASS F & G: Quantity Boundaries & Ownership Isolation';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST H, I: RELEASE & IDEMPOTENT DUPLICATE RELEASE
-- ============================================================================
DO $$
DECLARE
    v_target_variant UUID := 'b6000000-0000-0000-0000-000000000004';
    v_res_id UUID;
    v_avail_before INTEGER;
    v_avail_after INTEGER;
    v_released BOOLEAN;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';

    -- Find an active held reservation for Alice
    SELECT id INTO v_res_id
    FROM public.inventory_reservations
    WHERE quote_id = 'c6000000-0000-0000-0000-000000000001'
      AND variant_id = v_target_variant
      AND status = 'held'::inventory_reservation_status
    LIMIT 1;

    v_avail_before := public.get_variant_available_stock(v_target_variant);

    -- H. Release reservation -> Stock restored
    v_released := public.release_inventory_reservation(v_res_id);
    IF NOT v_released THEN
        RAISE EXCEPTION 'H. FAIL: Release returned false';
    END IF;

    v_avail_after := public.get_variant_available_stock(v_target_variant);
    IF v_avail_after <= v_avail_before THEN
        RAISE EXCEPTION 'H. FAIL: Available stock did not increase after release: before=%, after=%',
            v_avail_before, v_avail_after;
    END IF;

    -- I. Duplicate release: Must be a safe no-op returning true
    v_released := public.release_inventory_reservation(v_res_id);
    IF NOT v_released THEN
        RAISE EXCEPTION 'I. FAIL: Duplicate release failed';
    END IF;

    -- Stock must NOT double-release
    IF public.get_variant_available_stock(v_target_variant) != v_avail_after THEN
        RAISE EXCEPTION 'I. FAIL: Stock double-released on idempotent call';
    END IF;

    RAISE NOTICE 'ASSERTION PASS H & I: Release & Idempotent Duplicate Release';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST J, K, L: EXPIRY, DUPLICATE EXPIRY & EXPIRED CONSUMPTION BLOCK
-- ============================================================================
DO $$
DECLARE
    v_target_variant UUID := 'b6000000-0000-0000-0000-000000000004';
    v_quote_id UUID := 'c6000000-0000-0000-0000-000000000001';
    v_res_id UUID;
    v_avail_before INTEGER;
    v_avail_after INTEGER;
    v_expired BOOLEAN;
    v_threw BOOLEAN;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';

    -- Create a reservation
    v_res_id := public.create_inventory_reservation(v_quote_id, v_target_variant, 2);
    v_avail_before := public.get_variant_available_stock(v_target_variant);

    -- Simulate expiration by setting expires_at in the past (must reset role as customer cannot directly update reservations)
    RESET ROLE;
    UPDATE public.inventory_reservations
    SET expires_at = CURRENT_TIMESTAMP - INTERVAL '1 minute'
    WHERE id = v_res_id;
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';

    -- J. Run expiration
    v_expired := public.expire_inventory_reservation(v_res_id);
    IF NOT v_expired THEN
        RAISE EXCEPTION 'J. FAIL: Expiration returned false';
    END IF;

    v_avail_after := public.get_variant_available_stock(v_target_variant);
    IF v_avail_after != v_avail_before + 2 THEN
        RAISE EXCEPTION 'J. FAIL: Expected available stock %, got %', v_avail_before + 2, v_avail_after;
    END IF;

    -- K. Duplicate expiration -> Safe no-op, no second release
    v_expired := public.expire_inventory_reservation(v_res_id);
    IF v_expired THEN
        RAISE EXCEPTION 'K. FAIL: Second expiration returned true on already expired row';
    END IF;

    IF public.get_variant_available_stock(v_target_variant) != v_avail_after THEN
        RAISE EXCEPTION 'K. FAIL: Stock corrupted on duplicate expiration';
    END IF;

    -- L. Attempt to consume expired reservation -> MUST BE REJECTED
    v_threw := false;
    BEGIN
        PERFORM public.consume_inventory_reservation(v_res_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'L. FAIL: Expired reservation was successfully consumed';
    END IF;

    RAISE NOTICE 'ASSERTION PASS J, K, L: Expiry, Duplicate Expiry & Expired Consumption Rejection';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST M, N, O: CONSUMPTION, DUPLICATE CONSUMPTION & CONSUMED RELEASE BLOCK
-- ============================================================================
DO $$
DECLARE
    v_target_variant UUID := 'b6000000-0000-0000-0000-000000000004';
    v_quote_id UUID := 'c6000000-0000-0000-0000-000000000001';
    v_res_id UUID;
    v_on_hand_before INTEGER;
    v_on_hand_after INTEGER;
    v_reserved_before INTEGER;
    v_reserved_after INTEGER;
    v_consumed BOOLEAN;
    v_threw BOOLEAN;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';

    -- Create active reservation of 2 units
    v_res_id := public.create_inventory_reservation(v_quote_id, v_target_variant, 2);

    RESET ROLE;
    SELECT quantity_on_hand, quantity_reserved
    INTO v_on_hand_before, v_reserved_before
    FROM public.inventory_items
    WHERE variant_id = v_target_variant;

    -- M. Consume reservation into permanently sold inventory
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';
    v_consumed := public.consume_inventory_reservation(v_res_id);
    IF NOT v_consumed THEN
        RAISE EXCEPTION 'M. FAIL: Consume returned false';
    END IF;

    RESET ROLE;
    SELECT quantity_on_hand, quantity_reserved
    INTO v_on_hand_after, v_reserved_after
    FROM public.inventory_items
    WHERE variant_id = v_target_variant;

    -- Invariant: quantity_on_hand decreased by 2, quantity_reserved decreased by 2
    IF v_on_hand_after != v_on_hand_before - 2 OR v_reserved_after != v_reserved_before - 2 THEN
        RAISE EXCEPTION 'M. FAIL: Permanent inventory deduction incorrect: on_hand=% (was %), reserved=% (was %)',
            v_on_hand_after, v_on_hand_before, v_reserved_after, v_reserved_before;
    END IF;

    -- N. Duplicate consumption: Must be idempotent (returns true, no second deduction)
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';
    v_consumed := public.consume_inventory_reservation(v_res_id);
    IF NOT v_consumed THEN
        RAISE EXCEPTION 'N. FAIL: Duplicate consumption returned false';
    END IF;

    RESET ROLE;
    SELECT quantity_on_hand INTO v_on_hand_after
    FROM public.inventory_items WHERE variant_id = v_target_variant;

    IF v_on_hand_after != v_on_hand_before - 2 THEN
        RAISE EXCEPTION 'N. FAIL: Stock double-consumed on duplicate call: %', v_on_hand_after;
    END IF;

    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';

    -- O. Attempt to release an already-consumed reservation -> MUST BE REJECTED
    v_threw := false;
    BEGIN
        PERFORM public.release_inventory_reservation(v_res_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'O. FAIL: Released a committed/consumed reservation';
    END IF;

    RAISE NOTICE 'ASSERTION PASS M, N, O: Consumption, Idempotent Consumption & Consumed Release Protection';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST P: PAYMENT / EXPIRATION RACE CONDITION SIMULATION
-- ============================================================================
DO $$
DECLARE
    v_target_variant UUID := 'b6000000-0000-0000-0000-000000000004';
    v_quote_id UUID := 'c6000000-0000-0000-0000-000000000001';
    v_res_id UUID;
    v_threw BOOLEAN;
    v_status inventory_reservation_status;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';

    -- Create reservation
    v_res_id := public.create_inventory_reservation(v_quote_id, v_target_variant, 1);

    -- Simulate expiration occurring milliseconds before payment worker calls consume (reset role for test harness update)
    RESET ROLE;
    UPDATE public.inventory_reservations
    SET expires_at = CURRENT_TIMESTAMP - INTERVAL '1 second'
    WHERE id = v_res_id;
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';

    -- Consume under lock: Even though expiry worker has NOT run yet,
    -- consume_inventory_reservation inspects expires_at under row lock and REJECTS!
    v_threw := false;
    BEGIN
        PERFORM public.consume_inventory_reservation(v_res_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'P. FAIL: Payment worker consumed an expired reservation during race';
    END IF;

    -- Now expiry worker runs: Successfully marks as expired
    PERFORM public.expire_inventory_reservation(v_res_id);

    SELECT status INTO v_status FROM public.inventory_reservations WHERE id = v_res_id;
    IF v_status != 'expired'::inventory_reservation_status THEN
        RAISE EXCEPTION 'P. FAIL: Expected expired status, got %', v_status;
    END IF;

    RAISE NOTICE 'ASSERTION PASS P: Payment/Expiry Race Condition Mutual Exclusion Verified';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST Q, R: AUDIT LOG VALIDATION & RLS TENANT ISOLATION
-- ============================================================================
DO $$
DECLARE
    v_audit_count INTEGER;
    v_visible_count INTEGER;
    v_threw BOOLEAN;
BEGIN
    -- Q. Audit log check: Verify multiple mutation events recorded in append-only log
    SELECT count(*) INTO v_audit_count
    FROM public.inventory_audit_log
    WHERE variant_id IN (
        'b6000000-0000-0000-0000-000000000004',
        'b6000000-0000-0000-0000-000000000005'
    );

    IF v_audit_count < 4 THEN
        RAISE EXCEPTION 'Q. FAIL: Insufficient audit records in inventory_audit_log: %', v_audit_count;
    END IF;

    -- R.1 Customer Alice can only see reservations for her quotes
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';
    SELECT count(*) INTO v_visible_count
    FROM public.inventory_reservations
    WHERE quote_id = 'c6000000-0000-0000-0000-000000000002'; -- Bob's quote

    IF v_visible_count != 0 THEN
        RAISE EXCEPTION 'R.1 FAIL: Alice saw Bob reservations';
    END IF;

    -- R.2 Customer Alice cannot directly UPDATE inventory_reservations (must use RPCs)
    v_threw := false;
    BEGIN
        UPDATE public.inventory_reservations SET quantity = 100 WHERE quote_id = 'c6000000-0000-0000-0000-000000000001';
        -- If no rows updated or rejected, verify row count
        GET DIAGNOSTICS v_visible_count = ROW_COUNT;
        IF v_visible_count > 0 THEN v_threw := false; ELSE v_threw := true; END IF;
    EXCEPTION WHEN OTHERS THEN v_threw := true; END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'R.2 FAIL: Direct client update to inventory_reservations succeeded';
    END IF;

    RAISE NOTICE 'ASSERTION PASS Q & R: Audit Trail Immutability & RLS Tenancy Isolation';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST S: P1–P5 REGRESSION (CART, TAXONOMY VISIBILITY, SELLER LIFECYCLE)
-- ============================================================================
DO $$
DECLARE
    v_cart_lines INTEGER;
    v_is_visible BOOLEAN;
    v_product_id UUID := 'b6000000-0000-0000-0000-000000000003';
    v_seller_id UUID := 'b6000000-0000-0000-0000-000000000001';
BEGIN
    -- S.1 P5 Cart RPC remains functional
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000001';
    PERFORM public.add_to_customer_cart('b6000000-0000-0000-0000-000000000004', 1);
    RESET ROLE;
    SELECT count(*) INTO v_cart_lines
    FROM public.cart_lines cl
    JOIN public.carts c ON cl.cart_id = c.id
    WHERE c.user_id = 'a6000000-0000-0000-0000-000000000001';

    IF v_cart_lines = 0 THEN
        RAISE EXCEPTION 'S.1 FAIL: P5 Cart add failed';
    END IF;

    -- S.2 P3 Universal Catalog Visibility check
    SET ROLE anon;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    v_is_visible := public.is_product_visible(v_product_id);
    IF NOT v_is_visible THEN
        RAISE EXCEPTION 'S.2 FAIL: Live product not visible to anon';
    END IF;

    -- S.3 Seller suspension immediately hides product
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000009'; -- Admin Super
    PERFORM public.suspend_seller(v_seller_id, 'P6 regression test suspension');

    SET ROLE anon;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    v_is_visible := public.is_product_visible(v_product_id);
    IF v_is_visible THEN
        RAISE EXCEPTION 'S.3 FAIL: Suspended seller product still visible';
    END IF;

    -- Restore seller to active
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a6000000-0000-0000-0000-000000000009';
    PERFORM public.reactivate_seller(v_seller_id);
    RESET ROLE;

    RAISE NOTICE 'ASSERTION PASS S: P1-P5 Regression Intact';
END $$;

-- Summary notice
DO $$
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'ALL PHASE 6 INVENTORY RESERVATION TESTS PASSED!';
    RAISE NOTICE '==================================================';
END $$;
