# OGURA BACKEND — MASTER CONTEXT / SOURCE OF TRUTH

You are working on OGURA, a production-grade multi-vendor luxury fashion marketplace.

Your job is NOT to redesign the product. Your job is to turn the existing frontend/product specification into a secure, real, scalable backend capable of handling real users, real sellers, real inventory, real payments, real orders, real refunds, real payouts and real traffic.

Treat this document as the persistent context for the entire P0→P19 backend program.

==================================================
1. AUTHORITY ORDER
==================================================

When documents conflict, use this priority:

1. Explicit founder/product decisions
2. OGURA Master PRD
3. OGURA Backend Engineering Flows
4. OGURA Production Execution Runbook
5. Existing frontend implementation
6. Existing mock/demo behavior
7. Your assumptions

NEVER silently invent or resolve a business-critical conflict.

If a requirement is genuinely ambiguous or contradictory:
STOP → identify exact conflict → cite affected requirement/document → ask for decision.

Do not "fix" product requirements by guessing.

==================================================
2. PRODUCT
==================================================

OGURA is a multi-vendor luxury fashion marketplace.

Core actors:

- Customer / Buyer
- Seller
- Admin
- Service/backend
- External providers

Seller presentation types such as Brand, Designer and Boutique are presentation skins of the same Seller entity, NOT separate marketplace entities.

OGURA must support:

- product discovery
- taxonomy/category browsing
- search
- product pages
- variants
- per-size inventory
- cart
- wishlist
- addresses
- checkout
- payments
- orders
- seller sub-orders
- fulfilment
- returns
- refunds
- reviews
- made-to-order
- seller onboarding
- KYC
- seller product approval
- admin operations
- merchandising
- media
- notifications
- finance
- tax
- seller payouts
- audit
- analytics

==================================================
3. FRONTEND IS LOCKED
==================================================

Existing frontend is the product/UI reference.

Current baseline:

- React 19
- TypeScript
- TanStack Start
- Vite
- Tailwind CSS
- ~47 routes
- ~311 product styles
- ~1,463 variants
- repository abstraction
- mock repositories

IMPORTANT:

DO NOT change:

- UI
- UX
- visual design
- routes
- navigation
- information architecture
- taxonomy
- product presentation
- component anatomy
- merchandising structure
- existing user flows

Backend work must fit underneath the existing frontend.

The frontend is NOT authoritative for:

- price
- shipping
- discount
- tax
- totals
- inventory
- payment state
- refund state
- payout state
- order state
- seller permissions
- admin permissions
- user identity
- role
- financial state

Those become server/database authoritative.

Any change that would alter UI/UX/taxonomy/product behavior requires STOP + explicit approval.

==================================================
4. TARGET ARCHITECTURE
==================================================

Target live backend:

- Lovable Cloud
- PostgreSQL
- PostgreSQL RLS
- Auth
- Edge Functions / Deno
- Storage
- scheduled jobs
- transactional/outbox patterns
- Razorpay
- Razorpay Route
- approved logistics providers
- tax/compliance provider such as ClearTax/equivalent where approved
- email/SMS/WhatsApp providers where approved
- media/CDN infrastructure
- analytics infrastructure

Architecture:

CUSTOMER
   ↓
EXISTING OGURA FRONTEND
   ↓
RLS-SCOPED DATABASE READS
   +
EDGE FUNCTIONS FOR PRIVILEGED OPERATIONS
   ↓
POSTGRESQL = SOURCE OF TRUTH
   ↓
OUTBOX / JOBS / WEBHOOK PROCESSING
   ↓
EXTERNAL PROVIDERS
   ↓
WEBHOOKS
   ↓
POSTGRESQL

External services are integrations, NOT sources of truth.

==================================================
5. SCALE TARGET
==================================================

Design for at least:

- 100,000 users
- 10,000 SKUs/styles
- ~100,000 inventory units
- many sellers/brands
- concurrent checkout
- real payment traffic
- real order traffic
- real seller operations

Do not optimize only for the current demo dataset.

Architecture must prevent:

- overselling
- duplicate payments
- duplicate orders
- duplicate refunds
- duplicate payouts
- privilege escalation
- cross-seller access
- cross-user data access
- financial manipulation

==================================================
6. SOURCE OF TRUTH RULE
==================================================

PostgreSQL is authoritative for application state.

Server-side logic is authoritative for:

- pricing
- discounts
- shipping
- taxes
- order totals
- payment verification
- inventory reservation
- inventory decrement
- order creation
- refund decisions
- payout eligibility
- commission
- TCS/TDS
- ledger entries
- privileged state transitions

Client values are REQUESTS, never trusted facts.

Money uses INTEGER PAISE.

==================================================
7. UNIVERSAL VISIBILITY GATE
==================================================

A product may appear to customers only when all applicable conditions pass:

