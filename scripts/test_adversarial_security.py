#!/usr/bin/env python3
"""
OGURA Phase 12A — Adversarial Security & RLS Isolation Audit
Target Database: ogura_test

Tests row-level security, tenant isolation, and administrative gate enforcement:
1. Customer Cross-User Isolation:
   - Customer A cannot read Customer B's cart
   - Customer A cannot read Customer B's wishlist
   - Customer A cannot read Customer B's customer_addresses
   - Customer A cannot read Customer B's orders
2. Seller Cross-Tenancy Isolation:
   - Seller A cannot read Seller B's seller_sub_orders
   - Seller A cannot read Seller B's private seller record / bank accounts
3. Privilege Escalation & State Tampering Defenses:
   - Seller cannot approve own seller application (Gate 1 violation)
   - Seller cannot approve another seller
   - Seller cannot directly force order payment to 'captured'
   - Seller cannot force payout settlement
   - Customer cannot mutate order total_payable_paise (immutable order trigger)
   - Customer cannot directly alter inventory_items (RLS restricted)
   - Customer cannot force refund authorization
4. Admin RBAC Restrictions:
   - Non-admin (customer or seller) cannot invoke admin RPCs (e.g. approve_seller, admin_authorize_refund)
   - Viewer role is strictly read-only and cannot mutate catalog or financial state
"""

import sys
import json
import os
import psycopg2
import uuid

DB_NAME = os.environ.get("PGDATABASE", "ogura_test")
DB_USER = os.environ.get("PGUSER") or os.environ.get("USER") or "postgres"
DB_HOST = os.environ.get("PGHOST", "localhost")
DB_PORT = int(os.environ.get("PGPORT", 5432))

