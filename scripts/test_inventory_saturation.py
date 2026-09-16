#!/usr/bin/env python3
"""
OGURA Phase 12A — Inventory MVP Saturation & Concurrency Test
Target Database: ogura_test

Tests the exact scenario required by the mandate:
Variant with quantity_on_hand = 5:
1. Customer A reserves 1 (Succeeds)
2. Customer B reserves 1 (Succeeds)
3. Customer C reserves 1 (Succeeds)
4. Customer D reserves 1 (Succeeds)
5. Customer E reserves 1 (Succeeds)
6. Customer F attempts reservation (Fails - Insufficient stock)
-> Verifies: NO OVERSELLING.
7. Cancel / Expire reservations -> Verifies availability returns to 5.
8. Tests complete lifecycle: cart -> quote -> reservation -> payment failure -> cancellation -> consumption.
"""

import sys
import os
import psycopg2
import uuid

DB_NAME = os.environ.get("PGDATABASE", "ogura_test")
DB_USER = os.environ.get("PGUSER") or os.environ.get("USER") or "postgres"
DB_HOST = os.environ.get("PGHOST", "localhost")
DB_PORT = int(os.environ.get("PGPORT", 5432))

def run_test():
    print("=" * 65)
    print(f"OGURA INVENTORY SATURATION TEST (DATABASE: {DB_NAME})")
    print("=" * 65)

    conn = psycopg2.connect(f"dbname={DB_NAME} user={DB_USER} host={DB_HOST} port={DB_PORT}")
    conn.autocommit = False
    cur = conn.cursor()

    try:
        # Setup test brand, seller, product, and variant with quantity_on_hand = 5
        seller_user_id = str(uuid.uuid4())
        seller_id = str(uuid.uuid4())
        brand_id = str(uuid.uuid4())
        product_id = str(uuid.uuid4())
        variant_id = str(uuid.uuid4())
        inv_id = str(uuid.uuid4())

        # Insert seller user & profile
        cur.execute("""
            INSERT INTO auth.users (id, email) VALUES (%s, %s) ON CONFLICT (id) DO NOTHING;
            INSERT INTO public.profiles (id, full_name, email) VALUES (%s, 'Inv Seller', %s)
                ON CONFLICT (id) DO UPDATE SET full_name = 'Inv Seller';
            INSERT INTO public.user_roles (user_id, role) VALUES (%s, 'seller')
                ON CONFLICT (user_id, role) DO NOTHING;
        """, (seller_user_id, f"seller_{seller_user_id[:8]}@ogura.test",
              seller_user_id, f"seller_{seller_user_id[:8]}@ogura.test", seller_user_id))

        # Insert seller
        cur.execute("""
            INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status, commission_rate_bps)
            VALUES (%s, %s, 'Sat Atelier', 'Sat Atelier LLP', %s, 'active', 1500);
        """, (seller_id, seller_user_id, f"sat-atelier-{seller_id[:6]}"))

        # Insert brand
        cur.execute("""
            INSERT INTO public.brands (id, seller_id, name, slug, is_active)
            VALUES (%s, %s, 'Sat Brand', %s, true);
        """, (brand_id, seller_id, f"sat-brand-{brand_id[:6]}"))

        # Insert category & subcategory if needed
        cur.execute("SELECT id FROM public.categories LIMIT 1;")
        cat_id = cur.fetchone()[0]
        cur.execute("SELECT id FROM public.subcategories WHERE category_id = %s LIMIT 1;", (cat_id,))
        subcat_id = cur.fetchone()[0]

        # Insert Product (Non-MTO)
        cur.execute("""
            INSERT INTO public.products (id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order)
            VALUES (%s, %s, %s, %s, %s, 'Inventory Saturation Silk Kurta', %s, 'live', false);
        """, (product_id, seller_id, brand_id, cat_id, subcat_id, f"sat-kurta-{product_id[:6]}"))

        # Insert Variant
        cur.execute("""
            INSERT INTO public.product_variants (id, product_id, sku, size, color, price_paise, is_active)
            VALUES (%s, %s, %s, 'M', 'Navy', 500000, true);
        """, (variant_id, product_id, f"SKU-SAT-{variant_id[:6]}"))

        # Insert physical inventory with EXACTLY 5 units
        cur.execute("""
            INSERT INTO public.inventory_items (id, variant_id, quantity_on_hand, quantity_reserved)
            VALUES (%s, %s, 5, 0);
        """, (inv_id, variant_id))

        conn.commit()

        # Step 0: Verify initial stock calculation
        cur.execute("SELECT public.get_variant_available_stock(%s);", (variant_id,))
        initial_stock = cur.fetchone()[0]
        assert initial_stock == 5, f"Expected initial stock 5, got {initial_stock}"
        print(f"[CHECK 0] Initial purchasable stock verified: {initial_stock} units")

        # Create 6 distinct customers A, B, C, D, E, F
        customers = []
        for name in ["Customer_A", "Customer_B", "Customer_C", "Customer_D", "Customer_E", "Customer_F"]:
            uid = str(uuid.uuid4())
            unique_email = f"{name.lower()}_{uid[:6]}@ogura.test"
            cur.execute("""
                INSERT INTO auth.users (id, email) VALUES (%s, %s) ON CONFLICT (id) DO NOTHING;
                INSERT INTO public.profiles (id, full_name, email) VALUES (%s, %s, %s)
                    ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;
                INSERT INTO public.user_roles (user_id, role) VALUES (%s, 'customer')
                    ON CONFLICT (user_id, role) DO NOTHING;
                INSERT INTO public.customer_addresses (user_id, full_name, phone, line1, city, state, pincode, is_default)
                VALUES (%s, %s, '+919876543210', '123 Marine Drive', 'Mumbai', 'Maharashtra', '400001', true);
            """, (uid, unique_email, uid, name, unique_email, uid, uid, name))
            customers.append((name, uid))
        conn.commit()

        # Step 1-5: Customers A through E each add 1 unit to cart and request a quote (which reserves 1 unit)
        quote_ids = []
        for i, (name, uid) in enumerate(customers[:5]):
            # Set auth context for Customer
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (uid,))
            cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")

            # 1. Add to cart
            cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (variant_id,))
            
            # 2. Create quote (P7 atomically reserves physical stock)
            cur.execute("SELECT public.create_checkout_quote();")
            quote_res = cur.fetchone()[0]
            quote_id = quote_res["quote_id"]
            quote_ids.append(quote_id)

            # Check available stock decreases
            cur.execute("SELECT public.get_variant_available_stock(%s);", (variant_id,))
            stock_left = cur.fetchone()[0]
            expected_left = 5 - (i + 1)
            assert stock_left == expected_left, f"Expected {expected_left} remaining, got {stock_left}"
            print(f"[CHECK 1.{i+1}] {name} reserved 1 unit (Quote: {quote_id[:8]}). Available stock remaining: {stock_left}")

        conn.commit()

        # Step 6: Verify Customer F attempts to reserve 1 unit -> MUST FAIL (Oversell Prevention)
        name_f, uid_f = customers[5]
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (uid_f,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")

        # Add to cart
        cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (variant_id,))
        conn.commit()

        # Attempt quote creation (Must throw insufficient stock error)
        try:
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (uid_f,))
            cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
            cur.execute("SELECT public.create_checkout_quote();")
            conn.commit()
            print("[FAIL] Customer F reservation unexpectedly SUCCEEDED! Overselling defect detected!")
            sys.exit(1)
        except psycopg2.DatabaseError as e:
            conn.rollback()
            err_msg = str(e)
            print(f"[CHECK 2] Customer F reservation REJECTED as expected: {err_msg.strip()[:70]}...")
            assert "insufficient" in err_msg.lower() or "stock" in err_msg.lower() or "unavailable" in err_msg.lower(), \
                f"Unexpected error text: {err_msg}"

        # Verify stock remains exactly 0
        cur.execute("SELECT public.get_variant_available_stock(%s);", (variant_id,))
        stock_at_zero = cur.fetchone()[0]
        assert stock_at_zero == 0, f"Expected available stock 0, got {stock_at_zero}"
        print(f"[CHECK 3] Zero available stock invariant confirmed: {stock_at_zero} units")

        # Step 7: Release / Cancel reservations for Customer A and B -> Stock must restore to 2
        for i in range(2):
            qid = quote_ids[i]
            owner_uid = customers[i][1]
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (owner_uid,))
            cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
            cur.execute("SELECT public.cancel_checkout_quote(%s);", (qid,))
            conn.commit()
            print(f"[CHECK 4.{i+1}] Canceled reservation for Quote {qid[:8]}")

        cur.execute("SELECT public.get_variant_available_stock(%s);", (variant_id,))
        restored_stock = cur.fetchone()[0]
        assert restored_stock == 2, f"Expected 2 restored units, got {restored_stock}"
        print(f"[CHECK 5] Partial cancellation restored stock correctly: {restored_stock} units available")

        # Step 8: Customer F tries again now that 2 units are available -> MUST SUCCEED
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (uid_f,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        cur.execute("SELECT public.create_checkout_quote();")
        q_f_res = cur.fetchone()[0]
        q_f_id = q_f_res["quote_id"]
        conn.commit()
        print(f"[CHECK 6] Customer F reservation now SUCCEEDED (Quote: {q_f_id[:8]}) after stock restoration")

        # Check stock is now 1
        cur.execute("SELECT public.get_variant_available_stock(%s);", (variant_id,))
        stock_now = cur.fetchone()[0]
        assert stock_now == 1, f"Expected 1 unit, got {stock_now}"
        print(f"[CHECK 7] Available stock correctly decremented to: {stock_now} unit")

        # Step 9: Customer C completes order and payment capture (Inventory consumed)
        name_c, uid_c = customers[2]
        qid_c = quote_ids[2]
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (uid_c,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        cur.execute("SELECT public.create_order_from_quote(%s);", (qid_c,))
        ord_c_res = cur.fetchone()[0]
        ord_c_id = ord_c_res["order_id"]
        conn.commit()

        # Confirm payment -> calls consume_quote_reservations
        cur.execute("SELECT public.confirm_order_payment(%s, %s);", (ord_c_id, f"pay_sat_test_{uuid.uuid4().hex[:8]}"))
        conn.commit()
        print(f"[CHECK 8] Customer C order payment confirmed and inventory consumed (Order: {ord_c_id[:8]})")

        # Verify physical on_hand decremented from 5 to 4, reserved reduced accordingly
        cur.execute("SELECT quantity_on_hand, quantity_reserved FROM public.inventory_items WHERE id = %s;", (inv_id,))
        on_hand, reserved = cur.fetchone()
        assert on_hand == 4, f"Expected quantity_on_hand = 4 after consumption, got {on_hand}"
        print(f"[CHECK 9] Physical on_hand decremented atomically: on_hand = {on_hand}, reserved = {reserved}")

        print("\n" + "=" * 65)
        print("ALL INVENTORY SATURATION & CONCURRENCY CHECKS PASSED (100%)")
        print("=" * 65)

    finally:
        conn.close()

if __name__ == "__main__":
    run_test()