- product is LIVE
- seller is ACTIVE
- product is sellable
- stock/backorder rules pass
- requested surface/taxonomy/tag rules pass
- location/delivery rules pass where applicable

Suspended sellers must have products hidden.

Search must not become a second source of truth.

If search/indexing is used, it mirrors PostgreSQL.

==================================================
8. SELLER MODEL
==================================================

Seller lifecycle:

APPLICATION
→ ADMIN APPROVAL
→ ACTIVE
→ KYC PROCESS
→ KYC VERIFIED

KYC does NOT prevent selling.

KYC gates payout.

Product lifecycle:

DRAFT
→ SUBMITTED
→ ADMIN REVIEW
→ LIVE

Trusted sellers may have approved auto-publish behavior according to PRD.

Seller suspension must cascade into marketplace visibility and payout controls.

Seller can only access its own:

- seller data
- products
- variants
- images
- inventory
- sub-orders
- permitted customer/order information

==================================================
9. CUSTOMER COMMERCE
==================================================

Support:

- Google auth
- phone auth
- email auth
- guest cart
- guest→authenticated cart merge
- server cart as final source of truth
- wishlist
- addresses
- checkout
- orders
- reviews
- made-to-order

Wishlist:

- login gated
- can retain OOS products
- move-to-cart supported
- RLS protected

==================================================
10. INVENTORY
==================================================

Inventory is per variant/size where applicable.

Must support:

- available stock
- reservation
- reservation expiry
- release
- decrement
- low-stock threshold
- sold-out state
- concurrent checkout

Checkout must reserve inventory safely.

Inventory consumption must happen only after verified payment.

Inventory operations requiring authority must execute server-side.

Concurrency must be handled transactionally.

Default low-stock threshold is <5 unless PRD says otherwise.

==================================================
11. CHECKOUT + PAYMENT
==================================================

Checkout pipeline:

CLIENT REQUEST
→ SERVER VALIDATES CART
→ SERVER RESOLVES AUTHORITATIVE PRICES
→ SERVER CALCULATES DISCOUNT
→ SERVER CALCULATES SHIPPING
→ SERVER CALCULATES TAX
→ SERVER CALCULATES FINAL TOTAL
→ RESERVE INVENTORY
→ CREATE PAYMENT
→ CUSTOMER PAYS
→ VERIFY PAYMENT SIGNATURE
→ CONFIRM PAYMENT
→ CREATE/CONFIRM ORDER STATE
→ DECREMENT INVENTORY
→ SPLIT/ROUTE FINANCIAL STATE
→ CLEAR CART

Never trust client:

- amount
- total
- shipping
- discount
- tax
- order number
- payment status
- inventory availability

==================================================
12. RAZORPAY
==================================================

Provider lock:

RAZORPAY = customer payment provider.

RAZORPAY ROUTE = seller payout/split mechanism.

Do NOT substitute Stripe, Paddle, Shopify Payments, etc.

OGURA collects customer payment.

Seller settlement occurs through Razorpay Route according to payout eligibility.

Payment verification must be server-side.

Webhook processing must be:

- authenticated/verified
- idempotent
- replay-safe
- state-transition-safe

==================================================
13. ORDERS
==================================================

One customer order may contain multiple seller sub-orders.

Parent order is system/service-owned.

Seller owns only its own sub-order state.

Order state must not be client-controlled.

Tracking parent status is derived from underlying sub-order/service states.

Support operational workflows must not grant money-out authority.

==================================================
14. FULFILMENT
==================================================

Seller fulfils its own sub-order.

Launch logistics can support manual AWB.

Core lifecycle includes:

PACKED
→ SHIPPED
→ DELIVERED

AWB belongs to appropriate seller/sub-order scope.

Parent order status is derived by service/backend logic.

SLA misses must be detectable.

==================================================
15. RETURNS + REFUNDS
==================================================

Customer return window:

7 days, according to PRD.

Typical flow:

CUSTOMER REQUEST
→ SUPPORT REVIEW
→ APPROVAL / REJECTION
→ PICKUP
→ ITEM RECEIVED
→ CONDITION CHECK
→ REFUND DECISION
→ FINANCE REFUND
→ LEDGER UPDATE

Refund authority is server/Finance controlled.

Never allow client to directly create a financial refund.

==================================================
16. REVIEWS
==================================================

Reviews require:

- verified purchase
- delivered order
- within 90 days
- one review per product/order according to PRD

Verified Purchase badge is system-derived.

Seller cannot delete reviews.

Moderation belongs to authorized admin/support roles.

==================================================
17. KYC + COMPLIANCE
==================================================

Seller onboarding includes:

- PAN
- GST
- bank
- Razorpay account/linking
- document verification
- penny-drop verification
- Finance review

KYC VERIFIED unlocks payouts.

Compliance requirements include:

- GST
- TCS 1%
- TDS 1% under Section 194-O per seller GSTIN
- applicable KYC/AML requirements
- tax reconciliation
- CA/compliance sign-off where required

Do not invent tax/accounting policy.

==================================================
18. FINANCE + LEDGER
==================================================

Financial truth must be represented through an auditable ledger.

Ledger must support:

- customer payment
- commission
- discounts
- shipping
- tax
- TCS
- TDS
- refunds
- seller payable
- payout
- adjustments
- reconciliation

Financial records must be:

- auditable
- idempotent
- append-only where specified
- traceable to source events
- protected from ordinary client/admin mutation

Month-end concept:

DELIVERED
→ RETURN WINDOW PASSED
→ PAYOUT ELIGIBILITY
→ COMMISSION/TAX CALCULATION
→ SELLER STATEMENT
→ RAZORPAY RECONCILIATION
→ FINANCE APPROVAL
→ RAZORPAY ROUTE SETTLEMENT

==================================================
19. ADMIN ROLES
==================================================

Roles:

- Super
- Catalog
- Finance
- Support
- Viewer

Super can combine roles.

Catalog:

- catalog/taxonomy/merchandising
- no money-out
- no KYC authority

Finance:

- KYC
- payouts
- ledger
- tax
- commission
- Razorpay accounts
- financial operations

Support:

- orders
- returns
- reviews/moderation
- permitted PII
- no money-out
- no KYC authority

Viewer:

- read-only aggregate access
- no PII

All privileged operations must be enforced server-side/RLS, not merely hidden in UI.

==================================================
20. MERCHANDISING
==================================================

Launch does NOT use paid/sponsored placement.

Admin controls:

- curation
- ranking
- banners
- scheduled merchandising
- placements
- catalog presentation

Scheduled assets automatically activate/expire according to their schedule.

Pinned products still pass universal visibility gates.

==================================================
21. MADE-TO-ORDER
==================================================

MTO Lite is supported.

Do not invent the final MTO request destination or workflow if source documents conflict or leave it undefined.

This remains a known contract item requiring confirmation before implementation if unresolved.

==================================================
22. MEDIA / SEARCH / ANALYTICS
==================================================

Media must use controlled storage/CDN architecture.

Search, if implemented:

POSTGRES SOURCE
→ SEARCH MIRROR/INDEX

Never:

CLIENT
→ SEARCH INDEX
→ authoritative commerce state

Analytics must not become operational truth.

==================================================
23. SECURITY MODEL
==================================================

Every domain requires explicit trust boundaries.

Protect against:

- IDOR
- broken object-level authorization
- broken function-level authorization
- seller cross-access
- customer cross-access
- admin privilege escalation
- role spoofing
- price manipulation
- inventory manipulation
- payment manipulation
- refund manipulation
- payout manipulation
- webhook replay
- duplicate processing
- forged state transitions
- mass assignment
- insecure direct database access
- leaked secrets
- exposed service-role credentials

Service-role credentials must NEVER reach the client.

RLS is mandatory wherever appropriate.

Edge Functions are used for privileged operations.

==================================================
24. RELIABILITY
==================================================

All important external-event workflows must consider:

- retries
- duplicate events
- delayed webhooks
- out-of-order events
- provider downtime
- database failures
- partial completion
- timeout
- reservation expiry
- payment success after timeout
- payment failure after reservation
- refund retry
- payout retry

Use idempotency keys and durable state.

Do not rely on frontend retries for financial correctness.

==================================================
25. OBSERVABILITY
==================================================

Production system needs:

- structured logs
- correlation/request IDs
- important business event logging
- webhook logging
- payment event auditability
- inventory event auditability
- financial audit trail
- admin audit trail
- failure visibility
- operational metrics
- alerts for critical failures

==================================================
26. EXTERNAL OGURA SUPABASE
==================================================

Lovable Cloud is the sole live backend.

External OGURA Supabase is NOT live traffic infrastructure.

It is only a delayed one-way safety/recovery copy where specified.

Do NOT introduce:

- dual writes
- live failover
- competing auth
- competing source of truth
- live traffic routing

==================================================
27. BACKEND PROGRAM: P0 → P19
==================================================

P0  Contract + Architecture Freeze
    Audit all requirements, resolve/flag contradictions,
    normalize contracts, define backend boundaries and
    implementation-ready architecture. NO production implementation.

P1  Database Foundation
    Build the authoritative PostgreSQL schema, enums,
    constraints, indexes, relationships, timestamps,
    financial/inventory foundations and migration structure.

P2  Auth + Identity + RLS
    Authentication, profiles, roles, ownership boundaries,
    RLS, authorization primitives and identity security.

P3  Catalog + Taxonomy + Visibility
    Sellers, products, variants, taxonomy, tags,
    product lifecycle, visibility gate and catalog reads.

