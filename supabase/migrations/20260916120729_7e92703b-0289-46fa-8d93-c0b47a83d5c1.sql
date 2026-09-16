-- ============================================================================
-- OGURA P2: AUTH, IDENTITY, ROLE RESOLUTION & RLS — CLOUD BOOTSTRAP
-- Source: 20260915000001_ogura_p2_auth_identity_rls.sql (unmodified on disk)
-- Cloud delta: local `auth.uid()` shim and the `on_auth_user_created` trigger on
-- auth.users are omitted (Supabase Cloud owns the auth schema). All other SQL identical.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.has_role(required_role user_role_type)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE user_id = v_user_id AND role = 'admin_super'
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE user_id = v_user_id AND role = required_role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.current_seller_id()
RETURNS UUID AS $$
DECLARE
    v_seller_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT id INTO v_seller_id 
    FROM public.sellers 
    WHERE user_id = auth.uid() AND status = 'active'
    LIMIT 1;

    RETURN v_seller_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.is_verified_purchase(p_product_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 
        FROM public.order_items oi
        JOIN public.product_variants pv ON oi.variant_id = pv.id
        JOIN public.seller_sub_orders sso ON oi.sub_order_id = sso.id
        JOIN public.orders o ON sso.order_id = o.id
        WHERE o.user_id = v_user_id
          AND pv.product_id = p_product_id
          AND o.status IN ('confirmed', 'partially_fulfilled', 'fulfilled', 'completed')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.enforce_single_admin_role()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.role IN ('customer', 'seller') THEN
        RETURN NEW;
    END IF;

    IF NEW.role = 'admin_super' OR EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE user_id = NEW.user_id AND role = 'admin_super'
    ) THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE user_id = NEW.user_id 
          AND role IN ('admin_catalog', 'admin_finance', 'admin_support', 'admin_viewer')
          AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) THEN
        RAISE EXCEPTION 'Non-super users may hold at most one admin role.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_enforce_single_admin_role ON user_roles;
CREATE TRIGGER trg_enforce_single_admin_role
BEFORE INSERT OR UPDATE ON user_roles
FOR EACH ROW EXECUTE FUNCTION public.enforce_single_admin_role();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, is_active)
    VALUES (NEW.id, NEW.email, '', true)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'customer')
    ON CONFLICT (user_id, role) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

-- ============================================================================
-- 2. ENABLE ROW-LEVEL SECURITY ON ALL 37 TABLES
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sellers ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE subcategories ENABLE ROW LEVEL SECURITY;
ALTER TABLE occasions ENABLE ROW LEVEL SECURITY;
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE designers ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkout_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_wishlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_sub_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE return_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE refund_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE mto_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_statements ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchandising_slots ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. IDENTITY & PROFILES POLICIES
-- ============================================================================

DROP POLICY IF EXISTS p_profiles_read ON profiles;
CREATE POLICY p_profiles_read ON profiles FOR SELECT
USING (id = auth.uid() OR has_role('admin_viewer') OR has_role('admin_support'));

DROP POLICY IF EXISTS p_profiles_update ON profiles;
CREATE POLICY p_profiles_update ON profiles FOR UPDATE
USING (id = auth.uid() OR has_role('admin_super'))
WITH CHECK (id = auth.uid() OR has_role('admin_super'));

DROP POLICY IF EXISTS p_user_roles_read ON user_roles;
CREATE POLICY p_user_roles_read ON user_roles FOR SELECT
USING (user_id = auth.uid() OR has_role('admin_super'));

DROP POLICY IF EXISTS p_user_roles_admin ON user_roles;
CREATE POLICY p_user_roles_admin ON user_roles FOR ALL
USING (has_role('admin_super'))
WITH CHECK (has_role('admin_super'));

