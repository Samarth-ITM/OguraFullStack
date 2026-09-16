# OGURA — IMMUTABLE RULES & DO-NOT-BREAK SPECIFICATION

> **Classification:** STRICTLY ENFORCED SYSTEM INVARIANTS  
> **Audience:** All Software Engineers, AI Agents, and Contributors  
> **Target:** OGURA Production Infrastructure & Applications

---

## 1. Authority & Governance
1. **Never override locked founder decisions or PRD specifications** with engineering convenience assumptions or AI suggestions.
2. **Never change product taxonomy or category hierarchies** without explicit written founder approval.
3. **Never casually alter the established route structure** (`/`, `/shop`, `/product/:slug`, `/cart`, `/checkout`, `/account/*`, `/seller/*`, `/admin/*`).
4. **Never alter product card anatomy, luxury visual styling, or brand aesthetics** when working on backend or logic tasks.

---

## 2. Security & Secrets
5. **Never put secrets, private keys, or the Supabase `service_role` key into browser-facing code, client bundles, or repository files.**
6. **Never bypass Row Level Security (RLS).** Every single table in the `public` schema must have RLS enabled with explicit restrictive policies.
7. **Never trust client-side role claims.** Visual badges, frontend state, or JWT inspection in the UI are strictly for display. Actual permissions MUST be verified in PostgreSQL RPCs or RLS policies.
8. **Never expose seller or customer Personally Identifiable Information (PII)** across tenant boundaries. Sellers must never see customer phone numbers or full addresses of unrelated orders.

---

## 3. Financial Invariants
9. **Never trust client-side monetary calculations.** The database recalculates subtotals, GST, platform commission, shipping fees, and final order totals from canonical tables.
10. **Never use floating-point types for currency.** All financial arithmetic must be conducted strictly in integer Indian Paise (`₹1.00 = 100 paise`).
11. **Never mutate or delete financial ledger entries.** The table `financial_ledger_entries` is strictly append-only double-entry bookkeeping.
12. **Never activate live deferred external providers** (Razorpay, live 3PL logistics, live KYC APIs) without complete provider configuration and founder authorization.

---

## 4. Inventory & Orders
13. **Never allow overselling under any circumstances.** Authoritative available stock is:
    $$\text{available\_stock} = \text{quantity\_on\_hand} - \text{quantity\_reserved}$$
14. **Never perform non-atomic inventory updates.** All inventory reservations must use `SELECT ... FOR UPDATE` row-level locks with explicit TTL expiration.
15. **Never break parent-order / seller-sub-order relationships.** A parent order contains customer payment state; child sub-orders partition line items for independent seller fulfillment.
16. **Never bypass Made-to-Order (MTO) crafting semantics.** MTO items do not decrement inventory on hand but transition through an `'in_crafting'` state with lead-time tracking.

---

## 5. KYC & Tenancy Separation
17. **Never require seller KYC for ordinary customer shopping.** Customers can browse, register, add to cart, and purchase without PAN, GST, or business documents.
18. **Never bypass the seller KYC payout gate.** Seller disbursements cannot be transferred unless the seller's KYC status is verified and approved by an admin.
19. **Never compromise seller tenant isolation.** A seller must only access products, sub-orders, shipments, and ledger balances where `seller_id = (current seller)`.

---

## 6. Development & Release Hygiene
20. **Never silently fall back to mock data in production.** If database connectivity or configuration is missing in a production build, the application must **FAIL CLOSED**.
21. **Never edit or rewrite applied database migrations.** All schema updates must be introduced via incremental, forward-only SQL migration files.
22. **Never introduce machine-specific or developer-specific paths** (`/Users/...`, `C:\Users\...`, local developer usernames, `localhost:5432`, `127.0.0.1`) into production code or configuration.
23. **Never deploy to production automatically.** Automated agents MUST NOT trigger live deployments. Deployment is strictly gated for manual founder action.
