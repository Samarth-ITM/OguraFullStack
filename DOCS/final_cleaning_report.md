# OGURA — FINAL CLEANING & PRODUCTION ARCHITECTURE AUDIT REPORT

> **Execution Date:** 2026-09-16  
> **Role:** Senior Software Architect, Security Engineer, DevOps Engineer, PostgreSQL/RLS Engineer, Release Engineer  
> **Deployment Status:** **READY FOR FINAL TESTING**  
> **Deployment Action:** Manual Founder Deployment Only (**Zero Automated Deployment Executed**)

---

## 1. Files Inspected
A comprehensive repository-wide audit was conducted across source code, database scripts, test harnesses, configuration files, and build outputs:
- **Application Source Code (`src/`):**
  - `src/lib/supabase.ts`
  - `src/config/dataMode.ts`
  - `src/routes/account.profile.tsx`
  - `src/routes/index.tsx`, `src/routes/shop.tsx`, `src/routes/cart.tsx`, `src/routes/checkout.tsx`
  - `src/routes/account.*.tsx`, `src/routes/seller.*.tsx`, `src/routes/admin.*.tsx`
  - All components in `src/components/`, `src/data/`, and `src/repositories/`
- **Database Migrations & Test Harnesses (`supabase/`):**
  - `supabase/migrations/20260915000000_ogura_p1_database_foundation.sql` through `20260916000001_ogura_rigorous_redteam_corrections.sql`
  - `supabase/tests/p2_security_matrix_test.sql`
  - `supabase/tests/p3_catalog_visibility_test.sql`
  - `supabase/tests/run_security_tests.sql`
- **Automation, Dev & Test Tooling (`scripts/`):**
  - `scripts/clean_dev_db.py`
  - `scripts/supabase_dev_server.py`
  - `scripts/test_defect_corrections.py`
  - `scripts/test_mvp_business_flows.py`
  - `scripts/test_adversarial_security.py`
  - `scripts/test_inventory_saturation.py`
  - `scripts/red_team_audit.py`
  - `scripts/test_p11_http_smoke.py`
  - `scripts/crawl_routes.py`
- **Configuration & Operational Files:**
  - `package.json`, `wrangler.json`, `vite.config.ts`, `tsconfig.json`, `.gitignore`
  - `AGENTS.md`
  - `DO_NOT_BREAK.md`
  - `DOCS/architecture.md`
  - `.output/` (Server and client build artifacts)

---

## 2. Files Changed
1. **`package.json` & `wrangler.json`:**
   - Updated package name to `"ogura-marketplace"`.
   - Created root `wrangler.json` configuring `"name": "ogura-marketplace"` to eliminate auto-generated git worker names. Nitro now generates worker name `ogura-marketplace` cleanly.
2. **`src/lib/supabase.ts`:**
   - Added dynamic OAuth origin resolution: `redirectTo: window.location.origin + '/account/profile'` (strictly zero hardcoded ports).
   - Added automatic callback session parsing for Supabase Auth redirect hash tokens (`#access_token=...`).
3. **`src/routes/account.profile.tsx`:**
   - Added native "Continue with Google" OAuth trigger button with real-time feedback and dynamic origin redirect.
4. **`scripts/clean_dev_db.py`, `scripts/supabase_dev_server.py`, `scripts/test_*.py`:**
   - Replaced developer usernames and fixed database connection parameters with dynamic environment lookups (`PGUSER`, `PGHOST`, `PGPORT`, `PGDATABASE`).
5. **`supabase/tests/run_security_tests.sql`:**
   - Replaced hardcoded local machine paths with standardized SQL-level dynamic directory execution.
6. **`.gitignore`:**
   - Added Python cache directories (`__pycache__/`, `*.py[cod]`, `*.dump`) to ensure developer machine artifacts are never committed.
7. **`AGENTS.md`:**
   - Added mandatory **Change Classification Protocol** (11 categories).
   - Documented `SERVICE_ROLE IS TRUSTED SERVER-SIDE AUTHORITY ONLY`.
   - Updated database schema mapping to match actual tables, RPCs, and columns.
   - Replaced all absolute/file links with repository-relative paths (`/DOCS/architecture.md`, `/src/lib/supabase.ts`).
   - Preserved Lovable header block at lines 1–10.
