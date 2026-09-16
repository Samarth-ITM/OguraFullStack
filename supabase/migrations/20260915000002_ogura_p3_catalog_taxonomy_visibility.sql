-- ============================================================================
-- OGURA PRODUCTION CATALOG, TAXONOMY & UNIVERSAL VISIBILITY (PHASE 3)
-- Migration: 20260915000002_ogura_p3_catalog_taxonomy_visibility.sql
-- Target: PostgreSQL 16+ / Lovable Cloud / Supabase
-- Authority: OGURA Master PRD Domain 2 & 5, Backend Engineering Flows, Runbook
-- ============================================================================

-- ============================================================================
-- 1. AUTHORITATIVE TAXONOMY SEEDING & INTEGRITY (DOMAIN 2)
-- Categories, Subcategories, Occasions (Locked Canonical MVP Spec)
-- ============================================================================

-- 1.1 Categories Seeding (Idempotent)
INSERT INTO public.categories (id, name, slug, description, sort_order, is_active)
VALUES
    ('10000000-0000-0000-0000-000000000001', 'Clothing', 'clothing', 'Contemporary and classic clothing silhouettes.', 1, true),
    ('10000000-0000-0000-0000-000000000002', 'Ethnicwear', 'ethnicwear', 'Heritage and artisanal Indian festive ensembles.', 2, true),
    ('10000000-0000-0000-0000-000000000003', 'Footwear', 'footwear', 'Sculptural and artisan crafted footwear.', 3, true),
    ('10000000-0000-0000-0000-000000000004', 'Accessories', 'accessories', 'Curated bags and statement lifestyle pieces.', 4, true)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = EXCLUDED.is_active;

-- 1.2 Subcategories Seeding (Idempotent)
INSERT INTO public.subcategories (id, category_id, name, slug, description, sort_order, is_active)
VALUES
    -- Clothing Subcategories
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Dresses', 'dresses', 'Day to evening designer dresses.', 1, true),
    ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Tops & Upperwear', 'tops-and-upperwear', 'Shirts, blouses, knit tops and jackets.', 2, true),
    ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'Co-ord Sets', 'co-ord-sets', 'Harmonized matching two-piece sets.', 3, true),
    ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'Bottomwear', 'bottomwear', 'Trousers, tailored skirts and culottes.', 4, true),
    ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'Jumpsuits & Playsuits', 'jumpsuits-and-playsuits', 'Tailored one-piece silhouettes.', 5, true),

    -- Ethnicwear Subcategories
    ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000002', 'Sarees', 'sarees', 'Handwoven and designer drape sarees.', 1, true),
    ('20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000002', 'Lehengas', 'lehengas', 'Festive and bridal celebration lehengas.', 2, true),
    ('20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000002', 'Sets', 'sets', 'Kurta sets, shararas and ghararas.', 3, true),
    ('20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000002', 'Dresses & Gowns', 'dresses-and-gowns', 'Contemporary ethnic silhouettes and gowns.', 4, true),

    -- Footwear Subcategories
    ('20000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000003', 'Heels', 'heels', 'Sculptural and occasion evening heels.', 1, true),
    ('20000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000003', 'Sneakers', 'sneakers', 'Artisan leather luxury sneakers.', 2, true),
    ('20000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000003', 'Mules', 'mules', 'Backless pointed and block mules.', 3, true),
    ('20000000-0000-0000-0000-000000000013', '10000000-0000-0000-0000-000000000003', 'Ankle Boots', 'ankle-boots', 'Tailored leather ankle boots.', 4, true),
    ('20000000-0000-0000-0000-000000000014', '10000000-0000-0000-0000-000000000003', 'Knee-High Boots', 'knee-high-boots', 'Structured statement tall boots.', 5, true),
    ('20000000-0000-0000-0000-000000000015', '10000000-0000-0000-0000-000000000003', 'Sandals', 'sandals', 'Strappy resort and day sandals.', 6, true),

    -- Accessories Subcategories
    ('20000000-0000-0000-0000-000000000016', '10000000-0000-0000-0000-000000000004', 'Bags', 'bags', 'Totes, clutches, crossbody and shoulder bags.', 1, true)
ON CONFLICT (slug) DO UPDATE SET
    category_id = EXCLUDED.category_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = EXCLUDED.is_active;

