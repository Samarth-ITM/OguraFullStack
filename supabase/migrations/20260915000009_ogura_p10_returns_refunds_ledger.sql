-- ============================================================================
-- OGURA PHASE 10: RETURNS, REFUNDS & FINANCIAL LEDGER SETTLEMENT
-- Migration: 20260915000009_ogura_p10_returns_refunds_ledger.sql
-- 
-- Strictly server-authoritative return eligibility, return state machine,
-- condition verification (QC), refund calculations, double-entry financial
-- ledger settlement, platform commission accounting, and seller payout gate.
-- 
-- P1-P9 are LOCKED and untouched.
-- ============================================================================

-- 1. SCHEMA ENHANCEMENTS ON EXISTING P1 TABLES

-- Return requests enhancements: quantity, resolution, reverse logistics timestamps, QC timestamps
ALTER TABLE public.return_requests
    ADD COLUMN IF NOT EXISTS quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity >= 1),
    ADD COLUMN IF NOT EXISTS refund_amount_paise BIGINT CHECK (refund_amount_paise IS NULL OR refund_amount_paise >= 0),
    ADD COLUMN IF NOT EXISTS resolution VARCHAR(50) NOT NULL DEFAULT 'refund' CHECK (resolution IN ('refund', 'store_credit', 'replacement')),
    ADD COLUMN IF NOT EXISTS return_carrier VARCHAR(100),
    ADD COLUMN IF NOT EXISTS return_awb VARCHAR(100),
    ADD COLUMN IF NOT EXISTS pickup_scheduled_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS in_transit_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS hub_received_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS qc_passed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS qc_failed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS refund_authorized_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Customer Store Credits table (audited store credit balances)