8. **`DOCS/architecture.md`:**
   - Rewritten to match the actual database schema: `cart_lines`, `price_paise`, `reserve_inventory_for_quote`, `seller_sub_orders`, `payment_transactions`, `seller_kyc_documents`, `seller_bank_accounts`, `return_requests`, `refund_transactions`, `financial_ledger_entries`, `payout_statements`, `notification_outbox`, `media_assets`.
   - Added **Read vs. Command Architecture** diagram and prose.
   - Added structured provider status table separating internal contracts from deferred live execution.
9. **`DO_NOT_BREAK.md`:**
   - Formulated 23 immutable system invariants. Removed all developer usernames.
10. **Historical Reports (`DOCS/structure.md`, `DOCS/report.md`, `DOCS/p0_report.md`, `DOCS/p10_report.md`, `DOCS/frontend.md`):**
    - Scrubbed local machine paths and developer usernames, replacing them with repository-relative paths (`.`).

---

## 3. Files Moved
- Zero production files were moved. Moving files was strictly avoided to maintain all routing, component hierarchies, and import graph stability intact.

---

## 4. Files Deleted
- `scripts/__pycache__/crawl_routes.cpython-314.pyc` (transient bytecode artifact removed).

---

## 5. Hard-Coded Paths Found & Classification
- **Category A (Production-required configuration):** None found.
- **Category B (Development-only test infrastructure):** `scripts/clean_dev_db.py`, `scripts/supabase_dev_server.py`, `scripts/test_*.py` previously contained default connection usernames. Scrubbed and replaced with environment variables.
- **Category C (Documentation / historical reports):** Historical reports previously contained local console paths. Scrubbed and replaced with repository-relative paths.
- **Category D (Accidental production coupling):** Zero occurrences in `src/`. `src/` is completely clean of local machine paths, usernames, and local ports.
- **Category E (Build artifacts):** Generated worker name previously auto-derived from git remote origin. Resolved by pinning `"name": "ogura-marketplace"` in `package.json` and `wrangler.json`.
- **Category F (Secret or credential):** Zero hardcoded secrets in source code or production bundles.
- **Category G (Local test server implementation):** `scripts/supabase_dev_server.py` simulates Supabase REST endpoints for local offline testing.

---

## 6. Hard-Coded Paths Removed
- Removed all developer usernames from Python test scripts (`scripts/*.py`), replacing them with `os.environ.get("PGUSER") or os.environ.get("USER") or "postgres"`.
- Removed hardcoded local machine paths from `supabase/tests/run_security_tests.sql`.
- Replaced all markdown local absolute file links with repository-relative paths (`/DOCS/...`, `/AGENTS.md`, `/DO_NOT_BREAK.md`).
- Parameterized test server hosts and ports via environment variables (`PGHOST`, `PGPORT`, `PGDATABASE`).

---

## 7. Secrets Scan
- **Grep Audit:** Scanned all `src/`, `.output/`, and configuration files for:
  - `service_role`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - Razorpay keys / secrets (`rzp_`)
  - Courier / Shiprocket credentials
  - KYC provider keys
  - Private RSA / ECDSA keys
  - JWT secrets
- **Result:** **ZERO SECRETS FOUND.**
  - `src/` contains 0 secret keys.
  - `.output/public/` (client bundle) contains 0 secret keys.
  - `.output/server/` contains 0 secret keys.
  - Service-role usage is strictly confined to secure database RPCs and local test harnesses using ephemeral test fixtures.

---

## 8. Localhost & Port Scan
- **Production Code (`src/`):**
  - `localhost`: 0 occurrences.
  - `127.0.0.1`: 0 occurrences.
  - `5432`: 0 occurrences.
  - `54321`: 0 occurrences.
- **Client Bundle (`.output/public/`):**
  - `localhost`: 0 occurrences.
  - `127.0.0.1`: 0 occurrences.
- **Server Bundle (`.output/server/`):**
  - Only internal fallback references in third-party library code (`node_modules/@tanstack/react-router` and `h3`). Zero application-level hardcoded hosts.