P4  Seller Onboarding + Product Approval + KYC
    Seller application, approval, seller lifecycle,
    KYC workflow, verification state, product submission/review.

P5  Cart + Wishlist + Addresses
    Persistent customer commerce state,
    guest cart merge, wishlist and address ownership.

P6  Inventory + Reservations + Concurrency
    Per-variant inventory, reservations, release,
    decrement, concurrency safety and oversell prevention.

P7  Checkout + Pricing + Shipping + Tax
    Server-authoritative cart validation, pricing,
    discounts, shipping, tax and order-total calculation.

P8  Razorpay Payment + Verification + Webhooks
    Payment creation, signature verification,
    webhook processing, idempotency and payment state.

P9  Orders + Sub-orders + Ledger
    Parent orders, seller sub-orders, order items,
    state transitions, financial ledger and auditability.

P10 Fulfilment + Logistics + Tracking
    Seller fulfilment, AWB, shipment lifecycle,
    delivery state and tracking.

P11 Cancellation + Returns + Refunds + Store Credit
    Cancellation rules, returns, support workflow,
    condition checks, refunds and store-credit handling.

P12 Payouts + Razorpay Route + Reconciliation
    Seller payable calculation, payout eligibility,
    KYC gate, reconciliation, approval and Route settlement.

P13 Notifications + Outbox + Jobs
    Transactional outbox, scheduled jobs,
    email/SMS/WhatsApp notifications and retries.

P14 Made-to-Order
    Implement MTO only according to confirmed product contract.

P15 Admin + Moderation + Audit
    Admin control plane, role enforcement,
    moderation, operational workflows and admin audit.

P16 Merchandising + Media + Search + Analytics
    CMS/placements, scheduled merchandising,
    media pipeline, search mirror and analytics events.

P17 Frontend Backend Integration
    Replace mocks/repositories with production backend,
    preserving the existing frontend behavior/UI/UX/routes/taxonomy.

P18 Production Hardening + Security + Load + Recovery
    Security testing, concurrency testing, load testing,
    failure testing, observability, backups, recovery,
    rate limits and production hardening.

P19 Production Certification
    Full end-to-end certification against PRD,
    security, financial correctness, real traffic readiness,
    operational readiness and release gate.

==================================================
28. EXECUTION PROTOCOL
==================================================

Every phase follows:

ANALYSE
→ CLASSIFY
→ DECIDE
→ IMPLEMENT ONLY IF AUTHORIZED
→ VERIFY
→ REGRESSION TEST
→ DOCUMENT
→ STOP / CERTIFY
→ NEXT PHASE

Never skip verification.

Never advance merely because code compiles.

Never mark a feature complete because a mock works.

For production-critical domains, test the actual state transitions and security boundaries.

==================================================
29. ZERO-TOLERANCE RULES
==================================================

NEVER:

- redesign UI
- change taxonomy
- invent business policy
- weaken RLS for convenience
- trust client financial values
- expose service-role credentials
- use mock behavior as production truth
- substitute payment providers
- create dual sources of truth
- silently resolve conflicting requirements
- claim production readiness without evidence
- declare tests passed without actually running them
- fabricate integration success
- skip concurrency/security testing
- build a giant unverified implementation in one step

If blocked, STOP.

==================================================
30. REPORTING
==================================================

Every implementation phase must produce:

/DOCS/p{N}_report.md

Report:

- objective
- exact changes
- files changed
- schema/functions/policies added
- requirements covered
- requirements remaining
- tests executed
- test results
- security validation
- failure/edge-case validation
- performance considerations
- UI/UX impact
- taxonomy impact
- blockers
- known technical debt
- next-phase prerequisites

Do not hide failures.

==================================================
31. FINAL DEFINITION OF DONE
==================================================

OGURA is NOT production-ready until:

- all authoritative PRD requirements are implemented
- all critical business decisions are resolved
- PostgreSQL is the source of truth
- RLS is verified
- privileged operations are server-authoritative
- inventory is concurrency-safe
- checkout is financially authoritative
- Razorpay payments are verified
- webhooks are idempotent
- refunds are controlled
- seller payouts are controlled
- ledger is auditable
- KYC gates payouts correctly
- admin roles are enforced
- seller isolation is verified
- customer isolation is verified
- real integrations work
- frontend uses backend instead of mocks
- failure/retry paths work
- observability exists
- backups/recovery are tested
- load/security testing passes
- full end-to-end production certification passes

The goal is not "backend code exists."

The goal is:

REAL OGURA MARKETPLACE
+
REAL USERS
+
REAL SELLERS
+
REAL INVENTORY
+
REAL MONEY
+
REAL OPERATIONS
+
REAL TRAFFIC
+
NO TRUST BOUNDARY FAILURES.

Until then, do not claim production readiness.
