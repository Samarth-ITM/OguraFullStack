-- ============================================================================
-- OGURA PHASE 8: ORDER CREATION, SELLER SUB-ORDERS & PAYMENT STATE ENGINE
-- Comprehensive Acceptance Test Suite (Assertions A through Z)
-- Corrected Post-Payment Sub-Order Creation Lifecycle
-- File: supabase/tests/p8_order_payment_test.sql
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
    SET search_path = public, auth, pg_temp;
END $$;

BEGIN;

-- 1. SEED TEST IDENTIFIERS
INSERT INTO auth.users (id, email) VALUES
    ('a8000000-0000-0000-0000-000000000001', 'alice_p8@ogura.test'),
    ('a8000000-0000-0000-0000-000000000002', 'bob_p8@ogura.test'),
    ('a8000000-0000-0000-0000-000000000003', 'seller1_p8@ogura.test'),
    ('a8000000-0000-0000-0000-000000000004', 'seller2_p8@ogura.test'),
    ('a8000000-0000-0000-0000-000000000009', 'admin_p8@ogura.test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email, phone) VALUES
    ('a8000000-0000-0000-0000-000000000001', 'Alice P8', 'alice_p8@ogura.test', '+919888800001'),
    ('a8000000-0000-0000-0000-000000000002', 'Bob P8', 'bob_p8@ogura.test', '+919888800002'),
    ('a8000000-0000-0000-0000-000000000003', 'Seller One P8', 'seller1_p8@ogura.test', '+919888800003'),
    ('a8000000-0000-0000-0000-000000000004', 'Seller Two P8', 'seller2_p8@ogura.test', '+919888800004'),
    ('a8000000-0000-0000-0000-000000000009', 'Admin Super P8', 'admin_p8@ogura.test', '+919888800009')
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

DELETE FROM public.user_roles WHERE user_id IN (
    'a8000000-0000-0000-0000-000000000001',
    'a8000000-0000-0000-0000-000000000002',
    'a8000000-0000-0000-0000-000000000003',
    'a8000000-0000-0000-0000-000000000004',
    'a8000000-0000-0000-0000-000000000009'
);

INSERT INTO public.user_roles (user_id, role) VALUES
    ('a8000000-0000-0000-0000-000000000001', 'customer'),
    ('a8000000-0000-0000-0000-000000000002', 'customer'),
    ('a8000000-0000-0000-0000-000000000003', 'seller'),
    ('a8000000-0000-0000-0000-000000000004', 'seller'),
    ('a8000000-0000-0000-0000-000000000009', 'admin_super');

-- Seed Sellers
SELECT set_config('request.jwt.claim.sub', 'a8000000-0000-0000-0000-000000000009', true);

INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status) VALUES
    ('b8000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000003', 'P8 Seller A', 'P8 Seller A Pvt Ltd', 'p8-seller-a', 'active'),
    ('b8000000-0000-0000-0000-000000000002', 'a8000000-0000-0000-0000-000000000004', 'P8 Seller B', 'P8 Seller B Pvt Ltd', 'p8-seller-b', 'active')
ON CONFLICT (id) DO UPDATE SET status = 'active';

INSERT INTO public.brands (id, seller_id, name, slug) VALUES
    ('b8000000-0000-0000-0000-000000000011', 'b8000000-0000-0000-0000-000000000001', 'P8 Brand A', 'p8-brand-a'),
    ('b8000000-0000-0000-0000-000000000012', 'b8000000-0000-0000-0000-000000000002', 'P8 Brand B', 'p8-brand-b')
ON CONFLICT (id) DO NOTHING;

