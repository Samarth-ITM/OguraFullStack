-- ============================================================================
-- P2 SECURITY ASSERTION TEST RUNNER
-- ============================================================================

-- TEST 1: Customer Data Isolation
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111'; -- Customer A

    -- Customer A can see own address
    SELECT count(*) INTO v_count FROM customer_addresses WHERE user_id = '11111111-1111-1111-1111-111111111111';
    IF v_count != 1 THEN
        RAISE EXCEPTION 'TEST FAILED: Customer A cannot see own address';
    END IF;

    -- Customer A CANNOT see Customer B address
    SELECT count(*) INTO v_count FROM customer_addresses WHERE user_id = '22222222-2222-2222-2222-222222222222';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Customer A can see Customer B address (CROSS-CUSTOMER LEAK)';
    END IF;

    -- Customer A cannot update Customer B address
    UPDATE customer_addresses SET full_name = 'Hacked' WHERE user_id = '22222222-2222-2222-2222-222222222222';
    SELECT count(*) INTO v_count FROM customer_addresses WHERE user_id = '22222222-2222-2222-2222-222222222222' AND full_name = 'Hacked';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Customer A was able to update Customer B address';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS: Customer Data Isolation';
END $$;

-- TEST 2: Anonymous Access Denial on Private Data
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SET ROLE anon;
    RESET "request.jwt.claim.sub";

    -- Anonymous cannot see any customer addresses
    SELECT count(*) INTO v_count FROM customer_addresses;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Anonymous user can read customer addresses';
    END IF;

    -- Anonymous cannot see any orders
    SELECT count(*) INTO v_count FROM orders;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Anonymous user can read orders';
    END IF;

    -- Anonymous cannot see seller bank accounts
    SELECT count(*) INTO v_count FROM seller_bank_accounts;
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Anonymous user can read seller bank accounts';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS: Anonymous Access Denied on Private Tables';
END $$;

-- TEST 3: Seller Tenancy & Cross-Seller Isolation
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '33333333-3333-3333-3333-333333333333'; -- Seller A

    -- Seller A sees own bank account
    SELECT count(*) INTO v_count FROM seller_bank_accounts WHERE seller_id = 'aaaa1111-0000-0000-0000-000000000001';
    IF v_count != 1 THEN
        RAISE EXCEPTION 'TEST FAILED: Seller A cannot see own bank account';
    END IF;

    -- Seller A CANNOT see Seller B bank account
    SELECT count(*) INTO v_count FROM seller_bank_accounts WHERE seller_id = 'bbbb2222-0000-0000-0000-000000000002';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Seller A can see Seller B bank account (CROSS-SELLER LEAK)';
    END IF;

    -- Seller A CANNOT see Seller B KYC documents
    SELECT count(*) INTO v_count FROM seller_kyc_documents WHERE seller_id = 'bbbb2222-0000-0000-0000-000000000002';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Seller A can see Seller B KYC docs (CROSS-SELLER LEAK)';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS: Seller Tenancy & Financial Privacy';
END $$;

-- TEST 4: Admin Role Escalation Prevention
DO $$
DECLARE
    v_failed BOOLEAN := false;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111'; -- Normal Customer A

    -- Customer A attempts to grant themselves admin_super
    BEGIN
        INSERT INTO user_roles (user_id, role) VALUES ('11111111-1111-1111-1111-111111111111', 'admin_super');
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
    END;

    IF NOT v_failed THEN
        -- Check if row was silently blocked by RLS
        IF EXISTS (SELECT 1 FROM user_roles WHERE user_id = '11111111-1111-1111-1111-111111111111' AND role = 'admin_super') THEN
            RAISE EXCEPTION 'TEST FAILED: Normal customer escalated privileges to admin_super!';
        END IF;
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS: Customer Privilege Escalation Prevented';
END $$;

-- TEST 5: Non-Super Single Admin Role Invariant
DO $$
DECLARE
    v_threw_exception BOOLEAN := false;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '55555555-5555-5555-5555-555555555555'; -- Admin Super managing roles

    -- Super Admin assigns admin_finance to Admin Catalog user (who already has admin_catalog)
    -- Trigger enforce_single_admin_role MUST raise an exception!
    BEGIN
        INSERT INTO user_roles (user_id, role) VALUES ('66666666-6666-6666-6666-666666666666', 'admin_finance');
    EXCEPTION WHEN OTHERS THEN
        v_threw_exception := true;
    END;

    IF NOT v_threw_exception THEN
        RAISE EXCEPTION 'TEST FAILED: Non-super user was allowed to accumulate multiple admin roles!';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS: Non-super Single Admin Role Invariant Enforced';
END $$;