-- 1.3 Occasions Seeding (Idempotent)
INSERT INTO public.occasions (id, name, slug, description, sort_order, is_active)
VALUES
    ('30000000-0000-0000-0000-000000000001', 'Wedding Guest', 'wedding-guest', 'Curated looks for wedding guest occasions.', 1, true),
    ('30000000-0000-0000-0000-000000000002', 'Festive', 'festive', 'Heritage ensembles for celebration and festivities.', 2, true),
    ('30000000-0000-0000-0000-000000000003', 'Party', 'party', 'After-dark cocktail and celebration silhouettes.', 3, true),
    ('30000000-0000-0000-0000-000000000004', 'Brunch', 'brunch', 'Relaxed daytime refined tailoring and sets.', 4, true),
    ('30000000-0000-0000-0000-000000000005', 'Date Night', 'date-night', 'Intimate dinner silhouettes with subtle drama.', 5, true),
    ('30000000-0000-0000-0000-000000000006', 'Vacation', 'vacation', 'Breathable resort and holiday wardrobe pieces.', 6, true),
    ('30000000-0000-0000-0000-000000000007', 'Work', 'work', 'Structured, authoritative contemporary workwear.', 7, true),
    ('30000000-0000-0000-0000-000000000008', 'Casual', 'casual', 'Effortless elevated daily wardrobe staples.', 8, true)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = EXCLUDED.is_active;

-- ============================================================================
-- 2. SCHEMA CONSTRAINTS & TAXONOMY INTEGRITY (DOMAIN 2)
-- Category → Subcategory → Product & Brand ↔ Seller Invariants
-- ============================================================================

-- 2.1 Subcategories Compound Key for Foreign Key Validation
DO $$ BEGIN
    ALTER TABLE public.subcategories
    ADD CONSTRAINT uq_subcategories_id_category UNIQUE (id, category_id);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN null; END $$;

-- 2.2 Add category_id and occasion_id to products if not present
DO $$ BEGIN
    ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES public.categories(id) ON DELETE RESTRICT;
EXCEPTION WHEN duplicate_column THEN null; END $$;

DO $$ BEGIN
    ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS occasion_id UUID REFERENCES public.occasions(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN null; END $$;

-- Backfill category_id from subcategories for any pre-existing products
UPDATE public.products p
SET category_id = sc.category_id
FROM public.subcategories sc
WHERE p.subcategory_id = sc.id AND p.category_id IS NULL;

-- Make category_id NOT NULL after backfill
ALTER TABLE public.products ALTER COLUMN category_id SET NOT NULL;

-- 2.3 Compound Foreign Key: Ensures products.category_id EXACTLY matches subcategory.category_id
DO $$ BEGIN
    ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS fk_products_category_subcategory;

    ALTER TABLE public.products
    ADD CONSTRAINT fk_products_category_subcategory
    FOREIGN KEY (subcategory_id, category_id)
    REFERENCES public.subcategories(id, category_id) ON DELETE RESTRICT;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2.4 Auto-sync category_id from subcategory_id trigger (for convenience when category_id is omitted)
CREATE OR REPLACE FUNCTION public.sync_product_category()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.category_id IS NULL AND NEW.subcategory_id IS NOT NULL THEN
        SELECT category_id INTO NEW.category_id
        FROM public.subcategories
        WHERE id = NEW.subcategory_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_sync_product_category ON public.products;
CREATE TRIGGER trg_sync_product_category
BEFORE INSERT OR UPDATE OF subcategory_id ON public.products
FOR EACH ROW EXECUTE FUNCTION public.sync_product_category();

-- 2.5 Product Occasions Junction Table (Multi-Occasion Tagging Support)
CREATE TABLE IF NOT EXISTS public.product_occasions (
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    occasion_id UUID NOT NULL REFERENCES public.occasions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id, occasion_id)
);

