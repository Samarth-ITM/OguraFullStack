# P4 Report

Status: P4 ACCEPTED

Actual Implementation:
- Seller Application & Tenant Lifecycle: Authenticated RPC `apply_as_seller(...)` enforcing 1 profile per user in default `application` state.
- Gate 1 Seller Approval: RPC `approve_seller(seller_id)` restricted strictly to `admin_super`.
- Lifecycle State Machine: `enforce_seller_lifecycle()` database trigger enforcing valid state transitions (`application` -> `under_review` -> `active` -> `suspended` -> `terminated`).
- Per-Document KYC Management: `seller_kyc_documents` with independent states (`pending`, `verified`, `rejected`); review RPC `review_seller_kyc_document(...)` restricted to `admin_finance` and `admin_super`.
- Bank Account Verification: Self-registration with trigger blocking self-verification; RPC `verify_seller_bank_account(...)` for Finance/Super admins; details update resets verification to `pending`.
- Razorpay Linked-Account State: Stored on `sellers.razorpay_account_id` and `seller_bank_accounts.razorpay_fund_account_id` via privileged RPC `set_seller_razorpay_account(...)`.
- Payout Eligibility Engine: Security function `is_seller_payout_eligible(seller_id)`.

Defects Discovered:
- Direct illegal jump `application -> terminated` was permitted by loose NOT IN predicate in trigger.
- `is_seller_payout_eligible` lacked explicit validation of Razorpay fund/account reference linkage.
- Test harness required explicit `SET ROLE authenticated` and `request.jwt.claim.sub` context switching to avoid postgres superuser RLS bypass.

Fixes Made:
- Refined `enforce_seller_lifecycle()`: `application` restricted to `under_review` or `active`; `active` restricted to `suspended` or `terminated`; `terminated` strictly locked as terminal state.
- Updated `is_seller_payout_eligible()`: Added condition requiring non-empty `razorpay_fund_account_id` on verified bank account or `razorpay_account_id` on seller.
- Enriched acceptance suite: Added assertions verifying rejection of `application -> terminated`, `active -> application`, and unauthorized self-suspension/termination.

Final Security Acceptance:
- Seller Isolation: Verified (Seller A cannot read or mutate Seller B profile, KYC, or bank accounts).
- KYC Isolation: Verified (Zero public or viewer access; strictly scoped to owning seller and Finance/Super admins).
- Bank Isolation: Verified (Zero public or viewer access; seller cannot self-verify; modifications reset verification state).
- Admin Role Separation: Verified (Gate 1 approval strictly reserved to `admin_super`; Catalog/Support/Viewer denied sensitive financial data).
- Audit Immutability: Verified (Append-only immutability enforced on `admin_audit_logs`; UPDATE and DELETE statements raise fatal exceptions).

Payout Eligibility Semantics:
- Requires: (1) Seller exists and `status = 'active'`, (2) Verified PAN document, (3) Verified GST certificate if GSTIN exists, (4) Zero pending/rejected KYC documents, (5) Verified bank account with `penny_drop_status = 'success'`, and (6) Linked Razorpay fund/account identifier.

P3 Regression Result:
- PASS: Active seller + live product + available inventory is publicly visible.
- PASS: Active seller + live product + pending KYC remains publicly visible (KYC does NOT block selling).
- PASS: Suspended seller + live product is immediately hidden through P3 Universal Visibility Gate.

Test Results:
- Critical Acceptance Suite: PASS (8/8 automated test assertions A through H passed in `supabase/tests/p4_seller_onboarding_kyc_test.sql`).

Clean Migration Reproduction:
- PASS: Clean temporary database `ogura_clean_p4_cert` created; migrations P1 -> P2 -> P3 -> P4 applied with 0 errors; all acceptance tests passed; temporary database dropped.

TypeScript & Build Results:
- TypeScript: PASS (`npx tsc --noEmit` exited with 0 errors).
- Build: PASS (Nitro SSR build compiled successfully in 256ms).

External Providers / APIs:
- 100% local deterministic state machine; zero external credentials burned and zero external API calls made.

Explicit Remaining Limitations:
- Real automated Razorpay Route sub-account creation, automated penny-drop provider integration, and payout settlement dispatch belong to Phase 12 (Payouts).
- Frontend seller portal and admin dashboard integration belong to Phase 17.
- This certification validates P4 backend schema, security invariants, and business gates (not claiming 100% end-to-end production launch readiness).

Next:
P4 ACCEPTED — READY FOR P5 (Customer Cart, Wishlist, and Persistent Addresses Foundation).
