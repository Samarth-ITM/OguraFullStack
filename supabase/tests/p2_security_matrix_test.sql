-- ============================================================================
-- OGURA P2 SECURITY & RLS TEST SUITE
-- Target: Verify Customer Isolation, Seller Tenancy, Admin Least-Privilege,
--         Universal Visibility Gate, and Role Escalation Prevention.
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

-- Setup Test Users & Fixtures
BEGIN;
-- Clear test fixtures
DELETE FROM public.product_reviews WHERE user_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222'
);
DELETE FROM public.products WHERE seller_id IN (
    SELECT id FROM public.sellers WHERE user_id IN (
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        '44444444-4444-4444-4444-444444444444',
        '55555555-5555-5555-5555-555555555555',
        '66666666-6666-6666-6666-666666666666',
        '77777777-7777-7777-7777-777777777777'
    )
);
DELETE FROM public.brands WHERE seller_id IN (
    SELECT id FROM public.sellers WHERE user_id IN (
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        '44444444-4444-4444-4444-444444444444',
        '55555555-5555-5555-5555-555555555555',
        '66666666-6666-6666-6666-666666666666',
        '77777777-7777-7777-7777-777777777777'
    )
);
DELETE FROM public.seller_bank_accounts WHERE seller_id IN (
    SELECT id FROM public.sellers WHERE user_id IN (
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        '44444444-4444-4444-4444-444444444444',
        '55555555-5555-5555-5555-555555555555',
        '66666666-6666-6666-6666-666666666666',
        '77777777-7777-7777-7777-777777777777'
    )
);
DELETE FROM public.seller_kyc_documents WHERE seller_id IN (
    SELECT id FROM public.sellers WHERE user_id IN (
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        '33333333-3333-3333-3333-333333333333',
        '44444444-4444-4444-4444-444444444444',
        '55555555-5555-5555-5555-555555555555',
        '66666666-6666-6666-6666-666666666666',
        '77777777-7777-7777-7777-777777777777'
    )
);
DELETE FROM public.customer_addresses WHERE user_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222'
);
DELETE FROM public.sellers WHERE user_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666',
    '77777777-7777-7777-7777-777777777777'
);
DELETE FROM user_roles WHERE user_id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666',
    '77777777-7777-7777-7777-777777777777'
);
DELETE FROM profiles WHERE id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666',
    '77777777-7777-7777-7777-777777777777'
);
DELETE FROM auth.users WHERE id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
    '66666666-6666-6666-6666-666666666666',
    '77777777-7777-7777-7777-777777777777'
);

-- 1. Customer A
INSERT INTO auth.users (id, email) VALUES ('11111111-1111-1111-1111-111111111111', 'customer_a@test.com');
-- Trigger automatically created profile and customer role

-- 2. Customer B
INSERT INTO auth.users (id, email) VALUES ('22222222-2222-2222-2222-222222222222', 'customer_b@test.com');

-- Categories & Subcategories
INSERT INTO categories (id, name, slug) VALUES ('d0000000-0000-0000-0000-000000000001', 'Women', 'women')
ON CONFLICT (id) DO NOTHING;

INSERT INTO subcategories (id, category_id, name, slug) VALUES ('e0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Kurtas', 'kurtas')
ON CONFLICT (id) DO NOTHING;

-- 3. Seller A (Active)
INSERT INTO auth.users (id, email) VALUES ('33333333-3333-3333-3333-333333333333', 'seller_a@test.com');
INSERT INTO user_roles (user_id, role) VALUES ('33333333-3333-3333-3333-333333333333', 'seller');
INSERT INTO sellers (id, user_id, business_name, legal_entity_name, seller_slug, status)
VALUES ('aaaa1111-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'Atelier A', 'Atelier A Pvt Ltd', 'atelier-a', 'active');
INSERT INTO brands (id, seller_id, name, slug)
VALUES ('c0000000-0000-0000-0000-000000000001', 'aaaa1111-0000-0000-0000-000000000001', 'Brand A', 'brand-a')
ON CONFLICT (id) DO NOTHING;

-- 4. Seller B (Active)
INSERT INTO auth.users (id, email) VALUES ('44444444-4444-4444-4444-444444444444', 'seller_b@test.com');
INSERT INTO user_roles (user_id, role) VALUES ('44444444-4444-4444-4444-444444444444', 'seller');
INSERT INTO sellers (id, user_id, business_name, legal_entity_name, seller_slug, status)
VALUES ('bbbb2222-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 'Studio B', 'Studio B LLP', 'studio-b', 'active');

-- 5. Admin Super
INSERT INTO auth.users (id, email) VALUES ('55555555-5555-5555-5555-555555555555', 'admin_super@test.com');
INSERT INTO user_roles (user_id, role) VALUES ('55555555-5555-5555-5555-555555555555', 'admin_super');

-- 6. Admin Catalog
INSERT INTO auth.users (id, email) VALUES ('66666666-6666-6666-6666-666666666666', 'admin_catalog@test.com');
INSERT INTO user_roles (user_id, role) VALUES ('66666666-6666-6666-6666-666666666666', 'admin_catalog');

-- 7. Admin Viewer
INSERT INTO auth.users (id, email) VALUES ('77777777-7777-7777-7777-777777777777', 'admin_viewer@test.com');
INSERT INTO user_roles (user_id, role) VALUES ('77777777-7777-7777-7777-777777777777', 'admin_viewer');

-- Customer A Address
INSERT INTO customer_addresses (id, user_id, full_name, phone, line1, city, state, pincode)
VALUES ('ad111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Alice Kundra', '9999911111', 'Flat 4A Marine Lines', 'Mumbai', 'Maharashtra', '400020');

-- Customer B Address
INSERT INTO customer_addresses (id, user_id, full_name, phone, line1, city, state, pincode)
VALUES ('ad222222-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Bob Sharma', '9999922222', 'Bungalow 7 Koregaon', 'Pune', 'Maharashtra', '411001');

-- Seller A Bank Account & KYC
INSERT INTO seller_bank_accounts (seller_id, beneficiary_name, account_number, ifsc_code)
VALUES ('aaaa1111-0000-0000-0000-000000000001', 'Atelier A Pvt Ltd', '9988112233', 'HDFC0001234');
INSERT INTO seller_kyc_documents (seller_id, document_type, document_url)
VALUES ('aaaa1111-0000-0000-0000-000000000001', 'PAN', 'https://secure.cdn/pan_a.pdf');

-- Seller B Bank Account & KYC
INSERT INTO seller_bank_accounts (seller_id, beneficiary_name, account_number, ifsc_code)
VALUES ('bbbb2222-0000-0000-0000-000000000002', 'Studio B LLP', '4455667788', 'ICIC0005678');
INSERT INTO seller_kyc_documents (seller_id, document_type, document_url)
VALUES ('bbbb2222-0000-0000-0000-000000000002', 'PAN', 'https://secure.cdn/pan_b.pdf');

COMMIT;
