-- ============================================================================
-- OGURA PHASE 4 CRITICAL TEST SUITE: SELLER ONBOARDING, KYC & PAYOUT GATE
-- File: supabase/tests/p4_seller_onboarding_kyc_test.sql
-- ============================================================================

-- 0. Ensure test roles and fixture state
DO $$ BEGIN
    CREATE ROLE authenticated NOLOGIN;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE ROLE anon NOLOGIN;
EXCEPTION WHEN duplicate_object THEN null; END $$;

GRANT USAGE ON SCHEMA public, auth TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO authenticated, anon;

BEGIN;

-- Clean up previous P4 test records
DELETE FROM public.products WHERE slug = 'alpha-p4-test-gown';
DELETE FROM public.brands WHERE slug IN ('alpha-p4-couture-brand', 'beta-p4-couture-brand');
DELETE FROM public.seller_bank_accounts WHERE account_number LIKE 'TESTP4ACC%';
DELETE FROM public.seller_kyc_documents WHERE document_url LIKE 'https://ogura.test/p4_%';
DELETE FROM public.sellers WHERE seller_slug IN ('test-p4-seller-alpha', 'test-p4-seller-beta');

-- Seed Fresh P4 Auth Users
INSERT INTO auth.users (id, email) VALUES
    ('a4000000-0000-0000-0000-000000000001', 'seller_alpha_p4@ogura.test'),
    ('a4000000-0000-0000-0000-000000000002', 'seller_beta_p4@ogura.test'),
    ('a4000000-0000-0000-0000-000000000003', 'super_admin_p4@ogura.test'),
    ('a4000000-0000-0000-0000-000000000004', 'finance_admin_p4@ogura.test'),
    ('a4000000-0000-0000-0000-000000000005', 'catalog_admin_p4@ogura.test'),
    ('a4000000-0000-0000-0000-000000000006', 'viewer_admin_p4@ogura.test')
ON CONFLICT (id) DO NOTHING;

-- Seed Profiles
INSERT INTO public.profiles (id, full_name, email, phone) VALUES
    ('a4000000-0000-0000-0000-000000000001', 'P4 Seller Alpha', 'seller_alpha_p4@ogura.test', '+919888800001'),
    ('a4000000-0000-0000-0000-000000000002', 'P4 Seller Beta', 'seller_beta_p4@ogura.test', '+919888800002'),
    ('a4000000-0000-0000-0000-000000000003', 'P4 Super Admin', 'super_admin_p4@ogura.test', '+919888800003'),
    ('a4000000-0000-0000-0000-000000000004', 'P4 Finance Admin', 'finance_admin_p4@ogura.test', '+919888800004'),
    ('a4000000-0000-0000-0000-000000000005', 'P4 Catalog Admin', 'catalog_admin_p4@ogura.test', '+919888800005'),
    ('a4000000-0000-0000-0000-000000000006', 'P4 Viewer Admin', 'viewer_admin_p4@ogura.test', '+919888800006')
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

-- Seed Roles
DELETE FROM public.user_roles WHERE user_id IN (
    'a4000000-0000-0000-0000-000000000001',
    'a4000000-0000-0000-0000-000000000002',
    'a4000000-0000-0000-0000-000000000003',
    'a4000000-0000-0000-0000-000000000004',
    'a4000000-0000-0000-0000-000000000005',
    'a4000000-0000-0000-0000-000000000006'
);

INSERT INTO public.user_roles (user_id, role) VALUES
    ('a4000000-0000-0000-0000-000000000001', 'customer'),
    ('a4000000-0000-0000-0000-000000000002', 'customer'),
    ('a4000000-0000-0000-0000-000000000003', 'admin_super'),
    ('a4000000-0000-0000-0000-000000000004', 'admin_finance'),
    ('a4000000-0000-0000-0000-000000000005', 'admin_catalog'),
    ('a4000000-0000-0000-0000-000000000006', 'admin_viewer');

COMMIT;

-- ============================================================================
-- TEST A: SELLER IDENTITY & TENANCY ISOLATION
-- ============================================================================
DO $$
DECLARE
    v_seller_alpha_id UUID;
    v_seller_beta_id UUID;
    v_rows INTEGER;
