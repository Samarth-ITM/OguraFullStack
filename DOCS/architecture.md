# OGURA — BACKEND SYSTEM DESIGN & ARCHITECTURE SPECIFICATION

> **Status:** FROZEN FOR PRODUCTION (Lovable Cloud / Supabase Cloud)  
> **Deployment Authority:** Manual Founder Deployment Only  
> **Target Environment:** Lovable Cloud + Supabase Cloud (PostgreSQL 16, Supabase Auth, Storage, RLS, RPCs, Edge Functions)

---

## 1. Conceptual End-to-End Architecture

```
                    ┌───────────────────────────────┐
                    │        CUSTOMER / SELLER      │
                    │            BROWSER            │
                    └───────────────┬───────────────┘
                                    │
                                    │ HTTPS (Strict CSP, CORS, HTTPS Only)
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
          anon_key / user JWT              authenticated RPC / service_role
                    │                               │
                    └───────────────┬───────────────┘
                                    ▼
                    ┌───────────────────────────────┐
                    │       LOVABLE CLOUD           │
                    │                               │
                    │ Supabase Auth                 │
                    │ PostgreSQL 16 (Authoritative) │
                    │ Row Level Security (RLS)      │
                    │ Stored Procedures (RPCs)      │
                    │ Edge Functions (Deno Runtime) │
                    │ Storage (Media / Documents)   │
                    │ Scheduled Jobs (pg_cron)      │
                    │ Transactional Outbox Engine   │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │     CANONICAL DATABASE        │
                    │         PostgreSQL            │
                    │                               │
                    │ Identity (`profiles`, `roles`)│
                    │ Catalog (`products`, variants)│
                    │ Cart (`carts`, `cart_lines`)  │
                    │ Inventory (`inventory_items`) │
                    │ Checkout (`checkout_quotes`)  │
                    │ Orders (`orders`, sub-orders) │
                    │ Fulfillment (`shipments`)     │
                    │ Returns (`return_requests`)   │
                    │ Financial Ledger (`ledger`)   │
                    │ Seller KYC (`kyc_documents`)  │
                    │ Admin (`admin_audit_logs`)    │
                    │ Outbox (`notification_outbox`)│
                    └───────────────┬───────────────┘
                                    │
                          asynchronous boundary
                                    │
                    ┌───────────────▼───────────────┐
                    │      EXTERNAL PROVIDERS       │
                    │   [STATUS: DEFERRED IN MVP]   │
                    │                               │
                    │ Razorpay (Standard / UPI)     │
                    │ Razorpay Route (Seller Split) │
                    │ KYC Providers (PAN / GSTIN)   │
                    │ Courier / 3PL (Shiprocket)    │
                    │ SMS Provider (OTP / Alerts)   │
                    │ WhatsApp Provider             │
                    │ Transactional Email (Resend)  │
                    └───────────────────────────────┘
```

---

## 2. Read vs. Command Architecture

OGURA implements strict separation between queries (reads) and mutations (commands):

```
                         BROWSER
                            │
              ┌─────────────┴─────────────┐
              │                           │
           READS                       COMMANDS
              │                           │
              ▼                           ▼
       RLS-scoped data            RPC / Edge Function
              │                           │
              └─────────────┬─────────────┘
                            ▼
                       POSTGRESQL
                            │
                  AUTHORITATIVE STATE
                            │
                  ┌─────────┴─────────┐
                  │                   │
              DATABASE              OUTBOX
              COMMIT                  │
                                      ▼
                               PROVIDER ADAPTER
                                      │
                             DEFERRED EXTERNAL
                                INTEGRATIONS
```

### Architectural Explanation

1. **Reads Path (RLS-Scoped Queries):**
   - The browser queries public or user-scoped data directly against PostgreSQL via the Supabase client using the publishable `anon_key` and the user's authenticated session JWT.
   - All reads are guarded by PostgreSQL **Row Level Security (RLS)** policies. For example, anonymous users can only read from `public_catalog_products` or products where `status = 'live'` belonging to `active` sellers.
   - Customers can read only their own `customer_addresses`, `carts`, `cart_lines`, `customer_wishlist`, and parent `orders`.
   - Sellers can read only `seller_sub_orders` where `seller_id = current_seller_id()`.
   - Read queries never bypass RLS and never execute with administrative elevation.