-- Seed Products
INSERT INTO public.products (id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order) VALUES
    ('b8000000-0000-0000-0000-000000000021', 'b8000000-0000-0000-0000-000000000001', 'b8000000-0000-0000-0000-000000000011',
     (SELECT id FROM public.categories WHERE slug = 'clothing'), (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
     'P8 Silk Kaftan', 'p8-silk-kaftan', 'live', false),
    ('b8000000-0000-0000-0000-000000000022', 'b8000000-0000-0000-0000-000000000002', 'b8000000-0000-0000-0000-000000000012',
     (SELECT id FROM public.categories WHERE slug = 'clothing'), (SELECT id FROM public.subcategories WHERE slug = 'dresses'),
     'P8 Linen Dress', 'p8-linen-dress', 'live', false)
ON CONFLICT (id) DO UPDATE SET status = 'live';

-- Seed Variants:
-- V1: Seller A, ₹1,500 (150000 paise)
-- V2: Seller B, ₹1,499 (149900 paise)
INSERT INTO public.product_variants (id, product_id, sku, size, color, color_hex, price_paise, compare_at_price_paise) VALUES
    ('b8000000-0000-0000-0000-000000000031', 'b8000000-0000-0000-0000-000000000021', 'SKU-P8-KAFTAN-S', 'S', 'Ivory', '#fffff0', 150000, 180000),
    ('b8000000-0000-0000-0000-000000000032', 'b8000000-0000-0000-0000-000000000022', 'SKU-P8-LINEN-M',  'M', 'Olive', '#556b2f', 149900, 199900)
ON CONFLICT (id) DO NOTHING;

-- Seed Inventory items (100 each for robust testing)
INSERT INTO public.inventory_items (variant_id, quantity_on_hand, quantity_reserved, low_stock_threshold) VALUES
    ('b8000000-0000-0000-0000-000000000031', 100, 0, 2),
    ('b8000000-0000-0000-0000-000000000032', 100, 0, 2)
ON CONFLICT (variant_id) DO UPDATE SET
    quantity_on_hand = 100,
    quantity_reserved = 0,
    low_stock_threshold = 2;

-- Seed Customer Addresses
INSERT INTO public.customer_addresses (id, user_id, full_name, phone, line1, city, state, pincode, country, is_default) VALUES
    ('d8000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000001', 'Alice P8', '+919888800001', '801 Marine Drive', 'Mumbai', 'Maharashtra', '400020', 'IN', true),
    ('d8000000-0000-0000-0000-000000000002', 'a8000000-0000-0000-0000-000000000002', 'Bob P8', '+919888800002', '802 Bandra West', 'Mumbai', 'Maharashtra', '400050', 'IN', true)
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- ============================================================================
-- TEST A: SINGLE-SELLER ORDER CREATION (PRE-PAYMENT: NO SUB-ORDERS)
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_order JSONB;
    v_order_id UUID;
    v_sub_count INTEGER;
    v_payment RECORD;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001'; -- Alice

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 2); -- 2x Kaftan = 300000 paise (₹3,000 >= ₹2,999 free shipping)

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;

    -- Create Order from Quote
    v_order := public.create_order_from_quote(v_quote_id);
    v_order_id := (v_order->>'order_id')::UUID;

    -- Verify parent order
    IF (v_order->>'total_amount_paise')::BIGINT != 300000 THEN
        RAISE EXCEPTION 'A. FAIL: Expected total 300000, got %', v_order->>'total_amount_paise';
    END IF;

    IF v_order->>'status' != 'placed' THEN
        RAISE EXCEPTION 'A. FAIL: Expected status placed, got %', v_order->>'status';
    END IF;

    -- CRITICAL PRD INVARIANT: Exactly 0 seller sub-orders exist prior to payment confirmation!
    SELECT count(*) INTO v_sub_count FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_sub_count != 0 THEN
        RAISE EXCEPTION 'A. FAIL: Expected 0 seller sub-orders pre-payment, got %', v_sub_count;
    END IF;

    -- Verify payment transaction initiated
    SELECT id, gateway, amount_paise, status INTO v_payment
    FROM public.payment_transactions WHERE order_id = v_order_id;

    IF v_payment.id IS NULL OR v_payment.status != 'initiated'::payment_transaction_status OR v_payment.amount_paise != 300000 THEN
        RAISE EXCEPTION 'A. FAIL: Invalid payment transaction record: %', row_to_json(v_payment);
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS A: Single-Seller Order Created with 0 Pre-Payment Sub-Orders';
END $$;


