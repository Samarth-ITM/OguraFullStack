-- OGURA P4: SELLER ONBOARDING + KYC + PAYOUT GATE
-- Source: 20260915000003_ogura_p4_seller_onboarding_kyc_payout_gate.sql (applied verbatim)

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sellers' AND column_name = 'razorpay_account_id') THEN
        ALTER TABLE public.sellers ADD COLUMN razorpay_account_id VARCHAR(100) DEFAULT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sellers' AND column_name = 'approved_by') THEN
        ALTER TABLE public.sellers ADD COLUMN approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sellers' AND column_name = 'approved_at') THEN
        ALTER TABLE public.sellers ADD COLUMN approved_at TIMESTAMPTZ DEFAULT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sellers' AND column_name = 'suspended_reason') THEN
        ALTER TABLE public.sellers ADD COLUMN suspended_reason TEXT DEFAULT NULL;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.enforce_seller_lifecycle()
RETURNS TRIGGER AS $$
DECLARE
    v_is_super BOOLEAN;
    v_is_finance BOOLEAN;
BEGIN
    v_is_super := public.has_role('admin_super');
    v_is_finance := public.has_role('admin_finance');

    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF NOT v_is_super THEN
            RAISE EXCEPTION 'insufficient_privilege: only admin_super is authorized to mutate seller status'
                USING ERRCODE = '42501';
        END IF;

        IF OLD.status = 'application' AND NEW.status NOT IN ('under_review', 'active') THEN
            RAISE EXCEPTION 'invalid_transition: seller cannot transition from application to %', NEW.status;
        ELSIF OLD.status = 'under_review' AND NEW.status NOT IN ('active', 'application') THEN
            RAISE EXCEPTION 'invalid_transition: seller cannot transition from under_review to %', NEW.status;
        ELSIF OLD.status = 'active' AND NEW.status NOT IN ('suspended', 'terminated') THEN
            RAISE EXCEPTION 'invalid_transition: active seller can only transition to suspended or terminated';
        ELSIF OLD.status = 'suspended' AND NEW.status NOT IN ('active', 'terminated') THEN
            RAISE EXCEPTION 'invalid_transition: suspended seller can only be reactivated or terminated';
        ELSIF OLD.status = 'terminated' THEN
            RAISE EXCEPTION 'invalid_transition: terminated seller is in a final state and cannot be transitioned';
        END IF;

        IF NEW.status = 'active' AND OLD.status != 'active' THEN
            NEW.approved_at := CURRENT_TIMESTAMP;
            NEW.approved_by := auth.uid();
            NEW.suspended_reason := NULL;
        ELSIF NEW.status = 'suspended' AND OLD.status != 'suspended' THEN
            NULL;
        ELSIF NEW.status = 'active' AND OLD.status = 'suspended' THEN
            NEW.suspended_reason := NULL;
        END IF;
    END IF;

    IF NEW.commission_rate_bps IS DISTINCT FROM OLD.commission_rate_bps THEN
        IF NOT (v_is_super OR v_is_finance) THEN
            RAISE EXCEPTION 'insufficient_privilege: only admin_super or admin_finance can modify commission_rate_bps'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF NOT v_is_super THEN
        NEW.approved_by := OLD.approved_by;
        NEW.approved_at := OLD.approved_at;
        NEW.suspended_reason := OLD.suspended_reason;
        NEW.razorpay_account_id := OLD.razorpay_account_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_enforce_seller_lifecycle ON public.sellers;
CREATE TRIGGER trg_enforce_seller_lifecycle
BEFORE UPDATE ON public.sellers
FOR EACH ROW EXECUTE FUNCTION public.enforce_seller_lifecycle();

CREATE OR REPLACE FUNCTION public.enforce_kyc_document_security()
RETURNS TRIGGER AS $$
DECLARE
    v_is_finance BOOLEAN;
    v_is_super BOOLEAN;
BEGIN
    v_is_finance := public.has_role('admin_finance');
    v_is_super := public.has_role('admin_super');

    IF (NEW.verification_status IS DISTINCT FROM OLD.verification_status) 
       OR (NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason) THEN
        IF NOT (v_is_finance OR v_is_super) THEN
            RAISE EXCEPTION 'insufficient_privilege: only admin_finance or admin_super can review KYC documents'
                USING ERRCODE = '42501';
        END IF;

        IF NEW.verification_status IN ('verified', 'rejected') THEN
            NEW.reviewed_by := auth.uid();
            NEW.reviewed_at := CURRENT_TIMESTAMP;
        END IF;
    ELSE
        IF NEW.document_url IS DISTINCT FROM OLD.document_url THEN
            NEW.verification_status := 'pending'::kyc_verification_status;
            NEW.rejection_reason := NULL;
            NEW.reviewed_by := NULL;
            NEW.reviewed_at := NULL;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_enforce_kyc_document_security ON public.seller_kyc_documents;