BEGIN
    SET ROLE authenticated;

    -- User A applies as seller
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000001';
    v_seller_alpha_id := public.apply_as_seller(
        'Alpha Atelier P4',
        'Alpha Luxury Creations LLP',
        'test-p4-seller-alpha',
        '27ABCDE1234F1Z5',
        'ABCDE1234F'
    );

    IF v_seller_alpha_id IS NULL THEN
        RAISE EXCEPTION 'A.1 FAIL: apply_as_seller returned null';
    END IF;

    -- Verify default status is 'application'
    IF NOT EXISTS (SELECT 1 FROM public.sellers WHERE id = v_seller_alpha_id AND status = 'application') THEN
        RAISE EXCEPTION 'A.2 FAIL: seller created with status other than application';
    END IF;

    -- User B applies as seller
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000002';
    v_seller_beta_id := public.apply_as_seller(
        'Beta Atelier P4',
        'Beta Couturiers LLP',
        'test-p4-seller-beta',
        '27XYZAB9876C1Z3',
        'XYZAB9876C'
    );

    -- Check Tenancy Isolation: Seller A cannot update Seller B
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000001';
    UPDATE public.sellers SET business_name = 'Alpha Hacked Beta' WHERE id = v_seller_beta_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows > 0 THEN
        RAISE EXCEPTION 'A.3 FAIL: Seller A successfully modified Seller B';
    END IF;

    RAISE NOTICE 'ASSERTION PASS A: Seller Identity & Tenancy Isolation';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST B: SELLER APPROVAL (GATE 1)
-- ============================================================================
DO $$
DECLARE
    v_seller_alpha_id UUID;
    v_threw BOOLEAN;