DROP POLICY IF EXISTS p_addresses_customer ON customer_addresses;
CREATE POLICY p_addresses_customer ON customer_addresses FOR ALL
USING (user_id = auth.uid() OR has_role('admin_support'))
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS p_admin_audit_select ON admin_audit_logs;
CREATE POLICY p_admin_audit_select ON admin_audit_logs FOR SELECT
USING (has_role('admin_super'));

DROP POLICY IF EXISTS p_admin_audit_insert ON admin_audit_logs;
CREATE POLICY p_admin_audit_insert ON admin_audit_logs FOR INSERT
WITH CHECK (admin_id = auth.uid() AND (
    has_role('admin_super') OR has_role('admin_catalog') OR has_role('admin_finance') OR has_role('admin_support')
));

-- ============================================================================
-- 4. SELLER & KYC POLICIES
-- ============================================================================

DROP POLICY IF EXISTS p_sellers_read ON sellers;
CREATE POLICY p_sellers_read ON sellers FOR SELECT
USING (
    user_id = auth.uid() 
    OR status = 'active'
    OR has_role('admin_viewer') 
    OR has_role('admin_finance') 
    OR has_role('admin_catalog')
);

DROP POLICY IF EXISTS p_sellers_update ON sellers;
CREATE POLICY p_sellers_update ON sellers FOR UPDATE
USING (user_id = auth.uid() OR has_role('admin_finance'))
WITH CHECK (user_id = auth.uid() OR has_role('admin_finance'));

DROP POLICY IF EXISTS p_sellers_insert ON sellers;
CREATE POLICY p_sellers_insert ON sellers FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS p_kyc_read ON seller_kyc_documents;
CREATE POLICY p_kyc_read ON seller_kyc_documents FOR SELECT
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR has_role('admin_finance')
);

DROP POLICY IF EXISTS p_kyc_seller_insert ON seller_kyc_documents;
CREATE POLICY p_kyc_seller_insert ON seller_kyc_documents FOR INSERT
WITH CHECK (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS p_kyc_finance_update ON seller_kyc_documents;
CREATE POLICY p_kyc_finance_update ON seller_kyc_documents FOR UPDATE
USING (has_role('admin_finance'))
WITH CHECK (has_role('admin_finance'));

DROP POLICY IF EXISTS p_bank_read ON seller_bank_accounts;
CREATE POLICY p_bank_read ON seller_bank_accounts FOR SELECT
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR has_role('admin_finance')
);

DROP POLICY IF EXISTS p_bank_write ON seller_bank_accounts;
CREATE POLICY p_bank_write ON seller_bank_accounts FOR ALL
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR has_role('admin_finance')
)
WITH CHECK (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR has_role('admin_finance')
);

-- ============================================================================
-- 5. CATALOG & TAXONOMY POLICIES
-- ============================================================================

DROP POLICY IF EXISTS p_categories_read ON categories;
CREATE POLICY p_categories_read ON categories FOR SELECT
USING (is_active = true OR has_role('admin_catalog'));

DROP POLICY IF EXISTS p_categories_admin ON categories;
CREATE POLICY p_categories_admin ON categories FOR ALL
USING (has_role('admin_catalog'))
WITH CHECK (has_role('admin_catalog'));

DROP POLICY IF EXISTS p_subcategories_read ON subcategories;
CREATE POLICY p_subcategories_read ON subcategories FOR SELECT
USING (is_active = true OR has_role('admin_catalog'));

DROP POLICY IF EXISTS p_subcategories_admin ON subcategories;
CREATE POLICY p_subcategories_admin ON subcategories FOR ALL
USING (has_role('admin_catalog'))
WITH CHECK (has_role('admin_catalog'));

DROP POLICY IF EXISTS p_occasions_read ON occasions;
CREATE POLICY p_occasions_read ON occasions FOR SELECT
USING (is_active = true OR has_role('admin_catalog'));

DROP POLICY IF EXISTS p_occasions_admin ON occasions;
CREATE POLICY p_occasions_admin ON occasions FOR ALL
USING (has_role('admin_catalog'))
WITH CHECK (has_role('admin_catalog'));