2. **Commands Path (Authoritative Server Operations):**
   - High-stakes mutations (checkout quotes, inventory reservations, payment confirmations, order generation, cancellations, seller shipments, return requests, QC inspections, refund authorizations) are **never executed via raw client table mutations**.
   - Mutations are dispatched as authoritative commands to PostgreSQL stored procedures (`SECURITY DEFINER` RPCs) or Supabase Edge Functions.
   - The client submits only **intent** (e.g., variant IDs, quantities, address references). The database computes all tariff amounts in integer paise, resolves GST splits, acquires concurrency locks (`SELECT ... FOR UPDATE`), checks stock availability, updates state machine records, and writes audit trails.

3. **Authoritative Database Commit:**
   - All state transitions and inventory updates commit atomically inside PostgreSQL.
   - PostgreSQL is the **sole source of truth** for prices, stock, discounts, totals, order status, and permissions.

4. **Transactional Outbox Engine (`public.notification_outbox` / `public.webhook_events`):**
   - Side-effects (customer emails, seller SMS alerts, tracking webhooks, accounting entries) are written into outbox tables within the **exact same database transaction** that commits the entity change.
   - Dual-write race conditions are mathematically prevented.

5. **Provider Adapter & Deferred External Integrations:**
   - Background worker processes or asynchronous triggers poll pending records using `FOR UPDATE SKIP LOCKED`.
   - Provider adapters translate internal database event payloads into third-party API payloads.
   - In the current MVP release, the provider adapter contracts are fully implemented and verified, but **live external provider execution is DEFERRED** until the founder configures production credentials.

---

## 3. Provider Boundary: Internal Contract vs. Live Provider Status

| Provider Domain | Internal Schema & RPC Contract | Live Provider Configuration | Live Execution Status | Architectural Boundary Details |
|---|---|---|---|---|
| **Razorpay Checkout** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** | `payment_transactions` records gateway order IDs, payment IDs, and signatures. In MVP, `confirm_order_payment` validates quotes and captures orders. Live webhook signature verification and checkout SDK are deferred. |
| **Razorpay Route** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** | Seller linked accounts tracked in `seller_bank_accounts.razorpay_fund_account_id`. Split amounts computed in `seller_sub_orders`. Live automated route transfer execution is deferred. |
| **KYC Providers (PAN / GST / Aadhaar)** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** | `seller_kyc_documents` stores document references with restricted storage policies. Administrative approval RPCs (`review_seller_kyc_document`) verified. Live Karza/DigiLocker API verification is deferred. |
| **Penny-Drop Bank Verification** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** | `seller_bank_accounts.penny_drop_status` and `verify_seller_bank_account` RPC enforce payout gating. Automated bank API penny-drop call is deferred. |
| **Courier / 3PL (Shiprocket / Delhivery)** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** | `shipments` table, AWB assignment, and `process_tracking_webhook` state transitions verified. Live automated courier booking API is deferred. |
| **SMS Gateway (OTP / Notifications)** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** | Phone auth configured via Supabase Auth SMS interface. Notification events queued in `notification_outbox` with channel `'sms'`. Live Twilio/Gupshup delivery worker is deferred. |
| **WhatsApp Notifications** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** | Outbox channel `'whatsapp'` implemented with retry counters and payload schemas. Live WhatsApp Business API worker is deferred. |
| **Transactional Email** | **IMPLEMENTED & TESTED** | **NOT CONFIGURED** | **NOT VERIFIED** | Outbox channel `'email'` implemented with template keys (`order_confirmed`, `shipment_dispatched`). Live Resend/SES worker is deferred. |

---

## 4. Service-Role Authority & Security Model

