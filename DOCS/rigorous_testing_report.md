# OGURA — Rigorous Testing & Remediation Report

**Audit & Remediation Date:** September 16, 2026  
**Auditor & Engineering Roles:** Senior Backend Engineer + Security Engineer + QA Lead + Release Engineer  
**System Evaluated:** OGURA Semi-Production MVP Deployment Candidate  
**Target Environments Tested:** `ogura_test`, `ogura_clean_test`, `ogura_dev`, Local Server (`http://localhost:3003`)  
**Pristine Baseline Confirmed:** `ogura_dev` (0 orders, 0 sub-orders, 0 quotes, 0 returns, 0 ledger entries, 21 baseline catalog products)  
**Release Status:** `READY FOR MANUAL FOUNDER DEPLOYMENT`  
**Deployment Gate:** `OPEN (READY FOR MANUAL FOUNDER DEPLOYMENT)`  

---

## 1. Executive Summary

Following the initial red-team audit of the OGURA Semi-Production MVP, three authoritative defects were identified (2 HIGH severity and 1 MEDIUM severity privacy/security defect), placing the system into a `BLOCKED` state.

In accordance with the mandatory protocol:
$$\text{FIX} \longrightarrow \text{TARGETED TEST} \longrightarrow \text{FULL REGRESSION} \longrightarrow \text{CLEAN REPLAY} \longrightarrow \text{BUILD \& SCAN} \longrightarrow \text{DEPLOYMENT GATE}$$

All three defects have been remediated using a non-destructive forward migration (`20260916000001_ogura_rigorous_redteam_corrections.sql`). All historical migrations (P1–P10) remain strictly locked and unmodified.

Every defect was subjected to rigorous targeted testing (23/23 tests passing), followed by the complete execution of all baseline SQL test suites (P2–P10), multi-role Python business flows, adversarial security tests, inventory concurrency saturation, HTTP smoke tests, a 44-check red-team re-audit, clean database migration replay, a 13-point mathematical data corruption audit, a 50/50 route crawl, and end-to-end browser verification.

The system is fully certified with **0 Critical, 0 High, and 0 Medium defects**, and is approved for **Manual Founder Deployment**.

---

## 2. Authoritative Defect Remediation & Root Causes

### DEFECT-01 (HIGH) — Caller-Dependent Cart Clearing in Payment Confirmation
- **Affected Routine:** `public.confirm_order_payment(p_order_id, p_gateway_payment_id, p_gateway_signature, p_method)`
- **Root Cause:**  
  `confirm_order_payment()` previously invoked `PERFORM public.clear_customer_cart();`. That helper routine relies on `auth.uid()` from the calling JWT context. When executed by an automated background payment webhook or service-role caller where `auth.uid()` is `NULL`, the function crashed with SQLSTATE `42501` (`access_denied: user must be authenticated`). Furthermore, if an administrator confirmed an order on behalf of a customer, `clear_customer_cart()` operated on the administrator's `auth.uid()`, clearing the administrator's cart while leaving the buyer's cart untouched.
- **Exact Correction Applied:**  
  In forward migration `20260916000001_ogura_rigorous_redteam_corrections.sql` (Section 1), the routine was rewritten to execute an explicit, targeted deletion against `public.cart_lines` scoped specifically to the buyer who owns the order (`v_order.user_id`):
  ```sql
  -- Authoritative cart clearing targeted directly to order owner (safe for service-role/admin)
  DELETE FROM public.cart_lines
  WHERE cart_id IN (
      SELECT id FROM public.carts WHERE user_id = v_order.user_id
  );
  ```
  This completely removes reliance on the caller's JWT context while guaranteeing transactionality, idempotency, and strict cart isolation.

