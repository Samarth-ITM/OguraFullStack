#!/usr/bin/env python3
"""
P11 Real Backend HTTP Smoke Test Suite
Tests all 17 operations against http://127.0.0.1:54321 backed by PostgreSQL ogura_dev.
"""

import os
import json
import urllib.request
import urllib.error
import sys
import psycopg2
import uuid

BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:54321")
DB_NAME = os.environ.get("PGDATABASE", "ogura_dev")
DB_USER = os.environ.get("PGUSER") or os.environ.get("USER") or "postgres"
DB_HOST = os.environ.get("PGHOST", "localhost")
DB_PORT = int(os.environ.get("PGPORT", 5432))

def request(method, path, headers=None, body=None):
    url = f"{BASE_URL}{path}"
    h = {"Content-Type": "application/json"}
    if headers:
        h.update(headers)
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            status = resp.status
            content = resp.read().decode("utf-8")
            return status, json.loads(content) if content else None
    except urllib.error.HTTPError as e:
        content = e.read().decode("utf-8")
        try:
            parsed = json.loads(content)
        except Exception:
            parsed = content
        return e.code, parsed

def auth_headers(token):
    return {"Authorization": f"Bearer {token}"}

results = []

def test_step(name, passed, details=""):
    results.append((name, passed, details))
    mark = "PASS" if passed else "FAIL"
    print(f"[{mark}] {name} - {details}")

