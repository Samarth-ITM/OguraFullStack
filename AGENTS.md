<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

# OGURA — PERMANENT AGENT OPERATING INSTRUCTIONS & RUNBOOK

This document is the **authoritative, permanent operating guide** for any AI coding agent or software engineer working on the OGURA platform. Read this entire document before inspecting, modifying, testing, or building any part of the codebase.

---

## A. Mission
OGURA is a luxury multi-brand multi-seller e-commerce marketplace dedicated to curated high-fashion and artisanal apparel in India. The platform bridges discerning patrons with elite designer brands and independent ateliers, supporting ready-to-ship collections and bespoke Made-to-Order (MTO) garments with uncompromising security, privacy, and architectural rigor.

---

## B. System Architecture Overview

```
                    ┌───────────────────────────────┐
                    │        CUSTOMER / SELLER      │
                    │            BROWSER            │
                    └───────────────┬───────────────┘
                                    │
                                    │ HTTPS
                                    ▼
                    ┌───────────────────────────────┐
                    │       TANSTACK START          │
                    │ React 19 / TypeScript / UI    │
                    │ Routes / Components / State   │
                    └───────────────┬───────────────┘
                                    │
                         Repository / API layer
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
          RLS-SCOPED READS                 SERVER OPERATIONS
          Public/customer data             RPC / Edge Functions
                    │                               │
                    └───────────────┬───────────────┘
                                    ▼
                    ┌───────────────────────────────┐
                    │       LOVABLE CLOUD           │
                    │                               │
                    │ Supabase Auth                 │
                    │ PostgreSQL 16 (Canonical DB)  │
                    │ Row Level Security (RLS)      │
                    │ Stored Procedures (RPCs)      │
                    │ Edge Functions                │
                    │ Storage Buckets               │
                    │ Transactional Outbox Engine   │
                    └───────────────┬───────────────┘
                                    │
                          asynchronous boundary
                                    │
                    ┌───────────────▼───────────────┐
                    │      EXTERNAL PROVIDERS       │
                    │   [STATUS: DEFERRED IN MVP]   │
                    │                               │
                    │ Razorpay / Razorpay Route     │
                    │ Courier / 3PL (Shiprocket)    │
                    │ KYC & Penny-Drop Verification │
                    │ SMS / WhatsApp / Email        │
                    └───────────────────────────────┘
```

For full domain details, table definitions, and database schema flows, refer to [`/DOCS/architecture.md`](/DOCS/architecture.md).

---

## C. Authority Hierarchy
When making architectural, code, or operational decisions, you must adhere strictly to this precedence hierarchy:

1. **Founder Decisions / Locked Master Specifications**
2. **OGURA Master PRD**
3. **OGURA Backend Engineering Flows**
4. **OGURA Production Runbook**
5. **Latest Forensic & Security Remediation Reports**
6. **Current Database Migrations and Verified RPC/Edge Contracts**
7. **Current Frontend Implementation**
8. **Mock Repositories / Data Fixtures**
9. **Engineering Convenience Assumptions**

> [!CAUTION]
> If you detect a contradiction between documents, code, or requirements, **STOP IMMEDIATELY**. Do not silently resolve or guess. File an issue detailing the contradiction, affected files, and requirement references, and await founder clarification.

---

## D. Mandatory Change Classification Protocol

Every future user request must **FIRST** be formally classified into exactly one of the following 11 categories before proposing a plan or touching code:

| Classification | Permitted Scope of Changes | Strict Boundaries & Invariants | Required Verification Suites |
|---|---|---|---|
| **1. UI ONLY** | Presentation components (`src/components/ui/`, specific routes), local view state, styles (`src/index.css`). | **FORBIDDEN:** Modifying database migrations, RPCs, RLS, pricing, cart, checkout, or auth logic. | `npm run build`, route crawler (`scripts/crawl_routes.py`). |
| **2. CONTENT / SEO** | Static copy, meta tags, OpenGraph, JSON-LD structured data, sitemaps. | **FORBIDDEN:** Exposing private customer/seller data or mutating commerce state. | Route crawler, metadata inspection. |
| **3. FRONTEND DATA ACCESS** | Repository contracts (`src/repositories/contracts/`), backend repository implementations (`src/repositories/backend/`). | **FORBIDDEN:** Direct table queries bypassing RLS; client-side price/stock calculations. | `npx tsc --noEmit`, `npm run build`. |
| **4. BACKEND BUSINESS LOGIC** | RPC stored procedures (`supabase/migrations/`), Edge Functions. | All mutations must enforce atomicity, idempotency, and error handling. | Targeted SQL test + regression suites. |
| **5. DATABASE / RLS** | Forward migrations only (`supabase/migrations/`). RLS policies, triggers. | **FORBIDDEN:** Editing applied migration files. Every table MUST have RLS enabled. | `scripts/red_team_audit.py`, `scripts/test_defect_corrections.py`. |
| **6. AUTH** | Supabase Auth client, OAuth redirect handlers, profile sync triggers. | **FORBIDDEN:** Hardcoding local redirect ports; requiring KYC for customers. | Auth matrix tests, session callback tests. |
| **7. FINANCIAL** | Pricing, discounts, checkout quotes, double-entry ledger, payouts. | **FORBIDDEN:** Floating-point currency. All money must be integer paise. Ledger is append-only. | Double-entry balance tests, financial regression. |
| **8. INVENTORY** | Stock reservations, TTL expiry, allocation, MTO lead times. | **FORBIDDEN:** Non-atomic updates. Zero overselling under parallel purchasing threads. | `scripts/test_inventory_saturation.py`. |
| **9. SELLER / KYC** | Seller application, document review, payout gating. | **FORBIDDEN:** Imposing KYC on customer checkout. Seller KYC is payout-side only. | Seller isolation audit, payout gate tests. |
| **10. EXTERNAL INTEGRATION** | Provider adapters, webhook processors, payload serialization. | Must preserve internal contracts. Mark live external execution as deferred. | Webhook signature tests, idempotency tests. |
| **11. INFRASTRUCTURE** | Build configs, deployment configs, CI scripts, environment guards. | **FORBIDDEN:** Introducing machine-specific paths or leaking secrets. | Build check, bundle scan, path scan. |

---