### DEFECT-02 (HIGH) — Sub-Order Status Regression & Mutability
- **Affected Table & Trigger:** `public.seller_sub_orders` / `enforce_sub_order_immutability()`
- **Root Cause:**  
  The existing immutability trigger protected financial fields (totals, commission amounts) and prevented row deletion, but omitted transition validation on the `status` column. Consequently, an authenticated seller could issue a direct SQL statement:
  ```sql
  UPDATE public.seller_sub_orders SET status = 'packed' WHERE id = <dispatched_sub_order_id>;
  ```
  allowing dispatched sub-orders to regress back to packed, accepted, or in_crafting, and allowing terminal delivered states to be altered.
- **Exact Correction Applied:**  
  In forward migration `20260916000001_ogura_rigorous_redteam_corrections.sql` (Section 2), `enforce_sub_order_immutability()` was enhanced with state-machine transition guardrails:
  1. Terminal states `delivered` and `cancelled` strictly reject any mutation (`invalid_sub_order_transition: sub-order status % is terminal`).
  2. Dispatched sub-orders strictly reject regressions to `accepted`, `in_crafting`, `packed`, or `pending_acceptance`.
  3. Pre-dispatch sub-orders strictly reject backward transitions.
  4. Direct jumps from `packed` directly to `delivered` are prohibited (dispatch with AWB is mandatory).
  5. Only legitimate carrier webhook updates (`public.update_shipment_status()`) or authorized admin operations are permitted to advance a dispatched order to delivered.

### DEFECT-03 (MEDIUM) — Public Seller Confidential Data Leak
- **Affected Table & Policy:** `public.sellers` / `p_sellers_read`
- **Root Cause:**  
  The RLS policy `p_sellers_read` included the clause `OR (status = 'active')`. Because the base table `public.sellers` contains sensitive columns (`gstin`, `pan`, `commission_rate_bps`, `razorpay_account_id`), anonymous unauthenticated users (`anon` role) could query active sellers and view confidential tax identifiers and commercial commission terms.
- **Exact Correction Applied:**  
  In forward migration `20260916000001_ogura_rigorous_redteam_corrections.sql` (Section 3):
  1. Dropped the leaking policy `p_sellers_read` on `public.sellers`.
  2. Recreated `p_sellers_read` with strict tenant and least-privilege scoping: access to the base table is restricted to the owning seller (`user_id = auth.uid()`) and authorized administrative roles (`admin_super`, `admin_catalog`, `admin_finance`, `admin_support`, `admin_viewer`). Anonymous and standard customer roles are denied access (0 rows returned).
  3. Re-established the safe public projection view `public_sellers` (`id, business_name, seller_slug`) with `SECURITY DEFINER` view semantics, and explicitly granted `SELECT` to `anon` and `authenticated`. Public marketplace and storefront queries safely resolve brand and seller information without exposing confidential data.

---

## 3. Files and Migrations Changed

| File / Migration Path | Nature of Change | Purpose / Rationale |
|---|---|---|
| `supabase/migrations/20260916000001_ogura_rigorous_redteam_corrections.sql` | **NEW** (Forward Migration) | Implements atomic fixes for DEFECT-01, DEFECT-02, and DEFECT-03. Fully repeatable and idempotent. |
| `scripts/test_defect_corrections.py` | **NEW** (Targeted Test Suite) | Comprehensive 23-check test suite verifying DEFECT-01 (A–F), DEFECT-02 (A–I), and DEFECT-03 (A–H). |
| `scripts/red_team_audit.py` | **MODIFIED** | Expanded to 44 checks, including direct tests for anonymous base table seller leak denial and public view access. |
| `scripts/clean_dev_db.py` | **NEW** | Enforces clean database reset for `ogura_dev` without disabling triggers or violating constraints. |
| `scripts/supabase_dev_server.py` | **MODIFIED** | Corrected `/auth/v1/verify` fallback query to handle user verification without crashing on absent schema columns. |
| `scripts/test_p11_http_smoke.py` | **MODIFIED** | Updated return verification flow to dynamically deliver the smoke-created sub-order and enforce clean teardown. |
| `supabase/tests/p2_security_matrix_test.sql` | **MODIFIED** | Added topological cleanup of dependent child tables (`product_reviews`, `products`, `brands`) before deleting sellers. |
| `supabase/tests/run_security_tests.sql` | **MODIFIED** | Adjusted Test 7 fixture setup to insert seller as active before setting product to live, adhering to the P3 gate. |