DROP POLICY IF EXISTS p_brands_read ON brands;
CREATE POLICY p_brands_read ON brands FOR SELECT
USING (
    is_active = true 
    OR seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR has_role('admin_catalog')
);

DROP POLICY IF EXISTS p_brands_write ON brands;
CREATE POLICY p_brands_write ON brands FOR ALL
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR has_role('admin_catalog')
)
WITH CHECK (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR has_role('admin_catalog')
);

DROP POLICY IF EXISTS p_designers_read ON designers;
CREATE POLICY p_designers_read ON designers FOR SELECT
USING (is_active = true OR has_role('admin_catalog'));

DROP POLICY IF EXISTS p_designers_admin ON designers;
CREATE POLICY p_designers_admin ON designers FOR ALL
USING (has_role('admin_catalog'))
WITH CHECK (has_role('admin_catalog'));

DROP POLICY IF EXISTS p_products_read ON products;
CREATE POLICY p_products_read ON products FOR SELECT
USING (
    (status = 'live' AND seller_id IN (SELECT id FROM sellers WHERE status = 'active'))
    OR seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR has_role('admin_catalog')
    OR has_role('admin_viewer')
);

DROP POLICY IF EXISTS p_products_seller_write ON products;
CREATE POLICY p_products_seller_write ON products FOR ALL
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
    OR has_role('admin_catalog')
)
WITH CHECK (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
    OR has_role('admin_catalog')
);

DROP POLICY IF EXISTS p_variants_read ON product_variants;
CREATE POLICY p_variants_read ON product_variants FOR SELECT
USING (
    product_id IN (
        SELECT id FROM products 
        WHERE (status = 'live' AND seller_id IN (SELECT id FROM sellers WHERE status = 'active'))
           OR seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
           OR has_role('admin_catalog')
           OR has_role('admin_viewer')
    )
);

DROP POLICY IF EXISTS p_variants_write ON product_variants;
CREATE POLICY p_variants_write ON product_variants FOR ALL
USING (
    product_id IN (
        SELECT id FROM products 
        WHERE seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
           OR has_role('admin_catalog')
    )
)
WITH CHECK (
    product_id IN (
        SELECT id FROM products 
        WHERE seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
           OR has_role('admin_catalog')
    )
);

DROP POLICY IF EXISTS p_media_read ON media_assets;
CREATE POLICY p_media_read ON media_assets FOR SELECT
USING (
    product_id IN (
        SELECT id FROM products 
        WHERE (status = 'live' AND seller_id IN (SELECT id FROM sellers WHERE status = 'active'))
           OR seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
           OR has_role('admin_catalog')
    )
);

DROP POLICY IF EXISTS p_media_write ON media_assets;
CREATE POLICY p_media_write ON media_assets FOR ALL
USING (
    product_id IN (
        SELECT id FROM products 
        WHERE seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
           OR has_role('admin_catalog')
    )
)
WITH CHECK (
    product_id IN (
        SELECT id FROM products 
        WHERE seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
           OR has_role('admin_catalog')
    )
);

-- ============================================================================
-- 6. INVENTORY & RESERVATIONS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS p_inventory_read ON inventory_items;
CREATE POLICY p_inventory_read ON inventory_items FOR SELECT
USING (
    variant_id IN (
        SELECT pv.id FROM product_variants pv
        JOIN products p ON pv.product_id = p.id
        WHERE p.seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
           OR has_role('admin_catalog')
           OR has_role('admin_viewer')
    )
);

DROP POLICY IF EXISTS p_quotes_customer ON checkout_quotes;
CREATE POLICY p_quotes_customer ON checkout_quotes FOR SELECT
USING (user_id = auth.uid() OR has_role('admin_support'));