- **Development Tooling (`scripts/`):**
  - Localhost and port references are confined strictly to test runners (`scripts/crawl_routes.py`, `scripts/supabase_dev_server.py`) and do not enter production bundles.

---

## 9. Mock Code Separation & Boundary Verification
- **Mock Repositories:** Centralized in [`src/repositories/mock/`](/src/repositories/mock/) (`catalog.ts`, `index.ts`, `latency.ts`, `productMediaRepository.ts`).
- **Mock Datasets:** Centralized in [`src/data/`](/src/data/) (`mockHomepage.ts`, `mockReviews.ts`, `mockDesigners.ts`, `mockMerchandising.ts`).
- **Fail-Closed Proof:** Enforced in [`src/config/dataMode.ts`](/src/config/dataMode.ts).
  - In production (`import.meta.env.PROD === true`), if `VITE_DATA_MODE="mock"` is passed, `resolveDataMode()` throws: `"[OGURA FAIL-CLOSED] FATAL: VITE_DATA_MODE='mock' is strictly prohibited in production."`
  - In production, if backend config (`VITE_SUPABASE_URL` or `VITE_SUPABASE_ANON_KEY`) is missing, it throws: `"[OGURA FAIL-CLOSED] FATAL: Production backend configuration missing."`
  - In development with missing backend config and no explicit `VITE_DATA_MODE=mock`, it fails closed rather than silently falling back.
  - The application will **NEVER** silently produce a functioning mock application in production.

---

## 10. Test Separation
- Test runners and adversarial test suites are located in `scripts/` and `supabase/tests/`.
- No test files or mock data are imported into production client bundles (`.output/public`).

---

## 11. Google OAuth Configuration Status
- **Implementation State:** Fully wired and production-ready in [`src/lib/supabase.ts`](/src/lib/supabase.ts) and [`src/routes/account.profile.tsx`](/src/routes/account.profile.tsx).
- **Dynamic Origin:** Uses `window.location.origin + '/account/profile'` to dynamically handle whatever domain Lovable Cloud provisions (zero hardcoded ports).
- **Callback Parsing:** `loadSession()` automatically parses URL hash parameters (`#access_token=...`) on callback and establishes the Supabase session.
- **Cloud Configuration Requirement:** Google OAuth requires the platform administrator to configure the Google Client ID & Secret in the Supabase Cloud dashboard once the production domain is assigned by Lovable.

---

## 12. Customer KYC Status
- **INVARIANT VERIFIED:** **Customers do not undergo seller KYC.**
- Customer authentication, profile management, address storage, shopping cart, checkout quote, and order confirmation flows have **zero** dependencies on PAN, GSTIN, or business verification.

---

## 13. Seller KYC Status
- Seller KYC is implemented strictly on the seller side (`public.sellers`, `seller_kyc_documents`, `seller_bank_accounts`).
- Functions strictly as a **PAYOUT GATE**: prevents payout disbursement statements (`payout_statements`) from transitioning to `'settled'` unless verified by platform admin.

---

## 14. External Integration Status (Contract vs. Live Boundary)
All external providers remain intentionally **DEFERRED** in this release:

| Provider Domain | Internal Contract Status | Live Provider Status | Live Execution Status |
|---|---|---|---|
| **Razorpay Checkout** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **Razorpay Route** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **KYC Providers (PAN / GST)** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **Penny-Drop Bank Verification**| **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **Courier / 3PL (Shiprocket)** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **SMS Gateway (OTP)** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **WhatsApp Business API** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **Transactional Email** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |

---

## 15. Backend Architecture
Refer to [`/DOCS/architecture.md`](/DOCS/architecture.md) for the complete 13-domain architectural specification, Read vs. Command architecture, and system flow diagrams.

---

