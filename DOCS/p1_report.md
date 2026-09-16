# P1 Report

Status: PASS

P0 Corrections:
- MTO Decoupled: MTO frontend 404 is a P14 UX issue; table `mto_requests` provisioned in P1 foundation without blocking.
- Provider Candidates Decoupled: Razorpay/Route locked; Shiprocket, Resend, and Gupshup remain uncommitted candidates.
- Design Proposals Isolated: P0 account codes, retry intervals, and cron timings treated as implementation choices, not PRD mandates.

Business Decisions Used:
- Shipping: Standard ₹99 (9900 paise) below ₹2,999; free ≥ ₹2,999; charged ONCE at parent order level (`orders.shipping_fee_paise`). Express deferred.
- Financial: TCS 1% (`tcs_paise`), TDS 1% Sec 194-O (`tds_paise`), post-discount commission base, Razorpay Route settlement, integer paise (`BIGINT`).

Implemented:
- Migration: `supabase/migrations/20260915000000_ogura_p1_database_foundation.sql`.
- 37 Tables: Spanning IAM, Seller/KYC, Catalog, Inventory, Cart, Orders, Sub-orders, Payments, Returns, MTO, Ledger, and Outbox.
- 20 State Enums: Constraining all lifecycle transitions (seller, product, order, sub-order, shipment, payment, reservation, payout).
- Constraints: Math checks on order totals and net seller payable; inventory invariants (`quantity_on_hand >= quantity_reserved >= 0`).
- Immutable Ledger Guard: Database trigger function `prevent_ledger_modification()` strictly blocking UPDATE and DELETE.
- 36 Performance Indexes: Indexing product catalog facets, inventory holds, orders, shipments, and ledger references.

Validation:
- migrations: PASS (Executed with 0 errors on PostgreSQL 17.11)
- schema checks: PASS (Verified 37 public tables and 20 enums)
- constraint tests: PASS (Negative stock rejected; reserved > on-hand rejected; tampered order totals rejected)
- relevant tests: PASS (Immutable ledger trigger verified; fresh database reproduction passed)
- TypeScript/build: PASS (`tsc --noEmit` clean, `npm run build` Nitro SSR compiled in 176ms)

Security:
- Database Security Foundation: Structural ownership boundaries (`user_id`, `seller_id`) established across all domain tables.
- Important Finding: Financial/audit records protected by `ON DELETE RESTRICT` preventing accidental cascading deletion.

UI/UX/Taxonomy:
- NO CHANGE (Frontend routes, components, styling, navigation, and merchandising are 100% untouched).

Failures Fixed:
- Handled drop-trigger dependency syntax in migration for clean idempotent execution on fresh databases.

Remaining:
- P2: Authentication integration, identity mapping, and Row-Level Security (RLS) policies.

Next:
- P2 (Auth + Identity + RLS)