DROP POLICY IF EXISTS p_inventory_audit_read ON inventory_audit_log;
CREATE POLICY p_inventory_audit_read ON inventory_audit_log FOR SELECT
USING (has_role('admin_catalog') OR has_role('admin_super'));

-- ============================================================================
-- 7. COMMERCE, CARTS & WISHLIST POLICIES
-- ============================================================================

DROP POLICY IF EXISTS p_carts_owner ON carts;
CREATE POLICY p_carts_owner ON carts FOR ALL
USING (user_id = auth.uid() OR (user_id IS NULL AND session_id IS NOT NULL))
WITH CHECK (user_id = auth.uid() OR (user_id IS NULL AND session_id IS NOT NULL));

DROP POLICY IF EXISTS p_cart_lines_owner ON cart_lines;
CREATE POLICY p_cart_lines_owner ON cart_lines FOR ALL
USING (cart_id IN (SELECT id FROM carts WHERE user_id = auth.uid() OR (user_id IS NULL AND session_id IS NOT NULL)))
WITH CHECK (cart_id IN (SELECT id FROM carts WHERE user_id = auth.uid() OR (user_id IS NULL AND session_id IS NOT NULL)));

DROP POLICY IF EXISTS p_wishlist_owner ON customer_wishlist;
CREATE POLICY p_wishlist_owner ON customer_wishlist FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- 8. ORDERS, SUB-ORDERS & FULFILLMENT POLICIES
-- ============================================================================

DROP POLICY IF EXISTS p_orders_read ON orders;
CREATE POLICY p_orders_read ON orders FOR SELECT
USING (
    user_id = auth.uid() 
    OR has_role('admin_support') 
    OR has_role('admin_finance')
    OR has_role('admin_viewer')
);

DROP POLICY IF EXISTS p_sub_orders_read ON seller_sub_orders;
CREATE POLICY p_sub_orders_read ON seller_sub_orders FOR SELECT
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR order_id IN (SELECT id FROM orders WHERE user_id = auth.uid())
    OR has_role('admin_support')
    OR has_role('admin_finance')
    OR has_role('admin_viewer')
);

DROP POLICY IF EXISTS p_sub_orders_seller_update ON seller_sub_orders;
CREATE POLICY p_sub_orders_seller_update ON seller_sub_orders FOR UPDATE
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
    OR has_role('admin_support')
)
WITH CHECK (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
    OR has_role('admin_support')
);

DROP POLICY IF EXISTS p_order_items_read ON order_items;
CREATE POLICY p_order_items_read ON order_items FOR SELECT
USING (
    sub_order_id IN (
        SELECT id FROM seller_sub_orders 
        WHERE seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
           OR order_id IN (SELECT id FROM orders WHERE user_id = auth.uid())
           OR has_role('admin_support')
           OR has_role('admin_finance')
    )
);

DROP POLICY IF EXISTS p_shipments_read ON shipments;
CREATE POLICY p_shipments_read ON shipments FOR SELECT
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR sub_order_id IN (
        SELECT id FROM seller_sub_orders WHERE order_id IN (SELECT id FROM orders WHERE user_id = auth.uid())
    )
    OR has_role('admin_support')
);

DROP POLICY IF EXISTS p_shipments_seller_write ON shipments;
CREATE POLICY p_shipments_seller_write ON shipments FOR ALL
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
    OR has_role('admin_support')
)
WITH CHECK (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid() AND status = 'active')
    OR has_role('admin_support')
);

-- ============================================================================
-- 9. PAYMENTS, RETURNS & REFUNDS POLICIES
-- ============================================================================

DROP POLICY IF EXISTS p_payments_read ON payment_transactions;
CREATE POLICY p_payments_read ON payment_transactions FOR SELECT
USING (
    order_id IN (SELECT id FROM orders WHERE user_id = auth.uid())
    OR has_role('admin_finance')
);

DROP POLICY IF EXISTS p_returns_customer ON return_requests;
CREATE POLICY p_returns_customer ON return_requests FOR SELECT
USING (user_id = auth.uid() OR has_role('admin_support'));