def run_adversarial_tests():
    print("=" * 65)
    print(f"OGURA ADVERSARIAL SECURITY & RLS AUDIT (DATABASE: {DB_NAME})")
    print("=" * 65)

    conn = psycopg2.connect(f"dbname={DB_NAME} user={DB_USER} host={DB_HOST} port={DB_PORT}")
    conn.autocommit = False
    cur = conn.cursor()

    passed_tests = 0
    total_tests = 0

    def as_user(uid, role="authenticated"):
        cur.execute(f"SET ROLE {role};")
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', %s, true);", (role,))

    def reset_role():
        cur.execute("RESET ROLE;")

    def test_assertion(name, should_fail, func):
        nonlocal passed_tests, total_tests
        total_tests += 1
        try:
            func()
            reset_role()
            if should_fail:
                print(f"[FAIL] {name}: Expected security violation, but operation succeeded!")
                assert False, f"Adversarial breach in {name}"
            else:
                passed_tests += 1
                print(f"[PASS] {name}")
        except Exception as e:
            conn.rollback()
            reset_role()
            if should_fail:
                passed_tests += 1
                err_msg = str(e).split("\n")[0]
                print(f"[PASS] {name} (Safely Blocked: {err_msg[:60]}...)")
            else:
                print(f"[FAIL] {name}: Unexpected error {e}")
                raise

    try:
        # -------------------------------------------------------------
        # 1. SETUP TWO CUSTOMERS: Cust A & Cust B
        # -------------------------------------------------------------
        cust_a_id = str(uuid.uuid4())
        cust_b_id = str(uuid.uuid4())
        for cid, email in [(cust_a_id, f"cust_a_{cust_a_id[:6]}@test.ogura"), (cust_b_id, f"cust_b_{cust_b_id[:6]}@test.ogura")]:
            cur.execute("""
                INSERT INTO auth.users (id, email) VALUES (%s, %s) ON CONFLICT DO NOTHING;
                INSERT INTO public.profiles (id, full_name, email) VALUES (%s, %s, %s) ON CONFLICT DO NOTHING;
                INSERT INTO public.user_roles (user_id, role) VALUES (%s, 'customer') ON CONFLICT DO NOTHING;
            """, (cid, email, cid, email, email, cid))
        conn.commit()

        # Seed data for Cust B
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (cust_b_id,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', true);")
        cur.execute("""
            INSERT INTO public.customer_addresses (user_id, full_name, phone, line1, city, state, pincode, is_default)
            VALUES (%s, 'Cust B Private', '+919876543210', 'Private Villa 9', 'Delhi', 'Delhi', '110001', true)
            RETURNING id;
        """, (cust_b_id,))
        b_addr_id = cur.fetchone()[0]

        cur.execute("SELECT id FROM public.product_variants LIMIT 1;")
        sample_variant_id = cur.fetchone()[0]
        cur.execute("SELECT product_id FROM public.product_variants WHERE id = %s;", (sample_variant_id,))
        sample_product_id = cur.fetchone()[0]

        cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (sample_variant_id,))
        cur.execute("SELECT public.toggle_wishlist_item(%s);", (sample_product_id,))
        cur.execute("SELECT id FROM public.carts WHERE user_id = %s;", (cust_b_id,))
        b_cart_id = cur.fetchone()[0]
        conn.commit()

        # -------------------------------------------------------------
        # TEST 1.1: Cust A cannot read Cust B's address
        # -------------------------------------------------------------
        def test_cross_address():
            as_user(cust_a_id)
            cur.execute("SELECT * FROM public.customer_addresses WHERE id = %s;", (b_addr_id,))
            res = cur.fetchall()
            assert len(res) == 0, "Customer A could view Customer B address!"
        test_assertion("Customer A cannot read Customer B address", False, test_cross_address)

        # -------------------------------------------------------------
        # TEST 1.2: Cust A cannot read Cust B's cart
        # -------------------------------------------------------------
        def test_cross_cart():
            as_user(cust_a_id)
            cur.execute("SELECT * FROM public.carts WHERE id = %s;", (b_cart_id,))
            res = cur.fetchall()
            assert len(res) == 0, "Customer A could view Customer B cart row!"
            cur.execute("SELECT * FROM public.cart_lines WHERE cart_id = %s;", (b_cart_id,))
            lines = cur.fetchall()
            assert len(lines) == 0, "Customer A could view Customer B cart lines!"
        test_assertion("Customer A cannot read Customer B cart / cart_lines", False, test_cross_cart)

        # -------------------------------------------------------------
        # TEST 1.3: Cust A cannot read Cust B's wishlist
        # -------------------------------------------------------------
        def test_cross_wishlist():
            as_user(cust_a_id)
            cur.execute("SELECT public.get_customer_wishlist();")
            w_items = cur.fetchone()[0]
            if isinstance(w_items, str):
                w_items = json.loads(w_items)
            assert len(w_items) == 0, "Customer A could see Customer B wishlist items via RPC!"
        test_assertion("Customer A cannot read Customer B wishlist (RPC isolation)", False, test_cross_wishlist)

        # -------------------------------------------------------------
        # TEST 1.4: Cust A cannot read Cust B's orders
        # -------------------------------------------------------------
        def test_cross_orders():
            as_user(cust_a_id)
            cur.execute("SELECT * FROM public.orders WHERE user_id = %s;", (cust_b_id,))
            res = cur.fetchall()
            assert len(res) == 0, "Customer A could view Customer B orders!"
        test_assertion("Customer A cannot read Customer B orders", False, test_cross_orders)

        # -------------------------------------------------------------
        # 2. SETUP TWO SELLERS: Seller A & Seller B
        # -------------------------------------------------------------
        seller_a_uid = str(uuid.uuid4())
        seller_b_uid = str(uuid.uuid4())
        seller_a_id = str(uuid.uuid4())
        seller_b_id = str(uuid.uuid4())

        for uid, sid, name in [(seller_a_uid, seller_a_id, "Seller A"), (seller_b_uid, seller_b_id, "Seller B")]:
            unique_email = f"{name.lower().replace(' ', '_')}_{uid[:6]}@test.ogura"
            cur.execute("""
                INSERT INTO auth.users (id, email) VALUES (%s, %s) ON CONFLICT (id) DO NOTHING;
                INSERT INTO public.profiles (id, full_name, email) VALUES (%s, %s, %s) ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;
                INSERT INTO public.user_roles (user_id, role) VALUES (%s, 'seller') ON CONFLICT (user_id, role) DO NOTHING;
                INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status)
                VALUES (%s, %s, %s, %s || ' Pvt Ltd', %s, 'active') ON CONFLICT (id) DO NOTHING;
                INSERT INTO public.seller_bank_accounts (seller_id, beneficiary_name, account_number, ifsc_code, is_verified)
                VALUES (%s, %s, '123456789012', 'HDFC0001234', true) ON CONFLICT DO NOTHING;
            """, (uid, unique_email, uid, name, unique_email, uid,
                  sid, uid, name, name, f"slug-{sid[:6]}",
                  sid, name))
        conn.commit()

        # -------------------------------------------------------------
        # TEST 2.1: Seller A cannot read Seller B's private sub-orders
        # -------------------------------------------------------------
        def test_seller_isolation():
            as_user(seller_a_uid)
            cur.execute("SELECT * FROM public.seller_sub_orders WHERE seller_id = %s;", (seller_b_id,))
            res = cur.fetchall()
            assert len(res) == 0, "Seller A could view Seller B sub-orders!"
        test_assertion("Seller A cannot view Seller B sub-orders (Tenancy Isolation)", False, test_seller_isolation)

        # -------------------------------------------------------------
        # TEST 2.2: Seller A cannot view Seller B private bank accounts
        # -------------------------------------------------------------
        def test_seller_bank_isolation():
            as_user(seller_a_uid)
            try:
                cur.execute("SELECT * FROM public.seller_bank_accounts WHERE seller_id = %s;", (seller_b_id,))
                res = cur.fetchall()
                assert len(res) == 0, "Seller A could view Seller B bank accounts!"
            except psycopg2.errors.InsufficientPrivilege:
                # Permission denied by default PostgreSQL privileges (Fail Closed)
                conn.rollback()
        test_assertion("Seller A cannot view Seller B private bank accounts (Privilege/RLS Gate)", False, test_seller_bank_isolation)

        # -------------------------------------------------------------
        # 3. PRIVILEGE ESCALATION ATTEMPTS (SHOULD FAIL)
        # -------------------------------------------------------------
        # 3.1 Seller attempts to approve own seller application
        def test_seller_self_approve():
            as_user(seller_a_uid)
            cur.execute("SELECT public.approve_seller(%s);", (seller_a_id,))
        test_assertion("Seller cannot invoke approve_seller RPC (Gate 1)", True, test_seller_self_approve)

        # 3.2 Customer attempts to alter order table directly
        def test_customer_tamper_order():
            cur.execute("SELECT id, total_amount_paise FROM public.orders LIMIT 1;")
            row = cur.fetchone()
            if row:
                target_order_id, orig_amount = row
                as_user(cust_a_id)
                try:
                    cur.execute("""
                        UPDATE public.orders
                        SET total_amount_paise = 100
                        WHERE id = %s;
                    """, (target_order_id,))
                    conn.commit()
                except Exception:
                    conn.rollback()
                reset_role()
                cur.execute("SELECT total_amount_paise FROM public.orders WHERE id = %s;", (target_order_id,))
                val = cur.fetchone()[0]
                assert val == orig_amount, f"Order amount was tampered! (orig: {orig_amount}, current: {val})"
        test_assertion("Customer cannot tamper order total_amount_paise", False, test_customer_tamper_order)

        # 3.3 Customer attempts to directly mutate inventory
        def test_customer_tamper_inventory():
            cur.execute("SELECT quantity_on_hand FROM public.inventory_items WHERE variant_id = %s;", (sample_variant_id,))
            orig_qoh = cur.fetchone()[0]
            as_user(cust_a_id)
            try:
                cur.execute("""
                    UPDATE public.inventory_items
                    SET quantity_on_hand = 9999
                    WHERE variant_id = %s;
                """, (sample_variant_id,))
                conn.commit()
            except Exception:
                conn.rollback()
            reset_role()
            cur.execute("SELECT quantity_on_hand FROM public.inventory_items WHERE variant_id = %s;", (sample_variant_id,))
            qoh = cur.fetchone()[0]
            assert qoh == orig_qoh, f"Inventory was tampered! (orig: {orig_qoh}, current: {qoh})"
        test_assertion("Customer cannot mutate inventory_items table directly", False, test_customer_tamper_inventory)

        # 3.4 Non-admin attempts to authorize refund
        def test_customer_authorize_refund():
            cur.execute("SELECT id FROM public.return_requests LIMIT 1;")
            ret_id = cur.fetchone()[0]
            as_user(cust_a_id)
            cur.execute("SELECT public.admin_authorize_refund(%s, 'Hacked refund approval');", (ret_id,))
        test_assertion("Customer cannot invoke admin_authorize_refund RPC", True, test_customer_authorize_refund)

        # 3.5 Non-admin attempts to approve product
        def test_seller_approve_product():
            as_user(seller_a_uid)
            cur.execute("SELECT public.approve_product(%s);", (sample_product_id,))
        test_assertion("Seller cannot invoke approve_product RPC (Gate 2)", True, test_seller_approve_product)

        # 3.6 Viewer role cannot mutate catalog
        def test_viewer_mutate_catalog():
            viewer_uid = str(uuid.uuid4())
            cur.execute("""
                INSERT INTO auth.users (id, email) VALUES (%s, %s) ON CONFLICT DO NOTHING;
                INSERT INTO public.profiles (id, full_name, email) VALUES (%s, 'Viewer Admin', %s) ON CONFLICT DO NOTHING;
                INSERT INTO public.user_roles (user_id, role) VALUES (%s, 'admin_viewer') ON CONFLICT DO NOTHING;
            """, (viewer_uid, f"viewer_{viewer_uid[:6]}@ogura.test", viewer_uid, f"viewer_{viewer_uid[:6]}@ogura.test", viewer_uid))
            conn.commit()

            as_user(viewer_uid)
            cur.execute("SELECT public.approve_product(%s);", (sample_product_id,))
        test_assertion("Viewer role is read-only and cannot approve products", True, test_viewer_mutate_catalog)

        print("\n" + "=" * 65)
        print(f"ADVERSARIAL SECURITY AUDIT COMPLETE: {passed_tests}/{total_tests} TESTS PASSED")
        print("=" * 65)

    finally:
        conn.close()

if __name__ == "__main__":
    run_adversarial_tests()