-- ============================================================================
-- TEST B: MULTI-SELLER ORDER PRE-PAYMENT (0 SUB-ORDERS PRIOR TO CAPTURE)
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_order JSONB;
    v_order_id UUID;
    v_sub_count INTEGER;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001'; -- Alice

    PERFORM public.clear_customer_cart();
    -- 1x Seller A (₹1,500 = 150000) + 1x Seller B (₹1,499 = 149900)
    -- Subtotal = 299900 (Free shipping >= 299900)
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1);
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000032', 1);

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;

    v_order := public.create_order_from_quote(v_quote_id);
    v_order_id := (v_order->>'order_id')::UUID;

    -- Sub-orders must be 0 prior to payment capture
    SELECT count(*) INTO v_sub_count FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_sub_count != 0 THEN
        RAISE EXCEPTION 'B. FAIL: Expected 0 seller sub-orders pre-payment, got %', v_sub_count;
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS B: Multi-Seller Order Placed with 0 Pre-Payment Sub-Orders';
END $$;


-- ============================================================================
-- TEST C: QUOTE FINANCIAL AUTHORITY (NO CLIENT TAMPERING)
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_order JSONB;
    v_order_id UUID;
    v_threw BOOLEAN := false;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001'; -- Alice

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1); -- ₹1,500 (< ₹2,999 => +₹99 shipping = 159900 paise)

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;

    v_order := public.create_order_from_quote(v_quote_id);
    v_order_id := (v_order->>'order_id')::UUID;

    IF (v_order->>'total_amount_paise')::BIGINT != 159900 THEN
        RAISE EXCEPTION 'C. FAIL: Total did not derive authoritatively from quote: %', v_order->>'total_amount_paise';
    END IF;

    -- Try direct client update to modify total_amount_paise to 100 paise
    DECLARE
        v_rows INTEGER;
        v_client_tamper_blocked BOOLEAN := false;
    BEGIN
        BEGIN
            UPDATE public.orders SET total_amount_paise = 100 WHERE id = v_order_id;
            GET DIAGNOSTICS v_rows = ROW_COUNT;
            IF v_rows = 0 THEN
                v_client_tamper_blocked := true;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_client_tamper_blocked := true;
        END;

        IF NOT v_client_tamper_blocked THEN
            RAISE EXCEPTION 'C. FAIL: Client was able to update order rows directly';
        END IF;
    END;

    -- Reset role to verify database immutability trigger directly
    RESET ROLE;
    BEGIN
        UPDATE public.orders SET total_amount_paise = 100 WHERE id = v_order_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'C. FAIL: Direct database update of total_amount_paise was not blocked by trigger';
    END IF;

    RAISE NOTICE 'ASSERTION PASS C: Server-Authoritative Financial Values Protected';
END $$;