-- TEST 6: Admin Viewer Cannot Write (Least-Privilege)
DO $$
DECLARE
    v_write_blocked BOOLEAN := false;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '77777777-7777-7777-7777-777777777777'; -- Admin Viewer

    -- Viewer attempts to insert category
    BEGIN
        INSERT INTO categories (name, slug) VALUES ('Illegal Category', 'illegal-cat');
    EXCEPTION WHEN OTHERS THEN
        v_write_blocked := true;
    END;

    IF NOT v_write_blocked THEN
        IF EXISTS (SELECT 1 FROM categories WHERE slug = 'illegal-cat') THEN
            RAISE EXCEPTION 'TEST FAILED: Admin Viewer was able to write to categories!';
        END IF;
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS: Admin Viewer Write Denied (Least-Privilege)';
END $$;

-- TEST 7: Universal Visibility Gate (Active vs Suspended Seller)
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Setup product for Seller A (active) and Seller C (suspended)
    INSERT INTO sellers (id, user_id, business_name, legal_entity_name, seller_slug, status)
    VALUES ('cccc3333-0000-0000-0000-000000000003', '77777777-7777-7777-7777-777777777777', 'Suspended Brand', 'Suspended LLP', 'suspended-brand', 'active')
    ON CONFLICT (id) DO UPDATE SET status = 'active';

    INSERT INTO brands (id, seller_id, name, slug)
    VALUES ('c1110000-0000-0000-0000-000000000003', 'cccc3333-0000-0000-0000-000000000003', 'Suspended Brand', 'susp-brand')
    ON CONFLICT (id) DO NOTHING;

    -- Live product from active seller A
    INSERT INTO products (id, seller_id, brand_id, subcategory_id, title, slug, status, is_made_to_order)
    VALUES ('faaa0000-0000-0000-0000-000000000001', 'aaaa1111-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'Active Silk Kurta', 'active-silk-kurta', 'live', true)
    ON CONFLICT (id) DO UPDATE SET status = 'live', is_made_to_order = true;

    -- Live product from seller C while active, then suspend seller C
    INSERT INTO products (id, seller_id, brand_id, subcategory_id, title, slug, status, is_made_to_order)
    VALUES ('fccc0000-0000-0000-0000-000000000003', 'cccc3333-0000-0000-0000-000000000003', 'c1110000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000001', 'Hidden Kurta', 'hidden-kurta', 'live', true)
    ON CONFLICT (id) DO UPDATE SET status = 'live', is_made_to_order = true;

    SET LOCAL "request.jwt.claim.sub" = '55555555-5555-5555-5555-555555555555';
    SET ROLE authenticated;
    UPDATE sellers SET status = 'suspended' WHERE id = 'cccc3333-0000-0000-0000-000000000003';
    RESET ROLE;

    -- Draft product from active seller A
    INSERT INTO products (id, seller_id, brand_id, subcategory_id, title, slug, status)
    VALUES ('fddd0000-0000-0000-0000-000000000001', 'aaaa1111-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'Draft Kurta', 'draft-kurta', 'draft')
    ON CONFLICT (id) DO UPDATE SET status = 'draft';

    -- Public / Anonymous queries products
    SET ROLE anon;
    RESET "request.jwt.claim.sub";

    -- Must see live product from active seller
    SELECT count(*) INTO v_count FROM products WHERE slug = 'active-silk-kurta';
    IF v_count != 1 THEN
        RAISE EXCEPTION 'TEST FAILED: Public cannot see live product from active seller';
    END IF;

    -- Must NOT see live product from suspended seller (Universal Visibility Gate)
    SELECT count(*) INTO v_count FROM products WHERE slug = 'hidden-kurta';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Public can see live product from suspended seller! (GATE LEAK)';
    END IF;

    -- Must NOT see draft product
    SELECT count(*) INTO v_count FROM products WHERE slug = 'draft-kurta';
    IF v_count != 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Public can see draft product! (GATE LEAK)';
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS: Universal Visibility Gate (Live + Active Seller Enforced)';
END $$;

-- TEST 8: Verified Purchase Review Requirement
DO $$
DECLARE
    v_review_blocked BOOLEAN := false;
BEGIN
    SET ROLE authenticated;
    SET LOCAL "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111'; -- Customer A

    -- Customer A attempts to post review on product they never bought
    BEGIN
        INSERT INTO product_reviews (product_id, user_id, rating, title, body)
        VALUES ('faaa0000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 5, 'Great', 'I love it');
    EXCEPTION WHEN OTHERS THEN
        v_review_blocked := true;
    END;

    IF NOT v_review_blocked THEN
        IF EXISTS (SELECT 1 FROM product_reviews WHERE user_id = '11111111-1111-1111-1111-111111111111' AND product_id = 'faaa0000-0000-0000-0000-000000000001') THEN
            RAISE EXCEPTION 'TEST FAILED: Unverified buyer was able to submit review!';
        END IF;
    END IF;

    RESET ROLE;
    RAISE NOTICE 'ASSERTION PASS: Verified Purchase Review Guard';
END $$;