---

## 4. Targeted Test Results (`scripts/test_defect_corrections.py`)

All 23 targeted tests executed and passed on `ogura_test`:

```
============================================================
TESTING DEFECT-01: PAYMENT CONFIRMATION CALLER SAFETY
============================================================
[PASS] DEFECT-01.A: Customer Payment Confirmation: Customer cart cleared after customer confirmed payment
[PASS] DEFECT-01.B: Service/Background Payment Confirmation: Background caller confirmed payment without 42501; buyer cart cleared
[PASS] DEFECT-01.C: Administrator Payment Confirmation: Admin confirmed buyer order; buyer cart cleared; admin cart preserved untouched
[PASS] DEFECT-01.D: Cross-Customer Cart Isolation: Customer B's cart preserved completely unchanged during Customer A confirmation
[PASS] DEFECT-01.E: Idempotency: Idempotent re-confirmation returned cached state without duplicates (sub_orders=1, stock=96)
[PASS] DEFECT-01.F: Failure Atomicity: Transaction rolled back cleanly on downstream failure: order=placed, pay=initiated, stock preserved

============================================================
TESTING DEFECT-02: SUB-ORDER STATUS REGRESSION & IMMUTABILITY
============================================================
[PASS] DEFECT-02.A: Valid Seller Transitions: Lifecycle progression succeeded: pending_acceptance -> accepted -> in_crafting -> packed
[PASS] DEFECT-02.B: Shipping (packed -> dispatched): Sub-order transitioned to dispatched with AWB AWB-6D3BA4F522
[PASS] DEFECT-02.C: Delivery (dispatched -> delivered): Sub-order transitioned to delivered via carrier tracking webhook
[PASS] DEFECT-02.D: Block Invalid Regressions From Dispatched: All regressions from dispatched (-> packed, -> accepted, -> in_crafting) blocked by trigger
[PASS] DEFECT-02.E: Terminal Delivered State Immutability: All modifications away from terminal delivered status blocked by trigger
[PASS] DEFECT-02.F: Legitimate Carrier Webhook Delivery: Sub-order transitioned cleanly from dispatched -> delivered via carrier webhook
[PASS] DEFECT-02.G: Block Direct packed -> delivered Jump: Direct mutation from packed -> delivered blocked; dispatch is strictly required
[PASS] DEFECT-02.H: Parent Order Status Consistency: Parent order status consistent: status=fulfilled, fulfilled_at=2026-09-16 15:09:14.396290+05:30
[PASS] DEFECT-02.I: Database-Level Trigger Boundary: All invalid transitions were rejected directly by PostgreSQL trigger 'trg_enforce_sub_order_immutability'

============================================================
TESTING DEFECT-03: SELLER PRIVATE DATA LEAK PROTECTION
============================================================
[PASS] DEFECT-03.A: Anonymous Base Table Access Denied: Anonymous SELECT on public.sellers returned 0 rows (RLS policy denied access)
[PASS] DEFECT-03.B: Public Projection View: public_sellers view returned 39 active sellers with safe columns: ['id', 'business_name', 'seller_slug']
[PASS] DEFECT-03.C: Unauthorized Customer Access Denied: Customer caller denied access to public.sellers base table (0 rows returned)
[PASS] DEFECT-03.D: Seller Owner Access Preserved: Seller owner successfully retrieved their own profile (Atelier A)
[PASS] DEFECT-03.E: Administrator Access Preserved: Admin retrieved all seller rows (count=40)
[PASS] DEFECT-03.F: Commission Rate Privacy: commission_rate_bps is completely protected from public/anonymous access
[PASS] DEFECT-03.G: KYC Data Isolation: seller_kyc_documents is completely inaccessible to anonymous callers
[PASS] DEFECT-03.H: Bank Account Privacy: seller_bank_accounts is completely inaccessible to anonymous callers

Total: Passed=23, Failed=0 (100% SUCCESS)
```