DROP POLICY IF EXISTS p_returns_customer_insert ON return_requests;
CREATE POLICY p_returns_customer_insert ON return_requests FOR INSERT
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS p_returns_support_update ON return_requests;
CREATE POLICY p_returns_support_update ON return_requests FOR UPDATE
USING (has_role('admin_support'))
WITH CHECK (has_role('admin_support'));

DROP POLICY IF EXISTS p_refunds_finance ON refund_transactions;
CREATE POLICY p_refunds_finance ON refund_transactions FOR ALL
USING (has_role('admin_finance'))
WITH CHECK (has_role('admin_finance'));

-- ============================================================================
-- 10. MADE-TO-ORDER & MERCHANDISING POLICIES
-- ============================================================================

DROP POLICY IF EXISTS p_mto_read ON mto_requests;
CREATE POLICY p_mto_read ON mto_requests FOR SELECT
USING (
    user_id = auth.uid()
    OR product_id IN (SELECT id FROM products WHERE seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid()))
    OR has_role('admin_catalog')
    OR has_role('admin_support')
);

DROP POLICY IF EXISTS p_mto_insert ON mto_requests;
CREATE POLICY p_mto_insert ON mto_requests FOR INSERT
WITH CHECK (user_id = auth.uid() OR auth.uid() IS NULL);

DROP POLICY IF EXISTS p_reviews_read ON product_reviews;
CREATE POLICY p_reviews_read ON product_reviews FOR SELECT
USING (status = 'published' OR user_id = auth.uid() OR has_role('admin_support'));

DROP POLICY IF EXISTS p_reviews_insert ON product_reviews;
CREATE POLICY p_reviews_insert ON product_reviews FOR INSERT
WITH CHECK (
    user_id = auth.uid() 
    AND is_verified_purchase(product_id)
);

DROP POLICY IF EXISTS p_reviews_support ON product_reviews;
CREATE POLICY p_reviews_support ON product_reviews FOR UPDATE
USING (has_role('admin_support'))
WITH CHECK (has_role('admin_support'));

DROP POLICY IF EXISTS p_merchandising_read ON merchandising_slots;
CREATE POLICY p_merchandising_read ON merchandising_slots FOR SELECT
USING (
    (is_active = true AND (start_at IS NULL OR start_at <= now()) AND (end_at IS NULL OR end_at >= now()))
    OR has_role('admin_catalog')
);

DROP POLICY IF EXISTS p_merchandising_admin ON merchandising_slots;
CREATE POLICY p_merchandising_admin ON merchandising_slots FOR ALL
USING (has_role('admin_catalog'))
WITH CHECK (has_role('admin_catalog'));

-- ============================================================================
-- 11. FINANCE, LEDGER & SETTLEMENT POLICIES
-- ============================================================================

DROP POLICY IF EXISTS p_payouts_read ON payout_statements;
CREATE POLICY p_payouts_read ON payout_statements FOR SELECT
USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
    OR has_role('admin_finance')
);

DROP POLICY IF EXISTS p_payouts_finance ON payout_statements;
CREATE POLICY p_payouts_finance ON payout_statements FOR ALL
USING (has_role('admin_finance'))
WITH CHECK (has_role('admin_finance'));

DROP POLICY IF EXISTS p_ledger_finance ON financial_ledger_entries;
CREATE POLICY p_ledger_finance ON financial_ledger_entries FOR SELECT
USING (has_role('admin_finance'));

DROP POLICY IF EXISTS p_outbox_super ON notification_outbox;
CREATE POLICY p_outbox_super ON notification_outbox FOR SELECT
USING (has_role('admin_super'));

DROP POLICY IF EXISTS p_webhooks_super ON webhook_events;
CREATE POLICY p_webhooks_super ON webhook_events FOR SELECT
USING (has_role('admin_super'));