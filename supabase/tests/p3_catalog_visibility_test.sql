-- ============================================================================
-- OGURA P3: CATALOG, TAXONOMY & UNIVERSAL VISIBILITY TEST SUITE
-- File: supabase/tests/p3_catalog_visibility_test.sql
-- Target: PostgreSQL 16+ / Lovable Cloud / Supabase
-- Verifies: Catalog Ownership, Product Approval Security, Universal Visibility
--           Gate, Public Privacy Shield, Admin Least-Privilege, Taxonomy Integrity,
--           Variant Integrity, and Media Integrity.
-- ============================================================================

-- Setup test roles if not present
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

-- ============================================================================
-- 0. FIXTURES SETUP
-- ============================================================================

BEGIN;

-- Reset previous P3 test fixtures
DELETE FROM public.media_assets WHERE product_id IN (
    'aa010000-0000-0000-0000-000000000001',
    'aa020000-0000-0000-0000-000000000002',
    'aa030000-0000-0000-0000-000000000003',
    'bb010000-0000-0000-0000-000000000001',
    'cc010000-0000-0000-0000-000000000001',
    'ee010000-0000-0000-0000-000000000001'
);

DELETE FROM public.inventory_items WHERE variant_id IN (
    'ca010000-0000-0000-0000-000000000001',
    'ca020000-0000-0000-0000-000000000002',
    'ca030000-0000-0000-0000-000000000003',
    'cb010000-0000-0000-0000-000000000001',
    'cc010000-0000-0000-0000-000000000001',
    'ce010000-0000-0000-0000-000000000001'
);

DELETE FROM public.product_variants WHERE product_id IN (
    'aa010000-0000-0000-0000-000000000001',
    'aa020000-0000-0000-0000-000000000002',
    'aa030000-0000-0000-0000-000000000003',
    'bb010000-0000-0000-0000-000000000001',
    'cc010000-0000-0000-0000-000000000001',
    'ee010000-0000-0000-0000-000000000001'
);

DELETE FROM public.products WHERE id IN (
    'aa010000-0000-0000-0000-000000000001',
    'aa020000-0000-0000-0000-000000000002',
    'aa030000-0000-0000-0000-000000000003',
    'bb010000-0000-0000-0000-000000000001',
    'cc010000-0000-0000-0000-000000000001',
    'ee010000-0000-0000-0000-000000000001'
);

DELETE FROM public.brands WHERE id IN (
    'ba010000-0000-0000-0000-000000000001',
    'bb010000-0000-0000-0000-000000000001',
    'bc010000-0000-0000-0000-000000000001'
);

DELETE FROM public.seller_bank_accounts WHERE seller_id IN (
    'aa010000-0000-0000-0000-000000000001',
    'bb010000-0000-0000-0000-000000000001',
    'cc010000-0000-0000-0000-000000000001'
);

DELETE FROM public.seller_kyc_documents WHERE seller_id IN (
    'aa010000-0000-0000-0000-000000000001',
    'bb010000-0000-0000-0000-000000000001',
    'cc010000-0000-0000-0000-000000000001'
);

DELETE FROM public.sellers WHERE id IN (
    'aa010000-0000-0000-0000-000000000001',
    'bb010000-0000-0000-0000-000000000001',
    'cc010000-0000-0000-0000-000000000001'
);

DELETE FROM public.user_roles WHERE user_id IN (
    '11111111-0000-0000-0000-000000000001', -- Customer
    '22222222-0000-0000-0000-000000000001', -- Seller A
    '33333333-0000-0000-0000-000000000001', -- Seller B
    '44444444-0000-0000-0000-000000000001', -- Seller Suspended
    '55555555-0000-0000-0000-000000000001', -- Admin Catalog
    '66666666-0000-0000-0000-000000000001', -- Admin Viewer
    '77777777-0000-0000-0000-000000000001', -- Admin Support
    '88888888-0000-0000-0000-000000000001', -- Admin Finance
    '99999999-0000-0000-0000-000000000001'  -- Admin Super
);