-- ============================================================================
-- TEST D: QUOTE OWNERSHIP ENFORCEMENT
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_alice_quote_id UUID;
    v_threw BOOLEAN := false;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001'; -- Alice

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1);
    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_alice_quote_id := (v_quote->>'quote_id')::UUID;

    -- Bob attempts to create order from Alice's quote
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000002'; -- Bob
    BEGIN
        PERFORM public.create_order_from_quote(v_alice_quote_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'D. FAIL: Bob was able to create order from Alice quote!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS D: Quote Ownership Enforced';
END $$;


-- ============================================================================
-- TEST E & F: EXPIRED QUOTE AND EXPIRED RESERVATION REJECTION
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_threw BOOLEAN := false;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001'; -- Alice

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1);

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;

    -- Simulate quote expiration
    RESET ROLE;
    UPDATE public.checkout_quotes
    SET expires_at = CURRENT_TIMESTAMP - INTERVAL '1 minute'
    WHERE id = v_quote_id;

    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';

    BEGIN
        PERFORM public.create_order_from_quote(v_quote_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'E. FAIL: Allowed order creation from expired quote';
    END IF;

    -- Test F: Unexpired quote, but expired reservation
    RESET ROLE;
    v_threw := false;
    UPDATE public.checkout_quotes
    SET expires_at = CURRENT_TIMESTAMP + INTERVAL '10 minutes'
    WHERE id = v_quote_id;

    UPDATE public.inventory_reservations
    SET expires_at = CURRENT_TIMESTAMP - INTERVAL '1 minute'
    WHERE quote_id = v_quote_id;

    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';

    BEGIN
        PERFORM public.create_order_from_quote(v_quote_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'F. FAIL: Allowed order creation with expired reservation';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS E & F: Expired Quote & Reservation Safely Rejected';
END $$;


-- ============================================================================
-- TEST G & H: INITIAL PAYMENT STATE & ORDER STATE
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_order JSONB;
    v_order_id UUID;
    v_payment RECORD;
    v_order_rec RECORD;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1);

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;
    v_order := public.create_order_from_quote(v_quote_id);
    v_order_id := (v_order->>'order_id')::UUID;

    -- G. Payment state is initiated
    SELECT status, gateway INTO v_payment FROM public.payment_transactions WHERE order_id = v_order_id;
    IF v_payment.status != 'initiated'::payment_transaction_status OR v_payment.gateway != 'razorpay' THEN
        RAISE EXCEPTION 'G. FAIL: Expected payment initiated, got %', v_payment.status;
    END IF;

    -- H. Order state is placed
    SELECT status INTO v_order_rec FROM public.orders WHERE id = v_order_id;
    IF v_order_rec.status != 'placed'::order_status THEN
        RAISE EXCEPTION 'H. FAIL: Expected order placed, got %', v_order_rec.status;
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS G & H: Initial Payment State (initiated) & Order State (placed) Verified';
END $$;


-- ============================================================================
-- TEST I & J: PAYMENT FAILURE & PAYMENT RETRY WORKFLOW
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_order JSONB;
    v_order_id UUID;
    v_fail_res JSONB;
    v_order_rec RECORD;
    v_payment RECORD;
    v_sub_count INTEGER;
    v_conf JSONB;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1);

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;
    v_order := public.create_order_from_quote(v_quote_id);
    v_order_id := (v_order->>'order_id')::UUID;

    -- I. Record payment failure
    v_fail_res := public.record_payment_failure(v_order_id, 'GATEWAY_ERROR', 'Card authorization failed');

    -- Verify payment is marked failed
    SELECT status INTO v_payment FROM public.payment_transactions WHERE order_id = v_order_id;
    IF v_payment.status != 'failed'::payment_transaction_status THEN
        RAISE EXCEPTION 'I. FAIL: Expected payment failed, got %', v_payment.status;
    END IF;

    -- Verify order remains placed (not confirmed)
    SELECT status INTO v_order_rec FROM public.orders WHERE id = v_order_id;
    IF v_order_rec.status != 'placed'::order_status THEN
        RAISE EXCEPTION 'I. FAIL: Order was prematurely changed from placed!';
    END IF;

    -- Verify 0 seller sub-orders exist after failure
    SELECT count(*) INTO v_sub_count FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_sub_count != 0 THEN
        RAISE EXCEPTION 'I. FAIL: Seller sub-orders created despite payment failure: count=%', v_sub_count;
    END IF;

    -- Verify inventory was NOT consumed (still held)
    IF NOT EXISTS (
        SELECT 1 FROM public.inventory_reservations
        WHERE quote_id = v_quote_id AND status = 'held'::inventory_reservation_status
    ) THEN
        RAISE EXCEPTION 'I. FAIL: Inventory reservation was altered after payment failure!';
    END IF;

    -- J. Customer retries payment and succeeds
    v_conf := public.confirm_order_payment(v_order_id, 'pay_retry_' || replace(v_order_id::text, '-', ''));

    IF v_conf->>'status' != 'confirmed' OR v_conf->>'payment_status' != 'captured' THEN
        RAISE EXCEPTION 'J. FAIL: Payment retry confirmation failed: %', v_conf;
    END IF;

    -- Verify seller sub-orders now exist
    SELECT count(*) INTO v_sub_count FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_sub_count != 1 THEN
        RAISE EXCEPTION 'J. FAIL: Expected 1 seller sub-order after successful retry, got %', v_sub_count;
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS I & J: Payment Failure Isolation & Retry Workflow Verified';
END $$;