BEGIN
    SELECT id INTO v_seller_alpha_id FROM public.sellers WHERE seller_slug = 'test-p4-seller-alpha';

    SET ROLE authenticated;

    -- B.1 Seller attempts self-activation -> MUST FAIL
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000001';
    v_threw := false;
    BEGIN
        UPDATE public.sellers SET status = 'active' WHERE id = v_seller_alpha_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'B.1 FAIL: seller self-activated status without exception';
    END IF;

    -- B.2 Seller attempts self-suspension / self-termination -> MUST FAIL
    v_threw := false;
    BEGIN
        UPDATE public.sellers SET status = 'suspended' WHERE id = v_seller_alpha_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'B.2.a FAIL: seller self-suspended without exception';
    END IF;

    v_threw := false;
    BEGIN
        UPDATE public.sellers SET status = 'terminated' WHERE id = v_seller_alpha_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'B.2.b FAIL: seller self-terminated without exception';
    END IF;

    -- B.3 Unauthorized roles attempt Gate 1 approval -> MUST FAIL
    -- Catalog Admin
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000005';
    v_threw := false;
    BEGIN
        PERFORM public.approve_seller(v_seller_alpha_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'B.3.a FAIL: catalog admin approved seller Gate 1';
    END IF;

    -- Support Admin
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000006'; -- Viewer/Support
    v_threw := false;
    BEGIN
        PERFORM public.approve_seller(v_seller_alpha_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'B.3.b FAIL: viewer/support admin approved seller Gate 1';
    END IF;

    -- Finance Admin
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000004';
    v_threw := false;
    BEGIN
        PERFORM public.approve_seller(v_seller_alpha_id);
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'B.3.c FAIL: admin_finance approved seller Gate 1';
    END IF;

    -- B.4 Illegal state transitions tested under Super Admin context
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000003';
    -- application -> terminated (MUST FAIL)
    v_threw := false;
    BEGIN
        UPDATE public.sellers SET status = 'terminated' WHERE id = v_seller_alpha_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'B.4.a FAIL: direct application -> terminated transition was permitted';
    END IF;

    -- B.5 Authorized admin (admin_super) approves seller -> MUST SUCCEED
    PERFORM public.approve_seller(v_seller_alpha_id);

    IF NOT EXISTS (SELECT 1 FROM public.sellers WHERE id = v_seller_alpha_id AND status = 'active' AND approved_by = 'a4000000-0000-0000-0000-000000000003') THEN
        RAISE EXCEPTION 'B.5 FAIL: admin_super could not activate seller';
    END IF;

    -- B.6 Active -> application (MUST FAIL)
    v_threw := false;
    BEGIN
        UPDATE public.sellers SET status = 'application' WHERE id = v_seller_alpha_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'B.6 FAIL: active -> application transition was permitted';
    END IF;

    RAISE NOTICE 'ASSERTION PASS B: Gate 1 Seller Approval & Lifecycle State Machine';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST C: KYC DOCUMENT SUBMISSION & ISOLATION
-- ============================================================================
DO $$
DECLARE
    v_seller_alpha_id UUID;
    v_seller_beta_id UUID;
    v_doc_pan_id UUID;
    v_threw BOOLEAN;
    v_count INTEGER;
BEGIN
    SELECT id INTO v_seller_alpha_id FROM public.sellers WHERE seller_slug = 'test-p4-seller-alpha';
    SELECT id INTO v_seller_beta_id FROM public.sellers WHERE seller_slug = 'test-p4-seller-beta';

    SET ROLE authenticated;

    -- C.1 Seller Alpha submits PAN document
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000001';
    INSERT INTO public.seller_kyc_documents (
        seller_id,
        document_type,
        document_url,
        verification_status
    ) VALUES (
        v_seller_alpha_id,
        'pan_card',
        'https://ogura.test/p4_pan_alpha.pdf',
        'pending'
    ) RETURNING id INTO v_doc_pan_id;

    -- C.2 Seller Beta attempts to read Seller Alpha KYC -> MUST RETURN 0 ROWS
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000002';
    SELECT count(*) INTO v_count FROM public.seller_kyc_documents WHERE seller_id = v_seller_alpha_id;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'C.2 FAIL: Seller Beta read Seller Alpha KYC documents';
    END IF;

    -- C.3 Anonymous attempts to read KYC -> MUST RETURN 0 ROWS
    RESET ROLE;
    SET ROLE anon;
    SELECT count(*) INTO v_count FROM public.seller_kyc_documents WHERE seller_id = v_seller_alpha_id;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'C.3 FAIL: Anonymous user read seller KYC documents';
    END IF;

    -- C.4 Seller attempts to mark own KYC verified -> MUST FAIL
    RESET ROLE;
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000001';
    v_threw := false;
    BEGIN
        UPDATE public.seller_kyc_documents SET verification_status = 'verified' WHERE id = v_doc_pan_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'C.4 FAIL: Seller self-verified KYC document';
    END IF;

    RAISE NOTICE 'ASSERTION PASS C: KYC Document Submission & Security Isolation';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST D: BANK ACCOUNT REGISTRATION & VERIFICATION
-- ============================================================================
DO $$
DECLARE
    v_seller_alpha_id UUID;
    v_bank_acc_id UUID;
    v_threw BOOLEAN;
BEGIN
    SELECT id INTO v_seller_alpha_id FROM public.sellers WHERE seller_slug = 'test-p4-seller-alpha';

    SET ROLE authenticated;

    -- D.1 Seller Alpha submits bank account
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000001';
    INSERT INTO public.seller_bank_accounts (
        seller_id,
        beneficiary_name,
        account_number,
        ifsc_code,
        bank_name
    ) VALUES (
        v_seller_alpha_id,
        'Alpha Luxury Creations',
        'TESTP4ACC12345678',
        'HDFC0001234',
        'HDFC Bank'
    ) RETURNING id INTO v_bank_acc_id;

    -- D.2 Seller attempts to self-verify bank account -> MUST FAIL
    v_threw := false;
    BEGIN
        UPDATE public.seller_bank_accounts SET is_verified = true, penny_drop_status = 'success' WHERE id = v_bank_acc_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'D.2 FAIL: Seller self-verified bank account';
    END IF;

    -- D.3 Finance admin verifies bank account via RPC -> MUST SUCCEED
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000004';
    PERFORM public.verify_seller_bank_account(v_bank_acc_id, true, 'success', 'fund_alpha_p4_test');

    IF NOT EXISTS (SELECT 1 FROM public.seller_bank_accounts WHERE id = v_bank_acc_id AND is_verified = true AND penny_drop_status = 'success') THEN
        RAISE EXCEPTION 'D.3 FAIL: Finance admin could not verify bank account';
    END IF;

    RAISE NOTICE 'ASSERTION PASS D: Bank Account Registration & Verification';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST E: PAYOUT ELIGIBILITY FOUNDATION & SELLING INDEPENDENCE
-- ============================================================================
DO $$
DECLARE
    v_seller_alpha_id UUID;
    v_doc_pan_id UUID;
    v_doc_gst_id UUID;
    v_eligible BOOLEAN;
BEGIN
    SELECT id INTO v_seller_alpha_id FROM public.sellers WHERE seller_slug = 'test-p4-seller-alpha';
    SELECT id INTO v_doc_pan_id FROM public.seller_kyc_documents WHERE seller_id = v_seller_alpha_id AND document_type = 'pan_card';

    -- E.1 Currently PAN is pending -> Payout MUST BE FALSE
    v_eligible := public.is_seller_payout_eligible(v_seller_alpha_id);
    IF v_eligible THEN
        RAISE EXCEPTION 'E.1 FAIL: Seller is payout eligible with pending KYC';
    END IF;

    -- Finance admin verifies PAN document
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000004';
    PERFORM public.review_seller_kyc_document(v_doc_pan_id, 'verified');

    -- E.2 Seller has GSTIN on record, so GST cert is also required. GST is currently missing -> Payout MUST BE FALSE
    v_eligible := public.is_seller_payout_eligible(v_seller_alpha_id);
    IF v_eligible THEN
        RAISE EXCEPTION 'E.2 FAIL: Seller with GSTIN is payout eligible without GST certificate';
    END IF;

    -- Seller uploads GST doc, Finance verifies it
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000001';
    INSERT INTO public.seller_kyc_documents (
        seller_id,
        document_type,
        document_url,
        verification_status
    ) VALUES (
        v_seller_alpha_id,
        'gst_certificate',
        'https://ogura.test/p4_gst_alpha.pdf',
        'pending'
    ) RETURNING id INTO v_doc_gst_id;

    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000004';
    PERFORM public.review_seller_kyc_document(v_doc_gst_id, 'verified');

    -- E.3 Now Active + Verified PAN + Verified GST + Verified Bank -> Payout MUST BE TRUE
    v_eligible := public.is_seller_payout_eligible(v_seller_alpha_id);
    IF NOT v_eligible THEN
        RAISE EXCEPTION 'E.3 FAIL: Seller with all verified credentials is not payout eligible';
    END IF;

    RAISE NOTICE 'ASSERTION PASS E: Payout Gate Evaluation & Compliance Rules';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST F: ADMIN ROLE SEPARATION OF DUTIES
-- ============================================================================
DO $$
DECLARE
    v_seller_alpha_id UUID;
    v_count INTEGER;
    v_rows INTEGER;
BEGIN
    SELECT id INTO v_seller_alpha_id FROM public.sellers WHERE seller_slug = 'test-p4-seller-alpha';

    SET ROLE authenticated;

    -- F.1 Catalog Admin attempts to read sensitive KYC -> MUST RETURN 0 ROWS
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000005';
    SELECT count(*) INTO v_count FROM public.seller_kyc_documents WHERE seller_id = v_seller_alpha_id;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'F.1 FAIL: Catalog Admin accessed seller KYC documents';
    END IF;

    -- F.2 Support Admin attempts to read bank accounts -> MUST RETURN 0 ROWS
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000005';
    SELECT count(*) INTO v_count FROM public.seller_bank_accounts WHERE seller_id = v_seller_alpha_id;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'F.2 FAIL: Support/Catalog Admin accessed seller bank accounts';
    END IF;

    -- F.3 Viewer Admin attempts write -> RLS MUST REJECT (0 rows updated)
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000006';
    UPDATE public.sellers SET business_name = 'Viewer Tamper' WHERE id = v_seller_alpha_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows > 0 THEN
        RAISE EXCEPTION 'F.3 FAIL: Viewer Admin successfully mutated seller';
    END IF;

    RAISE NOTICE 'ASSERTION PASS F: Admin Separation of Duties (Least Privilege)';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST G: AUDIT LOGGING & IMMUTABILITY
-- ============================================================================
DO $$
DECLARE
    v_audit_id BIGINT;
    v_threw BOOLEAN;
BEGIN
    -- G.1 Verify consequential actions generated audit entries
    SELECT id INTO v_audit_id 
    FROM public.admin_audit_logs 
    WHERE action IN ('SELLER_APPROVED', 'KYC_DOCUMENT_VERIFIED', 'BANK_ACCOUNT_VERIFIED') 
    LIMIT 1;

    IF v_audit_id IS NULL THEN
        RAISE EXCEPTION 'G.1 FAIL: No audit records found for consequential actions';
    END IF;

    -- G.2 Attempt to UPDATE audit record -> MUST FAIL
    v_threw := false;
    BEGIN
        UPDATE public.admin_audit_logs SET action = 'HACKED' WHERE id = v_audit_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'G.2 FAIL: audit record was mutated';
    END IF;

    -- G.3 Attempt to DELETE audit record -> MUST FAIL
    v_threw := false;
    BEGIN
        DELETE FROM public.admin_audit_logs WHERE id = v_audit_id;
    EXCEPTION WHEN OTHERS THEN
        v_threw := true;
    END;
    IF NOT v_threw THEN
        RAISE EXCEPTION 'G.3 FAIL: audit record was deleted';
    END IF;

    RAISE NOTICE 'ASSERTION PASS G: Append-Only Audit Logging & Immutability';
END $$;

-- ============================================================================
-- TEST H: SELLER SUSPENSION & P3 VISIBILITY INTERLOCK
-- ============================================================================
DO $$
DECLARE
    v_seller_alpha_id UUID;
    v_product_id UUID;
    v_brand_id UUID;
    v_category_id UUID;
    v_subcategory_id UUID;
    v_visible BOOLEAN;
BEGIN
    SELECT id INTO v_seller_alpha_id FROM public.sellers WHERE seller_slug = 'test-p4-seller-alpha';

    -- Seed brand for Seller Alpha
    INSERT INTO public.brands (
        seller_id,
        name,
        slug
    ) VALUES (
        v_seller_alpha_id,
        'Alpha P4 Couture Brand',
        'alpha-p4-couture-brand'
    ) RETURNING id INTO v_brand_id;

    SELECT id INTO v_category_id FROM public.categories WHERE slug = 'clothing';
    SELECT id INTO v_subcategory_id FROM public.subcategories WHERE slug = 'dresses';

    -- Create live test product under active Seller Alpha
    INSERT INTO public.products (
        seller_id,
        brand_id,
        category_id,
        subcategory_id,
        title,
        slug,
        status,
        is_made_to_order
    ) VALUES (
        v_seller_alpha_id,
        v_brand_id,
        v_category_id,
        v_subcategory_id,
        'Alpha P4 Test Gown',
        'alpha-p4-test-gown',
        'live',
        true
    ) RETURNING id INTO v_product_id;

    -- H.1 Seller Alpha is ACTIVE -> product is visible
    v_visible := public.is_product_visible(v_product_id);
    IF NOT v_visible THEN
        RAISE EXCEPTION 'H.1 FAIL: Active seller MTO product is not visible';
    END IF;

    -- H.2 Super Admin suspends Seller Alpha
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = 'a4000000-0000-0000-0000-000000000003';
    PERFORM public.suspend_seller(v_seller_alpha_id, 'Regulatory audit pending');
    RESET ROLE;

    -- Verify product is now immediately HIDDEN to public / anonymous customers through P3 visibility gate
    SET ROLE anon;
    SET LOCAL "request.jwt.claim.sub" = '';
    v_visible := public.is_product_visible(v_product_id);
    RESET ROLE;

    IF v_visible THEN
        RAISE EXCEPTION 'H.2 FAIL: Suspended seller product is still visible through P3 gate';
    END IF;

    -- Clean up test product
    DELETE FROM public.products WHERE id = v_product_id;
    DELETE FROM public.brands WHERE id = v_brand_id;

    RAISE NOTICE 'ASSERTION PASS H: Seller Suspension & Catalog Visibility Cascade';
END $$;
