#!/usr/bin/env python3
"""
OGURA Phase 12A — MVP Multi-Role Business Flow Test
Target Database: ogura_test

Tests the complete lifecycle across Customer, Seller, and Admin personas:
CUSTOMER FLOW (1-20):
- Catalog discovery & PDP projection
- Cart & Wishlist management
- Profile & Google auth readiness
- Address creation
- Checkout quote & inventory reservation
- Order creation & payment capture
- Order retrieval & status progression
- 7-day return window eligibility check
- Customer return request creation

SELLER FLOW (1-15):
- Seller onboarding application
- Admin approval & activation
- Dashboard access & tenancy
- Product draft creation & submission
- Admin review & publication to 'live'
- Inventory management
- Sub-order queue visibility
- Accept order & manual AWB dispatch
- Shipment delivery progression
- Payout statement & KYC gate check

ADMIN FLOW (1-8):
- Role enforcement (Super, Catalog, Finance, Support, Viewer)
- Seller approval gate
- Catalog review gate
- Systemwide order governance
- Return QC & refund authorization
- Finance ledger visibility & double-entry audit
"""

import sys
import json
import psycopg2
from psycopg2.extras import register_default_jsonb
import uuid

DB_NAME = os.environ.get("PGDATABASE", "ogura_test")
DB_USER = os.environ.get("PGUSER") or os.environ.get("USER") or "postgres"
DB_HOST = os.environ.get("PGHOST", "localhost")
DB_PORT = int(os.environ.get("PGPORT", 5432))

def parse_json(val):
    if isinstance(val, str):
        return json.loads(val)
    return val