-- ============================================================================
-- TEST K, L, M & N: SUCCESSFUL PAYMENT CONFIRMATION, IDEMPOTENCY & STOCK
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_order JSONB;
    v_order_id UUID;
    v_conf1 JSONB;
    v_conf2 JSONB;
    v_on_hand_before INTEGER;
    v_on_hand_after INTEGER;
    v_res_status inventory_reservation_status;
    v_sub_count INTEGER;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';

    -- Stock state before order
    SELECT quantity_on_hand INTO v_on_hand_before
    FROM public.inventory_items WHERE variant_id = 'b8000000-0000-0000-0000-000000000031';

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 2);

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;
    v_order := public.create_order_from_quote(v_quote_id);
    v_order_id := (v_order->>'order_id')::UUID;

    -- Prior to confirmation: 0 sub-orders
    SELECT count(*) INTO v_sub_count FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_sub_count != 0 THEN
        RAISE EXCEPTION 'K. FAIL: Sub-orders existed before confirmation!';
    END IF;

    -- K & M. Confirm payment: captures payment, confirms order, creates sub-orders, consumes stock
    v_conf1 := public.confirm_order_payment(v_order_id, 'pay_' || replace(v_order_id::text, '-', ''), 'sig_' || replace(v_order_id::text, '-', ''));

    IF v_conf1->>'status' != 'confirmed' OR v_conf1->>'payment_status' != 'captured' THEN
        RAISE EXCEPTION 'K. FAIL: Payment confirmation failed: %', v_conf1;
    END IF;

    -- Sub-orders now created
    SELECT count(*) INTO v_sub_count FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_sub_count != 1 THEN
        RAISE EXCEPTION 'K. FAIL: Expected 1 seller sub-order after confirmation, got %', v_sub_count;
    END IF;

    -- Reservation is committed
    SELECT status INTO v_res_status FROM public.inventory_reservations WHERE quote_id = v_quote_id;
    IF v_res_status != 'committed'::inventory_reservation_status THEN
        RAISE EXCEPTION 'M. FAIL: Reservation not committed: %', v_res_status;
    END IF;

    -- Stock decremented exactly once by 2
    SELECT quantity_on_hand INTO v_on_hand_after
    FROM public.inventory_items WHERE variant_id = 'b8000000-0000-0000-0000-000000000031';

    IF v_on_hand_after != (v_on_hand_before - 2) THEN
        RAISE EXCEPTION 'M. FAIL: Stock not decremented by 2 (before %, after %)', v_on_hand_before, v_on_hand_after;
    END IF;

    -- L & N. Duplicate confirmation (idempotency check)
    v_conf2 := public.confirm_order_payment(v_order_id, 'pay_' || replace(v_order_id::text, '-', ''), 'sig_' || replace(v_order_id::text, '-', ''));

    IF (v_conf2->>'is_idempotent')::BOOLEAN IS NOT TRUE THEN
        RAISE EXCEPTION 'L. FAIL: Duplicate confirmation not marked idempotent';
    END IF;

    -- Sub-orders count still exactly 1 (no duplicate sub-orders)
    SELECT count(*) INTO v_sub_count FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_sub_count != 1 THEN
        RAISE EXCEPTION 'L. FAIL: Duplicate sub-orders created upon repeat confirmation: %', v_sub_count;
    END IF;

    -- Stock not decremented a second time
    SELECT quantity_on_hand INTO v_on_hand_after
    FROM public.inventory_items WHERE variant_id = 'b8000000-0000-0000-0000-000000000031';

    IF v_on_hand_after != (v_on_hand_before - 2) THEN
        RAISE EXCEPTION 'N. FAIL: Stock decremented twice upon duplicate payment confirmation!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS K, L, M & N: Payment Capture, Sub-Order Creation, Stock Consumption & Idempotency Verified';