> [!CAUTION]
> **SERVICE_ROLE IS TRUSTED SERVER-SIDE AUTHORITY ONLY.**
> - `service_role` is **NEVER** a normal application authorization mechanism.
> - Default to: **RLS**, **authenticated RPCs**, and **least privilege**.
> - Use `service_role` only inside explicitly trusted server-side boundaries (Deno Edge Functions, database migration scripts, administrative cron tasks).
> - **NEVER expose `SUPABASE_SERVICE_ROLE_KEY` to browser or client bundles.**

### Security Invariants
1. **Row Level Security (RLS):** Enabled on 100% of public database tables. Zero unprotected tables.
2. **Tenant Isolation:**
   - Customers: Query bounded strictly by `user_id = auth.uid()`.
   - Sellers: Query bounded strictly by `seller_id = current_seller_id()`.
   - Admins: Role verification via `has_role(auth.uid(), 'admin_...'::user_role_type)`. UI role badges provide zero security authorization.
3. **Database-Level Immutability Triggers:**
   - `trg_enforce_order_immutability` on `orders`
   - `trg_enforce_sub_order_immutability` on `seller_sub_orders`
   - `trg_prevent_ledger_modification` on `financial_ledger_entries` (strictly append-only)
   - `trg_prevent_audit_modification` on `admin_audit_logs`

---

## 5. Actual Database Schema & Domain Mapping (Domains 1 – 13)

The following tables, columns, RPCs, and enums reflect the **exact factual database implementation** in `supabase/migrations/`:

### DOMAIN 1 — Identity & Access
- **Tables:** `profiles`, `user_roles`, `sellers`
- **Role Enum (`user_role_type`):** `'customer'`, `'seller'`, `'admin_super'`, `'admin_catalog'`, `'admin_finance'`, `'admin_support'`, `'admin_viewer'`
- **Functions / RPCs:**
  - `has_role(uid uuid, role_name user_role_type) RETURNS boolean`
  - `enforce_single_admin_role()` trigger (blocks conflicting admin roles)
  - `handle_new_user()` trigger (auto-creates customer profile on `auth.users` insert)

### DOMAIN 2 — Catalog & Taxonomy
- **Tables:** `categories`, `subcategories`, `occasions`, `product_occasions`, `brands`, `designers`, `products`, `product_variants`, `media_assets`
- **Views:** `public_catalog_products`, `public_sellers`
- **Key Columns:**
  - `products`: `id`, `seller_id`, `brand_id`, `designer_id`, `category_id`, `subcategory_id`, `occasion_id`, `title`, `slug`, `description`, `details` (jsonb), `status` (`product_status`), `is_made_to_order`, `is_new_arrival`, `is_launchpad`
  - `product_variants`: `id`, `product_id`, `sku`, `size`, `color`, `color_hex`, `price_paise` (bigint), `compare_at_price_paise` (bigint), `is_active`
  - `media_assets`: `id`, `product_id`, `slot_role` (`media_slot_role`), `asset_url`, `thumbnail_url`, `sort_order`
- **Enums:**
  - `product_status`: `'draft'`, `'submitted'`, `'in_review'`, `'live'`, `'rejected'`, `'suspended'`, `'archived'`
  - `media_slot_role`: `'primary'`, `'secondary'`, `'back'`, `'detail'`, `'lookbook'`
- **Functions / RPCs:**
  - `get_public_catalog(...)`, `get_public_product_by_slug(p_slug text)`
  - `submit_product_for_review(p_product_id uuid)`
  - `approve_product(p_product_id uuid)`, `reject_product(p_product_id uuid, p_reason text)`
  - `is_product_visible(p_product_id uuid) RETURNS boolean`

### DOMAIN 3 — Customer Commerce
- **Tables:** `carts`, `cart_lines`, `customer_wishlist`, `customer_addresses`, `customer_store_credits`
- **Key Columns:**
  - `carts`: `id`, `user_id`, `session_id`, `created_at`, `updated_at`
  - `cart_lines`: `id`, `cart_id`, `variant_id`, `quantity`, `created_at`, `updated_at`
  - `customer_addresses`: `id`, `user_id`, `full_name`, `phone`, `line1`, `line2`, `city`, `state`, `pincode`, `country`, `is_default`, `is_active`
  - `customer_wishlist`: `id`, `user_id`, `product_id`, `created_at`
