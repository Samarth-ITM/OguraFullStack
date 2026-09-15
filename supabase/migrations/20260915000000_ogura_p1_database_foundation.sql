-- ============================================================================
-- OGURA PRODUCTION DATABASE FOUNDATION (PHASE 1)
-- Migration: 20260915000000_ogura_p1_database_foundation.sql
-- Target: PostgreSQL 16+ / Lovable Cloud / Supabase
-- Currency Standard: Integer Paise (BIGINT)
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Auth Compatibility Schema (for standalone Postgres & Supabase portability)
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 1. ENUMS & STATE DOMAINS
-- ============================================================================

DO $$ BEGIN
    CREATE TYPE user_role_type AS ENUM (
        'customer',
        'seller',
        'admin_super',
        'admin_catalog',
        'admin_finance',
        'admin_support',
        'admin_viewer'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE seller_status AS ENUM (
        'application',
        'under_review',
        'approved',
        'active',
        'suspended',
        'terminated'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE kyc_verification_status AS ENUM (
        'not_submitted',
        'pending',
        'verified',
        'rejected'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE product_status AS ENUM (
        'draft',
        'submitted',
        'in_review',
        'live',
        'rejected',
        'suspended',
        'archived'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE media_slot_role AS ENUM (
        'primary',
        'secondary',
        'back',
        'detail',
        'lookbook'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE inventory_reservation_status AS ENUM (
        'held',
        'committed',
        'released',
        'expired'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE checkout_quote_status AS ENUM (
        'pending',
        'paid',
        'expired',
        'cancelled'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payment_transaction_status AS ENUM (
        'initiated',
        'pending',
        'authorized',
        'captured',
        'failed',
        'refunded'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE order_status AS ENUM (
        'draft',
        'placed',
        'confirmed',
        'partially_fulfilled',
        'fulfilled',
        'completed',
        'cancelled',
        'returned'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE sub_order_status AS ENUM (
        'pending_acceptance',
        'accepted',
        'in_crafting',
        'packed',
        'ready_for_pickup',
        'dispatched',
        'delivered',
        'cancelled'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE shipment_status AS ENUM (
        'manifest_created',
        'awb_assigned',
        'pickup_scheduled',
        'in_transit',
        'out_for_delivery',
        'delivered',
        'undelivered_attempt',
        'rto_initiated',
        'rto_delivered'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE return_request_status AS ENUM (
        'requested',
        'support_review',
        'approved',
        'pickup_scheduled',
        'in_transit',
        'hub_received',
        'qc_passed',
        'qc_failed',
        'refund_authorized',
        'refunded',
        'rejected'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE refund_status AS ENUM (
        'initiated',
        'processing',
        'completed',
        'failed'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payout_statement_status AS ENUM (
        'accruing',
        'return_hold',
        'statement_generated',
        'finance_approved',
        'settlement_initiated',
        'settled',
        'failed'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE mto_request_status AS ENUM (
        'inquiry_submitted',
        'atelier_review',
        'price_quoted',
        'customer_accepted',
        'advance_paid',
        'in_crafting',
        'dispatched',
        'delivered',
        'declined'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE notification_channel AS ENUM (
        'email',
        'sms',
        'whatsapp'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE notification_status AS ENUM (
        'queued',
        'processing',
        'sent',
        'failed',
        'dead_letter'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE ledger_entry_type AS ENUM (
        'credit',
        'debit'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE ledger_account_type AS ENUM (
        'platform_cash_escrow',
        'customer_payable_refund',
        'seller_payable_escrow',
        'statutory_tcs_payable',
        'statutory_tds_payable',
        'platform_commission_revenue',
        'platform_shipping_revenue',
        'logistics_expense'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE review_status AS ENUM (
        'pending_moderation',
        'published',
        'rejected',
        'hidden'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ============================================================================
-- 2. IDENTITY & PROFILES (DOMAIN 1)
-- ============================================================================

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    full_name VARCHAR(255),
    avatar_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role user_role_type NOT NULL DEFAULT 'customer',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_roles_user_role UNIQUE(user_id, role)
);

CREATE TABLE IF NOT EXISTS customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    line1 TEXT NOT NULL,
    line2 TEXT,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    pincode VARCHAR(10) NOT NULL,
    country VARCHAR(100) NOT NULL DEFAULT 'India',
    is_default BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    admin_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    previous_state JSONB,
    new_state JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 3. SELLER ONBOARDING & KYC (DOMAIN 10)
-- ============================================================================

CREATE TABLE IF NOT EXISTS sellers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    business_name VARCHAR(255) NOT NULL,
    legal_entity_name VARCHAR(255) NOT NULL,
    seller_slug VARCHAR(255) NOT NULL UNIQUE,
    gstin VARCHAR(15) UNIQUE,
    pan VARCHAR(10) UNIQUE,
    commission_rate_bps INTEGER DEFAULT 1500 CHECK (commission_rate_bps >= 0 AND commission_rate_bps <= 10000),
    status seller_status NOT NULL DEFAULT 'application',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS seller_kyc_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES sellers(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL,
    document_url TEXT NOT NULL,
    verification_status kyc_verification_status NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS seller_bank_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES sellers(id) ON DELETE CASCADE,
    beneficiary_name VARCHAR(255) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    ifsc_code VARCHAR(11) NOT NULL,
    bank_name VARCHAR(100),
    razorpay_fund_account_id VARCHAR(100),
    penny_drop_status VARCHAR(50) NOT NULL DEFAULT 'pending',
    is_verified BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 4. CATALOG & TAXONOMY (DOMAIN 2)
-- ============================================================================

CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subcategories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS occasions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(100),
    established_year INTEGER,
    story TEXT,
    logo_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS designers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id) ON DELETE SET NULL,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    bio TEXT,
    philosophy TEXT,
    portrait_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    brand_id UUID NOT NULL REFERENCES brands(id) ON DELETE RESTRICT,
    designer_id UUID REFERENCES designers(id) ON DELETE SET NULL,
    subcategory_id UUID NOT NULL REFERENCES subcategories(id) ON DELETE RESTRICT,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    details JSONB DEFAULT '[]'::jsonb,
    materials VARCHAR(255),
    care_instructions TEXT,
    status product_status NOT NULL DEFAULT 'draft',
    rejection_reason TEXT,
    is_made_to_order BOOLEAN NOT NULL DEFAULT false,
    is_new_arrival BOOLEAN NOT NULL DEFAULT false,
    is_launchpad BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    sku VARCHAR(100) NOT NULL UNIQUE,
    size VARCHAR(50) NOT NULL,
    color VARCHAR(50) NOT NULL,
    price_paise BIGINT NOT NULL CHECK (price_paise > 0),
    compare_at_price_paise BIGINT CHECK (compare_at_price_paise IS NULL OR compare_at_price_paise > price_paise),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS media_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    slot_role media_slot_role NOT NULL DEFAULT 'primary',
    asset_url TEXT NOT NULL,
    thumbnail_url TEXT,
    aspect_ratio VARCHAR(20) DEFAULT '3:4',
    alt_text TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 5. INVENTORY & RESERVATIONS (DOMAIN 5)
-- ============================================================================

CREATE TABLE IF NOT EXISTS inventory_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_id UUID NOT NULL UNIQUE REFERENCES product_variants(id) ON DELETE CASCADE,
    quantity_on_hand INTEGER NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved INTEGER NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    low_stock_threshold INTEGER NOT NULL DEFAULT 5 CHECK (low_stock_threshold >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_inventory_reserved_le_on_hand CHECK (quantity_on_hand >= quantity_reserved)
);

-- Forward declaration of checkout_quotes table for inventory_reservations reference
CREATE TABLE IF NOT EXISTS checkout_quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    session_id VARCHAR(100),
    subtotal_paise BIGINT NOT NULL CHECK (subtotal_paise >= 0),
    discount_paise BIGINT NOT NULL DEFAULT 0 CHECK (discount_paise >= 0),
    shipping_fee_paise BIGINT NOT NULL DEFAULT 0 CHECK (shipping_fee_paise >= 0),
    tax_paise BIGINT NOT NULL DEFAULT 0 CHECK (tax_paise >= 0),
    total_payable_paise BIGINT NOT NULL CHECK (total_payable_paise >= 0),
    shipping_address JSONB NOT NULL,
    status checkout_quote_status NOT NULL DEFAULT 'pending',
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_quote_total CHECK (total_payable_paise = subtotal_paise - discount_paise + shipping_fee_paise + tax_paise)
);

CREATE TABLE IF NOT EXISTS inventory_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_id UUID NOT NULL REFERENCES checkout_quotes(id) ON DELETE CASCADE,
    variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    status inventory_reservation_status NOT NULL DEFAULT 'held',
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS inventory_audit_log (
    id BIGSERIAL PRIMARY KEY,
    variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
    change_type VARCHAR(50) NOT NULL,
    quantity_delta INTEGER NOT NULL,
    quantity_on_hand_after INTEGER NOT NULL CHECK (quantity_on_hand_after >= 0),
    quantity_reserved_after INTEGER NOT NULL CHECK (quantity_reserved_after >= 0),
    reference_id UUID,
    actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 6. CUSTOMER COMMERCE, CART & WISHLIST (DOMAIN 3)
-- ============================================================================

CREATE TABLE IF NOT EXISTS carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    session_id VARCHAR(100) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_cart_owner CHECK (user_id IS NOT NULL OR session_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS cart_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity >= 1 AND quantity <= 10),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_cart_lines_cart_variant UNIQUE(cart_id, variant_id)
);

CREATE TABLE IF NOT EXISTS customer_wishlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_customer_wishlist_user_product UNIQUE(user_id, product_id)
);

-- ============================================================================
-- 7. ORDERS & MULTI-SELLER SUB-ORDERS (DOMAIN 7)
-- ============================================================================

-- Parent Order (Customer Order Header)
-- Shipping Tariff Invariant: Standard shipping = ₹99 (9900 paise) below ₹2,999 (299900 paise); free ≥ ₹2,999.
-- Multi-seller: Charged ONCE at the parent order level.
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    quote_id UUID REFERENCES checkout_quotes(id) ON DELETE SET NULL,
    subtotal_paise BIGINT NOT NULL CHECK (subtotal_paise >= 0),
    discount_paise BIGINT NOT NULL DEFAULT 0 CHECK (discount_paise >= 0),
    shipping_fee_paise BIGINT NOT NULL DEFAULT 0 CHECK (shipping_fee_paise >= 0),
    tax_paise BIGINT NOT NULL DEFAULT 0 CHECK (tax_paise >= 0),
    total_amount_paise BIGINT NOT NULL CHECK (total_amount_paise >= 0),
    shipping_address JSONB NOT NULL,
    status order_status NOT NULL DEFAULT 'placed',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_order_total CHECK (total_amount_paise = subtotal_paise - discount_paise + shipping_fee_paise + tax_paise)
);

-- Seller Sub-Order (Seller Fulfillment Slice)
-- No shipping fee duplicated here (customer shipping is at parent level).
-- Net payable calculated post-discount, deducting commission, statutory TCS 1%, TDS 1% (Sec 194-O), and freight.
CREATE TABLE IF NOT EXISTS seller_sub_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sub_order_number VARCHAR(60) NOT NULL UNIQUE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    seller_id UUID NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    subtotal_paise BIGINT NOT NULL CHECK (subtotal_paise >= 0),
    discount_paise BIGINT NOT NULL DEFAULT 0 CHECK (discount_paise >= 0),
    tax_paise BIGINT NOT NULL DEFAULT 0 CHECK (tax_paise >= 0),
    total_amount_paise BIGINT NOT NULL CHECK (total_amount_paise >= 0),
    commission_paise BIGINT NOT NULL DEFAULT 0 CHECK (commission_paise >= 0),
    tcs_paise BIGINT NOT NULL DEFAULT 0 CHECK (tcs_paise >= 0),
    tds_paise BIGINT NOT NULL DEFAULT 0 CHECK (tds_paise >= 0),
    logistics_deduction_paise BIGINT NOT NULL DEFAULT 0 CHECK (logistics_deduction_paise >= 0),
    net_seller_payable_paise BIGINT NOT NULL CHECK (net_seller_payable_paise >= 0),
    status sub_order_status NOT NULL DEFAULT 'pending_acceptance',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_sub_order_total CHECK (total_amount_paise = subtotal_paise - discount_paise + tax_paise),
    CONSTRAINT chk_net_payable CHECK (net_seller_payable_paise = (subtotal_paise - discount_paise) - commission_paise - tcs_paise - tds_paise - logistics_deduction_paise)
);

CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sub_order_id UUID NOT NULL REFERENCES seller_sub_orders(id) ON DELETE RESTRICT,
    variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE RESTRICT,
    product_title VARCHAR(255) NOT NULL,
    variant_sku VARCHAR(100) NOT NULL,
    size VARCHAR(50) NOT NULL,
    color VARCHAR(50) NOT NULL,
    unit_price_paise BIGINT NOT NULL CHECK (unit_price_paise > 0),
    quantity INTEGER NOT NULL CHECK (quantity >= 1),
    total_price_paise BIGINT NOT NULL CHECK (total_price_paise = unit_price_paise * quantity),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_status_history (
    id BIGSERIAL PRIMARY KEY,
    order_id UUID REFERENCES orders(id) ON DELETE RESTRICT,
    sub_order_id UUID REFERENCES seller_sub_orders(id) ON DELETE RESTRICT,
    from_status VARCHAR(50),
    to_status VARCHAR(50) NOT NULL,
    actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sub_order_id UUID NOT NULL REFERENCES seller_sub_orders(id) ON DELETE RESTRICT,
    seller_id UUID NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    carrier VARCHAR(100) NOT NULL,
    awb_number VARCHAR(100) NOT NULL UNIQUE,
    tracking_url TEXT,
    status shipment_status NOT NULL DEFAULT 'manifest_created',
    pickup_scheduled_at TIMESTAMPTZ,
    dispatched_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 8. PAYMENTS & WEBHOOKS (DOMAIN 6)
-- ============================================================================

CREATE TABLE IF NOT EXISTS payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    gateway VARCHAR(50) NOT NULL DEFAULT 'razorpay',
    gateway_order_id VARCHAR(100) NOT NULL UNIQUE,
    gateway_payment_id VARCHAR(100) UNIQUE,
    gateway_signature VARCHAR(255),
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    status payment_transaction_status NOT NULL DEFAULT 'initiated',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS webhook_events (
    id BIGSERIAL PRIMARY KEY,
    provider VARCHAR(50) NOT NULL,
    event_id VARCHAR(100) NOT NULL UNIQUE,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    signature VARCHAR(255),
    processed BOOLEAN NOT NULL DEFAULT false,
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 9. RETURNS & REFUNDS (DOMAIN 8)
-- ============================================================================

CREATE TABLE IF NOT EXISTS return_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_item_id UUID NOT NULL REFERENCES order_items(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    reason VARCHAR(255) NOT NULL,
    customer_notes TEXT,
    status return_request_status NOT NULL DEFAULT 'requested',
    qc_notes TEXT,
    reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS refund_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    return_request_id UUID REFERENCES return_requests(id) ON DELETE RESTRICT,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    payment_id UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE RESTRICT,
    gateway_refund_id VARCHAR(100) UNIQUE,
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    reason VARCHAR(255),
    status refund_status NOT NULL DEFAULT 'initiated',
    authorized_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 10. MADE-TO-ORDER (MTO) BESPOKE INTAKE (DOMAIN 13)
-- ============================================================================

CREATE TABLE IF NOT EXISTS mto_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_number VARCHAR(50) NOT NULL UNIQUE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    variant_id UUID REFERENCES product_variants(id) ON DELETE RESTRICT,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_email VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL,
    measurements JSONB NOT NULL,
    notes TEXT,
    target_date DATE,
    quote_price_paise BIGINT CHECK (quote_price_paise IS NULL OR quote_price_paise > 0),
    status mto_request_status NOT NULL DEFAULT 'inquiry_submitted',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 11. FINANCIAL LEDGER & PAYOUTS (DOMAIN 9)
-- ============================================================================

CREATE TABLE IF NOT EXISTS payout_statements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    statement_number VARCHAR(50) NOT NULL UNIQUE,
    seller_id UUID NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    settlement_period_start DATE NOT NULL,
    settlement_period_end DATE NOT NULL,
    gross_sales_paise BIGINT NOT NULL CHECK (gross_sales_paise >= 0),
    commission_deductions_paise BIGINT NOT NULL CHECK (commission_deductions_paise >= 0),
    tcs_deductions_paise BIGINT NOT NULL CHECK (tcs_deductions_paise >= 0),
    tds_deductions_paise BIGINT NOT NULL CHECK (tds_deductions_paise >= 0),
    logistics_deductions_paise BIGINT NOT NULL CHECK (logistics_deductions_paise >= 0),
    refund_deductions_paise BIGINT NOT NULL CHECK (refund_deductions_paise >= 0),
    net_payout_paise BIGINT NOT NULL CHECK (net_payout_paise >= 0),
    razorpay_payout_id VARCHAR(100) UNIQUE,
    bank_utr_number VARCHAR(100),
    status payout_statement_status NOT NULL DEFAULT 'statement_generated',
    authorized_by UUID REFERENCES profiles(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payout_statement_dates CHECK (settlement_period_end >= settlement_period_start),
    CONSTRAINT chk_payout_statement_net CHECK (net_payout_paise = gross_sales_paise - commission_deductions_paise - tcs_deductions_paise - tds_deductions_paise - logistics_deductions_paise - refund_deductions_paise)
);

CREATE TABLE IF NOT EXISTS financial_ledger_entries (
    id BIGSERIAL PRIMARY KEY,
    transaction_group_id UUID NOT NULL,
    entry_type ledger_entry_type NOT NULL,
    account_type ledger_account_type NOT NULL,
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    order_id UUID REFERENCES orders(id) ON DELETE RESTRICT,
    sub_order_id UUID REFERENCES seller_sub_orders(id) ON DELETE RESTRICT,
    seller_id UUID REFERENCES sellers(id) ON DELETE RESTRICT,
    payment_id UUID REFERENCES payment_transactions(id) ON DELETE RESTRICT,
    refund_id UUID REFERENCES refund_transactions(id) ON DELETE RESTRICT,
    payout_id UUID REFERENCES payout_statements(id) ON DELETE RESTRICT,
    reference_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Immutable Ledger Guard: Prevent UPDATE and DELETE operations
CREATE OR REPLACE FUNCTION prevent_ledger_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'financial_ledger_entries is an immutable append-only ledger. UPDATE and DELETE operations are strictly prohibited.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_immutable_ledger ON financial_ledger_entries;
CREATE TRIGGER trg_immutable_ledger
BEFORE UPDATE OR DELETE ON financial_ledger_entries
FOR EACH ROW EXECUTE FUNCTION prevent_ledger_modification();

-- Immutable Audit Guards: Prevent UPDATE and DELETE on audit logs
CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION '% is an immutable append-only audit record. UPDATE and DELETE operations are strictly prohibited.', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_immutable_admin_audit ON admin_audit_logs;
CREATE TRIGGER trg_immutable_admin_audit
BEFORE UPDATE OR DELETE ON admin_audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();

DROP TRIGGER IF EXISTS trg_immutable_inventory_audit ON inventory_audit_log;
CREATE TRIGGER trg_immutable_inventory_audit
BEFORE UPDATE OR DELETE ON inventory_audit_log
FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();

DROP TRIGGER IF EXISTS trg_immutable_order_status_history ON order_status_history;
CREATE TRIGGER trg_immutable_order_status_history
BEFORE UPDATE OR DELETE ON order_status_history
FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();

-- ============================================================================
-- 12. NOTIFICATION OUTBOX, REVIEWS & MERCHANDISING (DOMAINS 11 & 12)
-- ============================================================================

CREATE TABLE IF NOT EXISTS notification_outbox (
    id BIGSERIAL PRIMARY KEY,
    channel notification_channel NOT NULL,
    recipient VARCHAR(255) NOT NULL,
    template_key VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    status notification_status NOT NULL DEFAULT 'queued',
    attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    max_attempts INTEGER NOT NULL DEFAULT 5,
    next_retry_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS product_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(255),
    body TEXT NOT NULL,
    is_verified_purchase BOOLEAN NOT NULL DEFAULT false,
    status review_status NOT NULL DEFAULT 'pending_moderation',
    moderated_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_reviews_user_order UNIQUE(product_id, user_id, order_id)
);

CREATE TABLE IF NOT EXISTS merchandising_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slot_key VARCHAR(100) NOT NULL UNIQUE,
    title VARCHAR(255),
    subtitle VARCHAR(255),
    target_url TEXT,
    image_url TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 13. PERFORMANCE & ACCESS PATH INDEXES
-- ============================================================================

-- Catalog Indexes
CREATE INDEX IF NOT EXISTS idx_products_catalog ON products (status, is_made_to_order, subcategory_id) WHERE status = 'live';
CREATE INDEX IF NOT EXISTS idx_products_seller ON products (seller_id);
CREATE INDEX IF NOT EXISTS idx_products_brand ON products (brand_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_product ON product_variants (product_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_sku ON product_variants (sku);
CREATE INDEX IF NOT EXISTS idx_media_assets_product ON media_assets (product_id, sort_order);

-- Inventory & Concurrency Indexes
CREATE INDEX IF NOT EXISTS idx_inventory_items_variant ON inventory_items (variant_id);
CREATE INDEX IF NOT EXISTS idx_inventory_reservations_expiry ON inventory_reservations (expires_at) WHERE status = 'held';
CREATE INDEX IF NOT EXISTS idx_inventory_reservations_quote ON inventory_reservations (quote_id);

-- Cart & Wishlist Indexes
CREATE INDEX IF NOT EXISTS idx_carts_user ON carts (user_id);
CREATE INDEX IF NOT EXISTS idx_carts_session ON carts (session_id);
CREATE INDEX IF NOT EXISTS idx_cart_lines_cart ON cart_lines (cart_id);
CREATE INDEX IF NOT EXISTS idx_customer_wishlist_user ON customer_wishlist (user_id);

-- Orders & Sub-orders Indexes
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_number ON orders (order_number);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status);
CREATE INDEX IF NOT EXISTS idx_seller_sub_orders_order ON seller_sub_orders (order_id);
CREATE INDEX IF NOT EXISTS idx_seller_sub_orders_seller ON seller_sub_orders (seller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_items_sub_order ON order_items (sub_order_id);
CREATE INDEX IF NOT EXISTS idx_shipments_sub_order ON shipments (sub_order_id);
CREATE INDEX IF NOT EXISTS idx_shipments_awb ON shipments (awb_number);

-- Payments & Webhooks Indexes
CREATE INDEX IF NOT EXISTS idx_payment_transactions_order ON payment_transactions (order_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_gateway_order ON payment_transactions (gateway_order_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_gateway_payment ON payment_transactions (gateway_payment_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_provider_event ON webhook_events (provider, event_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_unprocessed ON webhook_events (processed) WHERE processed = false;

-- Returns & Financial Ledger Indexes
CREATE INDEX IF NOT EXISTS idx_return_requests_user ON return_requests (user_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_item ON return_requests (order_item_id);
CREATE INDEX IF NOT EXISTS idx_financial_ledger_group ON financial_ledger_entries (transaction_group_id);
CREATE INDEX IF NOT EXISTS idx_financial_ledger_order ON financial_ledger_entries (order_id);
CREATE INDEX IF NOT EXISTS idx_financial_ledger_seller ON financial_ledger_entries (seller_id);
CREATE INDEX IF NOT EXISTS idx_payout_statements_seller ON payout_statements (seller_id);

-- Operations & Outbox Indexes
CREATE INDEX IF NOT EXISTS idx_notification_outbox_retry ON notification_outbox (status, next_retry_at) WHERE status = 'queued';
CREATE INDEX IF NOT EXISTS idx_product_reviews_product ON product_reviews (product_id, status) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_merchandising_slots_key ON merchandising_slots (slot_key) WHERE is_active = true;