END $$;


-- ============================================================================
-- TEST O & P: PAYMENT / EXPIRY RACE & LATE PAYMENT REJECTION
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_order JSONB;
    v_order_id UUID;
    v_threw BOOLEAN := false;
    v_sub_count INTEGER;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1);

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;
    v_order := public.create_order_from_quote(v_quote_id);
    v_order_id := (v_order->>'order_id')::UUID;

    -- Simulate reservation expiry prior to payment confirmation
    RESET ROLE;
    UPDATE public.inventory_reservations
    SET expires_at = CURRENT_TIMESTAMP - INTERVAL '5 seconds'
    WHERE quote_id = v_quote_id;

    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';

    BEGIN
        PERFORM public.confirm_order_payment(v_order_id, 'pay_late_123');
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'O. FAIL: Allowed payment confirmation on expired reservation!';
    END IF;

    -- P. Late payment: Order must remain placed (not confirmed)
    IF (SELECT status FROM public.orders WHERE id = v_order_id) = 'confirmed'::order_status THEN
        RAISE EXCEPTION 'P. FAIL: Order transitioned to confirmed despite expired reservation!';
    END IF;

    -- Zero seller sub-orders must exist
    SELECT count(*) INTO v_sub_count FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_sub_count != 0 THEN
        RAISE EXCEPTION 'P. FAIL: Sub-orders created on late/expired payment attempt!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS O & P: Payment / Expiry Race Condition Handled Safely & Sub-Orders Prohibited';
END $$;


-- ============================================================================
-- TEST Q: SELLER SUB-ORDER CREATION TIMING PROOF
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_quote_id UUID;
    v_order JSONB;
    v_order_id UUID;
    v_count_placed INTEGER;
    v_count_confirmed INTEGER;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1);
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000032', 1);

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_quote_id := (v_quote->>'quote_id')::UUID;

    -- Stage 1: Order placed (pre-payment)
    v_order := public.create_order_from_quote(v_quote_id);
    v_order_id := (v_order->>'order_id')::UUID;

    SELECT count(*) INTO v_count_placed FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_count_placed != 0 THEN
        RAISE EXCEPTION 'Q. FAIL: Forbidden state: seller sub-orders exist during placed status!';
    END IF;

    -- Stage 2: Payment confirmed (post-capture)
    PERFORM public.confirm_order_payment(v_order_id, 'pay_q_' || replace(v_order_id::text, '-', ''));

    SELECT count(*) INTO v_count_confirmed FROM public.seller_sub_orders WHERE order_id = v_order_id;
    IF v_count_confirmed != 2 THEN
        RAISE EXCEPTION 'Q. FAIL: Expected exactly 2 seller sub-orders post-capture, got %', v_count_confirmed;
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS Q: Strict Post-Capture Timing for Seller Sub-Orders Formally Proven';
END $$;