- **Functions / RPCs:**
  - `get_or_create_customer_cart()`, `get_customer_cart()`, `clear_customer_cart()`
  - `add_to_customer_cart(p_variant_id uuid, p_quantity integer)`
  - `update_cart_line_quantity(p_line_id uuid, p_quantity integer)`
  - `remove_cart_line(p_line_id uuid)`
  - `merge_guest_cart(p_items jsonb)`
  - `get_customer_wishlist()`, `toggle_wishlist_item(p_product_id uuid)`
  - `set_default_customer_address(p_address_id uuid)`

### DOMAIN 4 — Pricing & Checkout Engine
- **Tables:** `checkout_quotes`
- **Key Columns:**
  - `checkout_quotes`: `id`, `user_id`, `session_id`, `subtotal_paise` (bigint), `discount_paise` (bigint), `shipping_fee_paise` (bigint), `tax_paise` (bigint), `total_payable_paise` (bigint), `shipping_address` (jsonb), `status` (`checkout_quote_status`), `expires_at`, `created_at`
- **Quote Status Enum (`checkout_quote_status`):** `'pending'`, `'paid'`, `'expired'`, `'cancelled'`
- **Functions / RPCs:**
  - `create_checkout_quote(p_shipping_address jsonb, p_coupon_code text DEFAULT NULL)`
  - `get_checkout_quote(p_quote_id uuid)`
  - `cancel_checkout_quote(p_quote_id uuid)`
  - `enforce_quote_immutability()` trigger

### DOMAIN 5 — Inventory Engine
- **Tables:** `inventory_items`, `inventory_reservations`, `inventory_audit_log`
- **Key Columns:**
  - `inventory_items`: `id`, `variant_id`, `quantity_on_hand` (integer), `quantity_reserved` (integer), `low_stock_threshold`
  - `inventory_reservations`: `id`, `quote_id`, `variant_id`, `quantity` (integer), `status` (`inventory_reservation_status`), `expires_at`
- **Reservation Status Enum (`inventory_reservation_status`):** `'held'`, `'committed'`, `'released'`, `'expired'`
- **Authoritative Available Formula:**
  $$\text{available\_stock} = \text{quantity\_on\_hand} - \text{quantity\_reserved}$$
- **Functions / RPCs:**
  - `reserve_inventory_for_quote(p_quote_id uuid)`
  - `create_inventory_reservation(p_quote_id uuid, p_variant_id uuid, p_quantity integer, p_ttl_minutes integer)`
  - `consume_quote_reservations(p_quote_id uuid)`
  - `release_quote_reservations(p_quote_id uuid)`
  - `consume_inventory_reservation(p_reservation_id uuid)`
  - `release_inventory_reservation(p_reservation_id uuid)`
  - `expire_inventory_reservation(p_reservation_id uuid)`
  - `expire_stale_reservations()`
  - `get_variant_available_stock(p_variant_id uuid) RETURNS integer`

### DOMAIN 6 — Payment Boundary
- **Tables:** `payment_transactions`, `webhook_events`
- **Key Columns:**
  - `payment_transactions`: `id`, `order_id`, `gateway`, `gateway_order_id`, `gateway_payment_id`, `gateway_signature`, `amount_paise` (bigint), `currency`, `status` (`payment_transaction_status`)
- **Status Enum (`payment_transaction_status`):** `'initiated'`, `'pending'`, `'authorized'`, `'captured'`, `'failed'`, `'refunded'`
- **Functions / RPCs:**
  - `confirm_order_payment(p_quote_id uuid, p_gateway text, p_gateway_order_id text, p_gateway_payment_id text, p_gateway_signature text)`
  - `record_payment_failure(p_order_id uuid, p_gateway text, p_reason text)`