CREATE TABLE IF NOT EXISTS public.customer_store_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    return_request_id UUID REFERENCES return_requests(id) ON DELETE RESTRICT,
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    balance_remaining_paise BIGINT NOT NULL CHECK (balance_remaining_paise >= 0),
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'exhausted', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_store_credits_user ON public.customer_store_credits(user_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_order_item ON public.return_requests(order_item_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_user ON public.return_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_refund_transactions_order ON public.refund_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_refund_transactions_return ON public.refund_transactions(return_request_id);
CREATE INDEX IF NOT EXISTS idx_ledger_group ON public.financial_ledger_entries(transaction_group_id);


-- ============================================================================
-- 2. DOUBLE-ENTRY LEDGER BALANCE CONSTRAINT TRIGGER
-- Enforces: SUM(debit) = SUM(credit) per transaction_group_id
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_double_entry_balance(p_group_id UUID)
RETURNS VOID AS $$
DECLARE
    v_debit_sum BIGINT := 0;
    v_credit_sum BIGINT := 0;
BEGIN
    SELECT
        COALESCE(SUM(CASE WHEN entry_type = 'debit' THEN amount_paise ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN entry_type = 'credit' THEN amount_paise ELSE 0 END), 0)
    INTO v_debit_sum, v_credit_sum
    FROM public.financial_ledger_entries
    WHERE transaction_group_id = p_group_id;

    IF v_debit_sum != v_credit_sum THEN
        RAISE EXCEPTION 'unbalanced_ledger_transaction: debits (%) do not equal credits (%) for transaction_group_id %',
            v_debit_sum, v_credit_sum, p_group_id
            USING ERRCODE = '22023';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 3. RETURN ELIGIBILITY ENGINE
-- Server-authoritative derivation of return window, delivery state, item ownership
-- ============================================================================

CREATE OR REPLACE FUNCTION public.check_return_eligibility(
    p_order_item_id UUID,
    p_quantity INTEGER DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
    v_item RECORD;
    v_sub_order RECORD;
    v_order RECORD;
    v_product RECORD;
    v_caller_id UUID := auth.uid();
    v_is_admin BOOLEAN := FALSE;
    v_already_returned INTEGER := 0;
    v_available_qty INTEGER;
    v_window_expires_at TIMESTAMPTZ;
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
BEGIN
    IF p_quantity IS NULL OR p_quantity < 1 THEN
        RAISE EXCEPTION 'invalid_quantity: return quantity must be at least 1'
            USING ERRCODE = '22023';
    END IF;

    -- Check caller authority
    SELECT (has_role('admin_super') OR has_role('admin_support') OR has_role('admin_finance'))
    INTO v_is_admin;

    -- Fetch order item
    SELECT * INTO v_item
    FROM public.order_items
    WHERE id = p_order_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'order_item_not_found: order item does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    -- Fetch seller sub-order
    SELECT * INTO v_sub_order
    FROM public.seller_sub_orders
    WHERE id = v_item.sub_order_id;

    -- Fetch parent order
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = v_sub_order.order_id;

    -- Customer ownership check
    IF NOT v_is_admin THEN
        IF v_caller_id IS NULL OR v_caller_id != v_order.user_id THEN
            RAISE EXCEPTION 'access_denied: caller does not own the order for this item'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Verify parent order status
    IF v_order.status NOT IN ('confirmed', 'partially_fulfilled', 'fulfilled', 'completed') THEN
        RAISE EXCEPTION 'order_not_eligible_for_return: order is in % status', v_order.status
            USING ERRCODE = '22023';
    END IF;

    -- 1. Delivery Milestone Check
    IF v_sub_order.status != 'delivered' OR v_sub_order.delivered_at IS NULL THEN
        RAISE EXCEPTION 'item_not_delivered: returns are strictly permitted only after parcel delivery'
            USING ERRCODE = '22023';
    END IF;

    -- 2. 7-Day Policy Window Check
    v_window_expires_at := v_sub_order.delivered_at + INTERVAL '7 days';
    IF v_now > v_window_expires_at THEN
        RAISE EXCEPTION 'return_window_expired: 7-day return policy window expired at %', v_window_expires_at
            USING ERRCODE = '22023';
    END IF;

    -- 3. Final Sale / Made-To-Order Exclusions Check
    SELECT p.* INTO v_product
    FROM public.products p
    JOIN public.product_variants pv ON pv.product_id = p.id
    WHERE pv.id = v_item.variant_id;

    IF v_product.is_made_to_order = true THEN
        RAISE EXCEPTION 'item_final_sale: custom-crafted and made-to-order pieces are final sale'
            USING ERRCODE = '22023';
    END IF;

    -- 4. Quantity Already Returned / Under Review Check
    SELECT COALESCE(SUM(quantity), 0)
    INTO v_already_returned
    FROM public.return_requests
    WHERE order_item_id = p_order_item_id
      AND status NOT IN ('rejected', 'qc_failed');

    v_available_qty := v_item.quantity - v_already_returned;

    IF p_quantity > v_available_qty THEN
        RAISE EXCEPTION 'insufficient_returnable_quantity: requested % units, but only % available for return (% already requested/returned)',
            p_quantity, v_available_qty, v_already_returned
            USING ERRCODE = '22023';
    END IF;

    RETURN jsonb_build_object(
        'eligible', true,
        'order_item_id', v_item.id,
        'order_id', v_order.id,
        'sub_order_id', v_sub_order.id,
        'product_title', v_item.product_title,
        'delivered_at', v_sub_order.delivered_at,
        'return_window_expires_at', v_window_expires_at,
        'unit_price_paise', v_item.unit_price_paise,
        'requested_quantity', p_quantity,
        'available_quantity', v_available_qty,
        'estimated_refund_paise', (v_item.unit_price_paise * p_quantity)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 4. CUSTOMER CREATE RETURN REQUEST
-- ============================================================================

CREATE OR REPLACE FUNCTION public.customer_create_return_request(
    p_order_item_id UUID,
    p_reason VARCHAR(255),
    p_customer_notes TEXT DEFAULT NULL,
    p_resolution VARCHAR(50) DEFAULT 'refund',
    p_quantity INTEGER DEFAULT 1
)
RETURNS JSONB AS $$
DECLARE
    v_eligibility JSONB;
    v_item RECORD;
    v_sub_order RECORD;
    v_order RECORD;
    v_return_id UUID;
    v_unit_price BIGINT;
    v_refund_paise BIGINT;
    v_resolution VARCHAR(50);
BEGIN
    -- Validate resolution type
    v_resolution := COALESCE(NULLIF(TRIM(p_resolution), ''), 'refund');
    IF v_resolution NOT IN ('refund', 'store_credit', 'replacement') THEN
        RAISE EXCEPTION 'invalid_resolution: resolution must be refund, store_credit, or replacement'
            USING ERRCODE = '22023';
    END IF;

    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'invalid_reason: return reason cannot be blank'
            USING ERRCODE = '22023';
    END IF;

    -- Check eligibility under lock
    v_eligibility := public.check_return_eligibility(p_order_item_id, p_quantity);

    SELECT * INTO v_item FROM public.order_items WHERE id = p_order_item_id;
    SELECT * INTO v_sub_order FROM public.seller_sub_orders WHERE id = v_item.sub_order_id;
    SELECT * INTO v_order FROM public.orders WHERE id = v_sub_order.order_id;

    -- Calculate server-authoritative refund amount
    v_unit_price := v_item.unit_price_paise;
    v_refund_paise := v_unit_price * p_quantity;

    -- Insert return request
    INSERT INTO public.return_requests (
        order_item_id,
        user_id,
        reason,
        customer_notes,
        status,
        quantity,
        refund_amount_paise,
        resolution
    ) VALUES (
        p_order_item_id,
        v_order.user_id,
        TRIM(p_reason),
        p_customer_notes,
        'requested',
        p_quantity,
        v_refund_paise,
        v_resolution
    ) RETURNING id INTO v_return_id;

    -- Audit trail in order_status_history
    INSERT INTO public.order_status_history (
        order_id,
        sub_order_id,
        from_status,
        to_status,
        actor_id,
        notes
    ) VALUES (
        v_order.id,
        v_sub_order.id,
        v_sub_order.status::text,
        v_sub_order.status::text,
        auth.uid(),
        'Return requested for item: ' || v_item.product_title || ' (Qty: ' || p_quantity || ', Reason: ' || p_reason || ')'
    );

    RETURN jsonb_build_object(
        'success', true,
        'return_request_id', v_return_id,
        'order_id', v_order.id,
        'sub_order_id', v_sub_order.id,
        'status', 'requested',
        'quantity', p_quantity,
        'refund_amount_paise', v_refund_paise,
        'resolution', v_resolution,
        'created_at', CURRENT_TIMESTAMP
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 5. ADMIN / SUPPORT REVIEW RETURN REQUEST
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_review_return_request(
    p_return_request_id UUID,
    p_action VARCHAR(50),
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_return RECORD;
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
    v_new_status return_request_status;
BEGIN
    IF NOT (has_role('admin_support') OR has_role('admin_super')) THEN
        RAISE EXCEPTION 'access_denied: only support or super administrators may review return requests'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_return
    FROM public.return_requests
    WHERE id = p_return_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'return_request_not_found: return request % does not exist', p_return_request_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_return.status NOT IN ('requested', 'support_review') THEN
        RAISE EXCEPTION 'invalid_return_transition: cannot review return request in % status', v_return.status
            USING ERRCODE = '22023';
    END IF;

    IF p_action = 'approve' THEN
        v_new_status := 'approved';
        UPDATE public.return_requests
        SET
            status = v_new_status,
            reviewed_by = auth.uid(),
            updated_at = v_now
        WHERE id = p_return_request_id;
    ELSIF p_action = 'reject' THEN
        v_new_status := 'rejected';
        UPDATE public.return_requests
        SET
            status = v_new_status,
            reviewed_by = auth.uid(),
            rejected_at = v_now,
            rejection_reason = COALESCE(p_notes, 'Rejected by support audit'),
            updated_at = v_now
        WHERE id = p_return_request_id;
    ELSIF p_action = 'hold_review' THEN
        v_new_status := 'support_review';
        UPDATE public.return_requests
        SET
            status = v_new_status,
            reviewed_by = auth.uid(),
            updated_at = v_now
        WHERE id = p_return_request_id;
    ELSE
        RAISE EXCEPTION 'invalid_review_action: action must be approve, reject, or hold_review'
            USING ERRCODE = '22023';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'return_request_id', v_return.id,
        'status', v_new_status,
        'reviewed_by', auth.uid(),
        'updated_at', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 6. ADMIN UPDATE RETURN LOGISTICS
-- Moves reverse logistics through: pickup_scheduled -> in_transit -> hub_received
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_update_return_logistics(
    p_return_request_id UUID,
    p_carrier VARCHAR(100),
    p_awb VARCHAR(100),
    p_status VARCHAR(50)
)
RETURNS JSONB AS $$
DECLARE
    v_return RECORD;
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
    v_carrier VARCHAR(100);
    v_awb VARCHAR(100);
BEGIN
    IF NOT (has_role('admin_support') OR has_role('admin_super')) THEN
        RAISE EXCEPTION 'access_denied: only support or super administrators may update reverse logistics'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_return
    FROM public.return_requests
    WHERE id = p_return_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'return_request_not_found: return request does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    v_carrier := COALESCE(NULLIF(TRIM(p_carrier), ''), v_return.return_carrier);
    v_awb := COALESCE(NULLIF(TRIM(p_awb), ''), v_return.return_awb);

    IF p_status = 'pickup_scheduled' THEN
        IF v_return.status != 'approved' THEN
            RAISE EXCEPTION 'invalid_return_transition: pickup can only be scheduled for approved returns'
                USING ERRCODE = '22023';
        END IF;

        IF v_carrier IS NULL OR v_awb IS NULL THEN
            RAISE EXCEPTION 'missing_reverse_logistics: carrier and AWB are mandatory when scheduling pickup'
                USING ERRCODE = '22023';
        END IF;

        UPDATE public.return_requests
        SET
            status = 'pickup_scheduled',
            return_carrier = v_carrier,
            return_awb = v_awb,
            pickup_scheduled_at = COALESCE(pickup_scheduled_at, v_now),
            updated_at = v_now
        WHERE id = p_return_request_id;

    ELSIF p_status = 'in_transit' THEN
        IF v_return.status NOT IN ('pickup_scheduled', 'approved') THEN
            RAISE EXCEPTION 'invalid_return_transition: cannot transition to in_transit from %', v_return.status
                USING ERRCODE = '22023';
        END IF;

        UPDATE public.return_requests
        SET
            status = 'in_transit',
            in_transit_at = COALESCE(in_transit_at, v_now),
            updated_at = v_now
        WHERE id = p_return_request_id;

    ELSIF p_status = 'hub_received' THEN
        IF v_return.status != 'in_transit' THEN
            RAISE EXCEPTION 'invalid_return_transition: return must be in_transit before being received at hub'
                USING ERRCODE = '22023';
        END IF;

        UPDATE public.return_requests
        SET
            status = 'hub_received',
            hub_received_at = COALESCE(hub_received_at, v_now),
            updated_at = v_now
        WHERE id = p_return_request_id;
    ELSE
        RAISE EXCEPTION 'invalid_logistics_status: status must be pickup_scheduled, in_transit, or hub_received'
            USING ERRCODE = '22023';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'return_request_id', v_return.id,
        'status', p_status,
        'return_carrier', v_carrier,
        'return_awb', v_awb,
        'updated_at', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 7. RECORD RETURN QC (CONDITION CHECK)
-- Authoritative check by Hub Inspector / Support Admin or Seller Atelier
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_record_return_qc(
    p_return_request_id UUID,
    p_qc_passed BOOLEAN,
    p_qc_notes TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_return RECORD;
    v_item RECORD;
    v_sub_order RECORD;
    v_is_admin BOOLEAN := FALSE;
    v_is_seller BOOLEAN := FALSE;
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
    v_new_status return_request_status;
BEGIN
    IF p_qc_notes IS NULL OR TRIM(p_qc_notes) = '' THEN
        RAISE EXCEPTION 'missing_qc_notes: QC inspection notes are mandatory'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_return
    FROM public.return_requests
    WHERE id = p_return_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'return_request_not_found: return request does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    SELECT * INTO v_item FROM public.order_items WHERE id = v_return.order_item_id;
    SELECT * INTO v_sub_order FROM public.seller_sub_orders WHERE id = v_item.sub_order_id;

    -- Caller authorization check: Admin OR Seller owning sub-order
    SELECT (has_role('admin_support') OR has_role('admin_super')) INTO v_is_admin;
    IF NOT v_is_admin THEN
        SELECT EXISTS (
            SELECT 1 FROM public.sellers
            WHERE user_id = auth.uid() AND id = v_sub_order.seller_id AND status = 'active'
        ) INTO v_is_seller;

        IF NOT v_is_seller THEN
            RAISE EXCEPTION 'access_denied: caller is not authorized to perform QC on this return'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Return must be received at hub/atelier before QC can occur
    IF v_return.status != 'hub_received' THEN
        RAISE EXCEPTION 'invalid_return_transition: QC can only be performed on hub_received returns (current: %)', v_return.status
            USING ERRCODE = '22023';
    END IF;

    IF p_qc_passed THEN
        v_new_status := 'qc_passed';
        UPDATE public.return_requests
        SET
            status = v_new_status,
            qc_notes = TRIM(p_qc_notes),
            qc_passed_at = v_now,
            updated_at = v_now
        WHERE id = p_return_request_id;
    ELSE
        v_new_status := 'qc_failed';
        UPDATE public.return_requests
        SET
            status = v_new_status,
            qc_notes = TRIM(p_qc_notes),
            qc_failed_at = v_now,
            updated_at = v_now
        WHERE id = p_return_request_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'return_request_id', v_return.id,
        'status', v_new_status,
        'qc_passed', p_qc_passed,
        'qc_notes', TRIM(p_qc_notes),
        'updated_at', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 8. ORDER PAYMENT LEDGER SETTLEMENT (DOUBLE-ENTRY POSTING)
-- Posts Event 1: Payment Capture & Initial Platform / Seller Escrow Allocation
-- ============================================================================

CREATE OR REPLACE FUNCTION public.post_order_payment_ledger_settlement(p_order_id UUID)
RETURNS UUID AS $$
DECLARE
    v_order RECORD;
    v_payment RECORD;
    v_sub RECORD;
    v_seller RECORD;
    v_group_id UUID := gen_random_uuid();
    v_commission_rate_bps INTEGER;
    v_sub_commission BIGINT;
    v_sub_tcs BIGINT;
    v_sub_tds BIGINT;
    v_sub_net_payable BIGINT;
    v_taxable_value BIGINT;
BEGIN
    SELECT * INTO v_order
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'order_not_found: order % does not exist', p_order_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Fetch captured payment
    SELECT * INTO v_payment
    FROM public.payment_transactions
    WHERE order_id = p_order_id AND status = 'captured'
    ORDER BY created_at DESC LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'no_captured_payment: order % does not have a captured payment', p_order_id
            USING ERRCODE = '55000';
    END IF;

    -- Idempotency check: already posted ledger entries for this order's payment
    IF EXISTS (
        SELECT 1 FROM public.financial_ledger_entries
        WHERE order_id = p_order_id AND payment_id = v_payment.id
    ) THEN
        SELECT transaction_group_id INTO v_group_id
        FROM public.financial_ledger_entries
        WHERE order_id = p_order_id AND payment_id = v_payment.id
        LIMIT 1;

        RETURN v_group_id;
    END IF;

    -- 1. DEBIT: platform_cash_escrow for total gross amount paid by customer
    INSERT INTO public.financial_ledger_entries (
        transaction_group_id, entry_type, account_type, amount_paise,
        currency, order_id, payment_id, reference_note
    ) VALUES (
        v_group_id, 'debit', 'platform_cash_escrow', v_order.total_amount_paise,
        'INR', v_order.id, v_payment.id, 'Customer payment captured for order ' || v_order.order_number
    );

    -- 2. CREDITS: For each seller sub-order, allocate seller escrow, commission, TCS, TDS
    FOR v_sub IN
        SELECT * FROM public.seller_sub_orders
        WHERE order_id = p_order_id
        FOR UPDATE
    LOOP
        SELECT * INTO v_seller FROM public.sellers WHERE id = v_sub.seller_id;
        v_commission_rate_bps := COALESCE(v_seller.commission_rate_bps, 1500); -- Default 15%

        v_taxable_value := (v_sub.subtotal_paise - v_sub.discount_paise);
        v_sub_commission := (v_taxable_value * v_commission_rate_bps) / 10000;
        v_sub_tcs := (v_taxable_value * 100) / 10000; -- Statutory 1% TCS
        v_sub_tds := (v_taxable_value * 100) / 10000; -- Statutory 1% TDS (Sec 194-O)
        v_sub_net_payable := v_taxable_value - v_sub_commission - v_sub_tcs - v_sub_tds - v_sub.logistics_deduction_paise;

        -- Update sub-order accounting values to match locked check constraints
        UPDATE public.seller_sub_orders
        SET
            commission_paise = v_sub_commission,
            tcs_paise = v_sub_tcs,
            tds_paise = v_sub_tds,
            net_seller_payable_paise = v_sub_net_payable,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_sub.id;

        -- Credit: seller_payable_escrow
        IF v_sub_net_payable > 0 THEN
            INSERT INTO public.financial_ledger_entries (
                transaction_group_id, entry_type, account_type, amount_paise,
                currency, order_id, sub_order_id, seller_id, payment_id, reference_note
            ) VALUES (
                v_group_id, 'credit', 'seller_payable_escrow', v_sub_net_payable,
                'INR', v_order.id, v_sub.id, v_sub.seller_id, v_payment.id,
                'Seller net payable escrow allocation for sub-order ' || v_sub.sub_order_number
            );
        END IF;

        -- Credit: platform_commission_revenue
        IF v_sub_commission > 0 THEN
            INSERT INTO public.financial_ledger_entries (
                transaction_group_id, entry_type, account_type, amount_paise,
                currency, order_id, sub_order_id, seller_id, payment_id, reference_note
            ) VALUES (
                v_group_id, 'credit', 'platform_commission_revenue', v_sub_commission,
                'INR', v_order.id, v_sub.id, v_sub.seller_id, v_payment.id,
                'Platform commission earned on sub-order ' || v_sub.sub_order_number
            );
        END IF;

        -- Credit: statutory_tcs_payable
        IF v_sub_tcs > 0 THEN
            INSERT INTO public.financial_ledger_entries (
                transaction_group_id, entry_type, account_type, amount_paise,
                currency, order_id, sub_order_id, seller_id, payment_id, reference_note
            ) VALUES (
                v_group_id, 'credit', 'statutory_tcs_payable', v_sub_tcs,
                'INR', v_order.id, v_sub.id, v_sub.seller_id, v_payment.id,
                'Statutory 1% TCS withheld on sub-order ' || v_sub.sub_order_number
            );
        END IF;

        -- Credit: statutory_tds_payable
        IF v_sub_tds > 0 THEN
            INSERT INTO public.financial_ledger_entries (
                transaction_group_id, entry_type, account_type, amount_paise,
                currency, order_id, sub_order_id, seller_id, payment_id, reference_note
            ) VALUES (
                v_group_id, 'credit', 'statutory_tds_payable', v_sub_tds,
                'INR', v_order.id, v_sub.id, v_sub.seller_id, v_payment.id,
                'Statutory 1% TDS withheld on sub-order ' || v_sub.sub_order_number
            );
        END IF;
    END LOOP;

    -- 3. Credit: platform_shipping_revenue (if customer paid shipping)
    IF v_order.shipping_fee_paise > 0 THEN
        INSERT INTO public.financial_ledger_entries (
            transaction_group_id, entry_type, account_type, amount_paise,
            currency, order_id, payment_id, reference_note
        ) VALUES (
            v_group_id, 'credit', 'platform_shipping_revenue', v_order.shipping_fee_paise,
            'INR', v_order.id, v_payment.id, 'Customer shipping fee revenue for order ' || v_order.order_number
        );
    END IF;

    -- Validate mathematical double-entry balance: SUM(debit) = SUM(credit)
    PERFORM public.validate_double_entry_balance(v_group_id);

    RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 9. FINANCE AUTHORIZE REFUND & LEDGER SETTLEMENT (STEP A)
-- Creates refund_transactions record, reverses seller/commission accrual
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_authorize_refund(
    p_return_request_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_return RECORD;
    v_item RECORD;
    v_sub_order RECORD;
    v_order RECORD;
    v_seller RECORD;
    v_payment RECORD;
    v_refund_id UUID;
    v_existing_refund RECORD;
    v_refund_paise BIGINT;
    v_total_refunded BIGINT;
    v_group_id UUID := gen_random_uuid();
    v_commission_rate_bps INTEGER;
    v_comm_reversed BIGINT;
    v_tcs_reversed BIGINT;
    v_tds_reversed BIGINT;
    v_seller_deduction BIGINT;
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
BEGIN
    IF NOT (has_role('admin_finance') OR has_role('admin_super')) THEN
        RAISE EXCEPTION 'access_denied: only finance or super administrators may authorize refunds'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_return
    FROM public.return_requests
    WHERE id = p_return_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'return_request_not_found: return request does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    -- Idempotency check: already authorized refund transaction
    SELECT * INTO v_existing_refund
    FROM public.refund_transactions
    WHERE return_request_id = p_return_request_id;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'refund_id', v_existing_refund.id,
            'return_request_id', p_return_request_id,
            'amount_paise', v_existing_refund.amount_paise,
            'status', v_existing_refund.status,
            'is_idempotent', true,
            'message', 'Refund already authorized'
        );
    END IF;

    IF v_return.status != 'qc_passed' THEN
        RAISE EXCEPTION 'invalid_refund_authorization: return must pass QC inspection before refund authorization (current: %)', v_return.status
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_item FROM public.order_items WHERE id = v_return.order_item_id;
    SELECT * INTO v_sub_order FROM public.seller_sub_orders WHERE id = v_item.sub_order_id;
    SELECT * INTO v_order FROM public.orders WHERE id = v_sub_order.order_id;
    SELECT * INTO v_seller FROM public.sellers WHERE id = v_sub_order.seller_id;

    -- Fetch payment
    SELECT * INTO v_payment
    FROM public.payment_transactions
    WHERE order_id = v_order.id AND status = 'captured'
    ORDER BY created_at DESC LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'no_captured_payment: cannot refund order without captured payment'
            USING ERRCODE = '55000';
    END IF;

    v_refund_paise := v_return.refund_amount_paise;

    -- Refund Cap Check: Total refunds cannot exceed captured order amount
    SELECT COALESCE(SUM(amount_paise), 0)
    INTO v_total_refunded
    FROM public.refund_transactions
    WHERE order_id = v_order.id AND status != 'failed';

    IF v_total_refunded + v_refund_paise > v_payment.amount_paise THEN
        RAISE EXCEPTION 'refund_exceeds_paid_amount: cumulative refunds (%) exceed original payment (%)',
            (v_total_refunded + v_refund_paise), v_payment.amount_paise
            USING ERRCODE = '22023';
    END IF;

    -- Ensure initial order payment ledger settlement was posted
    PERFORM public.post_order_payment_ledger_settlement(v_order.id);

    -- Calculate proportional commission and tax reversals
    v_commission_rate_bps := COALESCE(v_seller.commission_rate_bps, 1500);
    v_comm_reversed := (v_refund_paise * v_commission_rate_bps) / 10000;
    v_tcs_reversed := (v_refund_paise * 100) / 10000;
    v_tds_reversed := (v_refund_paise * 100) / 10000;
    v_seller_deduction := v_refund_paise - v_comm_reversed - v_tcs_reversed - v_tds_reversed;

    -- Handle Store Credit Resolution
    IF v_return.resolution = 'store_credit' THEN
        INSERT INTO public.customer_store_credits (
            user_id, return_request_id, amount_paise, balance_remaining_paise
        ) VALUES (
            v_order.user_id, v_return.id, v_refund_paise, v_refund_paise
        );

        INSERT INTO public.refund_transactions (
            return_request_id, order_id, payment_id, gateway_refund_id,
            amount_paise, reason, status, authorized_by
        ) VALUES (
            v_return.id, v_order.id, v_payment.id, 'sc_' || replace(v_return.id::text, '-', ''),
            v_refund_paise, 'Store credit issued for return', 'completed', auth.uid()
        ) RETURNING id INTO v_refund_id;

        UPDATE public.return_requests
        SET
            status = 'refunded',
            refund_authorized_at = v_now,
            refunded_at = v_now,
            updated_at = v_now
        WHERE id = p_return_request_id;

        -- Balanced Ledger Entries for Store Credit (Reverses Seller & establishes customer credit)
        INSERT INTO public.financial_ledger_entries (
            transaction_group_id, entry_type, account_type, amount_paise,
            currency, order_id, sub_order_id, seller_id, refund_id, reference_note
        ) VALUES (
            v_group_id, 'debit', 'seller_payable_escrow', v_seller_deduction,
            'INR', v_order.id, v_sub_order.id, v_seller.id, v_refund_id,
            'Seller payable reversed for store credit on return ' || v_return.id
        );

        IF v_comm_reversed > 0 THEN
            INSERT INTO public.financial_ledger_entries (
                transaction_group_id, entry_type, account_type, amount_paise,
                currency, order_id, sub_order_id, seller_id, refund_id, reference_note
            ) VALUES (
                v_group_id, 'debit', 'platform_commission_revenue', v_comm_reversed,
                'INR', v_order.id, v_sub_order.id, v_seller.id, v_refund_id,
                'Platform commission reversed for return ' || v_return.id
            );
        END IF;

        IF v_tcs_reversed > 0 THEN
            INSERT INTO public.financial_ledger_entries (
                transaction_group_id, entry_type, account_type, amount_paise,
                currency, order_id, sub_order_id, seller_id, refund_id, reference_note
            ) VALUES (
                v_group_id, 'debit', 'statutory_tcs_payable', v_tcs_reversed,
                'INR', v_order.id, v_sub_order.id, v_seller.id, v_refund_id,
                'TCS deduction reversed for return ' || v_return.id
            );
        END IF;

        IF v_tds_reversed > 0 THEN
            INSERT INTO public.financial_ledger_entries (
                transaction_group_id, entry_type, account_type, amount_paise,
                currency, order_id, sub_order_id, seller_id, refund_id, reference_note
            ) VALUES (
                v_group_id, 'debit', 'statutory_tds_payable', v_tds_reversed,
                'INR', v_order.id, v_sub_order.id, v_seller.id, v_refund_id,
                'TDS deduction reversed for return ' || v_return.id
            );
        END IF;

        INSERT INTO public.financial_ledger_entries (
            transaction_group_id, entry_type, account_type, amount_paise,
            currency, order_id, refund_id, reference_note
        ) VALUES (
            v_group_id, 'credit', 'customer_payable_refund', v_refund_paise,
            'INR', v_order.id, v_refund_id,
            'Store credit liability established for customer on return ' || v_return.id
        );

        PERFORM public.validate_double_entry_balance(v_group_id);

        RETURN jsonb_build_object(
            'success', true,
            'refund_id', v_refund_id,
            'return_request_id', v_return.id,
            'resolution', 'store_credit',
            'status', 'completed',
            'amount_paise', v_refund_paise,
            'authorized_by', auth.uid()
        );
    END IF;

    -- Handle Standard Payment Method Refund
    INSERT INTO public.refund_transactions (
        return_request_id, order_id, payment_id,
        amount_paise, reason, status, authorized_by
    ) VALUES (
        v_return.id, v_order.id, v_payment.id,
        v_refund_paise, COALESCE(p_notes, v_return.reason), 'initiated', auth.uid()
    ) RETURNING id INTO v_refund_id;

    UPDATE public.return_requests
    SET
        status = 'refund_authorized',
        refund_authorized_at = v_now,
        updated_at = v_now
    WHERE id = p_return_request_id;

    -- Double-Entry Ledger Posting: Step A (Establish Customer Payable & Reverse Seller Escrow)
    INSERT INTO public.financial_ledger_entries (
        transaction_group_id, entry_type, account_type, amount_paise,
        currency, order_id, sub_order_id, seller_id, refund_id, reference_note
    ) VALUES (
        v_group_id, 'debit', 'seller_payable_escrow', v_seller_deduction,
        'INR', v_order.id, v_sub_order.id, v_seller.id, v_refund_id,
        'Seller payable reduction for return ' || v_return.id
    );

    IF v_comm_reversed > 0 THEN
        INSERT INTO public.financial_ledger_entries (
            transaction_group_id, entry_type, account_type, amount_paise,
            currency, order_id, sub_order_id, seller_id, refund_id, reference_note
        ) VALUES (
            v_group_id, 'debit', 'platform_commission_revenue', v_comm_reversed,
            'INR', v_order.id, v_sub_order.id, v_seller.id, v_refund_id,
            'Platform commission reversal for return ' || v_return.id
        );
    END IF;

    IF v_tcs_reversed > 0 THEN
        INSERT INTO public.financial_ledger_entries (
            transaction_group_id, entry_type, account_type, amount_paise,
            currency, order_id, sub_order_id, seller_id, refund_id, reference_note
        ) VALUES (
            v_group_id, 'debit', 'statutory_tcs_payable', v_tcs_reversed,
            'INR', v_order.id, v_sub_order.id, v_seller.id, v_refund_id,
            'Statutory TCS reversal for return ' || v_return.id
        );
    END IF;

    IF v_tds_reversed > 0 THEN
        INSERT INTO public.financial_ledger_entries (
            transaction_group_id, entry_type, account_type, amount_paise,
            currency, order_id, sub_order_id, seller_id, refund_id, reference_note
        ) VALUES (
            v_group_id, 'debit', 'statutory_tds_payable', v_tds_reversed,
            'INR', v_order.id, v_sub_order.id, v_seller.id, v_refund_id,
            'Statutory TDS reversal for return ' || v_return.id
        );
    END IF;

    INSERT INTO public.financial_ledger_entries (
        transaction_group_id, entry_type, account_type, amount_paise,
        currency, order_id, refund_id, reference_note
    ) VALUES (
        v_group_id, 'credit', 'customer_payable_refund', v_refund_paise,
        'INR', v_order.id, v_refund_id,
        'Customer payable refund liability recognized for return ' || v_return.id
    );

    -- Validate double-entry balance
    PERFORM public.validate_double_entry_balance(v_group_id);

    RETURN jsonb_build_object(
        'success', true,
        'refund_id', v_refund_id,
        'return_request_id', v_return.id,
        'status', 'initiated',
        'amount_paise', v_refund_paise,
        'authorized_by', auth.uid(),
        'transaction_group_id', v_group_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 10. FINANCE PROCESS REFUND SETTLEMENT (STEP B)
-- Reconciles gateway refund payout, clears customer_payable_refund, updates status
-- ============================================================================

CREATE OR REPLACE FUNCTION public.finance_process_refund_settlement(
    p_refund_id UUID,
    p_gateway_refund_id VARCHAR(100) DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_refund RECORD;
    v_return RECORD;
    v_group_id UUID := gen_random_uuid();
    v_gateway_id VARCHAR(100);
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
BEGIN
    IF NOT (has_role('admin_finance') OR has_role('admin_super') OR current_user = 'service_role' OR session_user = 'service_role') THEN
        RAISE EXCEPTION 'access_denied: only finance administrators or service role may settle refunds'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_refund
    FROM public.refund_transactions
    WHERE id = p_refund_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'refund_transaction_not_found: refund transaction does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_refund.status = 'completed' THEN
        RETURN jsonb_build_object(
            'success', true,
            'refund_id', v_refund.id,
            'gateway_refund_id', v_refund.gateway_refund_id,
            'status', 'completed',
            'amount_paise', v_refund.amount_paise,
            'is_idempotent', true,
            'message', 'Refund already completed'
        );
    END IF;

    v_gateway_id := COALESCE(NULLIF(TRIM(p_gateway_refund_id), ''), 'rfnd_sim_' || replace(p_refund_id::text, '-', ''));

    -- Update refund transaction to completed
    UPDATE public.refund_transactions
    SET
        status = 'completed',
        gateway_refund_id = v_gateway_id,
        updated_at = v_now
    WHERE id = p_refund_id;

    -- Update return request to refunded
    IF v_refund.return_request_id IS NOT NULL THEN
        UPDATE public.return_requests
        SET
            status = 'refunded',
            refunded_at = v_now,
            updated_at = v_now
        WHERE id = v_refund.return_request_id;
    END IF;

    -- Double-Entry Ledger Step B: Disburse cash from escrow and clear customer payable
    INSERT INTO public.financial_ledger_entries (
        transaction_group_id, entry_type, account_type, amount_paise,
        currency, order_id, refund_id, reference_note
    ) VALUES (
        v_group_id, 'debit', 'customer_payable_refund', v_refund.amount_paise,
        'INR', v_refund.order_id, v_refund.id,
        'Customer refund payable cleared via gateway disburse ' || v_gateway_id
    );

    INSERT INTO public.financial_ledger_entries (
        transaction_group_id, entry_type, account_type, amount_paise,
        currency, order_id, refund_id, reference_note
    ) VALUES (
        v_group_id, 'credit', 'platform_cash_escrow', v_refund.amount_paise,
        'INR', v_refund.order_id, v_refund.id,
        'Platform escrow cash outflow for refund disburse ' || v_gateway_id
    );

    PERFORM public.validate_double_entry_balance(v_group_id);

    RETURN jsonb_build_object(
        'success', true,
        'refund_id', v_refund.id,
        'gateway_refund_id', v_gateway_id,
        'status', 'completed',
        'amount_paise', v_refund.amount_paise,
        'is_idempotent', false,
        'settled_at', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 11. GENERATE SELLER PAYOUT STATEMENT (WITH 7-DAY RETURN HOLD & KYC GATES)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.generate_seller_payout_statement(
    p_seller_id UUID,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS JSONB AS $$
DECLARE
    v_seller RECORD;
    v_is_eligible BOOLEAN;
    v_existing_stmt RECORD;
    v_statement_id UUID;
    v_statement_num VARCHAR(50);
    v_gross_sales BIGINT := 0;
    v_commission BIGINT := 0;
    v_tcs BIGINT := 0;
    v_tds BIGINT := 0;
    v_logistics BIGINT := 0;
    v_refunds BIGINT := 0;
    v_net_payout BIGINT := 0;
    v_sub RECORD;
BEGIN
    IF NOT (has_role('admin_finance') OR has_role('admin_super')) THEN
        RAISE EXCEPTION 'access_denied: only finance or super administrators may generate payout statements'
            USING ERRCODE = '42501';
    END IF;

    IF p_period_end < p_period_start THEN
        RAISE EXCEPTION 'invalid_period: settlement period end date must be on or after start date'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_seller FROM public.sellers WHERE id = p_seller_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'seller_not_found: seller % does not exist', p_seller_id
            USING ERRCODE = 'P0002';
    END IF;

    -- 1. P4 Authoritative KYC Payout Gate
    v_is_eligible := public.is_seller_payout_eligible(p_seller_id);
    IF NOT v_is_eligible THEN
        RAISE EXCEPTION 'seller_not_eligible_for_payout: seller has unverified KYC, missing PAN, or unverified bank accounts'
            USING ERRCODE = '42501';
    END IF;

    -- Idempotency check: statement for this period already exists
    SELECT * INTO v_existing_stmt
    FROM public.payout_statements
    WHERE seller_id = p_seller_id
      AND settlement_period_start = p_period_start
      AND settlement_period_end = p_period_end;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'statement_id', v_existing_stmt.id,
            'statement_number', v_existing_stmt.statement_number,
            'seller_id', p_seller_id,
            'net_payout_paise', v_existing_stmt.net_payout_paise,
            'status', v_existing_stmt.status,
            'is_idempotent', true,
            'message', 'Payout statement already generated for this period'
        );
    END IF;

    -- 2. Aggregate Delivered Sub-Orders where 7-Day Return Window Has Elapsed
    FOR v_sub IN
        SELECT *
        FROM public.seller_sub_orders
        WHERE seller_id = p_seller_id
          AND status = 'delivered'
          AND delivered_at IS NOT NULL
          AND (delivered_at + INTERVAL '7 days') <= (p_period_end::timestamp + INTERVAL '1 day')
          AND (delivered_at + INTERVAL '7 days') >= p_period_start::timestamp
    LOOP
        v_gross_sales := v_gross_sales + v_sub.subtotal_paise;
        v_commission := v_commission + v_sub.commission_paise;
        v_tcs := v_tcs + v_sub.tcs_paise;
        v_tds := v_tds + v_sub.tds_paise;
        v_logistics := v_logistics + v_sub.logistics_deduction_paise;
    END LOOP;

    -- 3. Deduct Refunded Amounts for this seller during this period
    SELECT COALESCE(SUM(rt.amount_paise), 0)
    INTO v_refunds
    FROM public.refund_transactions rt
    JOIN public.return_requests rr ON rt.return_request_id = rr.id
    JOIN public.order_items oi ON rr.order_item_id = oi.id
    JOIN public.seller_sub_orders sso ON oi.sub_order_id = sso.id
    WHERE sso.seller_id = p_seller_id
      AND rt.status = 'completed'
      AND rt.created_at >= p_period_start::timestamp
      AND rt.created_at <= (p_period_end::timestamp + INTERVAL '1 day');

    v_net_payout := v_gross_sales - v_commission - v_tcs - v_tds - v_logistics - v_refunds;
    IF v_net_payout < 0 THEN
        RAISE EXCEPTION 'negative_net_payout: deductions (%) exceed gross sales (%) for seller % in period',
            (v_commission + v_tcs + v_tds + v_logistics + v_refunds), v_gross_sales, p_seller_id
            USING ERRCODE = '22023';
    END IF;

    v_statement_num := 'STMT-' || to_char(p_period_end, 'YYYYMMDD') || '-' || substring(p_seller_id::text from 1 for 8);

    INSERT INTO public.payout_statements (
        statement_number, seller_id, settlement_period_start, settlement_period_end,
        gross_sales_paise, commission_deductions_paise, tcs_deductions_paise,
        tds_deductions_paise, logistics_deductions_paise, refund_deductions_paise,
        net_payout_paise, status, authorized_by
    ) VALUES (
        v_statement_num, p_seller_id, p_period_start, p_period_end,
        v_gross_sales, v_commission, v_tcs,
        v_tds, v_logistics, v_refunds,
        v_net_payout, 'statement_generated', auth.uid()
    ) RETURNING id INTO v_statement_id;

    RETURN jsonb_build_object(
        'success', true,
        'statement_id', v_statement_id,
        'statement_number', v_statement_num,
        'seller_id', p_seller_id,
        'settlement_period_start', p_period_start,
        'settlement_period_end', p_period_end,
        'gross_sales_paise', v_gross_sales,
        'commission_deductions_paise', v_commission,
        'tcs_deductions_paise', v_tcs,
        'tds_deductions_paise', v_tds,
        'logistics_deductions_paise', v_logistics,
        'refund_deductions_paise', v_refunds,
        'net_payout_paise', v_net_payout,
        'status', 'statement_generated',
        'authorized_by', auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 12. FINANCE SETTLE PAYOUT STATEMENT (EXECUTES FINAL LEDGER PAYOUT DISBURSEMENT)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.finance_settle_payout_statement(
    p_statement_id UUID,
    p_bank_utr VARCHAR(100) DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_stmt RECORD;
    v_group_id UUID := gen_random_uuid();
    v_utr VARCHAR(100);
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
BEGIN
    IF NOT (has_role('admin_finance') OR has_role('admin_super') OR current_user = 'service_role' OR session_user = 'service_role') THEN
        RAISE EXCEPTION 'access_denied: only finance administrators or service role may settle payout statements'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_stmt
    FROM public.payout_statements
    WHERE id = p_statement_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'payout_statement_not_found: statement % does not exist', p_statement_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_stmt.status = 'settled' THEN
        RETURN jsonb_build_object(
            'success', true,
            'statement_id', v_stmt.id,
            'bank_utr_number', v_stmt.bank_utr_number,
            'status', 'settled',
            'net_payout_paise', v_stmt.net_payout_paise,
            'is_idempotent', true,
            'message', 'Statement already settled'
        );
    END IF;

    v_utr := COALESCE(NULLIF(TRIM(p_bank_utr), ''), 'UTR-SIM-' || replace(p_statement_id::text, '-', ''));

    UPDATE public.payout_statements
    SET
        status = 'settled',
        bank_utr_number = v_utr,
        updated_at = v_now
    WHERE id = p_statement_id;

    -- Double-Entry Ledger Posting: Disburse seller net payout from escrow
    IF v_stmt.net_payout_paise > 0 THEN
        INSERT INTO public.financial_ledger_entries (
            transaction_group_id, entry_type, account_type, amount_paise,
            currency, seller_id, payout_id, reference_note
        ) VALUES (
            v_group_id, 'debit', 'seller_payable_escrow', v_stmt.net_payout_paise,
            'INR', v_stmt.seller_id, v_stmt.id,
            'Seller payable escrow settled via bank transfer UTR ' || v_utr
        );

        INSERT INTO public.financial_ledger_entries (
            transaction_group_id, entry_type, account_type, amount_paise,
            currency, seller_id, payout_id, reference_note
        ) VALUES (
            v_group_id, 'credit', 'platform_cash_escrow', v_stmt.net_payout_paise,
            'INR', v_stmt.seller_id, v_stmt.id,
            'Platform cash escrow outflow for seller payout UTR ' || v_utr
        );

        PERFORM public.validate_double_entry_balance(v_group_id);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'statement_id', v_stmt.id,
        'seller_id', v_stmt.seller_id,
        'net_payout_paise', v_stmt.net_payout_paise,
        'bank_utr_number', v_utr,
        'status', 'settled',
        'settled_at', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 13. INSPECTION RPCS (TENANCY RESTRICTED)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_customer_return_requests()
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_res JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'unauthenticated: user must be logged in' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', rr.id,
        'order_item_id', rr.order_item_id,
        'product_title', oi.product_title,
        'variant_sku', oi.variant_sku,
        'quantity', rr.quantity,
        'refund_amount_paise', rr.refund_amount_paise,
        'reason', rr.reason,
        'status', rr.status,
        'resolution', rr.resolution,
        'return_carrier', rr.return_carrier,
        'return_awb', rr.return_awb,
        'created_at', rr.created_at
    )), '[]'::jsonb)
    INTO v_res
    FROM public.return_requests rr
    JOIN public.order_items oi ON rr.order_item_id = oi.id
    WHERE rr.user_id = v_user_id;

    RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, auth, pg_temp;


CREATE OR REPLACE FUNCTION public.get_seller_return_requests(p_seller_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_admin BOOLEAN := FALSE;
    v_is_seller BOOLEAN := FALSE;
    v_res JSONB;
BEGIN
    SELECT (has_role('admin_super') OR has_role('admin_support') OR has_role('admin_finance')) INTO v_is_admin;

    IF NOT v_is_admin THEN
        SELECT EXISTS (
            SELECT 1 FROM public.sellers
            WHERE user_id = v_caller_id AND id = p_seller_id
        ) INTO v_is_seller;

        IF NOT v_is_seller THEN
            RAISE EXCEPTION 'access_denied: caller cannot inspect returns for another seller'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', rr.id,
        'order_item_id', rr.order_item_id,
        'product_title', oi.product_title,
        'variant_sku', oi.variant_sku,
        'quantity', rr.quantity,
        'refund_amount_paise', rr.refund_amount_paise,
        'status', rr.status,
        'qc_notes', rr.qc_notes,
        'created_at', rr.created_at
    )), '[]'::jsonb)
    INTO v_res
    FROM public.return_requests rr
    JOIN public.order_items oi ON rr.order_item_id = oi.id
    JOIN public.seller_sub_orders sso ON oi.sub_order_id = sso.id
    WHERE sso.seller_id = p_seller_id;

    RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, auth, pg_temp;


-- ============================================================================
-- 14. RPC & TABLE GRANTS
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.check_return_eligibility(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.customer_create_return_request(UUID, VARCHAR, TEXT, VARCHAR, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_return_request(UUID, VARCHAR, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_return_logistics(UUID, VARCHAR, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_record_return_qc(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_authorize_refund(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finance_process_refund_settlement(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_order_payment_ledger_settlement(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_seller_payout_statement(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finance_settle_payout_statement(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_customer_return_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_seller_return_requests(UUID) TO authenticated;

-- RLS on customer_store_credits
DO $$ BEGIN
    ALTER TABLE public.customer_store_credits ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DROP POLICY IF EXISTS p_store_credits_read ON public.customer_store_credits;
CREATE POLICY p_store_credits_read ON public.customer_store_credits
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        has_role('admin_super') OR
        has_role('admin_finance') OR
        has_role('admin_support')
    );

GRANT SELECT ON public.customer_store_credits TO authenticated;
GRANT SELECT ON public.return_requests TO authenticated;
GRANT SELECT ON public.refund_transactions TO authenticated;
GRANT SELECT ON public.payout_statements TO authenticated;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        EXECUTE 'GRANT ALL ON public.customer_store_credits TO service_role';
        EXECUTE 'GRANT ALL ON public.return_requests TO service_role';
        EXECUTE 'GRANT ALL ON public.refund_transactions TO service_role';
        EXECUTE 'GRANT ALL ON public.financial_ledger_entries TO service_role';
        EXECUTE 'GRANT ALL ON public.payout_statements TO service_role';
    END IF;
END $$;