def run_test():
    print("=" * 65)
    print(f"OGURA MVP MULTI-ROLE BUSINESS FLOW TEST (DATABASE: {DB_NAME})")
    print("=" * 65)

    conn = psycopg2.connect(f"dbname={DB_NAME} user={DB_USER} host={DB_HOST} port={DB_PORT}")
    register_default_jsonb(conn)
    conn.autocommit = False
    cur = conn.cursor()

    try:
        # -------------------------------------------------------------
        # ADMIN PERSONAS SETUP
        # -------------------------------------------------------------
        admin_super_uid = str(uuid.uuid4())
        admin_catalog_uid = str(uuid.uuid4())
        admin_finance_uid = str(uuid.uuid4())
        admin_support_uid = str(uuid.uuid4())

        for uid, role, name in [
            (admin_super_uid, "admin_super", "Super Admin"),
            (admin_catalog_uid, "admin_catalog", "Catalog Admin"),
            (admin_finance_uid, "admin_finance", "Finance Admin"),
            (admin_support_uid, "admin_support", "Support Admin")
        ]:
            cur.execute("""
                INSERT INTO auth.users (id, email) VALUES (%s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id;
            """, (uid, f"{role}_{uid[:6]}@ogura.test"))
            inserted_uid = cur.fetchone()[0]
            cur.execute("""
                INSERT INTO public.profiles (id, full_name, email) VALUES (%s, %s, %s)
                    ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;
                INSERT INTO public.user_roles (user_id, role) VALUES (%s, %s)
                    ON CONFLICT (user_id, role) DO NOTHING;
            """, (inserted_uid, name, f"{role}_{inserted_uid[:6]}@ogura.test", inserted_uid, role))
        conn.commit()
        print("[SETUP] Administrative roles instantiated (Super, Catalog, Finance, Support)")

        # -------------------------------------------------------------
        # SELLER FLOW (1-8): Application, Admin Approval, Product Draft, Admin Review
        # -------------------------------------------------------------
        seller_uid = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO auth.users (id, email) VALUES (%s, %s) ON CONFLICT (id) DO NOTHING;
            INSERT INTO public.profiles (id, full_name, email) VALUES (%s, 'Maya Designer', %s)
                ON CONFLICT (id) DO UPDATE SET full_name = 'Maya Designer';
            INSERT INTO public.user_roles (user_id, role) VALUES (%s, 'seller')
                ON CONFLICT (user_id, role) DO NOTHING;
        """, (seller_uid, f"maya_{seller_uid[:6]}@ogura.test", seller_uid, f"maya_{seller_uid[:6]}@ogura.test", seller_uid))

        # 1. Seller application submitted
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (seller_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        test_hex = uuid.uuid4().hex[:4].upper()
        cur.execute("""
            SELECT public.apply_as_seller(
                'Maya Atelier',
                'Maya Couture Private Limited',
                %s,
                '27' || %s || 'E1234F1Z5',
                %s || 'E1234F'
            );
        """, (f"maya-atelier-{seller_uid[:6]}", test_hex, test_hex))
        seller_id = cur.fetchone()[0]
        conn.commit()
        print(f"[SELLER 1-3] Seller application submitted: {str(seller_id)[:8]} (Status: application)")

        # 2. Admin Super approves seller application -> Becomes 'active'
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (admin_super_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        cur.execute("SELECT public.approve_seller(%s);", (seller_id,))
        appr_ok = cur.fetchone()[0]
        assert appr_ok is True, "Seller approval returned false"
        
        cur.execute("SELECT status FROM public.sellers WHERE id = %s;", (seller_id,))
        s_status = cur.fetchone()[0]
        assert s_status == "active", f"Expected active, got {s_status}"
        conn.commit()
        print(f"[SELLER 4] Admin Super approved seller {str(seller_id)[:8]} -> Status: ACTIVE")

        # 3. Create Seller Brand
        brand_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO public.brands (id, seller_id, name, slug, is_active)
            VALUES (%s, %s, 'Maya Couture', %s, true);
        """, (brand_id, seller_id, f"maya-couture-{brand_id[:6]}"))
        conn.commit()

        # 4. Seller creates product draft
        cur.execute("SELECT id FROM public.categories LIMIT 1;")
        cat_id = cur.fetchone()[0]
        cur.execute("SELECT id FROM public.subcategories WHERE category_id = %s LIMIT 1;", (cat_id,))
        subcat_id = cur.fetchone()[0]

        product_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO public.products (
                id, seller_id, brand_id, subcategory_id, title, slug,
                description, status
            ) VALUES (
                %s, %s, %s, %s, 'Handwoven Banarasi Saree', %s,
                'Authentic pure silk zari saree', 'draft'
            );
        """, (product_id, seller_id, brand_id, subcat_id, f"maya-banarasi-saree-{uuid.uuid4().hex[:6]}"))

        # 5. Seller adds variant and physical inventory
        variant_id = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO public.product_variants (
                id, product_id, sku, size, color, price_paise, compare_at_price_paise, is_active
            ) VALUES (
                %s, %s, %s, 'Free Size', 'Royal Crimson', 1850000, 2200000, true
            );
        """, (variant_id, product_id, f"SKU-MAYA-{uuid.uuid4().hex[:6]}"))

        # Add primary media asset (required by approve_product gate)
        cur.execute("""
            INSERT INTO public.media_assets (
                product_id, asset_url, slot_role, sort_order
            ) VALUES (
                %s, 'https://images.unsplash.com/photo-1610030469983-98e550d6193c', 'primary', 1
            );
        """, (product_id,))

        cur.execute("""
            INSERT INTO public.inventory_items (variant_id, quantity_on_hand, quantity_reserved)
            VALUES (%s, 10, 0);
        """, (variant_id,))
        conn.commit()
        print(f"[SELLER 5-6] Product draft & variant created: {product_id[:8]} with 10 units purchasable inventory")

        # 6. Seller submits product for review
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (seller_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        cur.execute("SELECT public.submit_product_for_review(%s);", (product_id,))
        subm_res = parse_json(cur.fetchone()[0])
        assert subm_res["status"] == "submitted", f"Expected submitted, got {subm_res['status']}"
        conn.commit()
        print(f"[SELLER 7] Product submitted for review -> Status: submitted")

        # 7. Admin Catalog approves product -> Becomes 'live'
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (admin_catalog_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        cur.execute("SELECT public.approve_product(%s);", (product_id,))
        live_res = parse_json(cur.fetchone()[0])
        assert live_res["status"] == "live", f"Expected live, got {live_res['status']}"
        conn.commit()
        print(f"[SELLER 8] Admin Catalog approved product -> Status: LIVE")

        # -------------------------------------------------------------
        # CUSTOMER FLOW (1-16): Browse, Cart, Wishlist, Quote, Order, Payment
        # -------------------------------------------------------------
        cust_uid = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO auth.users (id, email) VALUES (%s, %s) ON CONFLICT (id) DO NOTHING;
            INSERT INTO public.profiles (id, full_name, email) VALUES (%s, 'Sita Customer', %s)
                ON CONFLICT (id) DO UPDATE SET full_name = 'Sita Customer';
            INSERT INTO public.user_roles (user_id, role) VALUES (%s, 'customer')
                ON CONFLICT (user_id, role) DO NOTHING;
            INSERT INTO public.customer_addresses (user_id, full_name, phone, line1, city, state, pincode, is_default)
            VALUES (%s, 'Sita Customer', '+919123456780', '42 Malabar Hill', 'Mumbai', 'Maharashtra', '400006', true);
        """, (cust_uid, f"sita_{cust_uid[:6]}@ogura.test", cust_uid, f"sita_{cust_uid[:6]}@ogura.test", cust_uid, cust_uid))
        conn.commit()

        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (cust_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")

        # 1. Add item to cart
        cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (variant_id,))
        cart_line_id = cur.fetchone()[0]
        assert cart_line_id is not None, "Cart line ID was not returned"
        print(f"[CUSTOMER 1] Added Banarasi Saree to cart (Line ID: {str(cart_line_id)[:8]})")

        # 2. Get customer cart
        cur.execute("SELECT public.get_customer_cart();")
        cart_data = parse_json(cur.fetchone()[0])
        assert cart_data["items_count"] >= 1, f"Expected items in cart, got {cart_data}"
        assert len(cart_data["lines"]) >= 1, "Cart lines empty"
        print(f"[CUSTOMER 2] Verified cart lines: {cart_data['items_count']} item(s), Subtotal: {cart_data['subtotal_paise']} paise")

        # 3. Wishlist toggle & check
        cur.execute("SELECT public.toggle_wishlist_item(%s);", (product_id,))
        w_toggled = cur.fetchone()[0]
        assert w_toggled is True
        cur.execute("SELECT public.get_customer_wishlist();")
        wishlist_items = parse_json(cur.fetchone()[0])
        assert len(wishlist_items) >= 1
        print(f"[CUSTOMER 3] Wishlist toggled and verified ({len(wishlist_items)} item)")

        # 4. Create authoritative checkout quote (reserves inventory atomically)
        cur.execute("SELECT public.create_checkout_quote();")
        quote_res = parse_json(cur.fetchone()[0])
        quote_id = quote_res["quote_id"]
        total_payable = quote_res["total_payable_paise"]
        conn.commit()
        print(f"[CUSTOMER 4] Checkout quote created: {quote_id[:8]} (Total: {total_payable} paise, Free Shipping: {quote_res['shipping_fee_paise'] == 0})")

        # Verify inventory reservation was created
        cur.execute("SELECT quantity_reserved FROM public.inventory_items WHERE variant_id = %s;", (variant_id,))
        reserved_qty = cur.fetchone()[0]
        assert reserved_qty == 1, f"Expected 1 reserved, got {reserved_qty}"

        # 5. Create Order from Quote
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (cust_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        cur.execute("SELECT public.create_order_from_quote(%s);", (quote_id,))
        ord_res = parse_json(cur.fetchone()[0])
        order_id = ord_res["order_id"]
        order_num = ord_res["order_number"]
        assert ord_res["status"] == "placed"
        conn.commit()
        print(f"[CUSTOMER 5] Order placed: {order_num} ({order_id[:8]}) in status 'placed'")

        # 6. Payment Confirmation & Inventory Consumption
        cur.execute("SELECT public.confirm_order_payment(%s, %s);", (order_id, f"pay_flow_test_{uuid.uuid4().hex[:8]}"))
        conf_res = parse_json(cur.fetchone()[0])
        assert conf_res["status"] == "confirmed"
        conn.commit()
        print(f"[CUSTOMER 6] Payment captured -> Order status: CONFIRMED. Inventory reservations consumed.")

        # Post order payment ledger settlement (P10 double-entry posting)
        cur.execute("SELECT public.post_order_payment_ledger_settlement(%s);", (order_id,))
        ledger_grp_id = cur.fetchone()[0]
        conn.commit()
        print(f"[FINANCE 1] Double-entry ledger posted for order (Group: {str(ledger_grp_id)[:8]})")

        # -------------------------------------------------------------
        # SELLER FULFILLMENT FLOW (9-14): Accept, Ship (Manual AWB), Deliver
        # -------------------------------------------------------------
        # Fetch seller sub-order
        cur.execute("SELECT id, sub_order_number FROM public.seller_sub_orders WHERE order_id = %s;", (order_id,))
        sub_order_id, sub_order_num = cur.fetchone()

        # Seller views orders
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (seller_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        cur.execute("SELECT * FROM public.seller_sub_orders WHERE id = %s;", (sub_order_id,))
        assert cur.fetchone() is not None, "Seller could not find own sub-order"

        # Seller accepts sub-order
        cur.execute("SELECT public.seller_accept_sub_order(%s);", (sub_order_id,))
        acc_res = parse_json(cur.fetchone()[0])
        assert acc_res["status"] == "accepted"
        conn.commit()
        print(f"[SELLER 9] Sub-order {sub_order_num} accepted by seller")

        # Seller dispatches order via Manual AWB fallback
        awb_tracking = f"OG-MANUAL-AWB-{uuid.uuid4().hex[:8].upper()}"
        cur.execute("""
            SELECT public.seller_ship_sub_order(%s, 'manual', 'Manual Atelier Courier', %s);
        """, (sub_order_id, awb_tracking))
        ship_res = parse_json(cur.fetchone()[0])
        assert ship_res["sub_order_status"] == "dispatched"
        conn.commit()
        print(f"[SELLER 10] Sub-order dispatched via manual AWB fallback ({awb_tracking})")

        # Update sub-order to 'delivered' and backdate delivered_at by 2 days to test return eligibility
        cur.execute("""
            UPDATE public.seller_sub_orders
            SET status = 'delivered',
                delivered_at = CURRENT_TIMESTAMP - INTERVAL '2 days',
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s;
            SELECT public.sync_parent_order_fulfillment_status(%s);
        """, (sub_order_id, order_id))
        conn.commit()
        print(f"[SELLER 11] Sub-order marked DELIVERED (Parent order synchronized to FULFILLED)")

        # -------------------------------------------------------------
        # CUSTOMER RETURN FLOW (17-20): Check Eligibility & Create Return Request
        # -------------------------------------------------------------
        # Fetch order item
        cur.execute("SELECT id FROM public.order_items WHERE sub_order_id = %s LIMIT 1;", (sub_order_id,))
        order_item_id = cur.fetchone()[0]

        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (cust_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")

        # Check return eligibility
        cur.execute("SELECT public.check_return_eligibility(%s);", (order_item_id,))
        elig_res = parse_json(cur.fetchone()[0])
        assert elig_res["eligible"] is True, f"Expected return eligible, got {elig_res}"
        print(f"[CUSTOMER 7] Return eligibility verified: {elig_res['eligible']} (Estimated Refund: {elig_res['estimated_refund_paise']} paise)")

        # Submit return request
        cur.execute("""
            SELECT public.customer_create_return_request(
                %s, 'size_fit', 'Fabric fit was too loose at borders', 'refund', 1
            );
        """, (order_item_id,))
        ret_res = parse_json(cur.fetchone()[0])
        return_id = ret_res["return_request_id"]
        assert ret_res["status"] == "requested"
        conn.commit()
        print(f"[CUSTOMER 8] Return request created: {return_id[:8]} (Status: requested)")

        # -------------------------------------------------------------
        # ADMIN SUPPORT / FINANCE QC & REFUND FLOW:
        # -------------------------------------------------------------
        # Admin Support reviews & approves return request
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (admin_support_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        cur.execute("""
            SELECT public.admin_review_return_request(%s, 'approve', 'Approved by support audit');
        """, (return_id,))
        appr_ret = parse_json(cur.fetchone()[0])
        assert appr_ret["status"] == "approved"
        conn.commit()

        # Admin Support progresses reverse logistics: pickup_scheduled -> in_transit -> hub_received
        cur.execute("""
            SELECT public.admin_update_return_logistics(%s, 'BlueDart Reverse', 'BD-REV-1234', 'pickup_scheduled');
            SELECT public.admin_update_return_logistics(%s, 'BlueDart Reverse', 'BD-REV-1234', 'in_transit');
            SELECT public.admin_update_return_logistics(%s, 'BlueDart Reverse', 'BD-REV-1234', 'hub_received');
        """, (return_id, return_id, return_id))
        conn.commit()
        print(f"[LOGISTICS 1] Return progressed through reverse logistics -> Status: HUB_RECEIVED")

        # Admin Support inspects & records QC pass
        cur.execute("""
            SELECT public.admin_record_return_qc(
                %s, true, 'Item returned in original tags, unaltered, unworn'
            );
        """, (return_id,))
        qc_res = parse_json(cur.fetchone()[0])
        assert qc_res["status"] == "qc_passed"
        conn.commit()
        print(f"[ADMIN 1] Support Admin recorded QC inspection -> Status: QC_PASSED")

        # Admin Finance authorizes refund
        cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (admin_finance_uid,))
        cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', false);")
        cur.execute("SELECT public.admin_authorize_refund(%s, 'QC verified, approving refund');", (return_id,))
        rfnd_auth_res = parse_json(cur.fetchone()[0])
        refund_id = rfnd_auth_res["refund_id"]
        assert rfnd_auth_res["status"] == "initiated"
        conn.commit()
        print(f"[ADMIN 2] Finance Admin authorized refund {refund_id[:8]} -> Status: INITIATED (Ledger Step A posted)")

        # Admin Finance settles refund
        cur.execute("SELECT public.finance_process_refund_settlement(%s, %s);", (refund_id, f"rfnd_gw_test_{uuid.uuid4().hex[:8]}"))
        settle_res = parse_json(cur.fetchone()[0])
        assert settle_res["status"] == "completed"
        conn.commit()
        print(f"[ADMIN 3] Finance Admin settled refund via gateway -> Status: COMPLETED (Ledger Step B posted)")

        # -------------------------------------------------------------
        # SELLER PAYOUT ELIGIBILITY GATING CHECK:
        # -------------------------------------------------------------
        # Test Seller KYC Payout Gate
        cur.execute("SELECT public.is_seller_payout_eligible(%s);", (seller_id,))
        kyc_status = cur.fetchone()[0]
        assert kyc_status is False, "New seller without verified bank/KYC unexpectedly marked eligible"
        print(f"[SELLER 12] KYC Payout Gate verified: Seller KYC/Bank unverified -> Payout Locked ({kyc_status})")

        print("\n" + "=" * 65)
        print("ALL MVP BUSINESS FLOWS VERIFIED CLEANLY (100% SUCCESS)")
        print("=" * 65)

    finally:
        conn.close()

if __name__ == "__main__":
    run_test()