### DOMAIN 7 — Orders & Multi-Seller Fulfillment
- **Tables:** `orders`, `seller_sub_orders`, `order_items`, `order_status_history`, `shipments`
- **Key Columns:**
  - `orders`: `id`, `order_number`, `user_id`, `quote_id`, `subtotal_paise`, `discount_paise`, `shipping_fee_paise`, `tax_paise`, `total_amount_paise`, `shipping_address` (jsonb), `status` (`order_status`), `fulfilled_at`
  - `seller_sub_orders`: `id`, `sub_order_number`, `order_id`, `seller_id`, `subtotal_paise`, `discount_paise`, `tax_paise`, `total_amount_paise`, `commission_paise`, `tcs_paise`, `tds_paise`, `logistics_deduction_paise`, `net_seller_payable_paise`, `status` (`sub_order_status`), `awb`, `courier`, `ship_by`, `accepted_at`, `dispatched_at`, `delivered_at`
  - `order_items`: `id`, `sub_order_id`, `variant_id`, `product_title`, `variant_sku`, `size`, `color`, `unit_price_paise`, `quantity`, `total_price_paise`
  - `shipments`: `id`, `sub_order_id`, `courier_code`, `tracking_number`, `label_url`, `status` (`shipment_status`)
- **Status Enums:**
  - `order_status`: `'draft'`, `'placed'`, `'confirmed'`, `'partially_fulfilled'`, `'fulfilled'`, `'completed'`, `'cancelled'`, `'returned'`
  - `sub_order_status`: `'pending_acceptance'`, `'accepted'`, `'in_crafting'`, `'packed'`, `'ready_for_pickup'`, `'dispatched'`, `'delivered'`, `'cancelled'`
  - `shipment_status`: `'manifest_created'`, `'awb_assigned'`, `'pickup_scheduled'`, `'in_transit'`, `'out_for_delivery'`, `'delivered'`, `'undelivered_attempt'`, `'rto_initiated'`, `'rto_delivered'`
- **Functions / RPCs:**
  - `create_order_from_quote(p_quote_id uuid)`
  - `seller_accept_sub_order(p_sub_order_id uuid)`
  - `seller_ship_sub_order(p_sub_order_id uuid, p_courier text, p_awb text)`
  - `seller_update_sub_order_status(p_sub_order_id uuid, p_status sub_order_status)`
  - `create_shipment(...)`, `update_shipment_status(...)`
  - `process_tracking_webhook(p_awb text, p_status shipment_status, p_payload jsonb)`
  - `sync_parent_order_fulfillment_status()` trigger (derives parent `order.status` from all child sub-orders)

### DOMAIN 8 — Returns & Reverse Logistics
- **Tables:** `return_requests`, `refund_transactions`
- **Key Columns:**
  - `return_requests`: `id`, `order_item_id`, `user_id`, `reason`, `customer_notes`, `quantity`, `refund_amount_paise`, `status` (`return_request_status`), `qc_notes`, `return_carrier`, `return_awb`, `in_transit_at`, `hub_received_at`, `qc_passed_at`, `qc_failed_at`, `refund_authorized_at`, `refunded_at`
  - `refund_transactions`: `id`, `return_request_id`, `order_id`, `payment_id`, `gateway_refund_id`, `amount_paise`, `reason`, `status` (`refund_status`), `authorized_by`
- **Status Enums:**
  - `return_request_status`: `'requested'`, `'support_review'`, `'approved'`, `'pickup_scheduled'`, `'in_transit'`, `'hub_received'`, `'qc_passed'`, `'qc_failed'`, `'refund_authorized'`, `'refunded'`, `'rejected'`
  - `refund_status`: `'initiated'`, `'processing'`, `'completed'`, `'failed'`
- **Functions / RPCs:**
  - `check_return_eligibility(p_order_item_id uuid)`
  - `customer_create_return_request(...)`
  - `admin_review_return_request(...)`, `admin_update_return_logistics(...)`
  - `admin_record_return_qc(p_return_id uuid, p_passed boolean, p_notes text)`
  - `admin_authorize_refund(p_return_id uuid)`
  - `finance_process_refund_settlement(p_refund_id uuid, p_gateway_refund_id text)`

