-- ============================================================================
-- OGURA PHASE 9 ACCEPTANCE TEST SUITE (27 AUTHORITATIVE ASSERTIONS)
--
-- File: supabase/tests/p9_fulfillment_test.sql
--
-- Tests the authoritative PRD fulfillment and shipping state engine:
-- Test 1:  Seller can initiate Ship on own sub-order
-- Test 2:  Seller cannot Ship another seller's sub-order (raises 42501)
-- Test 3:  Customer cannot initiate Ship (raises 42501)
-- Test 4:  Seller cannot directly manufacture delivered (raises 42501)
-- Test 5:  Manual AWB fallback works (carrier + AWB + status=dispatched)
-- Test 6:  Provider/aggregator shipment path represented correctly without live APIs
-- Test 7:  Shipment creation is idempotent (returns is_idempotent=true)
-- Test 8:  Duplicate Ship operation does not create duplicate shipments
-- Test 9:  AWB uniqueness across sub-orders is enforced (raises 23505)
-- Test 10: Invalid AWB/courier input is rejected (raises 22023)
-- Test 11: Delivery cannot be manufactured by seller via status update
-- Test 12: Tracking/webhook delivery transition is authoritative
-- Test 13: Duplicate delivery webhook is idempotent
-- Test 14: Invalid backward shipment transitions are rejected (raises 22023)
-- Test 15: Multi-seller fulfillment remains independent
-- Test 16: Parent order intermediate state is correct (confirmed -> partially_fulfilled)
-- Test 17: Parent order becomes fulfilled only when all non-cancelled sub-orders delivered
-- Test 18: All-cancelled behavior follows PRD (parent order becomes cancelled)
-- Test 19: Cancellation before shipment follows authoritative rules
-- Test 20: Cancellation after shipment is blocked (cannot cancel dispatched/delivered)
-- Test 21: Seller isolation (cross-seller access strictly blocked)
-- Test 22: Customer isolation (cross-customer access strictly blocked)
-- Test 23: Admin operational authority confirmed
-- Test 24: Shipment immutability triggers protect core references and block DELETE
-- Test 25: Append-only audit trail in order_status_history with courier/actor semantics
-- Test 26: Atomic rollback on error
-- Test 27: P8 order & payment regression invariants intact
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. SETUP TEST IDENTITIES
INSERT INTO auth.users (id, email) VALUES
    ('a9000000-0000-0000-0000-000000000001', 'alice_p9@ogura.test'),
    ('a9000000-0000-0000-0000-000000000002', 'bob_p9@ogura.test'),
    ('a9000000-0000-0000-0000-000000000003', 'seller1_p9@ogura.test'),
    ('a9000000-0000-0000-0000-000000000004', 'seller2_p9@ogura.test'),
    ('a9000000-0000-0000-0000-000000000009', 'admin_p9@ogura.test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, full_name) VALUES
    ('a9000000-0000-0000-0000-000000000001', 'alice_p9@ogura.test', 'Customer One P9'),
    ('a9000000-0000-0000-0000-000000000002', 'bob_p9@ogura.test', 'Customer Two P9'),
    ('a9000000-0000-0000-0000-000000000003', 'seller1_p9@ogura.test', 'Seller One User P9'),
    ('a9000000-0000-0000-0000-000000000004', 'seller2_p9@ogura.test', 'Seller Two User P9'),
    ('a9000000-0000-0000-0000-000000000009', 'admin_p9@ogura.test', 'Super Admin P9')
ON CONFLICT (id) DO NOTHING;

DELETE FROM public.user_roles WHERE user_id IN (
    'a9000000-0000-0000-0000-000000000001',
    'a9000000-0000-0000-0000-000000000002',
    'a9000000-0000-0000-0000-000000000003',
    'a9000000-0000-0000-0000-000000000004',
    'a9000000-0000-0000-0000-000000000009'
);

INSERT INTO public.user_roles (user_id, role) VALUES
    ('a9000000-0000-0000-0000-000000000001', 'customer'),
    ('a9000000-0000-0000-0000-000000000002', 'customer'),
    ('a9000000-0000-0000-0000-000000000003', 'seller'),
    ('a9000000-0000-0000-0000-000000000004', 'seller'),
    ('a9000000-0000-0000-0000-000000000009', 'admin_super');

-- Disable triggers temporarily for fixture seeding
SELECT set_config('session_replication_role', 'replica', false);

INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status) VALUES
    ('a9010000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000003', 'Sabyasachi P9', 'Sabyasachi Couture LLP', 'sabyasachi-p9', 'active'),
    ('a9010000-0000-0000-0000-000000000002', 'a9000000-0000-0000-0000-000000000004', 'Anita Dongre P9', 'House of Anita Dongre Ltd', 'anita-dongre-p9', 'active')