-- 1. Create Test Users
INSERT INTO auth.users (id, email) VALUES
    ('11111111-0000-0000-0000-000000000001', 'cust@ogura.test'),
    ('22222222-0000-0000-0000-000000000001', 'sellera@ogura.test'),
    ('33333333-0000-0000-0000-000000000001', 'sellerb@ogura.test'),
    ('44444444-0000-0000-0000-000000000001', 'sellersusp@ogura.test'),
    ('55555555-0000-0000-0000-000000000001', 'admincat@ogura.test'),
    ('66666666-0000-0000-0000-000000000001', 'adminview@ogura.test'),
    ('77777777-0000-0000-0000-000000000001', 'adminsupp@ogura.test'),
    ('88888888-0000-0000-0000-000000000001', 'adminfin@ogura.test'),
    ('99999999-0000-0000-0000-000000000001', 'adminsup@ogura.test')
ON CONFLICT (id) DO NOTHING;

-- 2. Assign Specific Roles
INSERT INTO public.user_roles (user_id, role) VALUES
    ('22222222-0000-0000-0000-000000000001', 'seller'),
    ('33333333-0000-0000-0000-000000000001', 'seller'),
    ('44444444-0000-0000-0000-000000000001', 'seller'),
    ('55555555-0000-0000-0000-000000000001', 'admin_catalog'),
    ('66666666-0000-0000-0000-000000000001', 'admin_viewer'),
    ('77777777-0000-0000-0000-000000000001', 'admin_support'),
    ('88888888-0000-0000-0000-000000000001', 'admin_finance'),
    ('99999999-0000-0000-0000-000000000001', 'admin_super')
ON CONFLICT DO NOTHING;