---

## 5. Full Regression Test Matrix

Following the defect fixes, every historical test suite and operational scenario was executed:

| Suite / Test Name | Test Type | Checks | Result | Highlights |
|---|---|---|---|---|
| `p2_security_matrix_test.sql` | SQL Invariants | 8 | **PASS** | Customer isolation, anonymous denial, admin escalation resistance. |
| `p3_catalog_visibility_test.sql` | SQL Invariants | 14 | **PASS** | Universal visibility gate (live status, active seller, inventory/MTO). |
| `p4_seller_onboarding_kyc_test.sql` | SQL Invariants | 8 | **PASS** | Seller application lifecycle and document verification gates. |
| `p5_customer_cart_wishlist_addresses_test.sql` | SQL Invariants | 12 | **PASS** | Cart lines, RPC isolation, multi-item pricing. |
| `p5_defect2_stock_quantity_test.sql` | SQL Invariants | 10 | **PASS** | Variant stock visibility and stock validation. |
| `p6_inventory_reservation_test.sql` | SQL Invariants | 19 | **PASS** | Multi-buyer reservation, expiry rollback, oversell prevention. |
| `p7_checkout_quote_test.sql` | SQL Invariants | 20 | **PASS** | Quote generation, snapshotting, address immutability. |
| `p8_order_payment_test.sql` | SQL Invariants | 26 | **PASS** | Order state machine, sub-order fan-out, payment capture. |
| `p9_fulfillment_test.sql` | SQL Invariants | 27 | **PASS** | AWB assignment, carrier webhook boundary, terminal delivery. |
| `p10_returns_refunds_ledger_test.sql` | SQL Invariants | 55 | **PASS** | 36 return/refund tests + 19 adversarial financial attacks defeated. |
| `test_mvp_business_flows.py` | Python Multi-Role | 12 | **PASS** | 12 end-to-end user journeys (Admin, Seller, Customer, Support, Finance). |
| `test_adversarial_security.py` | Python Security | 12 | **PASS** | 12 adversarial injection & IDOR attacks safely blocked. |
| `test_inventory_saturation.py` | Python Concurrency | 10 | **PASS** | Zero available stock invariant confirmed; partial cancellation restored stock. |
| `test_p11_http_smoke.py` | HTTP Integration | 17 | **PASS** | Real HTTP smoke tests over PostgREST/Auth bridge (`http://localhost:54321`). |
| `red_team_audit.py` | Red-Team Re-Audit | 44 | **PASS** | Comprehensive multi-suite audit covering all 12 operational domains. |
| `crawl_routes.py` | Route Health | 50 | **PASS** | 50/50 registered TanStack Start routes returning HTTP 200. |

---

## 6. Clean Database Validation (`ogura_clean_test`)

A fresh PostgreSQL database `ogura_clean_test` was reset from scratch (`DROP SCHEMA public CASCADE; CREATE SCHEMA public;`) and replayed sequentially through all 12 migrations:
1. `20260914000001_ogura_p1_foundations.sql`
2. `20260914000002_ogura_p2_security.sql`
3. `20260914000003_ogura_p3_catalog.sql`
4. `20260914000004_ogura_p4_seller.sql`
5. `20260914000005_ogura_p5_customer.sql`
6. `20260914000006_ogura_p6_inventory.sql`
7. `20260914000007_ogura_p7_checkout.sql`
8. `20260914000008_ogura_p8_order_payment.sql`
9. `20260914000009_ogura_p9_fulfillment.sql`
10. `20260914000010_ogura_p10_returns_refunds_ledger.sql`
11. `20260915000001_ogura_p12a_hardening.sql`
12. `20260916000001_ogura_rigorous_redteam_corrections.sql`

**Results:**
- All 12 migrations applied cleanly without errors or warnings.
- All 41 public tables, 40+ functions, 30+ RLS policies, 22 triggers, and views were verified intact.
- Baseline test suites executed cleanly on `ogura_clean_test`.