### DOMAIN 9 — Financial Double-Entry Ledger
- **Tables:** `financial_ledger_entries`, `payout_statements`
- **Key Columns:**
  - `financial_ledger_entries`: `id` (bigint), `transaction_group_id` (uuid), `entry_type` (`credit`, `debit`), `account_type` (`ledger_account_type`), `amount_paise` (bigint), `currency`, `order_id`, `sub_order_id`, `seller_id`, `payment_id`, `refund_id`, `payout_id`, `reference_note`, `created_at`
  - `payout_statements`: `id`, `statement_number`, `seller_id`, `settlement_period_start`, `settlement_period_end`, `gross_sales_paise`, `commission_deductions_paise`, `tcs_deductions_paise`, `tds_deductions_paise`, `logistics_deductions_paise`, `refund_deductions_paise`, `net_payout_paise`, `razorpay_payout_id`, `bank_utr_number`, `status` (`payout_statement_status`), `authorized_by`
- **Enums:**
  - `ledger_account_type`: `'platform_cash_escrow'`, `'customer_payable_refund'`, `'seller_payable_escrow'`, `'statutory_tcs_payable'`, `'statutory_tds_payable'`, `'platform_commission_revenue'`, `'platform_shipping_revenue'`, `'logistics_expense'`
  - `ledger_entry_type`: `'credit'`, `'debit'`
  - `payout_statement_status`: `'accruing'`, `'return_hold'`, `'statement_generated'`, `'finance_approved'`, `'settlement_initiated'`, `'settled'`, `'failed'`
- **Functions / RPCs:**
  - `post_order_payment_ledger_settlement(p_order_id uuid)`
  - `validate_double_entry_balance()` trigger (verifies $\sum \text{debits} == \sum \text{credits}$)
  - `prevent_ledger_modification()` trigger (strictly blocks `UPDATE` and `DELETE`)
  - `generate_seller_payout_statement(p_seller_id uuid, p_start date, p_end date)`
  - `finance_settle_payout_statement(p_statement_id uuid, p_utr text)`
  - `is_seller_payout_eligible(p_seller_id uuid) RETURNS boolean`

### DOMAIN 10 — Seller Onboarding & KYC
- **Tables:** `sellers`, `seller_kyc_documents`, `seller_bank_accounts`
- **Key Columns:**
  - `sellers`: `id`, `user_id`, `business_name`, `brand_name`, `seller_slug`, `pan`, `gstin`, `registered_address`, `status` (`seller_status`), `commission_rate_bps`
  - `seller_kyc_documents`: `id`, `seller_id`, `document_type`, `document_url`, `verification_status` (`kyc_verification_status`), `rejection_reason`, `reviewed_by`, `reviewed_at`
  - `seller_bank_accounts`: `id`, `seller_id`, `beneficiary_name`, `account_number`, `ifsc_code`, `bank_name`, `razorpay_fund_account_id`, `penny_drop_status`, `is_verified`
- **Enums:**
  - `seller_status`: `'application'`, `'under_review'`, `'approved'`, `'active'`, `'suspended'`, `'terminated'`
  - `kyc_verification_status`: `'not_submitted'`, `'pending'`, `'verified'`, `'rejected'`
- **Functions / RPCs:**
  - `apply_as_seller(...)`
  - `approve_seller(p_seller_id uuid)`, `suspend_seller(p_seller_id uuid)`, `reactivate_seller(p_seller_id uuid)`
  - `review_seller_kyc_document(p_document_id uuid, p_status kyc_verification_status, p_reason text)`
  - `verify_seller_bank_account(p_account_id uuid, p_is_verified boolean, p_penny_drop_status text)`
  - `enforce_bank_account_security()` trigger
  - `enforce_kyc_document_security()` trigger

### DOMAIN 11 — Admin Merchandising & Moderation
- **Tables:** `admin_audit_logs`, `merchandising_slots`, `product_reviews`
- **Functions / RPCs:**
  - `prevent_audit_modification()` trigger (append-only audit logs)

### DOMAIN 12 — Outbox Engine
- **Tables:** `notification_outbox`, `webhook_events`
- **Key Columns:**
  - `notification_outbox`: `id` (bigint), `channel` (`notification_channel`), `recipient`, `template_key`, `payload` (jsonb), `status` (`notification_status`), `attempts`, `max_attempts`, `next_retry_at`, `sent_at`, `error_message`