def main():
    print("============================================================")
    print("STARTING P11 REAL BACKEND HTTP SMOKE TESTS (17 CHECKS)")
    print("============================================================")

    created_quote_id = None
    created_order_id = None
    created_sub_order_id = None
    created_return_id = None
    temp_seller_id = None

    try:
        # 1. Auth check (OTP send & verify)
        status1, otp_res = request("POST", "/auth/v1/otp", body={"email": "alice_p10@ogura.test"})
        status2, verify_res = request("POST", "/auth/v1/verify", body={"email": "alice_p10@ogura.test", "token": "123456", "type": "email"})
        customer_token = verify_res.get("access_token") if (status2 == 200 and verify_res) else None
        customer_user_id = verify_res.get("user", {}).get("id") if (status2 == 200 and verify_res) else None
        test_step("1. Auth (OTP Lifecycle)", status2 == 200 and customer_token == "a1000000-0000-0000-0000-000000000001",
                  f"HTTP {status2}, User: {customer_user_id}")

        # 2. Catalog check
        status, cat_res = request("GET", "/rest/v1/public_catalog_products?select=*&limit=5")
        test_step("2. Catalog (Public Products)", status == 200 and len(cat_res) > 0, f"HTTP {status}, Found {len(cat_res)} products")

        # 3. Product Detail (PDP)
        sample_slug = "p10-summer-georgette-gown"
        status, pdp_res = request("POST", "/rest/v1/rpc/get_public_product_by_slug", body={"p_slug": sample_slug})
        has_variants = bool(pdp_res and len(pdp_res.get("variants", [])) > 0)
        sample_variant_id = pdp_res["variants"][0]["id"] if has_variants else "b1000000-0000-0000-0000-000000000033"
        test_step("3. Product Detail (PDP)", status == 200 and has_variants,
                  f"HTTP {status}, Title: '{pdp_res.get('title')}', Variants: {len(pdp_res.get('variants', []))}")

        # 4. Add to Cart (authenticated)
        status, add_res = request("POST", "/rest/v1/rpc/add_to_customer_cart",
                                  headers=auth_headers(customer_token),
                                  body={"p_variant_id": sample_variant_id, "p_quantity": 1})
        test_step("4. Add to Cart", status == 200 and bool(add_res), f"HTTP {status}, Line ID: {add_res}")

        # 5. Get Customer Cart (authenticated - DEFECT #1 AND DEFECT #2 VERIFICATION)
        status, cart_res = request("POST", "/rest/v1/rpc/get_customer_cart", headers=auth_headers(customer_token))
        cart_lines = cart_res.get("lines", []) if (status == 200 and cart_res) else []
        stock_qty = cart_lines[0].get("stock_quantity") if cart_lines else None
        primary_img = cart_lines[0].get("primary_image_url") if cart_lines else None
        test_step("5. Get Customer Cart (Defects #1 & #2 Repaired)",
                  status == 200 and len(cart_lines) > 0 and stock_qty is not None,
                  f"HTTP {status}, Lines: {len(cart_lines)}, Line 0 Stock: {stock_qty}, Image: {primary_img}")

        # 6. Wishlist Toggle (authenticated)
        sample_prod_id = "b1000000-0000-0000-0000-000000000023"
        status, wish_toggle = request("POST", "/rest/v1/rpc/toggle_wishlist_item",
                                      headers=auth_headers(customer_token),
                                      body={"p_product_id": sample_prod_id})
        test_step("6. Toggle Wishlist Item", status == 200, f"HTTP {status}, Result: {wish_toggle}")

        # 7. Get Customer Wishlist (authenticated - DEFECT #1 VERIFICATION)
        status, wish_res = request("POST", "/rest/v1/rpc/get_customer_wishlist", headers=auth_headers(customer_token))
        wish_count = len(wish_res) if isinstance(wish_res, list) else 0
        test_step("7. Get Customer Wishlist (Defect #1 Repaired)", status == 200 and isinstance(wish_res, list),
                  f"HTTP {status}, Total Wishlist Items: {wish_count}")

        # 8. Address Management (authenticated)
        status, addr_list = request("GET", "/rest/v1/customer_addresses?select=*&is_active=eq.true", headers=auth_headers(customer_token))
        addr_id = addr_list[0]["id"] if (status == 200 and addr_list) else None
        test_step("8. Address Management", status == 200 and addr_id is not None,
                  f"HTTP {status}, Found Address ID: {addr_id}, City: {addr_list[0].get('city') if addr_list else None}")

        # 9. Checkout Quote (authenticated)
        status, quote_res = request("POST", "/rest/v1/rpc/create_checkout_quote",
                                    headers=auth_headers(customer_token),
                                    body={"p_address_id": addr_id})
        created_quote_id = quote_res.get("quote_id") if (status == 200 and quote_res) else None
        payable_paise = quote_res.get("total_payable_paise") if quote_res else None
        test_step("9. Checkout Quote", status == 200 and created_quote_id is not None,
                  f"HTTP {status}, Quote ID: {created_quote_id}, Total: {payable_paise} paise")

        # 10. Order Creation (authenticated)
        status, order_create = request("POST", "/rest/v1/rpc/create_order_from_quote",
                                       headers=auth_headers(customer_token),
                                       body={"p_quote_id": created_quote_id})
        created_order_id = order_create.get("order_id") if (status == 200 and order_create) else None
        order_num = order_create.get("order_number") if order_create else None
        test_step("10. Order Creation", status == 200 and created_order_id is not None,
                  f"HTTP {status}, Order ID: {created_order_id}, Order #: {order_num}")

        # 11. Order Retrieval (authenticated customer)
        status, orders_res = request("GET", f"/rest/v1/orders?id=eq.{created_order_id}&select=*", headers=auth_headers(customer_token))
        status2, order_details = request("POST", "/rest/v1/rpc/get_order_details",
                                         headers=auth_headers(customer_token),
                                         body={"p_order_id": created_order_id})
        test_step("11. Order Retrieval", status == 200 and len(orders_res) > 0 and status2 == 200,
                  f"HTTP {status}, Status: {orders_res[0].get('status') if orders_res else None}")

        # 12. Seller Profile (authenticated seller)
        seller_user_id = "a1000000-0000-0000-0000-000000000003"
        seller_token = seller_user_id
        status, seller_prof = request("GET", f"/rest/v1/sellers?user_id=eq.{seller_user_id}&select=*", headers=auth_headers(seller_token))
        seller_id = seller_prof[0]["id"] if (status == 200 and seller_prof) else None
        test_step("12. Seller Profile", status == 200 and seller_id is not None,
                  f"HTTP {status}, Business: '{seller_prof[0].get('business_name') if seller_prof else None}'")

        # 13. Seller Sub-Orders
        status, suborders_res = request("GET", f"/rest/v1/seller_sub_orders?seller_id=eq.{seller_id}&select=*&limit=5", headers=auth_headers(seller_token))
        test_step("13. Seller Sub-Orders", status == 200 and isinstance(suborders_res, list),
                  f"HTTP {status}, Found {len(suborders_res)} sub-orders")

        # 14. Seller Ship (Payment Capture -> Accept -> Ship Sub-Order)
        status_pay, pay_res = request("POST", "/rest/v1/rpc/confirm_order_payment",
                                      headers=auth_headers(customer_token),
                                      body={
                                          "p_order_id": created_order_id,
                                          "p_gateway_payment_id": f"pay_smoke_{created_order_id[:8]}",
                                          "p_gateway_signature": "sig_test_valid_smoke_123",
                                          "p_method": "card"
                                      })
        
        # Identify sub-order and its corresponding seller
        sub_orders = pay_res.get("sub_orders", []) if (status_pay == 200 and isinstance(pay_res, dict)) else []
        if sub_orders:
            so_item = sub_orders[0]
            created_sub_order_id = so_item["sub_order_id"]
            order_seller_id = so_item["seller_id"]
            
            # Lookup seller user ID
            conn_temp = psycopg2.connect(dbname=DB_NAME, user=DB_USER, host=DB_HOST, port=DB_PORT)
            cur_temp = conn_temp.cursor()
            cur_temp.execute("SELECT user_id FROM public.sellers WHERE id = %s;", (order_seller_id,))
            order_seller_user_id = cur_temp.fetchone()[0]
            conn_temp.close()

            # Seller accepts sub-order
            status_acc, _ = request("POST", "/rest/v1/rpc/seller_accept_sub_order",
                                    headers=auth_headers(order_seller_user_id),
                                    body={"p_sub_order_id": created_sub_order_id})
            
            # Seller ships sub-order
            status_ship, ship_res = request("POST", "/rest/v1/rpc/seller_ship_sub_order",
                                            headers=auth_headers(order_seller_user_id),
                                            body={
                                                "p_sub_order_id": created_sub_order_id,
                                                "p_shipping_mode": "manual",
                                                "p_carrier": "Bluedart",
                                                "p_awb_number": f"AWB-SMOKE-{created_sub_order_id[:8]}",
                                                "p_tracking_url": "https://tracking.bluedart.com/awb"
                                            })
            test_step("14. Seller Ship (Dispatch Sub-Order)", status_ship == 200,
                      f"HTTP {status_ship}, Sub-Order {created_sub_order_id[:8]} dispatched (AWB: {ship_res.get('awb_number') if isinstance(ship_res, dict) else None})")
        else:
            test_step("14. Seller Ship (Dispatch Sub-Order)", False, f"Payment capture did not yield sub-orders: {pay_res}")

        # 15. Admin Authorization (Privileged vs Non-Admin RBAC)
        # Create an applicant seller for Gate 1 evaluation
        conn_adm = psycopg2.connect(dbname=DB_NAME, user=DB_USER, host=DB_HOST, port=DB_PORT)
        cur_adm = conn_adm.cursor()
        temp_seller_id = str(uuid.uuid4())
        cur_adm.execute("""
            INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status)
            VALUES (%s, 'a5000000-0000-0000-0000-000000000003', 'Smoke Temp Atelier', 'Smoke Temp LLC', %s, 'application');
        """, (temp_seller_id, f"smoke-temp-{temp_seller_id[:8]}"))
        conn_adm.commit()
        conn_adm.close()

        admin_token = "55555555-5555-5555-5555-555555555555"
        non_admin_token = "11111111-1111-1111-1111-111111111111"
        status_na, res_na = request("POST", "/rest/v1/rpc/approve_seller",
                                    headers=auth_headers(non_admin_token),
                                    body={"p_seller_id": temp_seller_id})
        status_admin, res_admin = request("POST", "/rest/v1/rpc/approve_seller",
                                          headers=auth_headers(admin_token),
                                          body={"p_seller_id": temp_seller_id})
        admin_passed = (status_na in (400, 403) and status_admin == 200 and res_admin is True)
        test_step("15. Admin Authorization Enforcement", admin_passed,
                  f"Non-admin rejected HTTP {status_na} (42501), Admin accepted HTTP {status_admin} (true)")

        # 16. Return Eligibility (derive test item from created_sub_order_id and deliver it)
        test_item_id = None
        conn_ret = psycopg2.connect(dbname=DB_NAME, user=DB_USER, host=DB_HOST, port=DB_PORT)
        cur_ret = conn_ret.cursor()
        if created_sub_order_id:
            cur_ret.execute("SELECT id FROM public.shipments WHERE sub_order_id = %s;", (created_sub_order_id,))
            s_row = cur_ret.fetchone()
            if s_row:
                cur_ret.execute("SELECT public.update_shipment_status(%s, 'in_transit'::shipment_status, 'In transit', 'ogura_carrier_webhook_secret_p9');", (s_row[0],))
                cur_ret.execute("SELECT public.update_shipment_status(%s, 'delivered'::shipment_status, 'Delivered', 'ogura_carrier_webhook_secret_p9');", (s_row[0],))
            cur_ret.execute("SELECT id FROM public.order_items WHERE sub_order_id = %s LIMIT 1;", (created_sub_order_id,))
            oi_row = cur_ret.fetchone()
            if oi_row:
                test_item_id = str(oi_row[0])
        conn_ret.commit()
        conn_ret.close()

        status_elig, elig_res = request("POST", "/rest/v1/rpc/check_return_eligibility",
                                        headers=auth_headers(customer_token),
                                        body={"p_order_item_id": test_item_id, "p_quantity": 1})
        is_eligible = elig_res.get("eligible") is True if (status_elig == 200 and isinstance(elig_res, dict)) else False
        test_step("16. Return Eligibility Check", status_elig == 200 and is_eligible,
                  f"HTTP {status_elig}, Eligible: {is_eligible}, Refund: {elig_res.get('estimated_refund_paise') if isinstance(elig_res, dict) else None} paise")

        # 17. Return Creation (authenticated customer return request)
        status_ret, ret_res = request("POST", "/rest/v1/rpc/customer_create_return_request",
                                      headers=auth_headers(customer_token),
                                      body={
                                          "p_order_item_id": test_item_id,
                                          "p_reason": "fit_too_small",
                                          "p_customer_notes": "P11 smoke verification return",
                                          "p_resolution": "refund",
                                          "p_quantity": 1
                                      })
        created_return_id = ret_res.get("return_request_id") if (status_ret == 200 and isinstance(ret_res, dict)) else None
        test_step("17. Return Creation Flow", status_ret == 200 and created_return_id is not None,
                  f"HTTP {status_ret}, Return Request ID: {created_return_id}")

    finally:
        # Cleanup ephemeral smoke test entities
        print("\nCleaning up ephemeral smoke test entities...")
        conn = psycopg2.connect(dbname=DB_NAME, user=DB_USER, host=DB_HOST, port=DB_PORT)
        cur = conn.cursor()
        if temp_seller_id:
            cur.execute("DELETE FROM public.sellers WHERE id = %s;", (temp_seller_id,))
            conn.commit()
        conn.close()
        try:
            from clean_dev_db import clean_development_database
            clean_development_database()
        except Exception as e:
            print(f"clean_dev_db notice: {e}")
        print("Cleanup completed.")

    print("============================================================")
    all_passed = all(p for _, p, _ in results)
    pass_count = sum(1 for _, p, _ in results if p)
    print(f"P11 HTTP SMOKE TEST SUMMARY: {pass_count} / {len(results)} PASSED")
    print("============================================================")
    if not all_passed:
        sys.exit(1)

if __name__ == "__main__":
    main()