CREATE TRIGGER trg_enforce_kyc_document_security
BEFORE UPDATE ON public.seller_kyc_documents
FOR EACH ROW EXECUTE FUNCTION public.enforce_kyc_document_security();

CREATE OR REPLACE FUNCTION public.enforce_bank_account_security()
RETURNS TRIGGER AS $$
DECLARE
    v_is_finance BOOLEAN;
    v_is_super BOOLEAN;
BEGIN
    v_is_finance := public.has_role('admin_finance');
    v_is_super := public.has_role('admin_super');

    IF (NEW.is_verified IS DISTINCT FROM OLD.is_verified)
       OR (NEW.penny_drop_status IS DISTINCT FROM OLD.penny_drop_status)
       OR (NEW.razorpay_fund_account_id IS DISTINCT FROM OLD.razorpay_fund_account_id) THEN
        IF NOT (v_is_finance OR v_is_super) THEN
            RAISE EXCEPTION 'insufficient_privilege: only admin_finance or admin_super can verify bank accounts'
                USING ERRCODE = '42501';
        END IF;
    ELSE
        IF (NEW.account_number IS DISTINCT FROM OLD.account_number)
           OR (NEW.ifsc_code IS DISTINCT FROM OLD.ifsc_code)
           OR (NEW.beneficiary_name IS DISTINCT FROM OLD.beneficiary_name) THEN
            NEW.is_verified := false;
            NEW.penny_drop_status := 'pending';
            NEW.razorpay_fund_account_id := NULL;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_enforce_bank_account_security ON public.seller_bank_accounts;
CREATE TRIGGER trg_enforce_bank_account_security
BEFORE UPDATE ON public.seller_bank_accounts
FOR EACH ROW EXECUTE FUNCTION public.enforce_bank_account_security();