-- 3. Create Sellers
INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status, gstin, pan, commission_rate_bps) VALUES
    ('aa010000-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', 'P3 Atelier A', 'P3 Atelier A LLP', 'p3-atelier-a', 'active', '07PAAAAA1111A1Z', 'PAAAAA1111', 1500),
    ('bb010000-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'P3 Maison B', 'P3 Maison B Pvt Ltd', 'p3-maison-b', 'active', '07PBBBBB2222B1Z', 'PBBBBB2222', 1500),
    ('cc010000-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000001', 'P3 Suspended C', 'P3 Suspended C Corp', 'p3-suspended-c', 'suspended', '07PCCCCC3333C1Z', 'PCCCCC3333', 1500);

-- Seller Private Bank and KYC fixtures
INSERT INTO public.seller_bank_accounts (seller_id, beneficiary_name, account_number, ifsc_code, is_verified) VALUES
    ('aa010000-0000-0000-0000-000000000001', 'Atelier A Beneficiary', '999999999901', 'HDFC0000001', true),
    ('bb010000-0000-0000-0000-000000000001', 'Maison B Beneficiary', '999999999902', 'HDFC0000002', true);

INSERT INTO public.seller_kyc_documents (seller_id, document_type, document_url, verification_status) VALUES
    ('aa010000-0000-0000-0000-000000000001', 'PAN_CARD', 'https://secure.ogura.in/kyc/sa01_pan.pdf', 'verified'),
    ('bb010000-0000-0000-0000-000000000001', 'PAN_CARD', 'https://secure.ogura.in/kyc/sb01_pan.pdf', 'verified');

-- 4. Create Brands (Seller-Owned)
INSERT INTO public.brands (id, seller_id, name, slug, story, is_active) VALUES
    ('ba010000-0000-0000-0000-000000000001', 'aa010000-0000-0000-0000-000000000001', 'P3 Brand A', 'p3-brand-a', 'Handmade luxury from Atelier A.', true),
    ('bb010000-0000-0000-0000-000000000001', 'bb010000-0000-0000-0000-000000000001', 'P3 Brand B', 'p3-brand-b', 'Haute couture from Maison B.', true),
    ('bc010000-0000-0000-0000-000000000001', 'cc010000-0000-0000-0000-000000000001', 'P3 Brand Suspended', 'p3-brand-suspended', 'Suspended brand narrative.', true);

COMMIT;

-- ============================================================================
-- TEST 1: CATALOG OWNERSHIP (ALLOW OWN PRODUCT, DENY OTHER SELLER PRODUCT)
-- ============================================================================
DO $$
DECLARE
    v_new_product_id UUID := 'aa010000-0000-0000-0000-000000000001';
    v_b_product_id UUID := 'bb010000-0000-0000-0000-000000000001';
    v_denied BOOLEAN := false;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '22222222-0000-0000-0000-000000000001'; -- Seller A

    -- 1.1 Seller A creates own product in draft with own brand -> ALLOW
    INSERT INTO public.products (
        id, seller_id, brand_id, category_id, subcategory_id, occasion_id, title, slug, status
    ) VALUES (
        v_new_product_id,
        'aa010000-0000-0000-0000-000000000001',
        'ba010000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001', -- Clothing
        '20000000-0000-0000-0000-000000000001', -- Dresses
        '30000000-0000-0000-0000-000000000001', -- Wedding Guest
        'Seller A Silk Maxi Dress',
        'seller-a-silk-maxi-dress',
        'draft'
    );

    -- 1.2 Seller A creates variant for own product -> ALLOW
    INSERT INTO public.product_variants (
        id, product_id, sku, size, color, price_paise, compare_at_price_paise
    ) VALUES (
        'ca010000-0000-0000-0000-000000000001',
        v_new_product_id,
        'SKU-A01-S-RED',
        'S',
        'Crimson',
        499900,
        599900
    );

    -- 1.3 Seller A creates primary media asset for own product -> ALLOW
    INSERT INTO public.media_assets (
        id, product_id, slot_role, asset_url, alt_text, sort_order
    ) VALUES (
        'da010000-0000-0000-0000-000000000001',
        v_new_product_id,
        'primary',
        'https://cdn.ogura.in/products/a01-primary.jpg',
        'Seller A Dress Front',
        1
    );

    -- 1.4 Seller A attempts to attach Seller B brand to own product -> MUST BE REJECTED BY FK
    v_denied := false;
    BEGIN
        INSERT INTO public.products (
            id, seller_id, brand_id, category_id, subcategory_id, title, slug, status
        ) VALUES (
            'aa020000-0000-0000-0000-000000000002',
            'aa010000-0000-0000-0000-000000000001',
            'bb010000-0000-0000-0000-000000000001', -- Seller B's Brand!
            '10000000-0000-0000-0000-000000000001',
            '20000000-0000-0000-0000-000000000001',
            'Spoofed Brand Product',
            'spoofed-brand-product',
            'draft'
        );
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied THEN
        RAISE EXCEPTION 'TEST FAILED: Seller A was able to attach Seller B brand!';
    END IF;

    -- Setup Seller B product under super context
    RESET ROLE;
    INSERT INTO public.products (
        id, seller_id, brand_id, category_id, subcategory_id, occasion_id, title, slug, status
    ) VALUES (
        v_b_product_id,
        'bb010000-0000-0000-0000-000000000001',
        'bb010000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000002', -- Ethnicwear
        '20000000-0000-0000-0000-000000000006', -- Sarees
        '30000000-0000-0000-0000-000000000002', -- Festive
        'Seller B Banarasi Saree',
        'seller-b-banarasi-saree',
        'draft'
    );

    -- 1.5 Seller A attempts to update Seller B product -> MUST BE DENIED / 0 rows
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '22222222-0000-0000-0000-000000000001'; -- Seller A
    UPDATE public.products SET title = 'Hacked Title' WHERE id = v_b_product_id;
    IF EXISTS (SELECT 1 FROM public.products WHERE id = v_b_product_id AND title = 'Hacked Title') THEN
        RAISE EXCEPTION 'TEST FAILED: Seller A was able to mutate Seller B product!';
    END IF;

    -- 1.6 Seller A attempts to insert variant for Seller B product -> MUST BE DENIED
    v_denied := false;
    BEGIN
        INSERT INTO public.product_variants (
            product_id, sku, size, color, price_paise
        ) VALUES (
            v_b_product_id,
            'SKU-HACKED-B01',
            'M',
            'Gold',
            100000
        );
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied AND EXISTS (SELECT 1 FROM public.product_variants WHERE sku = 'SKU-HACKED-B01') THEN
        RAISE EXCEPTION 'TEST FAILED: Seller A was able to insert variant on Seller B product!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 1: Catalog Ownership & Cross-Seller Isolation';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST 2: PRODUCT APPROVAL SECURITY (SELLER DIRECT LIVE DENIED, ADMIN ALLOW)
-- ============================================================================
DO $$
DECLARE
    v_product_id UUID := 'aa010000-0000-0000-0000-000000000001';
    v_denied BOOLEAN := false;
    v_res JSONB;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '22222222-0000-0000-0000-000000000001'; -- Seller A

    -- 2.1 Seller A attempts to directly UPDATE status to LIVE -> MUST BE REJECTED
    v_denied := false;
    BEGIN
        UPDATE public.products SET status = 'live' WHERE id = v_product_id;
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied THEN
        IF (SELECT status FROM public.products WHERE id = v_product_id) = 'live' THEN
            RAISE EXCEPTION 'TEST FAILED: Seller directly set product status to live!';
        END IF;
    END IF;

    -- 2.2 Seller A attempts to directly INSERT product with status LIVE -> MUST BE REJECTED
    v_denied := false;
    BEGIN
        INSERT INTO public.products (
            id, seller_id, brand_id, category_id, subcategory_id, title, slug, status
        ) VALUES (
            'aa030000-0000-0000-0000-000000000003',
            'aa010000-0000-0000-0000-000000000001',
            'ba010000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000001',
            '20000000-0000-0000-0000-000000000001',
            'Illegal Live Product',
            'illegal-live-product',
            'live'
        );
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied THEN
        RAISE EXCEPTION 'TEST FAILED: Seller directly inserted live product!';
    END IF;

    -- 2.3 Seller A submits product for review -> ALLOW
    SELECT public.submit_product_for_review(v_product_id) INTO v_res;
    IF (v_res->>'status') != 'submitted' THEN
        RAISE EXCEPTION 'TEST FAILED: Seller could not submit product for review';
    END IF;

    -- 2.4 Authorized Catalog Admin approves product -> ALLOW
    SET LOCAL "request.jwt.claim.sub" = '55555555-0000-0000-0000-000000000001'; -- Admin Catalog
    SELECT public.approve_product(v_product_id) INTO v_res;
    IF (v_res->>'status') != 'live' THEN
        RAISE EXCEPTION 'TEST FAILED: Catalog admin could not approve product';
    END IF;

    -- 2.5 Verify audit log entry exists for product approval (Super / System context)
    RESET ROLE;
    IF NOT EXISTS (
        SELECT 1 FROM public.admin_audit_logs 
        WHERE action = 'APPROVE_PRODUCT' AND entity_id = v_product_id::text
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: Admin audit log not recorded for product approval';
    END IF;

    -- 2.6 Attempt to approve product of suspended seller -> MUST BE REJECTED
    RESET ROLE;
    INSERT INTO public.products (
        id, seller_id, brand_id, category_id, subcategory_id, title, slug, status
    ) VALUES (
        'cc010000-0000-0000-0000-000000000001',
        'cc010000-0000-0000-0000-000000000001', -- Suspended Seller C
        'bc010000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001',
        'Suspended Seller Dress',
        'suspended-seller-dress',
        'submitted'
    );

    INSERT INTO public.product_variants (id, product_id, sku, size, color, price_paise)
    VALUES ('cc010000-0000-0000-0000-000000000001', 'cc010000-0000-0000-0000-000000000001', 'SKU-SUSP-01', 'M', 'Black', 300000);

    INSERT INTO public.media_assets (id, product_id, slot_role, asset_url, sort_order)
    VALUES ('dc010000-0000-0000-0000-000000000001', 'cc010000-0000-0000-0000-000000000001', 'primary', 'https://cdn.ogura.in/p/susp.jpg', 1);

    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '55555555-0000-0000-0000-000000000001'; -- Admin Catalog
    v_denied := false;
    BEGIN
        PERFORM public.approve_product('cc010000-0000-0000-0000-000000000001');
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied THEN
        RAISE EXCEPTION 'TEST FAILED: Product of suspended seller was approved!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 2: Product Approval Security & Admin Gates';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST 3: UNIVERSAL VISIBILITY GATE (SERVER-SIDE DISCOVERY ENFORCEMENT)
-- ============================================================================
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    RESET ROLE;

    -- Setup: Attach inventory to live product A (on-hand: 10, reserved: 0)
    INSERT INTO public.inventory_items (id, variant_id, quantity_on_hand, quantity_reserved)
    VALUES ('ea010000-0000-0000-0000-000000000001', 'ca010000-0000-0000-0000-000000000001', 10, 0)
    ON CONFLICT (variant_id) DO UPDATE SET quantity_on_hand = 10, quantity_reserved = 0;

    -- Setup: Product A2 (Live + Active seller + 0 inventory, NOT MTO)
    INSERT INTO public.products (
        id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order
    ) VALUES (
        'aa020000-0000-0000-0000-000000000002',
        'aa010000-0000-0000-0000-000000000001',
        'ba010000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001',
        'Sold Out Dress',
        'sold-out-dress',
        'live',
        false
    );
    INSERT INTO public.product_variants (id, product_id, sku, size, color, price_paise)
    VALUES ('ca020000-0000-0000-0000-000000000002', 'aa020000-0000-0000-0000-000000000002', 'SKU-A02-ZERO', 'L', 'Blue', 400000);
    INSERT INTO public.inventory_items (id, variant_id, quantity_on_hand, quantity_reserved)
    VALUES ('ea020000-0000-0000-0000-000000000002', 'ca020000-0000-0000-0000-000000000002', 0, 0);

    -- Setup: Product MTO (Live + Active seller + 0 inventory, BUT MTO = true)
    INSERT INTO public.products (
        id, seller_id, brand_id, category_id, subcategory_id, title, slug, status, is_made_to_order
    ) VALUES (
        'ee010000-0000-0000-0000-000000000001',
        'aa010000-0000-0000-0000-000000000001',
        'ba010000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000002',
        '20000000-0000-0000-0000-000000000007',
        'Bespoke MTO Bridal Lehenga',
        'bespoke-mto-bridal-lehenga',
        'live',
        true
    );
    INSERT INTO public.product_variants (id, product_id, sku, size, color, price_paise)
    VALUES ('ce010000-0000-0000-0000-000000000001', 'ee010000-0000-0000-0000-000000000001', 'SKU-MTO-01', 'Custom', 'Maroon', 1500000);

    -- Setup: Seller C was initially active, product was approved to live, then Seller C was suspended
    PERFORM set_config('request.jwt.claim.sub', '99999999-0000-0000-0000-000000000001', true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    UPDATE public.sellers SET status = 'active' WHERE id = 'cc010000-0000-0000-0000-000000000001';
    UPDATE public.products SET status = 'live' WHERE id = 'cc010000-0000-0000-0000-000000000001';
    UPDATE public.sellers SET status = 'suspended' WHERE id = 'cc010000-0000-0000-0000-000000000001';

    -- PUBLIC / ANONYMOUS CONTEXT
    SET ROLE anon;
    RESET "request.jwt.claim.sub";

    -- 3.1 Live + Active Seller + Stock -> VISIBLE (Expect 1)
    SELECT count(*) INTO v_count FROM public.products WHERE id = 'aa010000-0000-0000-0000-000000000001';
    IF v_count != 1 THEN
        RAISE EXCEPTION 'TEST FAILED: Public cannot see live product with active seller and stock';
    END IF;

    -- 3.2 Draft + Active Seller -> HIDDEN (Expect 0)
    SELECT count(*) INTO v_count FROM public.products WHERE id = 'bb010000-0000-0000-0000-000000000001';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Public can see draft product (GATE LEAK)';
    END IF;

    -- 3.3 Live + Suspended Seller -> HIDDEN (Expect 0)
    SELECT count(*) INTO v_count FROM public.products WHERE id = 'cc010000-0000-0000-0000-000000000001';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Public can see live product from suspended seller! (GATE LEAK)';
    END IF;

    -- 3.4 Live + Active Seller + 0 stock (non-MTO) -> HIDDEN (Expect 0)
    SELECT count(*) INTO v_count FROM public.products WHERE id = 'aa020000-0000-0000-0000-000000000002';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Public can see non-sellable 0-stock product without MTO! (GATE LEAK)';
    END IF;

    -- 3.5 Live + Active Seller + MTO = true -> VISIBLE (Expect 1)
    SELECT count(*) INTO v_count FROM public.products WHERE id = 'ee010000-0000-0000-0000-000000000001';
    IF v_count != 1 THEN
        RAISE EXCEPTION 'TEST FAILED: Public cannot see sellable MTO product!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 3: Universal Visibility Gate (Live + Active Seller + Inventory/MTO)';
END $$;

-- ============================================================================
-- TEST 4: PUBLIC PRIVACY (PROJECTION LEAKAGE PREVENTION)
-- ============================================================================
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SET ROLE anon;
    RESET "request.jwt.claim.sub";

    -- 4.1 Anonymous cannot read private sellers table
    SELECT count(*) INTO v_count FROM public.sellers;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Anonymous user can read private sellers table!';
    END IF;

    -- 4.2 Anonymous cannot read seller bank accounts
    SELECT count(*) INTO v_count FROM public.seller_bank_accounts;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Anonymous user can read seller bank accounts!';
    END IF;

    -- 4.3 Anonymous cannot read seller KYC documents
    SELECT count(*) INTO v_count FROM public.seller_kyc_documents;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Anonymous user can read seller KYC documents!';
    END IF;

    -- 4.4 Anonymous can read non-sensitive public directory view
    SELECT count(*) INTO v_count FROM public.public_sellers;
    IF v_count < 2 THEN
        RAISE EXCEPTION 'TEST FAILED: Anonymous cannot read public seller directory';
    END IF;

    -- 4.5 Anonymous cannot read unpublished product variants or media
    SELECT count(*) INTO v_count FROM public.product_variants WHERE product_id = 'bb010000-0000-0000-0000-000000000001';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Anonymous user can read variants of draft product!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 4: Public Privacy Shield & Zero Sensitive Data Leakage';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST 5: ADMIN LEAST PRIVILEGE (CATALOG WRITE RESTRICTED STRICTLY TO CATALOG/SUPER)
-- ============================================================================
DO $$
DECLARE
    v_denied BOOLEAN := false;
BEGIN
    -- 5.1 Admin Catalog -> WRITE ALLOWED
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '55555555-0000-0000-0000-000000000001'; -- Admin Catalog
    INSERT INTO public.categories (id, name, slug, sort_order)
    VALUES ('99990000-0000-0000-0000-000000000001', 'Admin Curated', 'admin-curated', 99)
    ON CONFLICT (slug) DO NOTHING;

    -- 5.2 Admin Viewer -> WRITE DENIED
    SET LOCAL "request.jwt.claim.sub" = '66666666-0000-0000-0000-000000000001'; -- Admin Viewer
    v_denied := false;
    BEGIN
        INSERT INTO public.categories (name, slug) VALUES ('Viewer Cat', 'viewer-cat');
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied AND EXISTS (SELECT 1 FROM public.categories WHERE slug = 'viewer-cat') THEN
        RAISE EXCEPTION 'TEST FAILED: Admin Viewer was able to write categories!';
    END IF;

    -- 5.3 Admin Support -> WRITE DENIED
    SET LOCAL "request.jwt.claim.sub" = '77777777-0000-0000-0000-000000000001'; -- Admin Support
    v_denied := false;
    BEGIN
        INSERT INTO public.categories (name, slug) VALUES ('Support Cat', 'support-cat');
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied AND EXISTS (SELECT 1 FROM public.categories WHERE slug = 'support-cat') THEN
        RAISE EXCEPTION 'TEST FAILED: Admin Support was able to write categories!';
    END IF;

    -- 5.4 Admin Finance -> WRITE DENIED
    SET LOCAL "request.jwt.claim.sub" = '88888888-0000-0000-0000-000000000001'; -- Admin Finance
    v_denied := false;
    BEGIN
        INSERT INTO public.categories (name, slug) VALUES ('Finance Cat', 'finance-cat');
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied AND EXISTS (SELECT 1 FROM public.categories WHERE slug = 'finance-cat') THEN
        RAISE EXCEPTION 'TEST FAILED: Admin Finance was able to write categories!';
    END IF;

    RESET ROLE;
    DELETE FROM public.categories WHERE id = '99990000-0000-0000-0000-000000000001';
    RAISE NOTICE 'ASSERTION PASS 5: Admin Least-Privilege & Catalog Boundaries';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST 6: TAXONOMY INTEGRITY (CATEGORY ↔ SUBCATEGORY RELATIONSHIP ENFORCEMENT)
-- ============================================================================
DO $$
DECLARE
    v_denied BOOLEAN := false;
BEGIN
    RESET ROLE;

    -- 6.1 Valid Category / Subcategory pairing: Ethnicwear ('1000...002') + Sarees ('2000...006') -> ALLOW
    INSERT INTO public.products (
        id, seller_id, brand_id, category_id, subcategory_id, title, slug, status
    ) VALUES (
        'aa030000-0000-0000-0000-000000000003',
        'aa010000-0000-0000-0000-000000000001',
        'ba010000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000002', -- Ethnicwear
        '20000000-0000-0000-0000-000000000006', -- Sarees (Belongs to Ethnicwear)
        'Valid Taxonomy Saree',
        'valid-taxonomy-saree',
        'draft'
    );

    -- 6.2 Invalid Category / Subcategory pairing: Clothing ('1000...001') + Sarees ('2000...006') -> MUST BE REJECTED BY COMPOUND FK
    v_denied := false;
    BEGIN
        INSERT INTO public.products (
            id, seller_id, brand_id, category_id, subcategory_id, title, slug, status
        ) VALUES (
            'aa030000-0000-0000-0000-000000000004',
            'aa010000-0000-0000-0000-000000000001',
            'ba010000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000001', -- Clothing (MISMATCH!)
            '20000000-0000-0000-0000-000000000006', -- Sarees (Belongs to Ethnicwear)
            'Invalid Taxonomy Product',
            'invalid-taxonomy-product',
            'draft'
        );
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied THEN
        RAISE EXCEPTION 'TEST FAILED: Invalid Category/Subcategory combination was accepted!';
    END IF;

    DELETE FROM public.products WHERE id = 'aa030000-0000-0000-0000-000000000003';
    RAISE NOTICE 'ASSERTION PASS 6: Taxonomy Integrity & Compound FK Enforcement';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST 7: VARIANT INTEGRITY (PRICE, PAIRING, DUPLICATE SKU REJECTION)
-- ============================================================================
DO $$
DECLARE
    v_denied BOOLEAN := false;
BEGIN
    RESET ROLE;

    -- 7.1 Negative price paise -> MUST BE REJECTED
    v_denied := false;
    BEGIN
        INSERT INTO public.product_variants (
            product_id, sku, size, color, price_paise
        ) VALUES (
            'aa010000-0000-0000-0000-000000000001',
            'SKU-NEGATIVE-PRICE',
            'M',
            'Red',
            -500
        );
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied THEN
        RAISE EXCEPTION 'TEST FAILED: Variant with negative price was accepted!';
    END IF;

    -- 7.2 Duplicate SKU -> MUST BE REJECTED
    v_denied := false;
    BEGIN
        INSERT INTO public.product_variants (
            product_id, sku, size, color, price_paise
        ) VALUES (
            'aa010000-0000-0000-0000-000000000001',
            'SKU-A01-S-RED', -- Already exists from Test 1
            'L',
            'Red',
            500000
        );
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied THEN
        RAISE EXCEPTION 'TEST FAILED: Duplicate SKU was accepted!';
    END IF;

    -- 7.3 Duplicate Size + Color for same product -> MUST BE REJECTED
    v_denied := false;
    BEGIN
        INSERT INTO public.product_variants (
            product_id, sku, size, color, price_paise
        ) VALUES (
            'aa010000-0000-0000-0000-000000000001',
            'SKU-A01-DUP-SIZE-COLOR',
            'S',
            'Crimson', -- Same size and color as existing variant
            500000
        );
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied THEN
        RAISE EXCEPTION 'TEST FAILED: Duplicate (size, color) variant was accepted!';
    END IF;

    RAISE NOTICE 'ASSERTION PASS 7: Variant Integrity (Pricing, SKU & Size/Color Uniqueness)';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST 8: MEDIA INTEGRITY (SINGLE PRIMARY ASSET ENFORCEMENT)
-- ============================================================================
DO $$
DECLARE
    v_denied BOOLEAN := false;
BEGIN
    RESET ROLE;

    -- 8.1 Second primary media asset for same product -> MUST BE REJECTED
    v_denied := false;
    BEGIN
        INSERT INTO public.media_assets (
            product_id, slot_role, asset_url, sort_order
        ) VALUES (
            'aa010000-0000-0000-0000-000000000001',
            'primary', -- Second primary!
            'https://cdn.ogura.in/p/second-primary.jpg',
            2
        );
    EXCEPTION WHEN OTHERS THEN
        v_denied := true;
    END;
    IF NOT v_denied THEN
        RAISE EXCEPTION 'TEST FAILED: Multiple primary media assets were accepted for same product!';
    END IF;

    -- 8.2 Secondary media asset -> ALLOW
    INSERT INTO public.media_assets (
        product_id, slot_role, asset_url, sort_order
    ) VALUES (
        'aa010000-0000-0000-0000-000000000001',
        'secondary',
        'https://cdn.ogura.in/p/second-image.jpg',
        2
    );

    RAISE NOTICE 'ASSERTION PASS 8: Media Integrity (Single Primary Image Invariant)';
END $$;
RESET ROLE;

-- ============================================================================
-- TEST 9: PUBLIC DISCOVERY RPCs (get_public_catalog & get_public_product_by_slug)
-- ============================================================================
DO $$
DECLARE
    v_catalog JSONB;
    v_pdp JSONB;
BEGIN
    SET ROLE anon;
    RESET "request.jwt.claim.sub";

    -- 9.1 Discovery RPC get_public_catalog
    SELECT public.get_public_catalog(p_category_slug := 'clothing') INTO v_catalog;
    IF (v_catalog->>'total')::int < 1 THEN
        RAISE EXCEPTION 'TEST FAILED: get_public_catalog returned 0 results for clothing!';
    END IF;

    -- 9.2 PDP Discovery RPC get_public_product_by_slug for live product
    SELECT public.get_public_product_by_slug('seller-a-silk-maxi-dress') INTO v_pdp;
    IF v_pdp IS NULL THEN
        RAISE EXCEPTION 'TEST FAILED: get_public_product_by_slug returned NULL for live product!';
    END IF;
    IF (v_pdp->>'title') != 'Seller A Silk Maxi Dress' THEN
        RAISE EXCEPTION 'TEST FAILED: get_public_product_by_slug returned incorrect title!';
    END IF;
    IF jsonb_array_length(v_pdp->'variants') < 1 THEN
        RAISE EXCEPTION 'TEST FAILED: get_public_product_by_slug did not include variants!';
    END IF;
    IF jsonb_array_length(v_pdp->'media') < 2 THEN
        RAISE EXCEPTION 'TEST FAILED: get_public_product_by_slug did not include media gallery!';
    END IF;

    -- 9.3 PDP Discovery RPC for unpublished product -> MUST RETURN NULL
    SELECT public.get_public_product_by_slug('seller-b-banarasi-saree') INTO v_pdp;
    IF v_pdp IS NOT NULL THEN
        RAISE EXCEPTION 'TEST FAILED: get_public_product_by_slug returned unpublished draft product!';
    END IF;

    -- 9.4 PDP Discovery RPC for suspended seller product -> MUST RETURN NULL
    SELECT public.get_public_product_by_slug('suspended-seller-dress') INTO v_pdp;
    IF v_pdp IS NOT NULL THEN
        RAISE EXCEPTION 'TEST FAILED: get_public_product_by_slug returned suspended seller product!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS 9: Public Discovery RPCs (Filtering, Sorting, PDP Projection)';
END $$;
