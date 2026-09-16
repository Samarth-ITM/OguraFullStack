#!/usr/bin/env python3
"""
Crawl all registered TanStack Start routes against the local dev server.
"""

import urllib.request
import urllib.error
import sys

BASE_URL = "http://localhost:3003"

# All 50 registered route paths mapped to concrete test URLs
ROUTES = [
    # Core & Discovery (12)
    ("/", "Home"),
    ("/shop", "Shop (Catalog PLP)"),
    ("/new-in", "New In"),
    ("/made-to-order", "Made to Order"),
    ("/launchpad", "Launchpad"),
    ("/search", "Search"),
    ("/occasions", "Occasions Index"),
    ("/occasion/wedding-guest", "Occasion Detail"),
    ("/brands", "Brands Index"),
    ("/brand/aarnaa", "Brand Detail"),
    ("/designers", "Designers Index"),
    ("/designer/aarnaa", "Designer Detail"),

    # Taxonomy & PDP (5)
    ("/women/clothing", "Category PLP"),
    ("/women/clothing/dresses", "Subcategory PLP"),
    ("/product/forest-green-envelope-belt-bag-og-w-bg-000001", "Product Detail Page"),
    ("/collections", "Collections Index"),
    ("/collections/corset-tops", "Collection Detail"),

    # Cart, Checkout & Order Success (3)
    ("/cart", "Shopping Bag"),
    ("/checkout", "Checkout Flow"),
    ("/order/success/OG-20260916-832B5328", "Order Success / Confirmation"),

    # Customer Account Portal (6)
    ("/account", "Account Overview (Layout)"),
    ("/account/", "Account Index"),
    ("/account/profile", "Customer Profile"),
    ("/account/addresses", "Customer Addresses"),
    ("/account/orders", "Order History"),
    ("/account/wishlist", "Account Wishlist"),
    ("/wishlist", "Public Wishlist Page"),

    # Seller Portal (5)
    ("/seller", "Seller Portal (Layout)"),
    ("/seller/", "Seller Index"),
    ("/seller/products", "Seller Products"),
    ("/seller/orders", "Seller Orders"),
    ("/seller/payouts", "Seller Payouts"),

    # Admin Portal (5)
    ("/admin", "Admin Portal (Layout)"),
    ("/admin/", "Admin Index"),
    ("/admin/catalog", "Admin Catalog"),
    ("/admin/orders", "Admin Orders"),
    ("/admin/merchandising", "Admin Merchandising"),

    # Informational, Support & Institutional (13)
    ("/about", "About Us"),
    ("/contact", "Contact Us"),
    ("/shipping", "Shipping & Delivery Policy"),
    ("/returns", "Returns & Exchanges Policy"),
    ("/terms", "Terms of Service"),
    ("/privacy", "Privacy Policy"),
    ("/help", "Help & FAQ"),
    ("/careers", "Careers"),
    ("/stores", "Store Locator"),
    ("/gift-card", "Gift Cards"),
    ("/seller-program", "Seller Program"),
    ("/join-as-designer", "Join as Designer"),
    ("/track-order", "Track Order")
]

def main():
    print(f"CRAWLING {len(ROUTES)} TANSTACK START ROUTES ON {BASE_URL}...\n")
    passed = 0
    failed = 0
    results = []

    for path, label in ROUTES:
        url = f"{BASE_URL}{path}"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Ogura-Route-Crawler/1.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                status = resp.status
                passed += 1
                results.append((path, label, status, "PASS"))
                print(f"[HTTP {status}] PASS: {path:<38} ({label})")
        except urllib.error.HTTPError as e:
            failed += 1
            results.append((path, label, e.code, "FAIL"))
            print(f"[HTTP {e.code}] FAIL: {path:<38} ({label})")
        except Exception as e:
            failed += 1
            results.append((path, label, 0, f"ERR: {str(e)[:30]}"))
            print(f"[ERR]     FAIL: {path:<38} ({label}) - {e}")

    print("\n" + "=" * 60)
    print(f"ROUTE CRAWLER SUMMARY: {passed} / {len(ROUTES)} PASSED (Failed: {failed})")
    print("=" * 60)

    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