---

## 7. Mathematical Data Corruption Audit

A 13-point corruption audit script was executed across `ogura_test`, `ogura_clean_test`, and `ogura_dev`:

| Mathematical / Relational Integrity Invariant | `ogura_test` | `ogura_clean_test` | `ogura_dev` | Status |
|---|---|---|---|---|
| Negative available inventory (`quantity_on_hand - quantity_reserved < 0`) | 0 | 0 | 0 | **PASS** |
| Reserved stock exceeding physical on hand (`quantity_reserved > quantity_on_hand`) | 0 | 0 | 0 | **PASS** |
| Negative physical stock (`quantity_on_hand < 0`) | 0 | 0 | 0 | **PASS** |
| Orphan sub-orders without valid parent order | 0 | 0 | 0 | **PASS** |
| Orphan order items without valid sub-order | 0 | 0 | 0 | **PASS** |
| Orphan inventory reservations without valid checkout quote | 0 | 0 | 0 | **PASS** |
| Duplicate captured payment transactions per order | 0 | 0 | 0 | **PASS** |
| Duplicate sub-orders per `(order_id, seller_id)` | 0 | 0 | 0 | **PASS** |
| Duplicate completed refunds for the same return request | 0 | 0 | 0 | **PASS** |
| Duplicate financial ledger entry primary keys | 0 | 0 | 0 | **PASS** |
| Unbalanced double-entry ledger groups (`SUM(debit) != SUM(credit)`) | 0 | 0 | 0 | **PASS** |
| Return quantity exceeding purchased order item quantity | 0 | 0 | 0 | **PASS** |
| Payout statement settled for seller failing KYC/bank verification | 0 | 0 | 0 | **PASS** |

**Verdict:** **ZERO CORRUPTION DETECTED (100% INTACT across all environments).**

---

## 8. Development Database (`ogura_dev`) Status

`ogura_dev` was verified to ensure zero contamination from test fixtures:
- `orders`: **0**
- `seller_sub_orders`: **0**
- `order_items`: **0**
- `payment_transactions`: **0**
- `checkout_quotes`: **0**
- `inventory_reservations`: **0**
- `return_requests`: **0**
- `refund_transactions`: **0**
- `financial_ledger_entries`: **0**
- `categories`: **5** (Intact baseline)
- `subcategories`: **17** (Intact baseline)
- `products`: **21** (Intact baseline)
- `product_variants`: **19** (Intact baseline)
- `sellers`: **21** (Intact baseline)

---

## 9. Production Build & Bundle Secret Scan

### TypeScript & Build Execution
- `npx tsc --noEmit`: Exited with code `0` (0 type errors).
- `npm run build`: Nitro / TanStack Start server and client bundles built cleanly into `.output/`.

### Bundle Secret Scan
The output directories `.output/public` and `.output/server` were scanned for leaked endpoints, database names, and credentials:
- `ogura_dev`: **NONE**
- `ogura_test`: **NONE**
- `service_role`: **NONE**
- `rzp_live`: **NONE**
- `rzp_test`: **NONE**
- `54321`: **NONE**
- `5432`: **NONE**
- `localhost` / `127.0.0.1`: Zero leaked API URLs; only standard internal framework fallbacks present in node bundle.

---

## 10. Real Browser Verification

The application running on `http://localhost:3003` was verified via headless browser automation:
- **Homepage (`/`):** Luxury header, announcement bar, curated editorial rails, product cards, footer. 0 console errors.
- **Shop Catalog (`/shop`):** 311 catalog styles loaded with filter facets, sorting, and INR currency formatting. 0 console errors.
- **Product Detail Page (`/product/...`):** Media carousel, color/size selection, "Add to Bag" interaction smoothly opens slide-out cart drawer. 0 console errors.
- **Cart & Checkout (`/cart`, `/checkout`):** Subtotal calculations, free shipping progress bar, shipping address collection form, payment method selector. 0 console errors.
- **Seller Portal (`/seller`):** Dashboard overview, product management table, sub-orders table, manual AWB entry modal. 0 console errors.
- **Admin Console (`/admin`):** Catalog approval queues, seller onboarding verification, order overview. 0 console errors.
- **Recording Artifact:** `ogura_post_fix_verify_1789551643838.webp`