ALTER TABLE public.product_occasions ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_product_occasions_occasion ON public.product_occasions (occasion_id, product_id);
CREATE INDEX IF NOT EXISTS idx_products_occasion ON public.products (occasion_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products (category_id);

-- 2.6 Sync primary occasion to junction table
CREATE OR REPLACE FUNCTION public.sync_product_occasion_junction()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.occasion_id IS NOT NULL THEN
        INSERT INTO public.product_occasions (product_id, occasion_id)
        VALUES (NEW.id, NEW.occasion_id)
        ON CONFLICT (product_id, occasion_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_sync_product_occasion ON public.products;
CREATE TRIGGER trg_sync_product_occasion
AFTER INSERT OR UPDATE OF occasion_id ON public.products
FOR EACH ROW EXECUTE FUNCTION public.sync_product_occasion_junction();

-- 2.7 Brand-Seller Ownership Compound Invariant
-- Ensures a seller can NEVER attach a brand belonging to another seller
DO $$ BEGIN
    ALTER TABLE public.brands
    ADD CONSTRAINT uq_brands_id_seller UNIQUE (id, seller_id);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN null; END $$;

-- If there are legacy test records with mismatched brand/seller, repair them before FK enforcement
UPDATE public.products p
SET seller_id = b.seller_id
FROM public.brands b
WHERE p.brand_id = b.id AND p.seller_id != b.seller_id;

DO $$ BEGIN
    ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS fk_products_brand_seller;

    ALTER TABLE public.products
    ADD CONSTRAINT fk_products_brand_seller
    FOREIGN KEY (brand_id, seller_id)
    REFERENCES public.brands(id, seller_id) ON DELETE RESTRICT;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2.8 Designer-Brand Alignment Trigger
CREATE OR REPLACE FUNCTION public.validate_product_designer()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.designer_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.designers 
            WHERE id = NEW.designer_id AND (brand_id IS NULL OR brand_id = NEW.brand_id)
        ) THEN
            RAISE EXCEPTION 'Invalid designer: designer does not belong to product brand.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_product_designer ON public.products;
CREATE TRIGGER trg_validate_product_designer
BEFORE INSERT OR UPDATE OF designer_id, brand_id ON public.products
FOR EACH ROW EXECUTE FUNCTION public.validate_product_designer();

-- ============================================================================
-- 3. PRODUCT VARIANT INTEGRITY (DOMAIN 2)
-- Money = Bigint Paise, Price >= 0, SKU Unique, Size/Color Unique
-- ============================================================================

-- Add color_hex to product_variants if not present
DO $$ BEGIN
    ALTER TABLE public.product_variants
    ADD COLUMN IF NOT EXISTS color_hex VARCHAR(20) DEFAULT '#000000';
EXCEPTION WHEN duplicate_column THEN null; END $$;

-- Relax price constraint from > 0 to >= 0 per P3 spec (Integer Paise)
ALTER TABLE public.product_variants DROP CONSTRAINT IF EXISTS product_variants_price_paise_check;
ALTER TABLE public.product_variants DROP CONSTRAINT IF EXISTS chk_variant_price;
ALTER TABLE public.product_variants ADD CONSTRAINT chk_variant_price CHECK (price_paise >= 0);

ALTER TABLE public.product_variants DROP CONSTRAINT IF EXISTS product_variants_compare_at_price_paise_check;
ALTER TABLE public.product_variants DROP CONSTRAINT IF EXISTS chk_variant_compare_at;
ALTER TABLE public.product_variants ADD CONSTRAINT chk_variant_compare_at CHECK (
    compare_at_price_paise IS NULL OR compare_at_price_paise >= price_paise
);

-- Variant uniqueness: size + color per product
DO $$ BEGIN
    ALTER TABLE public.product_variants
    ADD CONSTRAINT uq_product_variants_size_color UNIQUE (product_id, size, color);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN null; END $$;

-- ============================================================================
-- 4. PRODUCT MEDIA INTEGRITY (DOMAIN 2)
-- Single Primary Media Asset & Ordering
-- ============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS uq_media_assets_product_primary 
ON public.media_assets (product_id) 
WHERE slot_role = 'primary';

-- ============================================================================
-- 5. AUTHORITATIVE PRODUCT LIFECYCLE & APPROVAL SECURITY (DOMAIN 2)
-- Separate Seller & Product Approval Gates; Seller Cannot Bypass Review
-- ============================================================================

CREATE OR REPLACE FUNCTION public.enforce_product_lifecycle()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Catalog Admin, Super Admin, or System/Superuser (auth.uid() IS NULL):
    -- Authorized to moderate and approve products, subject to seller active invariant
    IF auth.uid() IS NULL OR public.has_role('admin_catalog') THEN
        -- Integrity invariant: Product cannot be set to 'live' if owning seller is not active
        IF NEW.status = 'live' THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.sellers 
                WHERE id = NEW.seller_id AND status = 'active'
            ) THEN
                RAISE EXCEPTION 'Cannot approve or set product to live: owning seller is not active.';
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    -- 2. Non-Catalog-Admin (Sellers / Normal Users with auth.uid() present):
    -- Invariant A: Sellers cannot transfer product ownership or alter seller_id
    IF TG_OP = 'UPDATE' AND NEW.seller_id != OLD.seller_id THEN
        RAISE EXCEPTION 'Sellers are strictly prohibited from transferring product ownership or changing seller_id.';
    END IF;

    -- Invariant B: Sellers cannot directly set product status to 'live'
    IF NEW.status = 'live' THEN
        RAISE EXCEPTION 'Sellers cannot directly set product status to live. Product approval requires authorized catalog admin review.';
    END IF;

    -- Invariant C: Sellers cannot directly set internal moderation statuses
    IF NEW.status IN ('in_review', 'rejected', 'suspended', 'archived') THEN
        -- Allow seller to archive only if transitioning from draft
        IF NOT (TG_OP = 'UPDATE' AND OLD.status = 'draft' AND NEW.status = 'archived') THEN
            RAISE EXCEPTION 'Sellers cannot transition product status to %. This state requires administrative moderation.', NEW.status;
        END IF;
    END IF;

    -- Invariant D: On INSERT, new products must be 'draft' or 'submitted'
    IF TG_OP = 'INSERT' AND NEW.status NOT IN ('draft', 'submitted') THEN
        RAISE EXCEPTION 'New products created by seller must have status draft or submitted.';
    END IF;

    -- Invariant E: On UPDATE, sellers may only transition between draft and submitted (or resubmit rejected)
    IF TG_OP = 'UPDATE' AND NEW.status != OLD.status THEN
        IF OLD.status IN ('draft', 'submitted', 'rejected') AND NEW.status IN ('draft', 'submitted') THEN
            RETURN NEW;
        ELSIF OLD.status = 'draft' AND NEW.status = 'archived' THEN
            RETURN NEW;
        ELSE
            RAISE EXCEPTION 'Unauthorized product status transition from % to % by seller.', OLD.status, NEW.status;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