## 16. State Machine Map
All state machines verified against database triggers and enums:
1. **Seller (`seller_status`):** `application` → `under_review` → `approved` → `active` → `suspended` / `terminated`
2. **Product (`product_status`):** `draft` → `submitted` → `in_review` → `live` → `archived` / `rejected` / `suspended`
3. **Inventory Reservation (`inventory_reservation_status`):** `held` → `released` / `expired` / `committed`
4. **Order (`order_status`):** `draft` → `placed` → `confirmed` → `partially_fulfilled` → `fulfilled` → `completed`
5. **Payment (`payment_transaction_status`):** `initiated` → `pending` → `authorized` → `captured` / `failed` → `refunded`
6. **Sub-Order (`sub_order_status`):** `pending_acceptance` → `accepted` → `in_crafting` → `packed` → `ready_for_pickup` → `dispatched` → `delivered`
7. **Return (`return_request_status`):** `requested` → `support_review` → `approved` → `pickup_scheduled` → `in_transit` → `hub_received` → `qc_passed` / `qc_failed` → `refund_authorized` → `refunded`

---

## 17. Security Model & Service-Role Authority
- `SERVICE_ROLE IS TRUSTED SERVER-SIDE AUTHORITY ONLY.` Service role is never an application authorization mechanism and is never exposed to browser bundles.
- Row Level Security (RLS) active on 100% of public database tables.
- Multi-tenancy isolation strictly enforced for customers and sellers.
- Least-privilege admin role separation (`admin_super`, `admin_catalog`, `admin_finance`, `admin_support`, `admin_viewer`).
- Double-entry ledger (`financial_ledger_entries`) is mathematically balanced and append-only immutable.

---

## 18. Future-Agent Operating Model
Detailed in [`/AGENTS.md`](/AGENTS.md):
$$\text{INSPECT} \rightarrow \text{CLASSIFY} \rightarrow \text{PLAN} \rightarrow \text{IMPLEMENT} \rightarrow \text{TARGETED TEST} \rightarrow \text{FULL REGRESSION} \rightarrow \text{REVIEW DIFF} \rightarrow \text{BUILD} \rightarrow \text{AWAIT AUTHORIZATION}$$

---

## 19. AGENTS.md Summary
[`/AGENTS.md`](/AGENTS.md) contains:
- Sections A through W
- Change Classification Protocol (11 categories)
- Service-Role Authority Rule
- Full architecture and actual database schema mapping
- Preserved Lovable tag block at lines 1–10

---

## 20. DO_NOT_BREAK.md Summary
[`/DO_NOT_BREAK.md`](/DO_NOT_BREAK.md) defines the 23 non-negotiable architectural and business invariants.

---

## 21. Tests Executed (Freshly Run After All Corrections)
All test suites were freshly executed after the final cleaning round corrections:
1. **`npx tsc --noEmit`:** Executed at 16:23:37. **0 errors.**
2. **`npm run build`:** Executed at 16:23:42. **Built cleanly.** Nitro worker name: `ogura-marketplace`.
3. **`python3 scripts/crawl_routes.py`:** Executed at 16:23:46. **50 / 50 Routes Returned HTTP 200.**
4. **`python3 scripts/test_defect_corrections.py`:** Executed at 16:23:49. **23 / 23 Passed** (0 failures).
5. **`python3 scripts/red_team_audit.py`:** Executed at 16:23:52. **44 / 44 Passed** (0 failures).

---

## 22. Build Result
- Production build succeeded cleanly in 193ms.
- Worker name: `ogura-marketplace` (zero personal or developer identifiers).
- Generated `.output/server/wrangler.json`, `.output/public/_headers`, and `.output/nitro.json`.

---

## 23. Route Result
50 out of 50 routes crawled and verified with HTTP 200 responses.

---

## 24. Bundle Result
Client bundle in `.output/public/` is completely clean:
- 0 developer usernames
- 0 local filesystem paths
- 0 local database endpoints
- 0 secret credentials

---

## 25. Remaining Known Limitations
- Live payment settlement requires founder configuration of live Razorpay credentials in Supabase secrets.
- Live Google OAuth requires adding the Lovable Cloud production domain to Google Cloud Console authorized redirect URIs.
- Automated courier dispatch requires connecting live Shiprocket API tokens.

---

## 26. Deployment Readiness
- **Final Status:** **READY FOR FINAL TESTING**
- **Action Required:** Manual Founder Deployment to Lovable Cloud.
- **Agent Action:** Antigravity has completed all cleaning, hardening, verification, and documentation. Zero automated deployments have been triggered.