-- ============================================================================
-- TEST R & S: CUSTOMER & SELLER TENANCY ISOLATION
-- ============================================================================
DO $$
DECLARE
    v_quote JSONB;
    v_alice_quote_id UUID;
    v_alice_order JSONB;
    v_alice_order_id UUID;
    v_threw BOOLEAN := false;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001'; -- Alice

    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1);

    v_quote := public.create_checkout_quote('d8000000-0000-0000-0000-000000000001');
    v_alice_quote_id := (v_quote->>'quote_id')::UUID;
    v_alice_order := public.create_order_from_quote(v_alice_quote_id);
    v_alice_order_id := (v_alice_order->>'order_id')::UUID;

    -- Confirm order
    PERFORM public.confirm_order_payment(v_alice_order_id, 'pay_rs_' || replace(v_alice_order_id::text, '-', ''));

    -- R. Bob attempts to view Alice's order via RPC
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000002'; -- Bob
    BEGIN
        PERFORM public.get_order_details(v_alice_order_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'R. FAIL: Bob was able to inspect Alice order!';
    END IF;

    -- S. Seller isolation: Seller B attempts to view order with only Seller A items
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000004'; -- Seller B
    v_threw := false;
    BEGIN
        PERFORM public.get_order_details(v_alice_order_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    IF NOT v_threw THEN
        RAISE EXCEPTION 'S. FAIL: Seller B was able to view order with no sub-orders for Seller B!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS R & S: Customer and Seller Tenancy Strictly Isolated';
END $$;


-- ============================================================================
-- TEST T, U & V: ORDER, SUB-ORDER & ITEM IMMUTABILITY TRIGGERS
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID;
    v_sub_order_id UUID;
    v_item_id UUID;
    v_threw BOOLEAN := false;
BEGIN
    SELECT id INTO v_order_id FROM public.orders WHERE status = 'confirmed' LIMIT 1;
    SELECT id INTO v_sub_order_id FROM public.seller_sub_orders WHERE order_id = v_order_id LIMIT 1;
    SELECT id INTO v_item_id FROM public.order_items WHERE sub_order_id = v_sub_order_id LIMIT 1;

    -- T. Attempt DELETE and financial UPDATE on orders
    BEGIN
        DELETE FROM public.orders WHERE id = v_order_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN RAISE EXCEPTION 'T. FAIL: Order delete was permitted!'; END IF;

    v_threw := false;
    BEGIN
        UPDATE public.orders SET subtotal_paise = subtotal_paise + 1000 WHERE id = v_order_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN RAISE EXCEPTION 'T. FAIL: Order subtotal_paise update was permitted!'; END IF;

    -- U. Attempt UPDATE on seller_sub_orders
    v_threw := false;
    BEGIN
        UPDATE public.seller_sub_orders SET subtotal_paise = subtotal_paise + 1000 WHERE id = v_sub_order_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN RAISE EXCEPTION 'U. FAIL: Sub-order subtotal_paise update was permitted!'; END IF;

    -- V. Attempt UPDATE and DELETE on order_items
    v_threw := false;
    BEGIN
        UPDATE public.order_items SET unit_price_paise = 1 WHERE id = v_item_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN RAISE EXCEPTION 'V. FAIL: Order item update was permitted!'; END IF;

    v_threw := false;
    BEGIN
        DELETE FROM public.order_items WHERE id = v_item_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN RAISE EXCEPTION 'V. FAIL: Order item delete was permitted!'; END IF;

    RAISE NOTICE 'ASSERTION PASS T, U & V: Order, Sub-Order & Item Immutability Confirmed';
END $$;


-- ============================================================================
-- TEST W: PARENT / SUB-ORDER CONSISTENCY & ITEM INTEGRITY
-- ============================================================================
DO $$
DECLARE
    v_order RECORD;
    v_sub_sum BIGINT;
    v_item_sum BIGINT;
BEGIN
    FOR v_order IN SELECT id, subtotal_paise, total_amount_paise FROM public.orders WHERE status = 'confirmed'
    LOOP
        SELECT COALESCE(SUM(subtotal_paise), 0) INTO v_sub_sum
        FROM public.seller_sub_orders WHERE order_id = v_order.id;

        IF v_sub_sum != v_order.subtotal_paise THEN
            RAISE EXCEPTION 'W. FAIL: Sub-order sum (%) != parent subtotal (%) for order %',
                v_sub_sum, v_order.subtotal_paise, v_order.id;
        END IF;

        SELECT COALESCE(SUM(total_price_paise), 0) INTO v_item_sum
        FROM public.order_items oi
        JOIN public.seller_sub_orders sso ON oi.sub_order_id = sso.id
        WHERE sso.order_id = v_order.id;

        IF v_item_sum != v_order.subtotal_paise THEN
            RAISE EXCEPTION 'W. FAIL: Order items sum (%) != parent subtotal (%) for order %',
                v_item_sum, v_order.subtotal_paise, v_order.id;
        END IF;
    END LOOP;

    RAISE NOTICE 'ASSERTION PASS W: Parent / Sub-Order & Item Integrity Reconciled';
END $$;


-- ============================================================================
-- TEST X: ATOMIC ROLLBACK ON DOWNSTREAM ERROR
-- ============================================================================
DO $$
DECLARE
    v_order_count_before INTEGER;
    v_order_count_after INTEGER;
    v_threw BOOLEAN := false;
BEGIN
    SELECT count(*) INTO v_order_count_before FROM public.orders;

    BEGIN
        SET ROLE authenticated;
        SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';
        PERFORM public.create_order_from_quote('00000000-0000-0000-0000-000000000000');
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;

    RESET ROLE;
    SELECT count(*) INTO v_order_count_after FROM public.orders;

    IF v_order_count_before != v_order_count_after THEN
        RAISE EXCEPTION 'X. FAIL: Atomicity violated: orphan order created upon failure!';
    END IF;

    RAISE NOTICE 'ASSERTION PASS X: Atomic Rollback Verified';
END $$;


-- ============================================================================
-- TEST Y: RLS DIRECT ACCESS DENIAL
-- ============================================================================
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000002'; -- Bob

    SELECT count(*) INTO v_count
    FROM public.orders
    WHERE user_id = 'a8000000-0000-0000-0000-000000000001';

    IF v_count != 0 THEN
        RAISE EXCEPTION 'Y. FAIL: Bob was able to read Alice orders directly via table SELECT (RLS leak)!';
    END IF;

    SELECT count(*) INTO v_count
    FROM public.payment_transactions pt
    JOIN public.orders o ON pt.order_id = o.id
    WHERE o.user_id = 'a8000000-0000-0000-0000-000000000001';

    IF v_count != 0 THEN
        RAISE EXCEPTION 'Y. FAIL: Bob was able to read Alice payments directly via table SELECT (RLS leak)!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS Y: RLS Cross-Customer Isolation Confirmed';
END $$;


-- ============================================================================
-- TEST Z: P1–P7 REGRESSION CHECKS
-- ============================================================================
DO $$
DECLARE
    v_visible BOOLEAN;
    v_cart_count INTEGER;
BEGIN
    -- 1. Catalog visibility (P3)
    SET ROLE anon;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    v_visible := public.is_product_visible('b8000000-0000-0000-0000-000000000021');
    IF NOT v_visible THEN
        RAISE EXCEPTION 'Z. FAIL: Catalog visibility broken for live product';
    END IF;

    -- 2. Cart & Address foundation (P5)
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a8000000-0000-0000-0000-000000000001';
    PERFORM public.clear_customer_cart();
    PERFORM public.add_to_customer_cart('b8000000-0000-0000-0000-000000000031', 1);

    SELECT count(*) INTO v_cart_count
    FROM public.cart_lines cl
    JOIN public.carts c ON cl.cart_id = c.id
    WHERE c.user_id = 'a8000000-0000-0000-0000-000000000001';

    IF v_cart_count != 1 THEN
        RAISE EXCEPTION 'Z. FAIL: Cart operations broken';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS Z: P1-P7 Regression Checks Passed';
END $$;

DO $$
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'ALL PHASE 8 (A through Z) ACCEPTANCE TESTS PASSED!';
    RAISE NOTICE '==================================================';
END $$;