DROP TRIGGER IF EXISTS trg_enforce_product_lifecycle ON public.products;
CREATE TRIGGER trg_enforce_product_lifecycle
BEFORE INSERT OR UPDATE ON public.products
FOR EACH ROW EXECUTE FUNCTION public.enforce_product_lifecycle();

-- Authoritative Product Approval RPC (Admin Only)
CREATE OR REPLACE FUNCTION public.approve_product(p_product_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_product RECORD;
    v_seller RECORD;
    v_variant_count INTEGER;
    v_primary_media_count INTEGER;
BEGIN
    -- 1. Authorization: Catalog Admin or Super Admin only
    IF NOT public.has_role('admin_catalog') THEN
        RAISE EXCEPTION 'Permission denied: approve_product requires admin_catalog role.';
    END IF;

    -- 2. Product Record Lookup
    SELECT * INTO v_product FROM public.products WHERE id = p_product_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', p_product_id;
    END IF;

    -- 3. Seller Status Gate: Owning seller must be active
    SELECT * INTO v_seller FROM public.sellers WHERE id = v_product.seller_id;
    IF NOT FOUND OR v_seller.status != 'active' THEN
        RAISE EXCEPTION 'Cannot approve product: owning seller % is not active (current status: %).', v_product.seller_id, COALESCE(v_seller.status::text, 'unknown');
    END IF;

    -- 4. Variant Gate: Product must have at least one active variant with valid pricing
    SELECT count(*) INTO v_variant_count 
    FROM public.product_variants 
    WHERE product_id = p_product_id AND is_active = true AND price_paise >= 0;
    
    IF v_variant_count = 0 THEN
        RAISE EXCEPTION 'Cannot approve product: product must have at least one active variant with valid pricing.';
    END IF;

    -- 5. Media Gate: Product must have a primary media asset
    SELECT count(*) INTO v_primary_media_count 
    FROM public.media_assets 
    WHERE product_id = p_product_id AND slot_role = 'primary';

    IF v_primary_media_count = 0 THEN
        RAISE EXCEPTION 'Cannot approve product: product must have at least one primary media asset.';
    END IF;

    -- 6. Execute Transition to LIVE
    UPDATE public.products 
    SET status = 'live', rejection_reason = NULL, updated_at = CURRENT_TIMESTAMP
    WHERE id = p_product_id;

    -- 7. Record Immutable Admin Audit Log
    INSERT INTO public.admin_audit_logs (
        admin_id, action, entity_type, entity_id, previous_state, new_state
    ) VALUES (
        auth.uid(),
        'APPROVE_PRODUCT',
        'product',
        p_product_id::text,
        jsonb_build_object('status', v_product.status),
        jsonb_build_object('status', 'live')
    );

    RETURN jsonb_build_object(
        'success', true,
        'product_id', p_product_id,
        'status', 'live'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- Authoritative Product Rejection RPC (Admin Only)
CREATE OR REPLACE FUNCTION public.reject_product(p_product_id UUID, p_reason TEXT)
RETURNS JSONB AS $$
DECLARE
    v_product RECORD;
BEGIN
    IF NOT public.has_role('admin_catalog') THEN
        RAISE EXCEPTION 'Permission denied: reject_product requires admin_catalog role.';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Rejection reason must be provided.';
    END IF;

    SELECT * INTO v_product FROM public.products WHERE id = p_product_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found: %', p_product_id;
    END IF;

    UPDATE public.products 
    SET status = 'rejected', rejection_reason = p_reason, updated_at = CURRENT_TIMESTAMP
    WHERE id = p_product_id;

    INSERT INTO public.admin_audit_logs (
        admin_id, action, entity_type, entity_id, previous_state, new_state
    ) VALUES (
        auth.uid(),
        'REJECT_PRODUCT',
        'product',
        p_product_id::text,
        jsonb_build_object('status', v_product.status),
        jsonb_build_object('status', 'rejected', 'rejection_reason', p_reason)
    );

    RETURN jsonb_build_object(
        'success', true,
        'product_id', p_product_id,
        'status', 'rejected'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- Authoritative Seller Submission RPC (Seller Only)
CREATE OR REPLACE FUNCTION public.submit_product_for_review(p_product_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_product RECORD;
    v_seller_id UUID := public.current_seller_id();
BEGIN
    IF v_seller_id IS NULL THEN
        RAISE EXCEPTION 'Permission denied: caller is not an active seller.';
    END IF;

    SELECT * INTO v_product FROM public.products WHERE id = p_product_id AND seller_id = v_seller_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found or not owned by active seller.';
    END IF;

    IF v_product.status NOT IN ('draft', 'rejected') THEN
        RAISE EXCEPTION 'Only draft or rejected products may be submitted for review (current status: %).', v_product.status;
    END IF;

    -- Validate variant count
    IF NOT EXISTS (SELECT 1 FROM public.product_variants WHERE product_id = p_product_id AND is_active = true) THEN
        RAISE EXCEPTION 'Product must have at least one variant before submitting for review.';
    END IF;

    UPDATE public.products 
    SET status = 'submitted', updated_at = CURRENT_TIMESTAMP
    WHERE id = p_product_id;

    RETURN jsonb_build_object(
        'success', true,
        'product_id', p_product_id,
        'status', 'submitted'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- ============================================================================
-- 6. UNIVERSAL VISIBILITY GATE & ROW-LEVEL SECURITY UPDATES (DOMAINS 2 & 5)
-- Live Product + Active Seller + Inventory/MTO Visibility
-- ============================================================================

-- 6.0 Security Definer RLS Helpers to avoid recursive policy evaluation
CREATE OR REPLACE FUNCTION public.product_has_available_inventory(p_product_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.product_variants pv
        LEFT JOIN public.inventory_items ii ON pv.id = ii.variant_id
        WHERE pv.product_id = p_product_id
          AND pv.is_active = true
          AND (ii.id IS NULL OR ii.quantity_on_hand > ii.quantity_reserved)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.is_product_visible(p_product_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.products p
        JOIN public.sellers s ON p.seller_id = s.id
        WHERE p.id = p_product_id
          AND p.status = 'live'
          AND s.status = 'active'
          AND (p.is_made_to_order = true OR public.product_has_available_inventory(p_product_id))
    )
    OR EXISTS (
        SELECT 1 FROM public.products p
        JOIN public.sellers s ON p.seller_id = s.id
        WHERE p.id = p_product_id AND s.user_id = auth.uid()
    )
    OR public.has_role('admin_catalog')
    OR public.has_role('admin_viewer');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.can_seller_write_product(p_product_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.products p
        JOIN public.sellers s ON p.seller_id = s.id
        WHERE p.id = p_product_id 
          AND s.user_id = auth.uid() 
          AND s.status = 'active'
    ) OR public.has_role('admin_catalog');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- 6.1 Products Universal Visibility Gate
DROP POLICY IF EXISTS p_products_read ON public.products;
CREATE POLICY p_products_read ON public.products FOR SELECT
USING (public.is_product_visible(id));

-- 6.2 Product Variants Universal Visibility
DROP POLICY IF EXISTS p_variants_read ON public.product_variants;
CREATE POLICY p_variants_read ON public.product_variants FOR SELECT
USING (public.is_product_visible(product_id));

DROP POLICY IF EXISTS p_variants_write ON public.product_variants;
CREATE POLICY p_variants_write ON public.product_variants FOR ALL
USING (public.can_seller_write_product(product_id))
WITH CHECK (public.can_seller_write_product(product_id));

-- 6.3 Media Assets Universal Visibility
DROP POLICY IF EXISTS p_media_read ON public.media_assets;
CREATE POLICY p_media_read ON public.media_assets FOR SELECT
USING (public.is_product_visible(product_id));

DROP POLICY IF EXISTS p_media_write ON public.media_assets;
CREATE POLICY p_media_write ON public.media_assets FOR ALL
USING (public.can_seller_write_product(product_id))
WITH CHECK (public.can_seller_write_product(product_id));

-- 6.4 Product Occasions RLS
DROP POLICY IF EXISTS p_product_occasions_read ON public.product_occasions;
CREATE POLICY p_product_occasions_read ON public.product_occasions FOR SELECT
USING (public.is_product_visible(product_id));

DROP POLICY IF EXISTS p_product_occasions_write ON public.product_occasions;
CREATE POLICY p_product_occasions_write ON public.product_occasions FOR ALL
USING (public.can_seller_write_product(product_id))
WITH CHECK (public.can_seller_write_product(product_id));

-- 6.5 Seller Privacy Shield: Public cannot query sensitive seller rows directly
DROP POLICY IF EXISTS p_sellers_read ON public.sellers;
CREATE POLICY p_sellers_read ON public.sellers FOR SELECT
USING (
    user_id = auth.uid() 
    OR has_role('admin_viewer') 
    OR has_role('admin_finance') 
    OR has_role('admin_catalog')
);

-- ============================================================================
-- 7. PUBLIC DISCOVERY VIEWS & DISCOVERY RPCS (DOMAINS 2 & 12)
-- Server-Side Surface Resolution & Controlled Public Projection
-- ============================================================================

-- 7.1 Non-Sensitive Public Sellers Directory View
CREATE OR REPLACE VIEW public.public_sellers AS
SELECT id, business_name, seller_slug
FROM public.sellers
WHERE status = 'active';

GRANT SELECT ON public.public_sellers TO anon, authenticated;

-- 7.2 Authoritative Public Catalog Products View
CREATE OR REPLACE VIEW public.public_catalog_products AS
SELECT 
    p.id,
    p.title,
    p.slug,
    p.description,
    p.materials,
    p.care_instructions,
    p.is_made_to_order,
    p.is_new_arrival,
    p.is_launchpad,
    p.created_at,
    c.id AS category_id,
    c.name AS category_name,
    c.slug AS category_slug,
    sc.id AS subcategory_id,
    sc.name AS subcategory_name,
    sc.slug AS subcategory_slug,
    b.id AS brand_id,
    b.name AS brand_name,
    b.slug AS brand_slug,
    b.logo_url AS brand_logo_url,
    d.id AS designer_id,
    d.name AS designer_name,
    d.slug AS designer_slug,
    o.id AS occasion_id,
    o.name AS occasion_name,
    o.slug AS occasion_slug,
    ma.asset_url AS primary_image_url,
    ma.alt_text AS primary_image_alt,
    COALESCE(
        (SELECT MIN(pv.price_paise) FROM public.product_variants pv WHERE pv.product_id = p.id AND pv.is_active = true),
        0
    ) AS min_price_paise,
    COALESCE(
        (SELECT MAX(pv.price_paise) FROM public.product_variants pv WHERE pv.product_id = p.id AND pv.is_active = true),
        0
    ) AS max_price_paise
FROM public.products p
JOIN public.sellers s ON p.seller_id = s.id
JOIN public.brands b ON p.brand_id = b.id
JOIN public.subcategories sc ON p.subcategory_id = sc.id
JOIN public.categories c ON p.category_id = c.id
LEFT JOIN public.designers d ON p.designer_id = d.id
LEFT JOIN public.occasions o ON p.occasion_id = o.id
LEFT JOIN public.media_assets ma ON ma.product_id = p.id AND ma.slot_role = 'primary'
WHERE p.status = 'live' 
  AND s.status = 'active'
  AND (
      p.is_made_to_order = true 
      OR EXISTS (
          SELECT 1 FROM public.product_variants pv
          LEFT JOIN public.inventory_items ii ON pv.id = ii.variant_id
          WHERE pv.product_id = p.id 
            AND pv.is_active = true
            AND (ii.id IS NULL OR ii.quantity_on_hand > ii.quantity_reserved)
      )
  );

GRANT SELECT ON public.public_catalog_products TO anon, authenticated;

-- 7.3 Public Discovery RPC: Filter, Sort & Paginate Catalog
CREATE OR REPLACE FUNCTION public.get_public_catalog(
    p_category_slug TEXT DEFAULT NULL,
    p_subcategory_slug TEXT DEFAULT NULL,
    p_brand_slugs TEXT[] DEFAULT NULL,
    p_occasion_slugs TEXT[] DEFAULT NULL,
    p_min_price_paise BIGINT DEFAULT NULL,
    p_max_price_paise BIGINT DEFAULT NULL,
    p_is_mto BOOLEAN DEFAULT NULL,
    p_is_new_arrival BOOLEAN DEFAULT NULL,
    p_is_launchpad BOOLEAN DEFAULT NULL,
    p_sort TEXT DEFAULT 'recommended',
    p_limit INTEGER DEFAULT 40,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
    v_total INTEGER;
    v_items JSONB;
BEGIN
    -- 1. Filtered Count
    SELECT count(*) INTO v_total
    FROM public.public_catalog_products p
    WHERE (p_category_slug IS NULL OR p.category_slug = p_category_slug)
      AND (p_subcategory_slug IS NULL OR p.subcategory_slug = p_subcategory_slug)
      AND (p_brand_slugs IS NULL OR p.brand_slug = ANY(p_brand_slugs))
      AND (p_occasion_slugs IS NULL OR p.occasion_slug = ANY(p_occasion_slugs))
      AND (p_min_price_paise IS NULL OR p.max_price_paise >= p_min_price_paise)
      AND (p_max_price_paise IS NULL OR p.min_price_paise <= p_max_price_paise)
      AND (p_is_mto IS NULL OR p.is_made_to_order = p_is_mto)
      AND (p_is_new_arrival IS NULL OR p.is_new_arrival = p_is_new_arrival)
      AND (p_is_launchpad IS NULL OR p.is_launchpad = p_is_launchpad);

    -- 2. Filtered, Sorted & Paginated Records
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb) INTO v_items
    FROM (
        SELECT 
            p.id,
            p.title,
            p.slug,
            p.description,
            p.materials,
            p.care_instructions,
            p.is_made_to_order,
            p.is_new_arrival,
            p.is_launchpad,
            p.category_name,
            p.category_slug,
            p.subcategory_name,
            p.subcategory_slug,
            p.brand_name,
            p.brand_slug,
            p.brand_logo_url,
            p.designer_name,
            p.designer_slug,
            p.occasion_name,
            p.occasion_slug,
            p.primary_image_url,
            p.primary_image_alt,
            p.min_price_paise,
            p.max_price_paise
        FROM public.public_catalog_products p
        WHERE (p_category_slug IS NULL OR p.category_slug = p_category_slug)
          AND (p_subcategory_slug IS NULL OR p.subcategory_slug = p_subcategory_slug)
          AND (p_brand_slugs IS NULL OR p.brand_slug = ANY(p_brand_slugs))
          AND (p_occasion_slugs IS NULL OR p.occasion_slug = ANY(p_occasion_slugs))
          AND (p_min_price_paise IS NULL OR p.max_price_paise >= p_min_price_paise)
          AND (p_max_price_paise IS NULL OR p.min_price_paise <= p_max_price_paise)
          AND (p_is_mto IS NULL OR p.is_made_to_order = p_is_mto)
          AND (p_is_new_arrival IS NULL OR p.is_new_arrival = p_is_new_arrival)
          AND (p_is_launchpad IS NULL OR p.is_launchpad = p_is_launchpad)
        ORDER BY
            CASE WHEN p_sort = 'price-asc' THEN p.min_price_paise END ASC,
            CASE WHEN p_sort = 'price-desc' THEN p.min_price_paise END DESC,
            CASE WHEN p_sort = 'newest' THEN p.created_at END DESC,
            p.created_at DESC
        LIMIT GREATEST(1, LEAST(p_limit, 100))
        OFFSET GREATEST(0, p_offset)
    ) sub;

    RETURN jsonb_build_object(
        'total', v_total,
        'limit', p_limit,
        'offset', p_offset,
        'items', v_items
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

GRANT EXECUTE ON FUNCTION public.get_public_catalog TO anon, authenticated;

-- 7.4 Public PDP Discovery RPC: Get Complete Product by Slug
CREATE OR REPLACE FUNCTION public.get_public_product_by_slug(p_slug TEXT)
RETURNS JSONB AS $$
DECLARE
    v_prod RECORD;
    v_variants JSONB;
    v_media JSONB;
BEGIN
    SELECT * INTO v_prod FROM public.public_catalog_products WHERE slug = p_slug;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Fetch active variants with availability indicator
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', pv.id,
            'sku', pv.sku,
            'size', pv.size,
            'color', pv.color,
            'color_hex', pv.color_hex,
            'price_paise', pv.price_paise,
            'compare_at_price_paise', pv.compare_at_price_paise,
            'in_stock', (v_prod.is_made_to_order OR COALESCE(ii.quantity_on_hand - ii.quantity_reserved, 0) > 0)
        ) ORDER BY pv.price_paise ASC, pv.size ASC
    ), '[]'::jsonb) INTO v_variants
    FROM public.product_variants pv
    LEFT JOIN public.inventory_items ii ON pv.id = ii.variant_id
    WHERE pv.product_id = v_prod.id AND pv.is_active = true;

    -- Fetch media gallery in sort order
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', ma.id,
            'slot_role', ma.slot_role,
            'asset_url', ma.asset_url,
            'thumbnail_url', ma.thumbnail_url,
            'alt_text', ma.alt_text,
            'sort_order', ma.sort_order
        ) ORDER BY ma.sort_order ASC, ma.created_at ASC
    ), '[]'::jsonb) INTO v_media
    FROM public.media_assets ma
    WHERE ma.product_id = v_prod.id;

    RETURN jsonb_build_object(
        'id', v_prod.id,
        'title', v_prod.title,
        'slug', v_prod.slug,
        'description', v_prod.description,
        'materials', v_prod.materials,
        'care_instructions', v_prod.care_instructions,
        'is_made_to_order', v_prod.is_made_to_order,
        'is_new_arrival', v_prod.is_new_arrival,
        'is_launchpad', v_prod.is_launchpad,
        'category', jsonb_build_object('id', v_prod.category_id, 'name', v_prod.category_name, 'slug', v_prod.category_slug),
        'subcategory', jsonb_build_object('id', v_prod.subcategory_id, 'name', v_prod.subcategory_name, 'slug', v_prod.subcategory_slug),
        'brand', jsonb_build_object('id', v_prod.brand_id, 'name', v_prod.brand_name, 'slug', v_prod.brand_slug, 'logo_url', v_prod.brand_logo_url),
        'designer', CASE WHEN v_prod.designer_id IS NOT NULL THEN jsonb_build_object('id', v_prod.designer_id, 'name', v_prod.designer_name, 'slug', v_prod.designer_slug) ELSE NULL END,
        'occasion', CASE WHEN v_prod.occasion_id IS NOT NULL THEN jsonb_build_object('id', v_prod.occasion_id, 'name', v_prod.occasion_name, 'slug', v_prod.occasion_slug) ELSE NULL END,
        'variants', v_variants,
        'media', v_media
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

GRANT EXECUTE ON FUNCTION public.get_public_product_by_slug TO anon, authenticated;