## E. Production Environment
- **Platform Host:** Lovable Cloud / Supabase Cloud.
- **Frontend Framework:** TanStack Start (React 19, Vite, Nitro SSR server).
- **Backend Core:** Supabase PostgreSQL 16 with Row Level Security (RLS) enabled on all tables.
- **Authentication:** Supabase Auth (Native PKCE flow, Google OAuth, Phone OTP).
- **Storage:** Supabase Storage (`catalog`, `avatars`, `seller-documents`).
- **Zero Local Coupling:** Production runtime must **never** depend on developer home directories, local usernames, localhost ports (`5432`, `54321`, `3000`), or local dev databases (`ogura_dev`, `ogura_test`). All cloud configuration is read via standard environment variables (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`).

---

## F. Customer Authentication
- **Guest Access:** Full access to public catalog, PLP, PDP, filters, and guest shopping cart without login.
- **Login Options:**
  - **Google OAuth:** Dynamic redirect URL generated via `window.location.origin` (zero hardcoded ports). Captures URL hash tokens on redirect callback.
  - **Phone OTP:** Supabase Auth SMS OTP integration.
- **Profiles:** Handled in `public.profiles` automatically linked to `auth.users.id`.
- **Customer Privacy:** Customers can only view and mutate their own profile, cart, addresses, wishlists, and parent orders.

---

## G. Customer vs. Seller KYC Boundary (CRITICAL RULE)
> [!IMPORTANT]
> **CUSTOMERS DO NOT UNDERGO SELLER KYC.**
> - Ordinary shoppers NEVER require PAN, GST, business registration, bank account checks, or KYC documents.
> - Customer checkout, account creation, and browsing must NEVER be gated by KYC checks.
> - **Seller KYC is seller-side ONLY** and functions primarily as a **PAYOUT GATE**. It governs when platform disbursements can be made to a seller's bank account, not whether buyers can shop.

---

## H. Database Architecture & Actual Schema
The database encompasses 13 authoritative domains managed exclusively through versioned migrations in `supabase/migrations/`:
1. `Identity & Access`: `profiles`, `user_roles`, `sellers`
2. `Catalog & Taxonomy`: `categories`, `subcategories`, `occasions`, `product_occasions`, `brands`, `designers`, `products`, `product_variants`, `media_assets`
3. `Customer Commerce`: `carts`, `cart_lines`, `customer_wishlist`, `customer_addresses`, `customer_store_credits`
4. `Pricing & Quotes`: `checkout_quotes`
5. `Inventory`: `inventory_items`, `inventory_reservations`, `inventory_audit_log`
6. `Payment Boundary`: `payment_transactions`, `webhook_events`
7. `Orders & Fulfillment`: `orders`, `seller_sub_orders`, `order_items`, `order_status_history`, `shipments`
8. `Returns & Reverse Logistics`: `return_requests`, `refund_transactions`
9. `Financial Ledger`: `financial_ledger_entries`, `payout_statements`
10. `Seller KYC & Bank Details`: `seller_kyc_documents`, `seller_bank_accounts`
11. `Admin & Moderation`: `admin_audit_logs`, `merchandising_slots`, `product_reviews`
12. `Transactional Outbox`: `notification_outbox`, `webhook_events`
13. `Made-To-Order`: `mto_requests`, `products.is_made_to_order`

---

## I. Row Level Security & Service-Role Authority

> [!CAUTION]
> **SERVICE_ROLE IS TRUSTED SERVER-SIDE AUTHORITY ONLY.**
> - `service_role` is **NEVER** a normal application authorization mechanism.
> - Default to: **RLS**, **authenticated RPCs**, and **least privilege**.
> - Use `service_role` only inside explicitly trusted server-side boundaries (Deno Edge Functions, migration scripts, background tasks).
> - **NEVER expose `SUPABASE_SERVICE_ROLE_KEY` to browser or client bundles.**

- **Default State:** `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;` is mandatory on EVERY public table.
- **Tenant Isolation:**
  - Customers: Filtered strictly on `user_id = auth.uid()`.
  - Sellers: Filtered on `seller_id = current_seller_id()`.
  - Admin: Enforced via `has_role(auth.uid(), 'admin_...'::user_role_type)`.
- **Public Reads:** Only approved live catalog items (`status = 'live'` belonging to `active` sellers) are readable by `anon` via views (`public_catalog_products`, `public_sellers`).

---

## J. State Machines

### 1. Seller Status (`seller_status`)
`application` → `under_review` → `approved` → `active` → `suspended` / `terminated`  
*(Managed strictly by Platform Admins).*

### 2. Product Lifecycle (`product_status`)
`draft` → `submitted` → `in_review` → `live` → `archived` / `rejected` / `suspended`  
*(Submission by Seller; Review/Approval by Admin; Delist by Seller).*

### 3. Inventory Reservation (`inventory_reservation_status`)
`held` → `released` / `expired` / `committed`  
*(Held on quote creation; Committed on payment capture; Released on timeout or checkout cancel).*

### 4. Order Lifecycle (`order_status`)
`draft` → `placed` → `confirmed` → `partially_fulfilled` → `fulfilled` → `completed`  
*(Confirmed on payment capture; Derived automatically from child `seller_sub_orders` by database trigger).*

### 5. Payment Lifecycle (`payment_transaction_status`)
`initiated` → `pending` → `authorized` → `captured` / `failed` → `refunded`  
*(Captured via server-side verification; Refunded on return QC completion).*

### 6. Sub-Order Fulfillment (`sub_order_status`)
`pending_acceptance` → `accepted` → `in_crafting` (MTO) → `packed` → `ready_for_pickup` → `dispatched` → `delivered`  
*(Managed by Seller fulfillment actions and 3PL courier webhooks).*

### 7. Return & Reverse Logistics (`return_request_status`)
`requested` → `support_review` → `approved` → `pickup_scheduled` → `in_transit` → `hub_received` → `qc_passed` / `qc_failed` → `refund_authorized` → `refunded`  
*(Requested by Customer; Approved by Admin; Inspected by Warehouse QC; Settled in Ledger).*

---

## K. Financial Authority Invariants
- **All Currency in Integer Paise:** `₹1 = 100 paise`. Never use floating-point numbers for money.
- **Zero Client Trust:** Prices submitted by the browser are discarded. The database recalculates subtotals, taxes, and shipping from live records.
- **Double-Entry Ledger:** `financial_ledger_entries` is strictly append-only. No updates or deletions allowed.
- **Phase Ownership:** Phase 8 owns order/payment workflows. Phase 10 owns the financial ledger and seller payout calculations.

---

## L. Inventory Authority Invariants
- **Available Stock Formula:**  
  $$\text{available\_stock} = \text{quantity\_on\_hand} - \text{quantity\_reserved}$$
- **Concurrency Protection:** All reservations execute under `SELECT ... FOR UPDATE` row-level locks via `reserve_inventory_for_quote`.
- **Zero Overselling:** Requests exceeding available stock are rejected immediately.
- **Made-to-Order Exception:** MTO items (`is_made_to_order = true`) track crafting capacity rather than decrementing stock.

---

## M. External Provider Boundary: Contract vs. Live Status

| Provider Domain | Internal Contract Status | Live Provider Status | Live Execution Status |
|---|---|---|---|
| **Razorpay Checkout** | **IMPLEMENTED / TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **Razorpay Route** | **IMPLEMENTED / TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **KYC Providers (PAN / GST)** | **IMPLEMENTED / TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **Penny-Drop Bank Verification**| **IMPLEMENTED / TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **Courier / 3PL (Shiprocket)** | **IMPLEMENTED / TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **SMS Gateway (OTP)** | **IMPLEMENTED / TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **WhatsApp Business API** | **IMPLEMENTED / TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |
| **Transactional Email** | **IMPLEMENTED / TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** |

Do NOT claim live provider verification until production credentials are provided and tested on Lovable Cloud.

---

## N. Mock Code Architecture & Boundary
- **Mock Repositories:** Located in [`src/repositories/mock/`](/src/repositories/mock/) (`catalog.ts`, `index.ts`, `latency.ts`, `productMediaRepository.ts`).
- **Mock Datasets:** Located in [`src/data/`](/src/data/) (`mockHomepage.ts`, `mockReviews.ts`, `mockDesigners.ts`, `mockMerchandising.ts`).
- **Test Fixtures & Tooling:** Located in [`scripts/`](/scripts/) and [`supabase/tests/`](/supabase/tests/).
- **Fail-Closed Boundary:** Enforced in [`src/config/dataMode.ts`](/src/config/dataMode.ts). In production (`import.meta.env.PROD`), if Supabase configuration is missing or `VITE_DATA_MODE=mock` is attempted, the application throws a fatal error and **FAILS CLOSED**. It will **NEVER** silently fall back to mock data.

---

## O. Testing Architecture & Verification Suites
Before certifying any change, execute the verified testing suites:
1. **Typecheck:** `npx tsc --noEmit`
2. **Production Build:** `npm run build`
3. **Route Crawl:** `python3 scripts/crawl_routes.py` (Verify 50/50 routes return HTTP 200)
4. **Defect Regression Suite:** `python3 scripts/test_defect_corrections.py` (23/23 tests must pass)
5. **Red-Team Security & Integrity Suite:** `python3 scripts/red_team_audit.py` (44/44 tests must pass)
6. **Concurrency Saturation Suite:** `python3 scripts/test_inventory_saturation.py` (Zero oversell under parallel threads)

---

## P. Deployment Architecture
- **Cloud Provider:** Lovable Cloud with Supabase Cloud backend.
- **Manual Founder Gate:** Antigravity and automated agents **MUST NOT** trigger live deployments. Deployment is executed manually by the founder.
- **Deployment Prerequisites:**
  - All automated tests green.
  - Zero TypeScript errors.
  - Clean production build (`.output` / `dist`).
  - Zero hardcoded developer paths or credentials.
  - Database migrations applied in sequence via forward migrations.

---

## Q. Rules for Future Agents

```
INSPECT
  ↓
DEFINE BOUNDARY (CLASSIFY REQUEST)
  ↓
PLAN
  ↓
IMPLEMENT
  ↓
TARGETED TEST
  ↓
FULL RELEVANT REGRESSION
  ↓
REVIEW DIFF
  ↓
BUILD
  ↓
AWAIT FOUNDER AUTHORIZATION
```

1. **Smallest Feasible Change:** Never refactor working systems when addressing a bug or adding a feature.
2. **Reuse Existing Components:** Check `src/components/` before creating new UI elements.
3. **Preserve P1–P12A:** Do not reopen or alter accepted phase architecture without verifiable evidence of a bug.
4. **No Direct Migrations Editing:** Never edit an already-applied migration file. Always write forward migrations.

---

## R. UI Change Rules
When given a UI-only request (e.g., "Add an SEO section to the homepage" or "Add a new collection rail"):
- **ALLOWED:**
  - Editing the specific route component (e.g., `src/routes/index.tsx`).
  - Creating or editing reusable presentation components in `src/components/`.
  - Adding styling or design tokens in `src/index.css`.
  - Adding static configuration data.
- **STRICTLY FORBIDDEN WITHOUT AN APPROVED PLAN:**
  - Modifying database migrations, tables, or RPCs.
  - Changing RLS policies.
  - Modifying checkout, pricing, or payment logic.
  - Altering auth or KYC flows.

---

## S. SEO & AI-Readiness Rules
- SEO improvements may update: `title`, `meta` tags, canonical links, OpenGraph tags, JSON-LD structured data (Product, Organization, BreadcrumbList), semantic HTML tags, and `sitemap.xml`.
- AI-readiness improvements may include: Semantic microdata, machine-readable JSON schemas, and structured breadcrumbs.
- **INVARIANT:** SEO and AI enhancements must never expose private seller, customer, or financial data, nor compromise checkout integrity.

---

## T. Critical Stop Conditions
Stop immediately and alert the founder if:
- A real secret, API key, or service-role credential is detected in client code.
- A machine-specific or developer-specific path is required by production code.
- Customer checkout or account creation requires seller KYC.
- Production runtime attempts to import or fall back to mock data.
- Google OAuth is coupled to a hardcoded local port.
- Any change causes financial or inventory atomicity tests to fail.

---

## U. Rollback Procedures
- **Code Rollback:** Revert git commit via standard `git revert <commit_id>`. Never force-push or rewrite published commits on the connected Lovable branch.
- **Database Rollback:** Apply a forward migration containing inverted DDL. Never delete migration records manually from `supabase_migrations.schema_migrations`.

---

## V. Known Deferred Integrations
1. **Razorpay Live Gateway:** Standard checkout and UPI payments.
2. **Razorpay Route:** Automated marketplace split payments and seller disbursement.
3. **Shiprocket / Delhivery:** Live automated courier dispatch, reverse pickup scheduling, and AWB generation.
4. **Bureau / Karza / DigiLocker:** Automated seller PAN, GSTIN, and Aadhaar verification.
5. **Twilio / Gupshup:** Live SMS and WhatsApp notification delivery.

---

## W. Current Production Readiness Status
- **Backend Architecture:** Phase 1 to Phase 12A complete, audited, and verified.
- **Security & RLS:** Red-team remediated; 44/44 security tests passing.
- **Frontend & Routes:** 50/50 routes verified HTTP 200.
- **OAuth Readiness:** Dynamic origin implementation complete.
- **Deployment Gate:** **OPEN FOR MANUAL FOUNDER DEPLOYMENT**.