---

## 11. Remaining Deferred Providers & Cloud Limitations

Per product specifications, the following live third-party integrations remain intentionally deferred:
1. **Live Payment Gateway:** Razorpay API keys are stubbed in local emulation; live payments require production credentials configured in Cloud environment variables.
2. **Live Logistics & Couriers:** Bluedart, Delhivery, and Shiprocket live carrier APIs are stubbed; tracking updates operate via the authenticated carrier webhook endpoint.
3. **Live Identity / KYC Verification:** Third-party document verification APIs remain simulated; manual administrator review is operational.
4. **Live SMS / WhatsApp Gateway:** OTP generation is handled through the internal authentication provider; live SMS delivery requires third-party provider credentials.

---

## 12. Final Release Checklist

- [x] **DEFECT-01 fixed:** Targeted order-owner cart deletion implemented.
- [x] **DEFECT-01 targeted regression PASS:** Customer, service-role, and admin payment confirmation verified (6/6 tests pass).
- [x] **DEFECT-02 fixed:** Authoritative sub-order state-machine guardrails enforced in PostgreSQL trigger.
- [x] **DEFECT-02 targeted regression PASS:** Regressions blocked, terminal immutability verified, carrier webhook delivery intact (9/9 tests pass).
- [x] **DEFECT-03 fixed:** Confidential columns removed from anonymous base table access; public view projection secured.
- [x] **DEFECT-03 targeted regression PASS:** Anonymous access denied, customer access denied, public view safe, admin/seller access preserved (8/8 tests pass).
- [x] **P2–P10 regression PASS:** All SQL assertion suites pass 100%.
- [x] **P11 HTTP smoke PASS:** 17 / 17 checks pass over HTTP bridge.
- [x] **P12A regression PASS:** Security hardening and database isolation confirmed.
- [x] **Full red-team PASS:** 44 / 44 checks pass on `ogura_test`.
- [x] **Clean migration replay PASS:** 12 / 12 migrations replayed from scratch on `ogura_clean_test`.
- [x] **Database integrity PASS:** 13 mathematical integrity invariants verified across all databases.
- [x] **No dev DB contamination:** `ogura_dev` verified with 0 orders, 0 sub-orders, 0 quotes, 21 baseline catalog products.
- [x] **TypeScript PASS:** `npx tsc --noEmit` exited with 0 errors.
- [x] **Build PASS:** `npm run build` completed successfully.
- [x] **Production bundle scan PASS:** Zero secrets, database names, or dev endpoints in `.output/`.
- [x] **50/50 routes PASS:** Route crawler confirms 50 / 50 HTTP 200.
- [x] **Browser MVP PASS:** Key customer, seller, and admin surfaces verified in real browser session.
- [x] **No critical/high/medium blocking defects:** All identified defects remediated and retested.
- [x] **No live credentials connected:** Zero live third-party keys connected.
- [x] **No live providers connected:** Deferred providers remain cleanly stubbed.

---

## 13. Deployment Boundary & Final Verdict

```
======================================================================
FINAL AUDIT & REMEDIATION VERDICT: CERTIFIED
RELEASE STATUS: READY FOR MANUAL FOUNDER DEPLOYMENT
DEPLOYMENT GATE: OPEN (READY FOR MANUAL FOUNDER DEPLOYMENT)
======================================================================
```

**Notice on Deployment Boundary:**  
In strict compliance with Absolute Rule 0.1 and Section 21 of the Operational Directive:
- **Antigravity MUST NOT deploy.**
- Execution stops at `READY FOR MANUAL FOUNDER DEPLOYMENT`.
- The system is clean, fully verified, and awaiting manual deployment to Lovable by the Founder.