- **Enums:**
  - `notification_channel`: `'email'`, `'sms'`, `'whatsapp'`
  - `notification_status`: `'queued'`, `'processing'`, `'sent'`, `'failed'`, `'dead_letter'`

### DOMAIN 13 — Made-to-Order (MTO) Architecture
- **Tables:** `mto_requests`, `products` (`is_made_to_order` flag)
- **Status Enum (`mto_request_status`):** `'inquiry_submitted'`, `'atelier_review'`, `'price_quoted'`, `'customer_accepted'`, `'advance_paid'`, `'in_crafting'`, `'dispatched'`, `'delivered'`, `'declined'`

---

## 6. State Machine Specifications

### 1. Seller Lifecycle (`seller_status`)
```
[application] ──(seller registers)──► [under_review]
                                             │
                       ┌─────────────────────┴─────────────────────┐
              (admin approves)                            (admin rejects)
                       │                                           │
                       ▼                                           ▼
                   [approved]                                 [terminated]
                       │
              (profile activated)
                       │
                       ▼
                    [active] ◄───(admin reactivates)───┐
                       │                               │
                       ▼ (admin suspends)              │
                  [suspended] ─────────────────────────┘
```

### 2. Product Lifecycle (`product_status`)
```
[draft] ──(seller submits)──► [submitted] ──► [in_review]
                                                    │
                                ┌───────────────────┴───────────────────┐
                       (admin approves)                        (admin rejects)
                                │                                       │
                                ▼                                       ▼
                             [live] ──(delist)──► [archived]        [rejected]
                                │
                        (seller suspended)
                                │
                                ▼
                           [suspended]
```

### 3. Inventory Reservation Lifecycle (`inventory_reservation_status`)
```
[held] ──(TTL expired / quote cancelled)──► [released]
  │
(payment confirmed)
  │
  ▼
[committed]
```

### 4. Order Lifecycle (`order_status`)
```
[draft] ──► [placed] ──(payment confirmed)──► [confirmed]
                                                   │
                              ┌────────────────────┴────────────────────┐
                    (some sub-orders ship)                    (all sub-orders ship)
                              │                                         │
                              ▼                                         ▼
                     [partially_fulfilled] ──(all delivered)──►   [fulfilled]
                                                                        │
                                                                 (all completed)
                                                                        │
                                                                        ▼
                                                                   [completed]
```

### 5. Payment Transaction Lifecycle (`payment_transaction_status`)
```
[initiated] ──► [pending] ──► [authorized] ──► [captured] ──(refund)──► [refunded]
     │
(failed / cancelled)
     │
     ▼
  [failed]
```

### 6. Sub-Order Fulfillment Lifecycle (`sub_order_status`)
```
[pending_acceptance] ──(seller accepts)──► [accepted]
                                                │
                                    (if MTO item crafting)
                                                │
                                                ▼
                                          [in_crafting]
                                                │
                                        (crafting done)
                                                │
                                                ▼
                                             [packed]
                                                │
                                       (ready for courier)
                                                │
                                                ▼
                                       [ready_for_pickup]
                                                │
                                        (courier pickup)
                                                │
                                                ▼
                                           [dispatched]
                                                │
                                        (proof of delivery)
                                                │
                                                ▼
                                           [delivered]
```

### 7. Return & Refund Lifecycle (`return_request_status`)
```
[requested] ──► [support_review] ──► [approved] ──► [pickup_scheduled]
                                                         │
                                                         ▼
                                                    [in_transit]
                                                         │
                                                         ▼
                                                  [hub_received]
                                                         │
                                    ┌────────────────────┴────────────────────┐
                               (QC passes)                               (QC fails)
                                    │                                         │
                                    ▼                                         ▼
                               [qc_passed]                               [qc_failed]
                                    │                                         │
                            (finance authorizes)                         (item returned)
                                    │                                         │
                                    ▼                                         ▼
                          [refund_authorized]                            [rejected]
                                    │
                         (payment settled)
                                    │
                                    ▼
                               [refunded]
```