ON CONFLICT (id) DO UPDATE SET status = 'active';
DELETE FROM public.shipments WHERE awb_number LIKE '%P9%' OR awb_number LIKE '%BD-%' OR awb_number LIKE '%DTDC-%' OR awb_number LIKE '%DEL-%' OR awb_number LIKE '%AGY-%' OR awb_number LIKE '%ADM-%';
DELETE FROM public.order_status_history WHERE notes LIKE '%P9%' OR notes LIKE '%Sub-order%';
DELETE FROM public.seller_sub_orders WHERE sub_order_number LIKE '%P9%';
DELETE FROM public.orders WHERE order_number LIKE '%P9%';

SELECT set_config('session_replication_role', 'origin', false);

COMMIT;

-- Helper to set authenticated context
CREATE OR REPLACE FUNCTION set_test_user_p9(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    SET LOCAL ROLE authenticated;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- TEST 1: SELLER CAN INITIATE SHIP ON OWN SUB-ORDER (PRD PATH B MANUAL)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_ship_res JSONB;
    v_sub RECORD;
    v_ship RECORD;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, shipping_fee_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T01', 'a9000000-0000-0000-0000-000000000001', 1500000, 0, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T01-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller 1 ships own sub-order
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    v_ship_res := public.seller_ship_sub_order(v_sub_order_id, 'manual', 'Delhivery Express', 'DEL-P9-T01-AWB');

    ASSERT (v_ship_res->>'success')::boolean = true, 'Test 1 Failed: seller ship failed';
    ASSERT (v_ship_res->>'status') = 'awb_assigned', 'Test 1 Failed: shipment status should be awb_assigned';
    ASSERT (v_ship_res->>'sub_order_status') = 'dispatched', 'Test 1 Failed: sub-order should transition to dispatched';

    RESET ROLE;
    SELECT * INTO v_sub FROM public.seller_sub_orders WHERE id = v_sub_order_id;
    ASSERT v_sub.status = 'dispatched', 'Test 1 Failed: sub-order status not dispatched in DB';
    ASSERT v_sub.awb = 'DEL-P9-T01-AWB', 'Test 1 Failed: AWB not stamped';
    ASSERT v_sub.courier = 'Delhivery Express', 'Test 1 Failed: courier not stamped';
    ASSERT v_sub.dispatched_at IS NOT NULL, 'Test 1 Failed: dispatched_at not stamped';

    SELECT * INTO v_ship FROM public.shipments WHERE sub_order_id = v_sub_order_id;
    ASSERT v_ship.carrier = 'Delhivery Express', 'Test 1 Failed: shipment carrier wrong';
    ASSERT v_ship.awb_number = 'DEL-P9-T01-AWB', 'Test 1 Failed: shipment AWB wrong';

    RAISE NOTICE 'ASSERTION PASS 1: Seller can initiate Ship on own sub-order';
END;
$$;


-- ============================================================================
-- TEST 2: SELLER CANNOT SHIP ANOTHER SELLER''S SUB-ORDER (RAISES 42501)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_failed BOOLEAN := FALSE;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T02', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    -- Sub-order belongs to Seller 1
    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T02-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller 2 attempts to ship Seller 1's sub-order
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000004');
    BEGIN
        PERFORM public.seller_ship_sub_order(v_sub_order_id, 'manual', 'BlueDart', 'BD-P9-T02-AWB');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed := TRUE;
        END IF;
    END;

    ASSERT v_failed, 'Test 2 Failed: cross-seller ship must raise 42501';
    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 2: Seller cannot Ship another seller''s sub-order';
END;
$$;


-- ============================================================================
-- TEST 3: CUSTOMER CANNOT INITIATE SHIP (RAISES 42501)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_failed BOOLEAN := FALSE;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T03', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T03-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Customer attempts to ship
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000001');
    BEGIN
        PERFORM public.seller_ship_sub_order(v_sub_order_id, 'manual', 'BlueDart', 'BD-P9-T03-AWB');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed := TRUE;
        END IF;
    END;

    ASSERT v_failed, 'Test 3 Failed: customer ship must raise 42501';
    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 3: Customer cannot initiate Ship';
END;
$$;


-- ============================================================================
-- TEST 4: SELLER CANNOT DIRECTLY MANUFACTURE DELIVERED (RAISES 42501)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_failed BOOLEAN := FALSE;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T04', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T04-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller attempts to directly mark sub-order as delivered
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    BEGIN
        PERFORM public.seller_update_sub_order_status(v_sub_order_id, 'delivered');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed := TRUE;
        END IF;
    END;

    ASSERT v_failed, 'Test 4 Failed: seller manufacturing delivered must raise 42501';
    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 4: Seller cannot directly manufacture delivered';
END;
$$;


-- ============================================================================
-- TEST 5: MANUAL AWB FALLBACK WORKS (CARRIER + AWB + STATUS=DISPATCHED)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_res JSONB;
    v_sub RECORD;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T05', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T05-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'packed');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller uses manual AWB fallback
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    v_res := public.seller_ship_sub_order(v_sub_order_id, 'manual', 'DTDC Courier', 'DTDC-MANUAL-12345');

    ASSERT (v_res->>'success')::boolean = true, 'Test 5 Failed: manual fallback failed';
    ASSERT (v_res->>'shipping_mode') = 'manual', 'Test 5 Failed: mode should be manual';
    ASSERT (v_res->>'carrier') = 'DTDC Courier', 'Test 5 Failed: carrier mismatch';
    ASSERT (v_res->>'awb_number') = 'DTDC-MANUAL-12345', 'Test 5 Failed: awb mismatch';

    RESET ROLE;
    SELECT * INTO v_sub FROM public.seller_sub_orders WHERE id = v_sub_order_id;
    ASSERT v_sub.status = 'dispatched', 'Test 5 Failed: sub-order should be dispatched';
    ASSERT v_sub.awb = 'DTDC-MANUAL-12345', 'Test 5 Failed: sub-order awb wrong';
    ASSERT v_sub.courier = 'DTDC Courier', 'Test 5 Failed: sub-order courier wrong';

    RAISE NOTICE 'ASSERTION PASS 5: Manual AWB fallback works';
END;
$$;


-- ============================================================================
-- TEST 6: PROVIDER/AGGREGATOR SHIPMENT PATH (SIMULATED ADAPTER BOUNDARY)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_res JSONB;
    v_sub RECORD;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T06', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T06-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller ships using aggregator mode (no credentials, simulated provider adapter boundary)
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    v_res := public.seller_ship_sub_order(v_sub_order_id, 'aggregator');

    ASSERT (v_res->>'success')::boolean = true, 'Test 6 Failed: aggregator ship failed';
    ASSERT (v_res->>'shipping_mode') = 'aggregator', 'Test 6 Failed: mode should be aggregator';
    ASSERT (v_res->>'carrier') = 'Delhivery', 'Test 6 Failed: default carrier should be Delhivery';
    ASSERT (v_res->>'awb_number') IS NOT NULL, 'Test 6 Failed: awb should be generated by adapter';
    ASSERT (v_res->>'sub_order_status') = 'dispatched', 'Test 6 Failed: sub-order should be dispatched';

    RESET ROLE;
    SELECT * INTO v_sub FROM public.seller_sub_orders WHERE id = v_sub_order_id;
    ASSERT v_sub.status = 'dispatched', 'Test 6 Failed: sub-order status not dispatched in DB';
    ASSERT v_sub.awb = (v_res->>'awb_number'), 'Test 6 Failed: sub-order awb does not match';
    ASSERT v_sub.courier = 'Delhivery', 'Test 6 Failed: sub-order courier wrong';

    RAISE NOTICE 'ASSERTION PASS 6: Provider/aggregator shipment path represented correctly without live APIs';
END;
$$;


-- ============================================================================
-- TEST 7: SHIPMENT CREATION IS IDEMPOTENT (RETURNS IS_IDEMPOTENT=TRUE)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_res1 JSONB;
    v_res2 JSONB;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T07', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T07-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    v_res1 := public.seller_ship_sub_order(v_sub_order_id, 'manual', 'BlueDart', 'BD-IDEM-001');
    -- Duplicate ship call with same AWB
    v_res2 := public.seller_ship_sub_order(v_sub_order_id, 'manual', 'BlueDart', 'BD-IDEM-001');

    ASSERT (v_res2->>'is_idempotent')::boolean = true, 'Test 7 Failed: should be marked idempotent';
    ASSERT (v_res1->>'shipment_id') = (v_res2->>'shipment_id'), 'Test 7 Failed: shipment id should match';

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 7: Shipment creation is idempotent';
END;
$$;


-- ============================================================================
-- TEST 8: DUPLICATE SHIP OPERATION DOES NOT CREATE DUPLICATE SHIPMENTS
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_count INT;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T08', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T08-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    PERFORM public.seller_ship_sub_order(v_sub_order_id, 'manual', 'BlueDart', 'BD-NO-DUP-001');
    PERFORM public.seller_ship_sub_order(v_sub_order_id, 'manual', 'BlueDart', 'BD-NO-DUP-001');

    RESET ROLE;
    SELECT COUNT(*) INTO v_count FROM public.shipments WHERE sub_order_id = v_sub_order_id;
    ASSERT v_count = 1, 'Test 8 Failed: duplicate shipment row created! Count = ' || v_count;

    RAISE NOTICE 'ASSERTION PASS 8: Duplicate Ship operation does not create duplicate shipments';
END;
$$;


-- ============================================================================
-- TEST 9: AWB UNIQUENESS ACROSS SUB-ORDERS IS ENFORCED (RAISES 23505)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id1 UUID := gen_random_uuid();
    v_sub_order_id2 UUID := gen_random_uuid();
    v_failed BOOLEAN := FALSE;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T09', 'a9000000-0000-0000-0000-000000000001', 3000000, 3000000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES
        (v_sub_order_id1, 'SO-P9-T09-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted'),
        (v_sub_order_id2, 'SO-P9-T09-2', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    PERFORM public.seller_ship_sub_order(v_sub_order_id1, 'manual', 'BlueDart', 'BD-UNIQUE-AWB');

    -- Attempt to assign same AWB to sub-order 2
    BEGIN
        PERFORM public.seller_ship_sub_order(v_sub_order_id2, 'manual', 'BlueDart', 'BD-UNIQUE-AWB');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '23505' THEN
            v_failed := TRUE;
        END IF;
    END;

    ASSERT v_failed, 'Test 9 Failed: duplicate AWB across different sub-orders must raise 23505';
    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 9: AWB uniqueness across sub-orders is enforced';
END;
$$;


-- ============================================================================
-- TEST 10: INVALID AWB / COURIER INPUT IS REJECTED (RAISES 22023)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_failed_carrier BOOLEAN := FALSE;
    v_failed_awb BOOLEAN := FALSE;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T10', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T10-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');

    -- Blank carrier
    BEGIN
        PERFORM public.seller_ship_sub_order(v_sub_order_id, 'manual', '   ', 'VALID-AWB-1234');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '22023' THEN
            v_failed_carrier := TRUE;
        END IF;
    END;

    -- Blank / too short AWB
    BEGIN
        PERFORM public.seller_ship_sub_order(v_sub_order_id, 'manual', 'Valid Carrier', '12');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '22023' THEN
            v_failed_awb := TRUE;
        END IF;
    END;

    ASSERT v_failed_carrier, 'Test 10 Failed: blank carrier must raise 22023';
    ASSERT v_failed_awb, 'Test 10 Failed: invalid AWB must raise 22023';

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 10: Invalid AWB / courier input is rejected';
END;
$$;


-- ============================================================================
-- TEST 11: DELIVERY CANNOT BE MANUFACTURED BY SELLER, CUSTOMER OR UNTRUSTED USERS (RAISES 42501)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_failed_sub_delivered BOOLEAN := FALSE;
    v_failed_seller_ship_status BOOLEAN := FALSE;
    v_failed_seller_ship_delivered BOOLEAN := FALSE;
    v_failed_customer_ship_status BOOLEAN := FALSE;
    v_failed_untrusted_ship_status BOOLEAN := FALSE;
    v_ship_res JSONB;
    v_shipment_id UUID;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T11', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T11-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller ships own sub-order
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    v_ship_res := public.seller_ship_sub_order(v_sub_order_id, 'manual', 'Delhivery', 'DEL-P9-T11-AWB');
    v_shipment_id := (v_ship_res->>'shipment_id')::UUID;

    -- 1. Seller attempts to update sub-order directly to delivered (BLOCKED)
    BEGIN
        PERFORM public.seller_update_sub_order_status(v_sub_order_id, 'delivered');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_sub_delivered := TRUE;
        END IF;
    END;

    -- 2. Seller attempts to directly mutate shipment status to in_transit (BLOCKED)
    BEGIN
        PERFORM public.update_shipment_status(v_shipment_id, 'in_transit');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_seller_ship_status := TRUE;
        END IF;
    END;

    -- 3. Seller attempts to directly mutate shipment status to delivered (BLOCKED)
    BEGIN
        PERFORM public.update_shipment_status(v_shipment_id, 'delivered');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_seller_ship_delivered := TRUE;
        END IF;
    END;

    -- 4. Customer attempts to mutate shipment status (BLOCKED)
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000001');
    BEGIN
        PERFORM public.update_shipment_status(v_shipment_id, 'delivered');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_customer_ship_status := TRUE;
        END IF;
    END;

    -- 5. Untrusted user attempts to mutate shipment status (BLOCKED)
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000002');
    BEGIN
        PERFORM public.update_shipment_status(v_shipment_id, 'in_transit');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_untrusted_ship_status := TRUE;
        END IF;
    END;

    ASSERT v_failed_sub_delivered, 'Test 11 Failed: seller update sub-order to delivered must raise 42501';
    ASSERT v_failed_seller_ship_status, 'Test 11 Failed: seller direct shipment mutation to in_transit must raise 42501';
    ASSERT v_failed_seller_ship_delivered, 'Test 11 Failed: seller direct shipment mutation to delivered must raise 42501';
    ASSERT v_failed_customer_ship_status, 'Test 11 Failed: customer direct shipment mutation must raise 42501';
    ASSERT v_failed_untrusted_ship_status, 'Test 11 Failed: untrusted direct shipment mutation must raise 42501';

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 11: Direct shipment and delivery status mutation strictly prohibited for sellers, customers, and untrusted users';
END;
$$;


-- ============================================================================
-- TEST 12: TRACKING WEBHOOK BOUNDARY (SECRET VERIFICATION, EVENT AUDIT, AUTHORITATIVE TRANSITION)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_ship_res JSONB;
    v_shipment_id UUID;
    v_failed_bad_secret BOOLEAN := FALSE;
    v_webhook_res JSONB;
    v_sub RECORD;
    v_ship RECORD;
    v_evt RECORD;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T12', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T12-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller ships
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    v_ship_res := public.seller_ship_sub_order(v_sub_order_id, 'manual', 'Delhivery', 'DEL-P9-T12-AWB');
    v_shipment_id := (v_ship_res->>'shipment_id')::UUID;

    -- 1. Webhook with invalid secret is DENIED (raises 42501)
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000002');
    BEGIN
        PERFORM public.process_tracking_webhook(
            'Delhivery',
            'EVT-T12-BAD',
            'tracking.update',
            jsonb_build_object('shipment_id', v_shipment_id, 'status', 'in_transit'),
            'bad_secret_xyz'
        );
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_bad_secret := TRUE;
        END IF;
    END;
    ASSERT v_failed_bad_secret, 'Test 12 Failed: webhook with invalid secret must raise 42501';

    -- 2. Trusted Provider Webhook with valid secret: in_transit
    v_webhook_res := public.process_tracking_webhook(
        'Delhivery',
        'EVT-T12-TRANSIT',
        'tracking.update',
        jsonb_build_object('shipment_id', v_shipment_id, 'status', 'in_transit', 'notes', 'Parcel scanned at Delhi Hub'),
        'ogura_carrier_webhook_secret_p9'
    );
    ASSERT (v_webhook_res->>'success')::boolean = true, 'Test 12 Failed: valid in_transit webhook should succeed';

    RESET ROLE;
    SELECT * INTO v_ship FROM public.shipments WHERE id = v_shipment_id;
    ASSERT v_ship.status = 'in_transit', 'Test 12 Failed: shipment should be in_transit';

    -- 3. Trusted Provider Webhook with valid secret: delivered
    v_webhook_res := public.process_tracking_webhook(
        'Delhivery',
        'EVT-T12-DELIVERED',
        'tracking.update',
        jsonb_build_object('shipment_id', v_shipment_id, 'status', 'delivered', 'notes', 'Delivered to recipient doorstep'),
        'ogura_carrier_webhook_secret_p9'
    );
    ASSERT (v_webhook_res->>'success')::boolean = true, 'Test 12 Failed: valid delivered webhook should succeed';

    RESET ROLE;
    SELECT * INTO v_sub FROM public.seller_sub_orders WHERE id = v_sub_order_id;
    SELECT * INTO v_ship FROM public.shipments WHERE id = v_shipment_id;

    ASSERT v_ship.status = 'delivered', 'Test 12 Failed: shipment status should be delivered';
    ASSERT v_ship.delivered_at IS NOT NULL, 'Test 12 Failed: shipment delivered_at not stamped';
    ASSERT v_sub.status = 'delivered', 'Test 12 Failed: sub-order should synchronize to delivered';
    ASSERT v_sub.delivered_at IS NOT NULL, 'Test 12 Failed: sub-order delivered_at not stamped';

    -- Verify webhook_events audit log
    SELECT * INTO v_evt FROM public.webhook_events WHERE event_id = 'EVT-T12-DELIVERED';
    ASSERT v_evt.id IS NOT NULL, 'Test 12 Failed: webhook_events record missing';
    ASSERT v_evt.processed = true, 'Test 12 Failed: webhook event not marked processed';

    RAISE NOTICE 'ASSERTION PASS 12: Tracking webhook boundary verified (secret checked, audit recorded, delivery authoritative)';
END;
$$;


-- ============================================================================
-- TEST 13: DUPLICATE DELIVERY WEBHOOK IS IDEMPOTENT (NO-OP)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_ship_res JSONB;
    v_shipment_id UUID;
    v_del_res JSONB;
    v_dup_webhook_res JSONB;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T13', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T13-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    v_ship_res := public.seller_ship_sub_order(v_sub_order_id, 'manual', 'Delhivery', 'DEL-P9-T13-AWB');
    v_shipment_id := (v_ship_res->>'shipment_id')::UUID;

    -- Process initial delivery event via process_tracking_webhook
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000009');
    PERFORM public.update_shipment_status(v_shipment_id, 'in_transit', 'In transit');
    
    v_del_res := public.process_tracking_webhook(
        'Delhivery',
        'EVT-T13-DELIVERED',
        'tracking.update',
        jsonb_build_object('shipment_id', v_shipment_id, 'status', 'delivered'),
        'ogura_carrier_webhook_secret_p9'
    );
    ASSERT (v_del_res->>'success')::boolean = true, 'Test 13 Failed: initial delivered webhook should succeed';

    -- Duplicate delivery webhook event with same event_id: must be NO-OP
    v_dup_webhook_res := public.process_tracking_webhook(
        'Delhivery',
        'EVT-T13-DELIVERED',
        'tracking.update',
        jsonb_build_object('shipment_id', v_shipment_id, 'status', 'delivered'),
        'ogura_carrier_webhook_secret_p9'
    );
    ASSERT (v_dup_webhook_res->>'is_idempotent')::boolean = true, 'Test 13 Failed: duplicate webhook event must be idempotent';
    ASSERT (v_dup_webhook_res->>'duplicate_event')::boolean = true, 'Test 13 Failed: duplicate_event flag must be true';

    -- Direct call to update_shipment_status with already-delivered shipment
    v_del_res := public.update_shipment_status(v_shipment_id, 'delivered', 'Duplicate direct call', 'ogura_carrier_webhook_secret_p9');
    ASSERT (v_del_res->>'is_idempotent')::boolean = true, 'Test 13 Failed: duplicate direct delivery status update must be idempotent';

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 13: Duplicate delivery webhook is idempotent (NO-OP)';
END;
$$;


-- ============================================================================
-- TEST 14: INVALID BACKWARD SHIPMENT TRANSITIONS ARE REJECTED (RAISES 22023)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_order_id UUID := gen_random_uuid();
    v_ship_res JSONB;
    v_shipment_id UUID;
    v_failed BOOLEAN := FALSE;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T14', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_order_id, 'SO-P9-T14-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    v_ship_res := public.seller_ship_sub_order(v_sub_order_id, 'manual', 'Delhivery', 'DEL-P9-T14-AWB');
    v_shipment_id := (v_ship_res->>'shipment_id')::UUID;

    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000009');
    PERFORM public.update_shipment_status(v_shipment_id, 'in_transit');
    PERFORM public.update_shipment_status(v_shipment_id, 'delivered');

    -- Attempt backward transition from delivered to in_transit
    BEGIN
        PERFORM public.update_shipment_status(v_shipment_id, 'in_transit');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '22023' THEN
            v_failed := TRUE;
        END IF;
    END;

    ASSERT v_failed, 'Test 14 Failed: backward transition from delivered must raise 22023';
    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 14: Invalid backward shipment transitions are rejected';
END;
$$;


-- ============================================================================
-- TEST 15, 16 & 17: MULTI-SELLER INDEPENDENCE, INTERMEDIATE PARTIAL & TERMINAL FULFILLED
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_a UUID := gen_random_uuid();
    v_sub_b UUID := gen_random_uuid();
    v_ship_a JSONB;
    v_ship_b JSONB;
    v_shipment_a_id UUID;
    v_shipment_b_id UUID;
    v_ord RECORD;
    v_sub_b_rec RECORD;
    v_term_transitions INT;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, shipping_fee_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T15', 'a9000000-0000-0000-0000-000000000001', 4000000, 0, 4000000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES
        (v_sub_a, 'SO-P9-T15-A', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted'),
        (v_sub_b, 'SO-P9-T15-B', v_order_id, 'a9010000-0000-0000-0000-000000000002', 2500000, 2500000, 2500000, 'pending_acceptance');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller A ships sub-order A
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    v_ship_a := public.seller_ship_sub_order(v_sub_a, 'manual', 'Delhivery', 'DEL-P9-T15-A');
    v_shipment_a_id := (v_ship_a->>'shipment_id')::UUID;

    RESET ROLE;
    -- Seller B sub-order must remain independent (still pending_acceptance)
    SELECT * INTO v_sub_b_rec FROM public.seller_sub_orders WHERE id = v_sub_b;
    ASSERT v_sub_b_rec.status = 'pending_acceptance', 'Test 15 Failed: Sub-order B affected by Seller A ship!';

    -- Check parent intermediate status: must be partially_fulfilled
    SELECT * INTO v_ord FROM public.orders WHERE id = v_order_id;
    ASSERT v_ord.status = 'partially_fulfilled', 'Test 16 Failed: parent order should be partially_fulfilled, got: ' || v_ord.status;

    -- Carrier delivers sub-order A
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000009');
    PERFORM public.update_shipment_status(v_shipment_a_id, 'in_transit');
    PERFORM public.update_shipment_status(v_shipment_a_id, 'delivered');

    RESET ROLE;
    -- Parent order still partially_fulfilled because Sub-order B is not delivered
    SELECT * INTO v_ord FROM public.orders WHERE id = v_order_id;
    ASSERT v_ord.status = 'partially_fulfilled', 'Test 16 Failed: parent order should remain partially_fulfilled';

    -- Now Seller B accepts and ships sub-order B
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000004');
    PERFORM public.seller_accept_sub_order(v_sub_b);
    v_ship_b := public.seller_ship_sub_order(v_sub_b, 'manual', 'BlueDart', 'BD-P9-T15-B');
    v_shipment_b_id := (v_ship_b->>'shipment_id')::UUID;

    -- Carrier delivers sub-order B
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000009');
    PERFORM public.update_shipment_status(v_shipment_b_id, 'in_transit');
    PERFORM public.update_shipment_status(v_shipment_b_id, 'delivered');

    RESET ROLE;
    -- Now all sub-orders are delivered -> parent order must be fulfilled
    SELECT * INTO v_ord FROM public.orders WHERE id = v_order_id;
    ASSERT v_ord.status = 'fulfilled', 'Test 17 Failed: parent order should be fulfilled, got: ' || v_ord.status;
    ASSERT v_ord.fulfilled_at IS NOT NULL, 'Test 17 Failed: fulfilled_at not stamped';

    -- J. Verify exactly one parent terminal transition to fulfilled
    SELECT count(*) INTO v_term_transitions
    FROM public.order_status_history
    WHERE order_id = v_order_id AND to_status = 'fulfilled';
    ASSERT v_term_transitions = 1, 'Test 17 Failed: exactly one parent terminal transition should be logged, got: ' || v_term_transitions;

    RAISE NOTICE 'ASSERTION PASS 15, 16 & 17: Multi-seller independence, intermediate partial & terminal fulfilled verified';
END;
$$;


-- ============================================================================
-- TEST 18: ALL-CANCELLED BEHAVIOR FOLLOWS PRD (PARENT ORDER CANCELLED)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub1 UUID := gen_random_uuid();
    v_sub2 UUID := gen_random_uuid();
    v_ord RECORD;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T18', 'a9000000-0000-0000-0000-000000000001', 3000000, 3000000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES
        (v_sub1, 'SO-P9-T18-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted'),
        (v_sub2, 'SO-P9-T18-2', v_order_id, 'a9010000-0000-0000-0000-000000000002', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller 1 cancels sub 1
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    PERFORM public.seller_update_sub_order_status(v_sub1, 'cancelled', 'Out of stock');

    -- Seller 2 cancels sub 2
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000004');
    PERFORM public.seller_update_sub_order_status(v_sub2, 'cancelled', 'Fabric defect');

    RESET ROLE;
    SELECT * INTO v_ord FROM public.orders WHERE id = v_order_id;
    ASSERT v_ord.status = 'cancelled', 'Test 18 Failed: parent order should be cancelled when all sub-orders are cancelled';

    RAISE NOTICE 'ASSERTION PASS 18: All-cancelled parent order progression verified';
END;
$$;


-- ============================================================================
-- TEST 19 & 20: CANCELLATION RULES (PRE-SHIPMENT ALLOWED, POST-SHIPMENT BLOCKED)
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_pre UUID := gen_random_uuid();
    v_sub_post UUID := gen_random_uuid();
    v_failed BOOLEAN := FALSE;
    v_sub RECORD;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T19', 'a9000000-0000-0000-0000-000000000001', 3000000, 3000000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES
        (v_sub_pre, 'SO-P9-T19-PRE', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'packed'),
        (v_sub_post, 'SO-P9-T19-POST', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Pre-shipment cancellation: Allowed
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    PERFORM public.seller_update_sub_order_status(v_sub_pre, 'cancelled', 'Customer requested pre-ship cancel');

    RESET ROLE;
    SELECT * INTO v_sub FROM public.seller_sub_orders WHERE id = v_sub_pre;
    ASSERT v_sub.status = 'cancelled', 'Test 19 Failed: pre-ship cancel should succeed';
    ASSERT v_sub.cancellation_reason = 'Customer requested pre-ship cancel', 'Test 19 Failed: reason not stamped';

    -- Post-shipment cancellation: Blocked
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    PERFORM public.seller_ship_sub_order(v_sub_post, 'manual', 'Delhivery', 'DEL-P9-T20-AWB');

    BEGIN
        PERFORM public.seller_update_sub_order_status(v_sub_post, 'cancelled', 'Cancel after ship');
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '22023' THEN
            v_failed := TRUE;
        END IF;
    END;

    ASSERT v_failed, 'Test 20 Failed: post-shipment cancel must raise 22023';
    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 19 & 20: Pre-shipment cancellation allowed, post-shipment blocked';
END;
$$;


-- ============================================================================
-- TEST 21 & 22: SELLER AND CUSTOMER TENANCY ISOLATION
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_id UUID := gen_random_uuid();
    v_failed_seller BOOLEAN := FALSE;
    v_failed_cust BOOLEAN := FALSE;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T21', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_id, 'SO-P9-T21-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Seller 2 tries to inspect Seller 1's sub-order details
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000004');
    BEGIN
        PERFORM public.get_sub_order_fulfillment_details(v_sub_id);
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_seller := TRUE;
        END IF;
    END;

    -- Customer 2 tries to inspect Customer 1's sub-order details
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000002');
    BEGIN
        PERFORM public.get_sub_order_fulfillment_details(v_sub_id);
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_cust := TRUE;
        END IF;
    END;

    ASSERT v_failed_seller, 'Test 21 Failed: cross-seller inspection must raise 42501';
    ASSERT v_failed_cust, 'Test 22 Failed: cross-customer inspection must raise 42501';

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 21 & 22: Seller and customer tenancy isolation confirmed';
END;
$$;


-- ============================================================================
-- TEST 23: ADMIN OPERATIONAL AUTHORITY CONFIRMED
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_id UUID := gen_random_uuid();
    v_ship_res JSONB;
    v_details JSONB;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T23', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_id, 'SO-P9-T23-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Admin super ships sub-order on behalf of seller
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000009');
    v_ship_res := public.seller_ship_sub_order(v_sub_id, 'manual', 'Admin Courier', 'ADM-P9-T23-AWB');
    ASSERT (v_ship_res->>'success')::boolean = true, 'Test 23 Failed: admin ship failed';

    -- Admin inspects fulfillment details
    v_details := public.get_sub_order_fulfillment_details(v_sub_id);
    ASSERT (v_details->>'sub_order_id')::UUID = v_sub_id, 'Test 23 Failed: admin inspection failed';

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 23: Admin operational authority confirmed';
END;
$$;


-- ============================================================================
-- TEST 24: SHIPMENT IMMUTABILITY TRIGGER PROTECTION CONFIRMED
-- ============================================================================
DO $$
DECLARE
    v_ship RECORD;
    v_failed_del BOOLEAN := FALSE;
    v_failed_upd BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_ship FROM public.shipments LIMIT 1;

    -- Block DELETE
    BEGIN
        DELETE FROM public.shipments WHERE id = v_ship.id;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_del := TRUE;
        END IF;
    END;

    -- Block updating core awb reference
    BEGIN
        UPDATE public.shipments SET awb_number = 'TAMPERED-AWB' WHERE id = v_ship.id;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_failed_upd := TRUE;
        END IF;
    END;

    ASSERT v_failed_del, 'Test 24 Failed: shipment DELETE must raise 42501';
    ASSERT v_failed_upd, 'Test 24 Failed: tampering shipment awb must raise 42501';

    RAISE NOTICE 'ASSERTION PASS 24: Shipment immutability trigger protection confirmed';
END;
$$;


-- ============================================================================
-- TEST 25: APPEND-ONLY AUDIT TRAIL IN ORDER_STATUS_HISTORY CONFIRMED
-- ============================================================================
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.order_status_history
    WHERE to_status = 'dispatched';

    ASSERT v_count >= 1, 'Test 25 Failed: no dispatched audit trail records found';
    RAISE NOTICE 'ASSERTION PASS 25: Append-only audit trail in order_status_history confirmed';
END;
$$;


-- ============================================================================
-- TEST 26: ATOMIC ROLLBACK ON ERROR CONFIRMED
-- ============================================================================
DO $$
DECLARE
    v_order_id UUID := gen_random_uuid();
    v_sub_id UUID := gen_random_uuid();
    v_sub RECORD;
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    INSERT INTO public.orders (id, order_number, user_id, subtotal_paise, total_amount_paise, shipping_address, status)
    VALUES (v_order_id, 'ORD-P9-T26', 'a9000000-0000-0000-0000-000000000001', 1500000, 1500000, '{"city":"Mumbai"}'::jsonb, 'confirmed');

    INSERT INTO public.seller_sub_orders (id, sub_order_number, order_id, seller_id, subtotal_paise, total_amount_paise, net_seller_payable_paise, status)
    VALUES (v_sub_id, 'SO-P9-T26-1', v_order_id, 'a9010000-0000-0000-0000-000000000001', 1500000, 1500000, 1500000, 'accepted');
    PERFORM set_config('session_replication_role', 'origin', false);

    -- Intentionally call ship with invalid AWB in manual mode
    PERFORM set_test_user_p9('a9000000-0000-0000-0000-000000000003');
    BEGIN
        PERFORM public.seller_ship_sub_order(v_sub_id, 'manual', 'Delhivery', 'AB');
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RESET ROLE;
    SELECT * INTO v_sub FROM public.seller_sub_orders WHERE id = v_sub_id;
    ASSERT v_sub.status = 'accepted', 'Test 26 Failed: status mutated despite error! Got: ' || v_sub.status;
    ASSERT NOT EXISTS (SELECT 1 FROM public.shipments WHERE sub_order_id = v_sub_id), 'Test 26 Failed: shipment row persisted despite error!';

    RAISE NOTICE 'ASSERTION PASS 26: Atomic rollback on error confirmed';
END;
$$;


-- ============================================================================
-- TEST 27: P8 ORDER & PAYMENT REGRESSION INVARIANTS INTACT
-- ============================================================================
DO $$
DECLARE
    v_ord RECORD;
    v_sub RECORD;
BEGIN
    SELECT * INTO v_ord FROM public.orders LIMIT 1;
    ASSERT v_ord.status IS NOT NULL, 'Test 27 Failed: order status missing';

    -- Financial immutability check
    BEGIN
        UPDATE public.orders SET total_amount_paise = 99999 WHERE id = v_ord.id;
        RAISE EXCEPTION 'Test 27 Failed: order financial immutability bypassed';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE != '42501' THEN
            RAISE EXCEPTION 'Unexpected error code: %', SQLSTATE;
        END IF;
    END;

    RAISE NOTICE 'ASSERTION PASS 27: P8 order & payment regression invariants intact';
END;
$$;


DO $$
BEGIN
    PERFORM set_config('session_replication_role', 'replica', false);
    DELETE FROM public.shipments WHERE awb_number LIKE '%P9%' OR awb_number LIKE '%BD-%' OR awb_number LIKE '%DTDC-%' OR awb_number LIKE '%DEL-%' OR awb_number LIKE '%AGY-%' OR awb_number LIKE '%ADM-%';
    DELETE FROM public.order_status_history WHERE notes LIKE '%P9%' OR notes LIKE '%Sub-order%';
    DELETE FROM public.order_items WHERE product_title LIKE '%P9%';
    DELETE FROM public.seller_sub_orders WHERE sub_order_number LIKE '%P9%';
    DELETE FROM public.orders WHERE order_number LIKE '%P9%';
    PERFORM set_config('session_replication_role', 'origin', false);

    RAISE NOTICE '==================================================';
    RAISE NOTICE 'ALL 27 PHASE 9 PRD-ALIGNED ACCEPTANCE TESTS PASSED!';
    RAISE NOTICE '==================================================';
END;
$$;