CREATE OR REPLACE FUNCTION public.apply_as_seller(
    p_business_name VARCHAR,
    p_legal_entity_name VARCHAR,
    p_seller_slug VARCHAR,
    p_gstin VARCHAR DEFAULT NULL,
    p_pan VARCHAR DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_caller_id UUID;
    v_seller_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'unauthenticated: user must be signed in to apply as seller'
            USING ERRCODE = '42501';
    END IF;

    IF EXISTS (SELECT 1 FROM public.sellers WHERE user_id = v_caller_id) THEN
        RAISE EXCEPTION 'duplicate_seller: user already has an active or pending seller profile';
    END IF;

    IF EXISTS (SELECT 1 FROM public.sellers WHERE seller_slug = p_seller_slug) THEN
        RAISE EXCEPTION 'duplicate_slug: seller_slug is already taken';
    END IF;

    INSERT INTO public.sellers (
        user_id,
        business_name,
        legal_entity_name,
        seller_slug,
        gstin,
        pan,
        status
    ) VALUES (
        v_caller_id,
        p_business_name,
        p_legal_entity_name,
        p_seller_slug,
        p_gstin,
        p_pan,
        'application'::seller_status
    )
    RETURNING id INTO v_seller_id;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_caller_id, 'seller'::user_role_type)
    ON CONFLICT (user_id, role) DO NOTHING;

    RETURN v_seller_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.approve_seller(p_seller_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_old_status seller_status;
    v_user_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.has_role('admin_super') THEN
        RAISE EXCEPTION 'insufficient_privilege: only admin_super is authorized to approve sellers (Gate 1)'
            USING ERRCODE = '42501';
    END IF;

    SELECT status, user_id INTO v_old_status, v_user_id
    FROM public.sellers
    WHERE id = p_seller_id;

    IF v_old_status IS NULL THEN
        RAISE EXCEPTION 'seller_not_found: seller with ID % does not exist', p_seller_id;
    END IF;

    IF v_old_status NOT IN ('application', 'under_review') THEN
        RAISE EXCEPTION 'invalid_state: seller in % status cannot be approved', v_old_status;
    END IF;

    UPDATE public.sellers
    SET status = 'active'::seller_status,
        approved_by = v_caller_id,
        approved_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_seller_id;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_user_id, 'seller'::user_role_type)
    ON CONFLICT (user_id, role) DO NOTHING;

    INSERT INTO public.admin_audit_logs (
        admin_id,
        action,
        entity_type,
        entity_id,
        previous_state,
        new_state
    ) VALUES (
        v_caller_id,
        'SELLER_APPROVED',
        'seller',
        p_seller_id::text,
        jsonb_build_object('status', v_old_status),
        jsonb_build_object('status', 'active', 'approved_by', v_caller_id)
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.suspend_seller(p_seller_id UUID, p_reason TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_old_status seller_status;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.has_role('admin_super') THEN
        RAISE EXCEPTION 'insufficient_privilege: only admin_super is authorized to suspend sellers'
            USING ERRCODE = '42501';
    END IF;

    SELECT status INTO v_old_status
    FROM public.sellers
    WHERE id = p_seller_id;

    IF v_old_status IS NULL THEN
        RAISE EXCEPTION 'seller_not_found: seller with ID % does not exist', p_seller_id;
    END IF;

    IF v_old_status = 'suspended' THEN
        RETURN true;
    END IF;

    UPDATE public.sellers
    SET status = 'suspended'::seller_status,
        suspended_reason = p_reason,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_seller_id;

    INSERT INTO public.admin_audit_logs (
        admin_id,
        action,
        entity_type,
        entity_id,
        previous_state,
        new_state
    ) VALUES (
        v_caller_id,
        'SELLER_SUSPENDED',
        'seller',
        p_seller_id::text,
        jsonb_build_object('status', v_old_status),
        jsonb_build_object('status', 'suspended', 'reason', p_reason)
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.reactivate_seller(p_seller_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_old_status seller_status;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.has_role('admin_super') THEN
        RAISE EXCEPTION 'insufficient_privilege: only admin_super is authorized to reactivate sellers'
            USING ERRCODE = '42501';
    END IF;

    SELECT status INTO v_old_status
    FROM public.sellers
    WHERE id = p_seller_id;

    IF v_old_status IS NULL THEN
        RAISE EXCEPTION 'seller_not_found: seller with ID % does not exist', p_seller_id;
    END IF;

    IF v_old_status != 'suspended' THEN
        RAISE EXCEPTION 'invalid_state: only suspended sellers can be reactivated';
    END IF;

    UPDATE public.sellers
    SET status = 'active'::seller_status,
        suspended_reason = NULL,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_seller_id;

    INSERT INTO public.admin_audit_logs (
        admin_id,
        action,
        entity_type,
        entity_id,
        previous_state,
        new_state
    ) VALUES (
        v_caller_id,
        'SELLER_REACTIVATED',
        'seller',
        p_seller_id::text,
        jsonb_build_object('status', v_old_status),
        jsonb_build_object('status', 'active')
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.review_seller_kyc_document(
    p_document_id UUID,
    p_status kyc_verification_status,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_old_status kyc_verification_status;
    v_seller_id UUID;
    v_doc_type VARCHAR(50);
BEGIN
    v_caller_id := auth.uid();
    IF NOT (public.has_role('admin_finance') OR public.has_role('admin_super')) THEN
        RAISE EXCEPTION 'insufficient_privilege: only admin_finance or admin_super can review KYC documents'
            USING ERRCODE = '42501';
    END IF;

    IF p_status NOT IN ('verified', 'rejected') THEN
        RAISE EXCEPTION 'invalid_status: review status must be verified or rejected';
    END IF;

    IF p_status = 'rejected' AND (p_rejection_reason IS NULL OR TRIM(p_rejection_reason) = '') THEN
        RAISE EXCEPTION 'rejection_reason_required: reason must be specified when rejecting KYC document';
    END IF;

    SELECT verification_status, seller_id, document_type
    INTO v_old_status, v_seller_id, v_doc_type
    FROM public.seller_kyc_documents
    WHERE id = p_document_id;

    IF v_old_status IS NULL THEN
        RAISE EXCEPTION 'document_not_found: KYC document % not found', p_document_id;
    END IF;

    UPDATE public.seller_kyc_documents
    SET verification_status = p_status,
        rejection_reason = CASE WHEN p_status = 'rejected' THEN p_rejection_reason ELSE NULL END,
        reviewed_by = v_caller_id,
        reviewed_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_document_id;

    INSERT INTO public.admin_audit_logs (
        admin_id,
        action,
        entity_type,
        entity_id,
        previous_state,
        new_state
    ) VALUES (
        v_caller_id,
        CASE WHEN p_status = 'verified' THEN 'KYC_DOCUMENT_VERIFIED' ELSE 'KYC_DOCUMENT_REJECTED' END,
        'seller_kyc_documents',
        p_document_id::text,
        jsonb_build_object('status', v_old_status, 'seller_id', v_seller_id, 'document_type', v_doc_type),
        jsonb_build_object('status', p_status, 'rejection_reason', p_rejection_reason)
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.verify_seller_bank_account(
    p_bank_account_id UUID,
    p_is_verified BOOLEAN,
    p_penny_drop_status VARCHAR,
    p_fund_account_id VARCHAR DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_old_verified BOOLEAN;
    v_seller_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF NOT (public.has_role('admin_finance') OR public.has_role('admin_super')) THEN
        RAISE EXCEPTION 'insufficient_privilege: only admin_finance or admin_super can verify bank accounts'
            USING ERRCODE = '42501';
    END IF;

    SELECT is_verified, seller_id
    INTO v_old_verified, v_seller_id
    FROM public.seller_bank_accounts
    WHERE id = p_bank_account_id;

    IF v_old_verified IS NULL THEN
        RAISE EXCEPTION 'bank_account_not_found: bank account % does not exist', p_bank_account_id;
    END IF;

    UPDATE public.seller_bank_accounts
    SET is_verified = p_is_verified,
        penny_drop_status = p_penny_drop_status,
        razorpay_fund_account_id = COALESCE(p_fund_account_id, razorpay_fund_account_id),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_bank_account_id;

    INSERT INTO public.admin_audit_logs (
        admin_id,
        action,
        entity_type,
        entity_id,
        previous_state,
        new_state
    ) VALUES (
        v_caller_id,
        CASE WHEN p_is_verified THEN 'BANK_ACCOUNT_VERIFIED' ELSE 'BANK_ACCOUNT_REJECTED' END,
        'seller_bank_accounts',
        p_bank_account_id::text,
        jsonb_build_object('is_verified', v_old_verified, 'seller_id', v_seller_id),
        jsonb_build_object('is_verified', p_is_verified, 'penny_drop_status', p_penny_drop_status, 'fund_account_id', p_fund_account_id)
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.set_seller_razorpay_account(
    p_seller_id UUID,
    p_razorpay_account_id VARCHAR(100)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_old_acc VARCHAR(100);
BEGIN
    v_caller_id := auth.uid();
    IF NOT (public.has_role('admin_finance') OR public.has_role('admin_super')) THEN
        RAISE EXCEPTION 'insufficient_privilege: only admin_finance or admin_super can set razorpay_account_id'
            USING ERRCODE = '42501';
    END IF;

    SELECT razorpay_account_id INTO v_old_acc
    FROM public.sellers
    WHERE id = p_seller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'seller_not_found: seller % does not exist', p_seller_id;
    END IF;

    UPDATE public.sellers
    SET razorpay_account_id = p_razorpay_account_id,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_seller_id;

    INSERT INTO public.admin_audit_logs (
        admin_id,
        action,
        entity_type,
        entity_id,
        previous_state,
        new_state
    ) VALUES (
        v_caller_id,
        'RAZORPAY_ACCOUNT_LINKED',
        'seller',
        p_seller_id::text,
        jsonb_build_object('razorpay_account_id', v_old_acc),
        jsonb_build_object('razorpay_account_id', p_razorpay_account_id)
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.is_seller_payout_eligible(p_seller_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_status seller_status;
    v_has_gstin BOOLEAN;
    v_has_verified_pan BOOLEAN;
    v_has_verified_gst BOOLEAN;
    v_has_unverified_docs BOOLEAN;
    v_has_verified_bank BOOLEAN;
BEGIN
    SELECT status, (gstin IS NOT NULL AND TRIM(gstin) != '')
    INTO v_status, v_has_gstin
    FROM public.sellers
    WHERE id = p_seller_id;

    IF v_status IS DISTINCT FROM 'active'::seller_status THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.seller_kyc_documents
        WHERE seller_id = p_seller_id
          AND document_type = 'pan_card'
          AND verification_status = 'verified'::kyc_verification_status
    ) INTO v_has_verified_pan;

    IF NOT v_has_verified_pan THEN
        RETURN false;
    END IF;

    IF v_has_gstin THEN
        SELECT EXISTS (
            SELECT 1 FROM public.seller_kyc_documents
            WHERE seller_id = p_seller_id
              AND document_type = 'gst_certificate'
              AND verification_status = 'verified'::kyc_verification_status
        ) INTO v_has_verified_gst;

        IF NOT v_has_verified_gst THEN
            RETURN false;
        END IF;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.seller_kyc_documents
        WHERE seller_id = p_seller_id
          AND verification_status IN ('pending'::kyc_verification_status, 'rejected'::kyc_verification_status)
    ) INTO v_has_unverified_docs;

    IF v_has_unverified_docs THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.seller_bank_accounts
        WHERE seller_id = p_seller_id
          AND is_verified = true
          AND penny_drop_status = 'success'
    ) INTO v_has_verified_bank;

    IF NOT v_has_verified_bank THEN
        RETURN false;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.seller_bank_accounts
        WHERE seller_id = p_seller_id
          AND is_verified = true
          AND penny_drop_status = 'success'
          AND razorpay_fund_account_id IS NOT NULL
          AND TRIM(razorpay_fund_account_id) != ''
    ) AND NOT EXISTS (
        SELECT 1 FROM public.sellers
        WHERE id = p_seller_id
          AND razorpay_account_id IS NOT NULL
          AND TRIM(razorpay_account_id) != ''
    ) THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP POLICY IF EXISTS p_sellers_read ON public.sellers;
CREATE POLICY p_sellers_read ON public.sellers FOR SELECT
USING (
    user_id = auth.uid()
    OR status = 'active'::seller_status
    OR public.has_role('admin_super')
    OR public.has_role('admin_finance')
    OR public.has_role('admin_catalog')
    OR public.has_role('admin_viewer')
);

DROP POLICY IF EXISTS p_sellers_insert ON public.sellers;
CREATE POLICY p_sellers_insert ON public.sellers FOR INSERT
WITH CHECK (
    user_id = auth.uid() 
    AND status = 'application'::seller_status
);

DROP POLICY IF EXISTS p_sellers_update ON public.sellers;
CREATE POLICY p_sellers_update ON public.sellers FOR UPDATE
USING (
    user_id = auth.uid() 
    OR public.has_role('admin_super')
    OR public.has_role('admin_finance')
)
WITH CHECK (
    user_id = auth.uid() 
    OR public.has_role('admin_super')
    OR public.has_role('admin_finance')
);

DROP POLICY IF EXISTS p_kyc_read ON public.seller_kyc_documents;
CREATE POLICY p_kyc_read ON public.seller_kyc_documents FOR SELECT
USING (
    seller_id IN (SELECT id FROM public.sellers WHERE user_id = auth.uid())
    OR public.has_role('admin_finance')
    OR public.has_role('admin_super')
);

DROP POLICY IF EXISTS p_kyc_seller_insert ON public.seller_kyc_documents;
CREATE POLICY p_kyc_seller_insert ON public.seller_kyc_documents FOR INSERT
WITH CHECK (
    seller_id IN (SELECT id FROM public.sellers WHERE user_id = auth.uid())
    AND verification_status = 'pending'::kyc_verification_status
);

DROP POLICY IF EXISTS p_kyc_finance_update ON public.seller_kyc_documents;
CREATE POLICY p_kyc_finance_update ON public.seller_kyc_documents FOR UPDATE
USING (
    seller_id IN (SELECT id FROM public.sellers WHERE user_id = auth.uid())
    OR public.has_role('admin_finance')
    OR public.has_role('admin_super')
)
WITH CHECK (
    seller_id IN (SELECT id FROM public.sellers WHERE user_id = auth.uid())
    OR public.has_role('admin_finance')
    OR public.has_role('admin_super')
);

DROP POLICY IF EXISTS p_bank_read ON public.seller_bank_accounts;
CREATE POLICY p_bank_read ON public.seller_bank_accounts FOR SELECT
USING (
    seller_id IN (SELECT id FROM public.sellers WHERE user_id = auth.uid())
    OR public.has_role('admin_finance')
    OR public.has_role('admin_super')
);

DROP POLICY IF EXISTS p_bank_insert ON public.seller_bank_accounts;
CREATE POLICY p_bank_insert ON public.seller_bank_accounts FOR INSERT
WITH CHECK (
    seller_id IN (SELECT id FROM public.sellers WHERE user_id = auth.uid())
    AND is_verified = false
    AND penny_drop_status = 'pending'
);

DROP POLICY IF EXISTS p_bank_write ON public.seller_bank_accounts;
CREATE POLICY p_bank_write ON public.seller_bank_accounts FOR UPDATE
USING (
    seller_id IN (SELECT id FROM public.sellers WHERE user_id = auth.uid())
    OR public.has_role('admin_finance')
    OR public.has_role('admin_super')
)
WITH CHECK (
    seller_id IN (SELECT id FROM public.sellers WHERE user_id = auth.uid())
    OR public.has_role('admin_finance')
    OR public.has_role('admin_super')
);

GRANT EXECUTE ON FUNCTION public.apply_as_seller(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_seller(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.suspend_seller(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reactivate_seller(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_seller_kyc_document(UUID, kyc_verification_status, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_seller_bank_account(UUID, BOOLEAN, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_seller_razorpay_account(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_seller_payout_eligible(UUID) TO authenticated, anon;