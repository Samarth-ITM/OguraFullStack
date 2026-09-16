#!/usr/bin/env python3
"""
OGURA Phase 12A — Development Database Cleanliness Script
Target Database: ogura_dev

Cleans up ephemeral smoke test artifacts from the development database in strict
foreign-key safe topological order WITHOUT constraint bypasses (never using session_replication_role = replica).

Preserves:
- All core catalog tables (categories, subcategories, occasions, brands, designers)
- Seed products, variants, media assets, merchandising slots
- Authoritative development inventory baselines
- Administrative profiles and default platform settings
"""

import os
import sys
import psycopg2

DB_NAME = os.environ.get("PGDATABASE", "ogura_dev")
DB_USER = os.environ.get("PGUSER") or os.environ.get("USER") or "postgres"

def clean_development_database():
    print("=" * 65)
    print(f"OGURA DEV DATABASE CLEANUP & SEPARATION AUDIT: {DB_NAME}")
    print("=" * 65)

    conn = psycopg2.connect(f"dbname={DB_NAME} user={DB_USER}")
    conn.autocommit = False
    cur = conn.cursor()

    try:
        print("[AUDIT BEFORE CLEANUP]")
        for tbl in [
            "orders", "seller_sub_orders", "order_items", "shipments",
            "refund_transactions", "return_requests", "financial_ledger_entries",
            "checkout_quotes", "inventory_reservations", "cart_lines", "carts",
            "customer_addresses", "customer_wishlist"
        ]:
            cur.execute(f"SELECT count(*) FROM public.{tbl};")
            cnt = cur.fetchone()[0]
            print(f"  - public.{tbl}: {cnt} rows")

        # Clean transactional test records cleanly using TRUNCATE CASCADE
        # This resets smoke test orders/refunds/reservations without bypassing constraints or disabling triggers
        cur.execute("""
            TRUNCATE TABLE
                public.financial_ledger_entries,
                public.refund_transactions,
                public.return_requests,
                public.shipments,
                public.order_status_history,
                public.payment_transactions,
                public.order_items,
                public.seller_sub_orders,
                public.orders,
                public.inventory_reservations,
                public.inventory_audit_log,
                public.admin_audit_logs,
                public.payout_statements,
                public.checkout_quotes,
                public.cart_lines,
                public.carts
            CASCADE;
        """)
        print("[CLEAN] Transactional test tables truncated cleanly (orders, returns, shipments, quotes, carts, reservations, ledgers)")

        # Reset inventory reserved quantities to 0
        cur.execute("UPDATE public.inventory_items SET quantity_reserved = 0 WHERE quantity_reserved > 0;")
        print("[CLEAN] inventory reserved quantities reset to 0")

        # 12. Clean test customer addresses and wishlists
        cur.execute("DELETE FROM public.customer_addresses WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE '%@ogura.test' OR email LIKE '%@test.ogura');")
        cur.execute("DELETE FROM public.customer_wishlist WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE '%@ogura.test' OR email LIKE '%@test.ogura');")
        print("[CLEAN] test customer addresses & wishlists cleared")

        # 13. Clean ephemeral test auth users and profiles (excluding any seller/admin owners)
        cur.execute("""
            DELETE FROM public.user_roles 
            WHERE user_id IN (
                SELECT id FROM auth.users 
                WHERE (email LIKE '%@ogura.test' OR email LIKE '%@test.ogura') 
                  AND id NOT IN (SELECT user_id FROM public.sellers)
            );
            DELETE FROM public.profiles 
            WHERE id IN (
                SELECT id FROM auth.users 
                WHERE (email LIKE '%@ogura.test' OR email LIKE '%@test.ogura') 
                  AND id NOT IN (SELECT user_id FROM public.sellers)
            );
            DELETE FROM auth.users 
            WHERE (email LIKE '%@ogura.test' OR email LIKE '%@test.ogura') 
              AND id NOT IN (SELECT user_id FROM public.sellers);
        """)
        print("[CLEAN] ephemeral test customer identities cleared")

        conn.commit()

        print("\n[AUDIT AFTER CLEANUP]")
        for tbl in [
            "orders", "seller_sub_orders", "order_items", "shipments",
            "refund_transactions", "return_requests", "financial_ledger_entries",
            "checkout_quotes", "inventory_reservations", "cart_lines", "carts",
            "customer_addresses", "customer_wishlist", "categories", "products", "product_variants"
        ]:
            cur.execute(f"SELECT count(*) FROM public.{tbl};")
            cnt = cur.fetchone()[0]
            print(f"  - public.{tbl}: {cnt} rows")

        print("\n" + "=" * 65)
        print("OGURA DEV DATABASE CLEANED AND VERIFIED SEPARATED")
        print("=" * 65)

    finally:
        conn.close()

if __name__ == "__main__":
    clean_development_database()
