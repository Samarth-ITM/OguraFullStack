#!/usr/bin/env python3
"""
OGURA — Rigorous Red-Team & System Test Suite
Targets: ogura_test (and ogura_clean_test)
Strictly adheres to isolated test infrastructure. Never touches ogura_dev.
"""

import sys
import os
import json
import time
import uuid
import threading
from decimal import Decimal
import psycopg2
import psycopg2.extras

DB_NAME = os.environ.get("PGDATABASE", "ogura_test")
DB_USER = os.environ.get("PGUSER") or os.environ.get("USER") or "postgres"
DB_HOST = os.environ.get("PGHOST", "localhost")
DB_PORT = int(os.environ.get("PGPORT", 5432))

# Colors for terminal output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
RESET = "\033[0m"

class RedTeamAudit:
    def __init__(self, db_name=DB_NAME):
        self.db_name = db_name
        self.conn = psycopg2.connect(f"dbname={self.db_name} user={DB_USER} host={DB_HOST} port={DB_PORT}")
        self.conn.autocommit = False
        self.cur = self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        self.results = []
        self.findings = []
        self.stop_triggered = False

    def log_result(self, suite, test_name, status, details="", severity="INFO"):
        entry = {
            "suite": suite,
            "name": test_name,
            "status": status,
            "details": details,
            "severity": severity,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        self.results.append(entry)
        col = GREEN if status == "PASS" else RED if status == "FAIL" else YELLOW
        print(f"[{col}{status}{RESET}] [{suite}] {test_name}: {details}")

        if status == "FAIL":
            self.findings.append(entry)
            if severity in ["CRITICAL", "HIGH"]:
                print(f"{RED}*** CRITICAL/HIGH DEFECT DISCOVERED: {test_name} ({severity}) ***{RESET}")
                # We record and report, stopping execution on this branch

    def as_user(self, uid, role="authenticated"):
        self.cur.execute(f"SET ROLE {role};")
        self.cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (str(uid),))
        self.cur.execute("SELECT set_config('request.jwt.claim.role', %s, false);", (role,))

    def reset_role(self):
        self.cur.execute("RESET ROLE;")
        self.cur.execute("SELECT set_config('request.jwt.claim.sub', '', false);")
        self.cur.execute("SELECT set_config('request.jwt.claim.role', '', false);")

    def setup_fixtures(self):
        print(f"\n{CYAN}--- SETTING UP ISOLATED TEST FIXTURES ON {self.db_name} ---{RESET}")
        self.reset_role()

        # Create test roles if not exists
        for r in ['authenticated', 'anon']:
            try:
                self.cur.execute(f"CREATE ROLE {r} NOLOGIN;")
            except Exception:
                self.conn.rollback()

        self.cur.execute("GRANT USAGE ON SCHEMA public, auth TO authenticated, anon;")
        self.cur.execute("GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, anon;")
        self.cur.execute("GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;")
        self.cur.execute("GRANT ALL ON ALL ROUTINES IN SCHEMA public TO authenticated, anon;")
        self.conn.commit()

        # Test User IDs
        self.cust_a = "11111111-1111-1111-1111-111111111111"
        self.cust_b = "22222222-2222-2222-2222-222222222222"
        self.seller_a_user = "33333333-3333-3333-3333-333333333331"
        self.seller_b_user = "33333333-3333-3333-3333-333333333332"
        self.seller_c_user = "33333333-3333-3333-3333-333333333333"

        self.admin_super = "99999999-9999-9999-9999-999999999990"
        self.admin_cat = "99999999-9999-9999-9999-999999999991"
        self.admin_fin = "99999999-9999-9999-9999-999999999992"
        self.admin_sup = "99999999-9999-9999-9999-999999999993"
        self.admin_view = "99999999-9999-9999-9999-999999999994"

        # Clean old test users
        # Upsert Auth Users (triggers auto-create profile & customer role)
        users = [
            (self.cust_a, "customer_a@oguratest.com"),
            (self.cust_b, "customer_b@oguratest.com"),
            (self.seller_a_user, "seller_a@oguratest.com"),
            (self.seller_b_user, "seller_b@oguratest.com"),
            (self.seller_c_user, "seller_c@oguratest.com"),
            (self.admin_super, "super_admin@oguratest.com"),
            (self.admin_cat, "cat_admin@oguratest.com"),
            (self.admin_fin, "fin_admin@oguratest.com"),
            (self.admin_sup, "sup_admin@oguratest.com"),
            (self.admin_view, "view_admin@oguratest.com"),
        ]
        for uid, email in users:
            self.cur.execute("INSERT INTO auth.users (id, email) VALUES (%s, %s) ON CONFLICT (id) DO NOTHING;", (uid, email))
        self.conn.commit()

        # Assign Specific Admin Roles
        admin_roles = [
            (self.admin_super, 'admin_super'),
            (self.admin_cat, 'admin_catalog'),
            (self.admin_fin, 'admin_finance'),
            (self.admin_sup, 'admin_support'),
            (self.admin_view, 'admin_viewer'),
        ]
        for uid, role in admin_roles:
            self.cur.execute("DELETE FROM user_roles WHERE user_id = %s;", (uid,))
            self.cur.execute("INSERT INTO user_roles (user_id, role) VALUES (%s, %s);", (uid, role))
        self.conn.commit()

        # Customer Addresses
        self.cur.execute("""
            INSERT INTO customer_addresses (id, user_id, full_name, phone, line1, city, state, pincode, is_default)
            VALUES ('a1111111-0000-0000-0000-000000000001', %s, 'Customer A', '9876543210', '101 Royal Lane', 'Mumbai', 'MH', '400001', true),
                   ('a2222222-0000-0000-0000-000000000002', %s, 'Customer B', '9876543211', '202 Marine Drive', 'Mumbai', 'MH', '400020', true)
            ON CONFLICT (id) DO NOTHING;
        """, (self.cust_a, self.cust_b))
        self.conn.commit()

        # Sellers
        self.seller_a_id = "aaaa1111-0000-0000-0000-000000000001"
        self.seller_b_id = "bbbb2222-0000-0000-0000-000000000002"
        self.seller_c_id = "cccc3333-0000-0000-0000-000000000003" # Suspended

        self.cur.execute("""
            INSERT INTO sellers (id, user_id, business_name, legal_entity_name, seller_slug, status)
            VALUES (%s, %s, 'Atelier Aarnaa', 'Aarnaa Creations LLP', 'atelier-aarnaa', 'active'),
                   (%s, %s, 'Bespoke Benares', 'Benares Silks Pvt Ltd', 'bespoke-benares', 'active'),
                   (%s, %s, 'Suspended Crafts', 'Suspended Crafts LLC', 'suspended-crafts', 'suspended')
            ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, user_id = EXCLUDED.user_id;
        """, (self.seller_a_id, self.seller_a_user, self.seller_b_id, self.seller_b_user, self.seller_c_id, self.seller_c_user))

        # Update seller roles
        self.cur.execute("INSERT INTO user_roles (user_id, role) VALUES (%s, 'seller'), (%s, 'seller') ON CONFLICT DO NOTHING;",
                         (self.seller_a_user, self.seller_b_user))
        self.conn.commit()

        # Brands
        self.brand_a = "c1110000-0000-0000-0000-000000000001"
        self.brand_b = "c2220000-0000-0000-0000-000000000002"
        self.cur.execute("""
            INSERT INTO brands (id, seller_id, name, slug)
            VALUES (%s, %s, 'Aarnaa Couture', 'aarnaa-couture'),
                   (%s, %s, 'Benares Heritage', 'benares-heritage')
            ON CONFLICT (id) DO NOTHING;
        """, (self.brand_a, self.seller_a_id, self.brand_b, self.seller_b_id))
        self.conn.commit()

        # Category & Subcategory
        self.cat_id = "d0000000-0000-0000-0000-000000000001"
        self.subcat_id = "e0000000-0000-0000-0000-000000000001"
        self.cur.execute("""
            INSERT INTO categories (id, name, slug) VALUES (%s, 'Women', 'women') ON CONFLICT DO NOTHING;
            INSERT INTO subcategories (id, category_id, name, slug) VALUES (%s, %s, 'Kurta Sets', 'kurta-sets') ON CONFLICT DO NOTHING;
        """, (self.cat_id, self.subcat_id, self.cat_id))
        self.conn.commit()

        # Products & Variants:
        # Product A1: Standard Stock = 5 units
        self.prod_a1 = "faaa1111-0000-0000-0000-000000000001"
        self.var_a1 = "0aaa1111-0000-0000-0000-000000000001"
        self.cur.execute("""
            INSERT INTO products (id, seller_id, brand_id, subcategory_id, category_id, title, slug, status, is_made_to_order)
            VALUES (%s, %s, %s, %s, %s, 'Aarnaa Handcrafted Anarkali', 'aarnaa-handcrafted-anarkali', 'live', false)
            ON CONFLICT (id) DO UPDATE SET status = 'live';

            INSERT INTO product_variants (id, product_id, sku, price_paise, size, color)
            VALUES (%s, %s, 'AAR-ANA-M', 2500000, 'M', 'Crimson Red') -- ₹25,000
            ON CONFLICT (id) DO NOTHING;

            INSERT INTO inventory_items (id, variant_id, quantity_on_hand, quantity_reserved)
            VALUES ('1aaa1111-0000-0000-0000-000000000001', %s, 5, 0)
            ON CONFLICT (variant_id) DO UPDATE SET quantity_on_hand = 5, quantity_reserved = 0;
        """, (self.prod_a1, self.seller_a_id, self.brand_a, self.subcat_id, self.cat_id, self.var_a1, self.prod_a1, self.var_a1))

        # Product A2: Low-value product for tariff threshold testing (₹1,500 < ₹2,999)
        self.prod_a2 = "faaa2222-0000-0000-0000-000000000002"
        self.var_a2 = "0aaa2222-0000-0000-0000-000000000002"
        self.cur.execute("""
            INSERT INTO products (id, seller_id, brand_id, subcategory_id, category_id, title, slug, status, is_made_to_order)
            VALUES (%s, %s, %s, %s, %s, 'Aarnaa Silk Stole', 'aarnaa-silk-stole', 'live', false)
            ON CONFLICT (id) DO UPDATE SET status = 'live';

            INSERT INTO product_variants (id, product_id, sku, price_paise, size, color)
            VALUES (%s, %s, 'AAR-STO-FS', 150000, 'Free Size', 'Gold') -- ₹1,500 (< 2999)
            ON CONFLICT (id) DO NOTHING;

            INSERT INTO inventory_items (id, variant_id, quantity_on_hand, quantity_reserved)
            VALUES ('1aaa2222-0000-0000-0000-000000000002', %s, 10, 0)
            ON CONFLICT (variant_id) DO UPDATE SET quantity_on_hand = 10, quantity_reserved = 0;
        """, (self.prod_a2, self.seller_a_id, self.brand_a, self.subcat_id, self.cat_id, self.var_a2, self.prod_a2, self.var_a2))

        # Product B1: Seller B product for Multi-Seller Cart testing (₹3,000)
        self.prod_b1 = "fbbb1111-0000-0000-0000-000000000001"
        self.var_b1 = "0bbb1111-0000-0000-0000-000000000001"
        self.cur.execute("""
            INSERT INTO products (id, seller_id, brand_id, subcategory_id, category_id, title, slug, status, is_made_to_order)
            VALUES (%s, %s, %s, %s, %s, 'Benares Brocade Dupatta', 'benares-brocade-dupatta', 'live', false)
            ON CONFLICT (id) DO UPDATE SET status = 'live';

            INSERT INTO product_variants (id, product_id, sku, price_paise, size, color)
            VALUES (%s, %s, 'BEN-DUP-FS', 300000, 'Free Size', 'Emerald') -- ₹3,000
            ON CONFLICT (id) DO NOTHING;

            INSERT INTO inventory_items (id, variant_id, quantity_on_hand, quantity_reserved)
            VALUES ('1bbb1111-0000-0000-0000-000000000001', %s, 5, 0)
            ON CONFLICT (variant_id) DO UPDATE SET quantity_on_hand = 5, quantity_reserved = 0;
        """, (self.prod_b1, self.seller_b_id, self.brand_b, self.subcat_id, self.cat_id, self.var_b1, self.prod_b1, self.var_b1))

        # Product MTO: Made to Order (Stock = 0, is_made_to_order = true)
        self.prod_mto = "faaa3333-0000-0000-0000-000000000003"
        self.var_mto = "0aaa3333-0000-0000-0000-000000000003"
        self.cur.execute("""
            INSERT INTO products (id, seller_id, brand_id, subcategory_id, category_id, title, slug, status, is_made_to_order)
            VALUES (%s, %s, %s, %s, %s, 'Bespoke Zardozi Lehenga', 'bespoke-zardozi-lehenga', 'live', true)
            ON CONFLICT (id) DO UPDATE SET status = 'live';

            INSERT INTO product_variants (id, product_id, sku, price_paise, size, color)
            VALUES (%s, %s, 'AAR-LHG-MTO', 12000000, 'Custom', 'Royal Purple') -- ₹120,000
            ON CONFLICT (id) DO NOTHING;

            INSERT INTO inventory_items (id, variant_id, quantity_on_hand, quantity_reserved)
            VALUES ('1aaa3333-0000-0000-0000-000000000003', %s, 0, 0)
            ON CONFLICT (variant_id) DO UPDATE SET quantity_on_hand = 0, quantity_reserved = 0;
        """, (self.prod_mto, self.seller_a_id, self.brand_a, self.subcat_id, self.cat_id, self.var_mto, self.prod_mto, self.var_mto))

        self.conn.commit()
        print(f"{GREEN}Fixtures initialized cleanly.{RESET}\n")

    # =========================================================================
    # SUITE 1: AUTHENTICATION TESTS
    # =========================================================================
    def run_auth_tests(self):
        print(f"{CYAN}=== SUITE 1: AUTHENTICATION TESTS ==={RESET}")
        suite = "AUTH"

        # 1A. Anonymous Access on private tables
        self.as_user(None, role="anon")
        try:
            self.cur.execute("SELECT count(*) FROM customer_addresses;")
            cnt = self.cur.fetchone()['count']
            if cnt == 0:
                self.log_result(suite, "Anonymous Private Read", "PASS", "Returned 0 private addresses")
            else:
                self.log_result(suite, "Anonymous Private Read", "FAIL", f"Leaked {cnt} addresses to anonymous!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Anonymous Private Read", "PASS", f"Safely denied: {str(e)[:40]}")

        # 1B. Customer cannot escalate role
        self.as_user(self.cust_a, role="authenticated")
        try:
            self.cur.execute("INSERT INTO user_roles (user_id, role) VALUES (%s, 'admin_super');", (self.cust_a,))
            self.conn.commit()
            self.log_result(suite, "Role Escalation to Admin", "FAIL", "Customer escalated role to admin_super!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Role Escalation to Admin", "PASS", f"Safely blocked: {str(e)[:40]}")

        # 1C. Invariant: Non-super admin single role invariant
        self.as_user(self.admin_super, role="authenticated")
        try:
            self.cur.execute("INSERT INTO user_roles (user_id, role) VALUES (%s, 'admin_finance');", (self.admin_cat,))
            self.conn.commit()
            self.log_result(suite, "Multi-Admin Role Conflict", "FAIL", "Allowed multiple non-super admin roles!", "HIGH")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Multi-Admin Role Conflict", "PASS", f"Safely blocked by invariant trigger: {str(e)[:40]}")

    # =========================================================================
    # SUITE 2: CUSTOMER TENANT ISOLATION
    # =========================================================================
    def run_customer_isolation_tests(self):
        print(f"\n{CYAN}=== SUITE 2: CUSTOMER TENANT ISOLATION ==={RESET}")
        suite = "CUSTOMER_ISOLATION"

        # Customer A tries to read Customer B address
        self.as_user(self.cust_a, role="authenticated")
        self.cur.execute("SELECT count(*) FROM customer_addresses WHERE user_id = %s;", (self.cust_b,))
        cnt = self.cur.fetchone()['count']
        if cnt == 0:
            self.log_result(suite, "Cross-Customer Address Read", "PASS", "0 rows returned (RLS filtered)")
        else:
            self.log_result(suite, "Cross-Customer Address Read", "FAIL", f"Customer A saw Customer B address! ({cnt} rows)", "CRITICAL")

        # Customer A tries to update Customer B address
        try:
            self.cur.execute("UPDATE customer_addresses SET full_name = 'Hacked' WHERE user_id = %s;", (self.cust_b,))
            self.cur.execute("SELECT count(*) FROM customer_addresses WHERE user_id = %s AND full_name = 'Hacked';", (self.cust_b,))
            cnt = self.cur.fetchone()['count']
            if cnt == 0:
                self.log_result(suite, "Cross-Customer Address Update", "PASS", "0 rows mutated")
            else:
                self.log_result(suite, "Cross-Customer Address Update", "FAIL", "Customer A modified Customer B address!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Cross-Customer Address Update", "PASS", f"Denied: {str(e)[:40]}")

        # Customer A tries to read Customer B cart
        self.cur.execute("SELECT count(*) FROM carts WHERE user_id = %s;", (self.cust_b,))
        cnt = self.cur.fetchone()['count']
        if cnt == 0:
            self.log_result(suite, "Cross-Customer Cart Read", "PASS", "0 rows returned")
        else:
            self.log_result(suite, "Cross-Customer Cart Read", "FAIL", f"Customer A read Customer B cart!", "CRITICAL")

        # Customer A tries to read Customer B wishlist
        self.cur.execute("SELECT count(*) FROM customer_wishlist WHERE user_id = %s;", (self.cust_b,))
        cnt = self.cur.fetchone()['count']
        if cnt == 0:
            self.log_result(suite, "Cross-Customer Wishlist Read", "PASS", "0 rows returned")
        else:
            self.log_result(suite, "Cross-Customer Wishlist Read", "FAIL", f"Customer A read Customer B wishlist!", "CRITICAL")

    # =========================================================================
    # SUITE 3: SELLER TENANT ISOLATION
    # =========================================================================
    def run_seller_isolation_tests(self):
        print(f"\n{CYAN}=== SUITE 3: SELLER TENANT ISOLATION ==={RESET}")
        suite = "SELLER_ISOLATION"

        # Seller A tries to read Seller B private bank account
        self.as_user(self.seller_a_user, role="authenticated")
        self.cur.execute("SELECT count(*) FROM seller_bank_accounts WHERE seller_id = %s;", (self.seller_b_id,))
        cnt = self.cur.fetchone()['count']
        if cnt == 0:
            self.log_result(suite, "Cross-Seller Bank Account Read", "PASS", "0 rows returned")
        else:
            self.log_result(suite, "Cross-Seller Bank Account Read", "FAIL", "Seller A read Seller B bank account!", "CRITICAL")

        # Seller A tries to read Seller B KYC docs
        self.cur.execute("SELECT count(*) FROM seller_kyc_documents WHERE seller_id = %s;", (self.seller_b_id,))
        cnt = self.cur.fetchone()['count']
        if cnt == 0:
            self.log_result(suite, "Cross-Seller KYC Read", "PASS", "0 rows returned")
        else:
            self.log_result(suite, "Cross-Seller KYC Read", "FAIL", "Seller A read Seller B KYC documents!", "CRITICAL")

        # Seller A tries to mutate Seller B product
        try:
            self.cur.execute("UPDATE products SET title = 'Defaced' WHERE seller_id = %s;", (self.seller_b_id,))
            self.cur.execute("SELECT count(*) FROM products WHERE seller_id = %s AND title = 'Defaced';", (self.seller_b_id,))
            cnt = self.cur.fetchone()['count']
            if cnt == 0:
                self.log_result(suite, "Cross-Seller Product Defacement", "PASS", "0 rows mutated")
            else:
                self.log_result(suite, "Cross-Seller Product Defacement", "FAIL", "Seller A defaced Seller B product!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Cross-Seller Product Defacement", "PASS", f"Blocked: {str(e)[:40]}")

        # Anonymous tries to query public.sellers confidential fields
        self.cur.execute("SET ROLE anon;")
        self.cur.execute("SELECT set_config('request.jwt.claim.sub', '', false);")
        self.cur.execute("SELECT set_config('request.jwt.claim.role', 'anon', false);")
        self.cur.execute("SELECT gstin, pan, commission_rate_bps FROM public.sellers WHERE status = 'active';")
        anon_rows = self.cur.fetchall()
        self.reset_role()
        if len(anon_rows) == 0:
            self.log_result(suite, "Anonymous Seller Confidential Read", "PASS", "0 rows returned (RLS denied base table access)")
        else:
            self.log_result(suite, "Anonymous Seller Confidential Read", "FAIL", f"Anonymous read leaked {len(anon_rows)} seller rows!", "HIGH")

        # Anonymous reads public_sellers view (authoritative projection)
        self.cur.execute("SET ROLE anon;")
        self.cur.execute("SELECT set_config('request.jwt.claim.sub', '', false);")
        self.cur.execute("SELECT set_config('request.jwt.claim.role', 'anon', false);")
        self.cur.execute("SELECT * FROM public.public_sellers;")
        pub_rows = self.cur.fetchall()
        self.reset_role()
        if len(pub_rows) > 0 and 'gstin' not in pub_rows[0]:
            self.log_result(suite, "Public Seller Projection", "PASS", f"public_sellers returned {len(pub_rows)} sellers with zero private columns")
        else:
            self.log_result(suite, "Public Seller Projection", "FAIL", "public_sellers view failed or leaked private fields", "MEDIUM")

        # Customer A tries to read public.sellers
        self.as_user(self.cust_a, role="authenticated")
        self.cur.execute("SELECT gstin, pan, commission_rate_bps FROM public.sellers;")
        cust_rows = self.cur.fetchall()
        self.reset_role()
        if len(cust_rows) == 0:
            self.log_result(suite, "Customer Seller Table Read", "PASS", "0 rows returned (customer denied access to sellers base table)")
        else:
            self.log_result(suite, "Customer Seller Table Read", "FAIL", f"Customer leaked {len(cust_rows)} seller rows!", "HIGH")

    # =========================================================================
    # SUITE 4: ADMIN LEAST-PRIVILEGE AUDIT
    # =========================================================================
    def run_admin_privilege_tests(self):
        print(f"\n{CYAN}=== SUITE 4: ADMIN LEAST-PRIVILEGE AUDIT ==={RESET}")
        suite = "ADMIN_PRIVILEGE"

        # 4A. Admin Catalog attempts financial refund authorization (Must FAIL)
        self.as_user(self.admin_cat, role="authenticated")
        try:
            fake_ret_id = str(uuid.uuid4())
            self.cur.execute("SELECT public.admin_authorize_refund(%s, 10000, 'defect');", (fake_ret_id,))
            self.conn.commit()
            self.log_result(suite, "Catalog Admin Authorizing Refund", "FAIL", "Catalog admin authorized refund!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Catalog Admin Authorizing Refund", "PASS", f"Safely blocked: {str(e)[:40]}")

        # 4B. Admin Finance attempts catalog approval (Must FAIL)
        self.as_user(self.admin_fin, role="authenticated")
        try:
            self.cur.execute("SELECT public.approve_product(%s);", (self.prod_a1,))
            self.conn.commit()
            self.log_result(suite, "Finance Admin Approving Product", "FAIL", "Finance admin approved product!", "HIGH")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Finance Admin Approving Product", "PASS", f"Safely blocked: {str(e)[:40]}")

        # 4C. Admin Viewer attempts write mutation (Must FAIL)
        self.as_user(self.admin_view, role="authenticated")
        try:
            self.cur.execute("UPDATE products SET title = 'Tampered' WHERE id = %s;", (self.prod_a1,))
            self.cur.execute("SELECT count(*) FROM products WHERE id = %s AND title = 'Tampered';", (self.prod_a1,))
            cnt = self.cur.fetchone()['count']
            if cnt == 0:
                self.log_result(suite, "Admin Viewer Write Mutation", "PASS", "0 rows mutated (read-only enforced)")
            else:
                self.log_result(suite, "Admin Viewer Write Mutation", "FAIL", "Admin Viewer mutated catalog data!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Admin Viewer Write Mutation", "PASS", f"Safely blocked: {str(e)[:40]}")

    # =========================================================================
    # SUITE 5: PRODUCT & SELLER LIFECYCLE INVARIANTS
    # =========================================================================
    def run_lifecycle_tests(self):
        print(f"\n{CYAN}=== SUITE 5: PRODUCT & SELLER LIFECYCLE INVARIANTS ==={RESET}")
        suite = "LIFECYCLE"

        # 5A. Inactive/Suspended Seller Product cannot be set to 'live'
        self.as_user(self.admin_super, role="authenticated")
        try:
            self.cur.execute("""
                INSERT INTO products (id, seller_id, brand_id, subcategory_id, category_id, title, slug, status)
                VALUES ('fccc1111-0000-0000-0000-000000000001', %s, %s, %s, %s, 'Illegal Live', 'illegal-live', 'live');
            """, (self.seller_c_id, self.brand_a, self.subcat_id, self.cat_id))
            self.conn.commit()
            self.log_result(suite, "Suspended Seller Product Live Invariant", "FAIL", "Suspended seller product became live!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Suspended Seller Product Live Invariant", "PASS", f"Safely blocked by lifecycle trigger: {str(e)[:50]}")

        # 5B. Seller self-approval attempt (Gate 1 violation)
        self.as_user(self.seller_b_user, role="authenticated")
        try:
            self.cur.execute("SELECT public.approve_seller(%s);", (self.seller_c_id,))
            self.conn.commit()
            self.log_result(suite, "Seller Approving Another Seller", "FAIL", "Seller invoked approve_seller RPC!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Seller Approving Another Seller", "PASS", f"Safely blocked: {str(e)[:40]}")

    # =========================================================================
    # SUITE 6: INVENTORY SATURATION, CONCURRENCY & RACE CONDITIONS
    # =========================================================================
    def run_inventory_saturation_tests(self):
        print(f"\n{CYAN}=== SUITE 6: INVENTORY SATURATION & CONCURRENCY RED-TEAM ==={RESET}")
        suite = "INVENTORY"

        # Reset variant A1 inventory to exactly 5 units on hand, 0 reserved
        self.reset_role()
        self.cur.execute("UPDATE inventory_items SET quantity_on_hand = 5, quantity_reserved = 0 WHERE variant_id = %s;", (self.var_a1,))
        self.conn.commit()

        # Concurrency race: 10 concurrent customer threads trying to reserve 1 unit each from a pool of 5
        # Each thread acts as a unique customer
        successes = []
        failures = []
        threads = []

        # Create 10 test customers for concurrency race
        concurrency_customers = [f"11111111-2222-3333-4444-{i:012d}" for i in range(10)]
        self.reset_role()
        for i, cid in enumerate(concurrency_customers):
            self.cur.execute("""
                INSERT INTO auth.users (id, email) VALUES (%s, %s)
                ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
            """, (cid, f"concur_{i}_{cid[-8:]}@test.com"))
            self.cur.execute("""
                INSERT INTO customer_addresses (id, user_id, full_name, phone, line1, city, state, pincode, is_default)
                VALUES (%s, %s, 'Concur User', '9876543210', '101 Concur St', 'Mumbai', 'MH', '400001', true)
                ON CONFLICT (id) DO NOTHING;
            """, (str(uuid.uuid4()), cid))
        self.conn.commit()

        def attempt_quote_reservation(thread_idx, customer_id):
            conn = psycopg2.connect(f"dbname={self.db_name} user={DB_USER} host={DB_HOST} port={DB_PORT}")
            conn.autocommit = False
            cur = conn.cursor()
            try:
                # Set as authenticated customer
                cur.execute("SET ROLE authenticated;")
                cur.execute("SELECT set_config('request.jwt.claim.sub', %s, true);", (customer_id,))
                cur.execute("SELECT set_config('request.jwt.claim.role', 'authenticated', true);")

                # 1. Add item to cart
                cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (self.var_a1,))
                
                # 2. Get customer address id
                cur.execute("SELECT id FROM customer_addresses WHERE user_id = %s LIMIT 1;", (customer_id,))
                addr_id = cur.fetchone()[0]

                # 3. Create checkout quote (which atomically reserves stock)
                cur.execute("SELECT public.create_checkout_quote(%s, NULL);", (addr_id,))
                res = cur.fetchone()[0]
                conn.commit()
                successes.append((thread_idx, res['quote_id']))
            except Exception as e:
                conn.rollback()
                failures.append((thread_idx, str(e)))
            finally:
                conn.close()

        for idx, cid in enumerate(concurrency_customers):
            t = threading.Thread(target=attempt_quote_reservation, args=(idx, cid))
            threads.append(t)
            t.start()

        for t in threads:
            t.join()

        # Evaluate concurrency invariant
        self.reset_role()
        self.cur.execute("SELECT quantity_on_hand, quantity_reserved FROM inventory_items WHERE variant_id = %s;", (self.var_a1,))
        inv = self.cur.fetchone()
        on_hand = inv['quantity_on_hand']
        reserved = inv['quantity_reserved']

        print(f"  Concurrency Outcome: {len(successes)} succeeded, {len(failures)} failed")
        print(f"  Database State: on_hand={on_hand}, reserved={reserved}")

        if len(successes) == 5 and len(failures) == 5 and reserved == 5:
            self.log_result(suite, "Concurrent Reservation Saturation", "PASS", f"Exactly 5 reserved, 5 rejected ({len(failures)} rejected with insufficient_inventory)")
        elif reserved > on_hand:
            self.log_result(suite, "Concurrent Reservation Saturation", "FAIL", f"OVERSELL DETECTED: reserved ({reserved}) > on_hand ({on_hand})!", "CRITICAL")
        else:
            self.log_result(suite, "Concurrent Reservation Saturation", "PASS", f"Oversell prevented: {len(successes)} reserved out of 10")

        # 6B. Invariant: available = max(on_hand - reserved, 0)
        self.cur.execute("SELECT quantity_on_hand - quantity_reserved AS avail FROM inventory_items WHERE variant_id = %s;", (self.var_a1,))
        avail = self.cur.fetchone()['avail']
        if avail >= 0:
            self.log_result(suite, "Non-Negative Stock Invariant", "PASS", f"Available stock is non-negative ({avail})")
        else:
            self.log_result(suite, "Non-Negative Stock Invariant", "FAIL", f"Negative stock detected ({avail})!", "CRITICAL")

        # 6C. Releasing reservations restores stock
        for tid, qid in successes:
            try:
                # cancel quote using service role / admin
                self.reset_role()
                self.cur.execute("SELECT public.cancel_checkout_quote(%s);", (qid,))
                self.conn.commit()
            except Exception:
                self.conn.rollback()

        self.cur.execute("SELECT quantity_on_hand, quantity_reserved FROM inventory_items WHERE variant_id = %s;", (self.var_a1,))
        inv_post = self.cur.fetchone()
        if inv_post and inv_post['quantity_reserved'] == 0:
            self.log_result(suite, "Reservation Release Invariant", "PASS", "All reserved quantity cleanly released to 0")
        else:
            self.log_result(suite, "Reservation Release Invariant", "FAIL", f"Orphan reservation quantity remaining: {inv_post['quantity_reserved'] if inv_post else 'None'}", "HIGH")

    # =========================================================================
    # SUITE 7: CHECKOUT & TARIFF CALCULATION ATTACKS
    # =========================================================================
    def run_checkout_tariff_tests(self):
        print(f"\n{CYAN}=== SUITE 7: CHECKOUT & TARIFF CALCULATION RED-TEAM ==={RESET}")
        suite = "TARIFF_CHECKOUT"

        self.as_user(self.cust_a, role="authenticated")
        self.cur.execute("SELECT id FROM customer_addresses WHERE user_id = %s LIMIT 1;", (self.cust_a,))
        addr_id = self.cur.fetchone()['id']

        # 7A. Subtotal < ₹2,999 -> Shipping MUST BE ₹99 (9,900 paise)
        # Clear cart and add variant A2 (₹1,500)
        self.cur.execute("SELECT public.clear_customer_cart();")
        self.cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (self.var_a2,))
        self.cur.execute("SELECT public.create_checkout_quote(%s, NULL);", (addr_id,))
        q_low = self.cur.fetchone()['create_checkout_quote']
        self.conn.commit()

        if q_low['shipping_fee_paise'] == 9900:
            self.log_result(suite, "Tariff Below Free Shipping Threshold", "PASS", f"Applied standard ₹99 shipping (total: {q_low['total_payable_paise']} paise)")
        else:
            self.log_result(suite, "Tariff Below Free Shipping Threshold", "FAIL", f"Expected 9900 shipping, got {q_low['shipping_fee_paise']}", "HIGH")

        # 7B. Subtotal >= ₹2,999 -> Shipping MUST BE ₹0
        # Clear cart and add variant B1 (₹3,000)
        self.cur.execute("SELECT public.clear_customer_cart();")
        self.cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (self.var_b1,))
        self.cur.execute("SELECT public.create_checkout_quote(%s, NULL);", (addr_id,))
        q_high = self.cur.fetchone()['create_checkout_quote']
        self.conn.commit()

        if q_high['shipping_fee_paise'] == 0:
            self.log_result(suite, "Tariff Above Free Shipping Threshold", "PASS", "Applied ₹0 free shipping")
        else:
            self.log_result(suite, "Tariff Above Free Shipping Threshold", "FAIL", f"Expected 0 shipping, got {q_high['shipping_fee_paise']}", "HIGH")

        # 7C. Multi-Seller Cart: Verify shipping is charged once at parent order level, NOT per seller
        # Low value item from Seller A (₹1,500) + Item from Seller B (₹3,000) -> Total ₹4,500 >= 2999 -> Free shipping
        self.cur.execute("SELECT public.clear_customer_cart();")
        self.cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (self.var_a2,))
        self.cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (self.var_b1,))
        self.cur.execute("SELECT public.create_checkout_quote(%s, NULL);", (addr_id,))
        q_multi = self.cur.fetchone()['create_checkout_quote']
        self.conn.commit()

        if q_multi['shipping_fee_paise'] == 0:
            self.log_result(suite, "Multi-Seller Shipping Threshold", "PASS", "Single order-level threshold applied correctly across multiple sellers")
        else:
            self.log_result(suite, "Multi-Seller Shipping Threshold", "FAIL", f"Unexpected multi-seller shipping fee: {q_multi['shipping_fee_paise']}", "HIGH")

        # Clean quotes
        self.reset_role()
        for q in [q_low['quote_id'], q_high['quote_id'], q_multi['quote_id']]:
            try:
                self.cur.execute("SELECT public.cancel_checkout_quote(%s);", (q,))
                self.conn.commit()
            except Exception:
                self.conn.rollback()

    # =========================================================================
    # SUITE 8: PAYMENT STATE-MACHINE & IDEMPOTENCY
    # =========================================================================
    def run_payment_idempotency_tests(self):
        print(f"\n{CYAN}=== SUITE 8: PAYMENT STATE-MACHINE & IDEMPOTENCY RED-TEAM ==={RESET}")
        suite = "PAYMENT_STATE"

        self.as_user(self.cust_a, role="authenticated")
        self.cur.execute("SELECT id FROM customer_addresses WHERE user_id = %s LIMIT 1;", (self.cust_a,))
        addr_id = self.cur.fetchone()['id']

        # 1. Create quote & place order
        self.cur.execute("SELECT public.clear_customer_cart();")
        self.cur.execute("SELECT public.add_to_customer_cart(%s, 1);", (self.var_a1,))
        self.cur.execute("SELECT public.create_checkout_quote(%s, NULL);", (addr_id,))
        q_res = self.cur.fetchone()['create_checkout_quote']
        qid = q_res['quote_id']
        self.conn.commit()

        self.cur.execute("SELECT public.create_order_from_quote(%s);", (qid,))
        o_res = self.cur.fetchone()['create_order_from_quote']
        order_id = o_res['order_id']
        self.conn.commit()

        # Check suborders count
        self.cur.execute("SELECT count(*) FROM seller_sub_orders WHERE order_id = %s;", (order_id,))
        sub_count = self.cur.fetchone()['count']
        self.log_result(suite, "Order Generation from Quote", "PASS", f"Order {order_id[:8]} created with {sub_count} sub-orders")

        # 2. Confirm payment
        fake_gw = f"pay_test_{uuid.uuid4().hex[:8]}"
        
        # 2A. Test Service-Role / Webhook confirmation (unauthenticated backend caller)
        self.reset_role()
        try:
            self.cur.execute("SELECT public.confirm_order_payment(%s, %s, %s);", (order_id, fake_gw, 'sig_test_123'))
            self.conn.commit()
            self.log_result(suite, "Service-Role Webhook Confirmation", "PASS", "Service-role caller successfully confirmed payment")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Service-Role Webhook Confirmation", "FAIL",
                            f"DEFECT: confirm_order_payment calls clear_customer_cart() requiring auth.uid(), crashing on webhook/service-role callers: {str(e)[:45]}", "HIGH")

        # 2B. Test Customer Confirmation (Authenticated caller)
        self.as_user(self.cust_a, role="authenticated")
        self.cur.execute("SELECT public.confirm_order_payment(%s, %s, %s);", (order_id, fake_gw, 'sig_test_123'))
        self.conn.commit()

        self.cur.execute("SELECT status FROM orders WHERE id = %s;", (order_id,))
        o_state = self.cur.fetchone()
        self.cur.execute("SELECT status FROM payment_transactions WHERE order_id = %s;", (order_id,))
        p_state = self.cur.fetchone()
        if o_state['status'] == 'confirmed' and p_state and p_state['status'] == 'captured':
            self.log_result(suite, "Customer Payment Capture", "PASS", "Order transitioned to confirmed, payment to captured")
        else:
            self.log_result(suite, "Customer Payment Capture", "FAIL", f"Order is {o_state['status']}, payment is {p_state['status'] if p_state else 'None'}", "CRITICAL")

        # 3. IDEMPOTENCY ATTACK: Confirm payment AGAIN with same or new gateway ID
        # Must NOT create duplicate sub-orders, must NOT consume inventory twice
        self.reset_role()
        self.cur.execute("SELECT count(*) FROM seller_sub_orders WHERE order_id = %s;", (order_id,))
        sub_count_before = self.cur.fetchone()['count']
        self.cur.execute("SELECT quantity_on_hand FROM inventory_items WHERE variant_id = %s;", (self.var_a1,))
        on_hand_before = self.cur.fetchone()['quantity_on_hand']

        self.as_user(self.cust_a, role="authenticated")
        try:
            self.cur.execute("SELECT public.confirm_order_payment(%s, %s, %s);", (order_id, fake_gw, 'sig_test_123'))
            self.conn.commit()
        except Exception:
            self.conn.rollback()

        self.reset_role()
        self.cur.execute("SELECT count(*) FROM seller_sub_orders WHERE order_id = %s;", (order_id,))
        sub_count_after = self.cur.fetchone()['count']

        self.cur.execute("SELECT quantity_on_hand FROM inventory_items WHERE variant_id = %s;", (self.var_a1,))
        on_hand_after = self.cur.fetchone()['quantity_on_hand']

        if sub_count_after == sub_count_before and on_hand_after == on_hand_before:
            self.log_result(suite, "Payment Confirmation Idempotency", "PASS", f"Repeated confirmation caused zero duplicate side-effects (suborders: {sub_count_after}, on_hand: {on_hand_after})")
        else:
            self.log_result(suite, "Payment Confirmation Idempotency", "FAIL",
                            f"Idempotency breach: suborders {sub_count_before}->{sub_count_after}, on_hand {on_hand_before}->{on_hand_after}", "CRITICAL")

        # Store order_id for fulfillment and returns test
        self.active_order_id = order_id

    # =========================================================================
    # SUITE 9: FULFILLMENT & SHIPPING SECURITY
    # =========================================================================
    def run_fulfillment_tests(self):
        print(f"\n{CYAN}=== SUITE 9: FULFILLMENT & SHIPPING SECURITY RED-TEAM ==={RESET}")
        suite = "FULFILLMENT"

        # Find suborder for active order
        self.reset_role()
        self.cur.execute("SELECT id, seller_id FROM seller_sub_orders WHERE order_id = %s LIMIT 1;", (self.active_order_id,))
        sub = self.cur.fetchone()
        sub_id = sub['id']
        owning_seller_id = sub['seller_id']

        # 9A. Seller B attempts to ship Seller A's suborder (Cross-Seller Shipping Attack)
        self.as_user(self.seller_b_user, role="authenticated")
        try:
            self.cur.execute("""
                SELECT public.seller_ship_sub_order(
                    %s,
                    'manual',
                    'Intruder Courier',
                    'HACKED-TRACKING',
                    NULL
                );
            """, (sub_id,))
            self.conn.commit()
            self.log_result(suite, "Cross-Seller Shipment Injection", "FAIL", "Seller B shipped Seller A's sub-order!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Cross-Seller Shipment Injection", "PASS", f"Safely blocked: {str(e)[:40]}")

        # 9B. Customer attempts to ship suborder
        self.as_user(self.cust_a, role="authenticated")
        try:
            self.cur.execute("""
                SELECT public.seller_ship_sub_order(
                    %s,
                    'manual',
                    'Customer Courier',
                    'CUST-TRACKING',
                    NULL
                );
            """, (sub_id,))
            self.conn.commit()
            self.log_result(suite, "Customer Shipment Mutation", "FAIL", "Customer shipped sub-order!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Customer Shipment Mutation", "PASS", f"Safely blocked: {str(e)[:40]}")

        # 9C. Legitimate Owning Seller A ships own suborder via Manual AWB
        self.as_user(self.seller_a_user, role="authenticated")
        try:
            # First accept suborder
            self.cur.execute("SELECT public.seller_accept_sub_order(%s);", (sub_id,))
            self.conn.commit()

            # Then ship with manual AWB
            tracking = f"OG-MANUAL-{uuid.uuid4().hex[:6].upper()}"
            self.cur.execute("""
                SELECT public.seller_ship_sub_order(
                    %s,
                    'manual',
                    'Atelier Express',
                    %s,
                    NULL
                );
            """, (sub_id, tracking))
            self.conn.commit()

            self.cur.execute("SELECT status FROM seller_sub_orders WHERE id = %s;", (sub_id,))
            st = self.cur.fetchone()['status']
            if st == 'dispatched':
                self.log_result(suite, "Legitimate Manual AWB Shipment", "PASS", f"Suborder dispatched cleanly with tracking {tracking}")
            else:
                self.log_result(suite, "Legitimate Manual AWB Shipment", "FAIL", f"Suborder status is {st}", "HIGH")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Legitimate Manual AWB Shipment", "FAIL", f"Shipment failed: {e}", "HIGH")

        # 9D. Illegal Transition: Dispatched/Delivered suborder cannot be reverted to packed
        try:
            self.cur.execute("UPDATE seller_sub_orders SET status = 'packed' WHERE id = %s;", (sub_id,))
            self.cur.execute("SELECT status FROM seller_sub_orders WHERE id = %s;", (sub_id,))
            post_st = self.cur.fetchone()['status']
            if post_st == 'packed':
                self.log_result(suite, "Sub-Order Illegal Reversion", "FAIL", "Dispatched suborder reverted to packed!", "HIGH")
            else:
                self.log_result(suite, "Sub-Order Illegal Reversion", "PASS", "Reversion blocked by trigger/RLS")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Sub-Order Illegal Reversion", "PASS", f"Blocked: {str(e)[:40]}")

    # =========================================================================
    # SUITE 10: RETURNS, REFUNDS & FINANCIAL LEDGER INTEGRITY
    # =========================================================================
    def run_returns_ledger_tests(self):
        print(f"\n{CYAN}=== SUITE 10: RETURNS, REFUNDS & DOUBLE-ENTRY LEDGER RED-TEAM ==={RESET}")
        suite = "RETURNS_LEDGER"

        # Transition suborder to delivered so return is eligible
        self.reset_role()
        self.cur.execute("""
            UPDATE seller_sub_orders 
            SET status = 'delivered', delivered_at = CURRENT_TIMESTAMP - INTERVAL '2 days'
            WHERE order_id = %s;
        """, (self.active_order_id,))
        self.conn.commit()

        # Find order item
        self.cur.execute("""
            SELECT i.id, i.variant_id, i.quantity, i.unit_price_paise 
            FROM order_items i 
            JOIN seller_sub_orders s ON i.sub_order_id = s.id 
            WHERE s.order_id = %s 
            LIMIT 1;
        """, (self.active_order_id,))
        item = self.cur.fetchone()
        item_id = item['id']
        refund_amount = item['unit_price_paise']

        # 10A. Customer creates return request
        self.as_user(self.cust_a, role="authenticated")
        self.cur.execute("""
            SELECT public.customer_create_return_request(
                %s,
                'defective',
                'Fabric flaw discovered upon unboxing',
                'refund',
                1
            );
        """, (item_id,))
        ret_res = self.cur.fetchone()['customer_create_return_request']
        ret_id = ret_res['return_request_id']
        self.conn.commit()
        self.log_result(suite, "Customer Return Creation", "PASS", f"Return request {ret_id[:8]} created")

        # 10B. Customer attempts to approve own refund (Privilege Escalation Attack)
        try:
            self.cur.execute("SELECT public.admin_authorize_refund(%s, 'Customer self authorization');", (ret_id,))
            self.conn.commit()
            self.log_result(suite, "Customer Self-Authorizing Refund", "FAIL", "Customer authorized own refund!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Customer Self-Authorizing Refund", "PASS", f"Safely blocked: {str(e)[:40]}")

        # 10C. Support Admin reviews return & records QC passed
        self.as_user(self.admin_sup, role="authenticated")
        try:
            self.cur.execute("SELECT public.admin_review_return_request(%s, 'approve', 'Support review passed');", (ret_id,))
            self.cur.execute("SELECT public.admin_update_return_logistics(%s, 'BlueDart', 'RETURN-AWB-101', 'pickup_scheduled');", (ret_id,))
            self.cur.execute("SELECT public.admin_update_return_logistics(%s, NULL, NULL, 'in_transit');", (ret_id,))
            self.cur.execute("SELECT public.admin_update_return_logistics(%s, NULL, NULL, 'hub_received');", (ret_id,))
            self.cur.execute("SELECT public.admin_record_return_qc(%s, true, 'Flaw confirmed by support QC');", (ret_id,))
            self.conn.commit()
            self.log_result(suite, "Support Return Review & QC", "PASS", "QC inspection recorded as qc_passed")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Support Return Review & QC", "FAIL", f"QC flow failed: {e}", "HIGH")

        # 10D. Finance Admin authorizes refund
        self.as_user(self.admin_fin, role="authenticated")
        try:
            self.cur.execute("SELECT public.admin_authorize_refund(%s, 'Authorized refund by finance');", (ret_id,))
            self.conn.commit()
            self.log_result(suite, "Finance Admin Refund Authorization", "PASS", f"Refund authorized successfully")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Finance Admin Refund Authorization", "FAIL", f"Refund authorization failed: {e}", "CRITICAL")

        # 10E. CRITICAL ATTACK: Idempotency of refund authorization
        self.cur.execute("SELECT count(*) FROM refund_transactions WHERE return_request_id = %s;", (ret_id,))
        ref_count_before = self.cur.fetchone()['count']

        self.cur.execute("SELECT public.admin_authorize_refund(%s, 'Duplicate refund attempt');", (ret_id,))
        dup_res = self.cur.fetchone()['admin_authorize_refund']
        self.conn.commit()

        self.cur.execute("SELECT count(*) FROM refund_transactions WHERE return_request_id = %s;", (ret_id,))
        ref_count_after = self.cur.fetchone()['count']

        if ref_count_after == ref_count_before and dup_res.get('is_idempotent'):
            self.log_result(suite, "Duplicate Refund Financial Safety Guard", "PASS", "Idempotent: zero duplicate refunds or ledger entries generated")
        else:
            self.log_result(suite, "Duplicate Refund Financial Safety Guard", "FAIL", f"Allowed duplicate refund transaction: count {ref_count_before}->{ref_count_after}", "CRITICAL")

        # 10F. DOUBLE-ENTRY LEDGER MATHEMATICAL BALANCE VERIFICATION
        # Every transaction group in financial_ledger_entries MUST have SUM(debit) == SUM(credit)
        self.reset_role()
        self.cur.execute("""
            SELECT transaction_group_id,
                   SUM(CASE WHEN entry_type = 'debit' THEN amount_paise ELSE 0 END) AS total_debits,
                   SUM(CASE WHEN entry_type = 'credit' THEN amount_paise ELSE 0 END) AS total_credits
            FROM financial_ledger_entries
            GROUP BY transaction_group_id;
        """)
        groups = self.cur.fetchall()
        imbalanced = []
        for g in groups:
            if g['total_debits'] != g['total_credits']:
                imbalanced.append(g)

        if len(imbalanced) == 0 and len(groups) > 0:
            self.log_result(suite, "Double-Entry Mathematical Balance", "PASS", f"All {len(groups)} ledger transaction groups are perfectly balanced (debits == credits)")
        elif len(imbalanced) > 0:
            self.log_result(suite, "Double-Entry Mathematical Balance", "FAIL", f"IMBALANCED LEDGER DETECTED in {len(imbalanced)} groups!", "CRITICAL")

        # 10G. IMMUTABLE LEDGER ATTACK: Attempt UPDATE or DELETE on ledger rows
        try:
            self.cur.execute("DELETE FROM financial_ledger_entries WHERE true;")
            self.conn.commit()
            self.log_result(suite, "Immutable Ledger Enforcement", "FAIL", "Ledger rows were deleted!", "CRITICAL")
        except Exception as e:
            self.conn.rollback()
            self.log_result(suite, "Immutable Ledger Enforcement", "PASS", f"Blocked by immutable trigger: {str(e)[:45]}")

    # =========================================================================
    # SUITE 11: PAYOUT GATE TESTING
    # =========================================================================
    def run_payout_gate_tests(self):
        print(f"\n{CYAN}=== SUITE 11: PAYOUT GATE AUDIT ==={RESET}")
        suite = "PAYOUT_GATE"

        # Check Seller A payout eligibility:
        # Seller A has active status, but bank account is unverified and KYC docs are pending.
        self.reset_role()
        self.cur.execute("SELECT public.is_seller_payout_eligible(%s);", (self.seller_a_id,))
        eligible = self.cur.fetchone()['is_seller_payout_eligible']
        if not eligible:
            self.log_result(suite, "Unverified Seller Payout Gate", "PASS", "Correctly returns false when bank/KYC is incomplete")
        else:
            self.log_result(suite, "Unverified Seller Payout Gate", "FAIL", "Unverified seller passed payout gate!", "CRITICAL")

    # =========================================================================
    # SUITE 12: DATA CORRUPTION AUDIT
    # =========================================================================
    def run_data_corruption_audit(self):
        print(f"\n{CYAN}=== SUITE 12: DATA INTEGRITY & CORRUPTION AUDIT ==={RESET}")
        suite = "DATA_CORRUPTION"

        self.reset_role()

        # Invariant 1: Negative inventory check
        self.cur.execute("SELECT count(*) FROM inventory_items WHERE quantity_on_hand < 0 OR quantity_reserved < 0;")
        neg_cnt = self.cur.fetchone()['count']
        if neg_cnt == 0:
            self.log_result(suite, "Negative Inventory Check", "PASS", "0 rows with negative inventory")
        else:
            self.log_result(suite, "Negative Inventory Check", "FAIL", f"{neg_cnt} rows with negative inventory!", "CRITICAL")

        # Invariant 2: Reserved > on_hand check
        self.cur.execute("SELECT count(*) FROM inventory_items WHERE quantity_reserved > quantity_on_hand;")
        res_gt_hand = self.cur.fetchone()['count']
        if res_gt_hand == 0:
            self.log_result(suite, "Reserved Exceeding On-Hand Check", "PASS", "0 rows where reserved > on_hand")
        else:
            self.log_result(suite, "Reserved Exceeding On-Hand Check", "FAIL", f"{res_gt_hand} rows where reserved > on_hand!", "CRITICAL")

        # Invariant 3: Orphan suborders without parent orders
        self.cur.execute("SELECT count(*) FROM seller_sub_orders s LEFT JOIN orders o ON s.order_id = o.id WHERE o.id IS NULL;")
        orphan_sub = self.cur.fetchone()['count']
        if orphan_sub == 0:
            self.log_result(suite, "Orphan Sub-Orders Check", "PASS", "0 orphan suborders")
        else:
            self.log_result(suite, "Orphan Sub-Orders Check", "FAIL", f"{orphan_sub} orphan suborders found!", "HIGH")

        # Invariant 4: Orphan order items
        self.cur.execute("SELECT count(*) FROM order_items i LEFT JOIN seller_sub_orders s ON i.sub_order_id = s.id WHERE s.id IS NULL;")
        orphan_items = self.cur.fetchone()['count']
        if orphan_items == 0:
            self.log_result(suite, "Orphan Order Items Check", "PASS", "0 orphan order items")
        else:
            self.log_result(suite, "Orphan Order Items Check", "FAIL", f"{orphan_items} orphan order items found!", "HIGH")

    # =========================================================================
    # EXECUTE ALL
    # =========================================================================
    def run_all(self):
        start_time = time.time()
        print(f"\n{YELLOW}======================================================================{RESET}")
        print(f"{YELLOW}STARTING RIGOROUS RED-TEAM & MVP SYSTEM AUDIT ({self.db_name}){RESET}")
        print(f"{YELLOW}======================================================================{RESET}\n")

        self.setup_fixtures()
        self.run_auth_tests()
        self.run_customer_isolation_tests()
        self.run_seller_isolation_tests()
        self.run_admin_privilege_tests()
        self.run_lifecycle_tests()
        self.run_inventory_saturation_tests()
        self.run_checkout_tariff_tests()
        self.run_payment_idempotency_tests()
        self.run_fulfillment_tests()
        self.run_returns_ledger_tests()
        self.run_payout_gate_tests()
        self.run_data_corruption_audit()

        elapsed = time.time() - start_time
        total = len(self.results)
        passed = sum(1 for r in self.results if r['status'] == 'PASS')
        failed = sum(1 for r in self.results if r['status'] == 'FAIL')

        print(f"\n{YELLOW}======================================================================{RESET}")
        print(f"{YELLOW}AUDIT EXECUTION COMPLETE IN {elapsed:.2f}s{RESET}")
        print(f"Total Checks Executed: {total}")
        print(f"{GREEN}Passed: {passed}{RESET}")
        print(f"{RED}Failed: {failed}{RESET}")
        print(f"{YELLOW}======================================================================{RESET}\n")

        if failed > 0:
            print(f"{RED}CRITICAL/HIGH DEFECTS DISCOVERED ({len(self.findings)}):{RESET}")
            for f in self.findings:
                print(f" - [{f['severity']}] [{f['suite']}] {f['name']}: {f['details']}")

        return {
            "total": total,
            "passed": passed,
            "failed": failed,
            "findings": self.findings,
            "results": self.results
        }

if __name__ == "__main__":
    audit = RedTeamAudit("ogura_test")
    res = audit.run_all()
    if res["failed"] > 0:
        sys.exit(1)
    sys.exit(0)
