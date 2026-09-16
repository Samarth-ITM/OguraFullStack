-- ============================================================================
-- OGURA PHASE 9: FULFILLMENT & SHIPPING STATE ENGINE (PRD-ALIGNED)
-- ============================================================================

-- 1. EXTEND SCHEMA COLUMNS (IDEMPOTENT)
ALTER TABLE public.seller_sub_orders
    ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS dispatched_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
    ADD COLUMN IF NOT EXISTS awb VARCHAR(100),
    ADD COLUMN IF NOT EXISTS courier VARCHAR(100),
    ADD COLUMN IF NOT EXISTS ship_by TIMESTAMPTZ;

ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS fulfilled_at TIMESTAMPTZ;

-- 2. SHIPMENT IMMUTABILITY TRIGGER
CREATE OR REPLACE FUNCTION public.enforce_shipment_immutability()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'forbidden: shipment records cannot be deleted'
            USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.sub_order_id IS DISTINCT FROM NEW.sub_order_id OR
           OLD.seller_id IS DISTINCT FROM NEW.seller_id OR
           OLD.awb_number IS DISTINCT FROM NEW.awb_number THEN
            RAISE EXCEPTION 'forbidden: core shipment references (sub_order_id, seller_id, awb_number) are immutable'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_shipment_immutability ON public.shipments;
CREATE TRIGGER trg_enforce_shipment_immutability
BEFORE UPDATE OR DELETE ON public.shipments
FOR EACH ROW EXECUTE FUNCTION public.enforce_shipment_immutability();


-- 3. PARENT ORDER STATUS SYNCHRONIZATION FUNCTION
CREATE OR REPLACE FUNCTION public.sync_parent_order_fulfillment_status(p_order_id UUID)
RETURNS VOID AS $$
DECLARE
    v_total_sub_orders INT;
    v_delivered_count INT;
    v_dispatched_count INT;
    v_cancelled_count INT;
    v_active_count INT;
    v_current_parent_status order_status;
    v_target_parent_status order_status;
BEGIN
    SELECT status INTO v_current_parent_status
    FROM public.orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'delivered'),
        COUNT(*) FILTER (WHERE status = 'dispatched'),
        COUNT(*) FILTER (WHERE status = 'cancelled')
    INTO
        v_total_sub_orders,
        v_delivered_count,
        v_dispatched_count,
        v_cancelled_count
    FROM public.seller_sub_orders
    WHERE order_id = p_order_id;

    IF v_total_sub_orders = 0 THEN
        RETURN;
    END IF;

    v_active_count := v_total_sub_orders - v_cancelled_count;

    IF v_active_count = 0 THEN
        v_target_parent_status := 'cancelled';
    ELSIF v_delivered_count = v_active_count AND v_active_count > 0 THEN
        v_target_parent_status := 'fulfilled';
    ELSIF (v_dispatched_count > 0 OR v_delivered_count > 0) THEN
        v_target_parent_status := 'partially_fulfilled';
    ELSE
        v_target_parent_status := v_current_parent_status;
    END IF;

    IF v_target_parent_status IS DISTINCT FROM v_current_parent_status THEN
        UPDATE public.orders
        SET
            status = v_target_parent_status,
            fulfilled_at = CASE WHEN v_target_parent_status = 'fulfilled' THEN COALESCE(fulfilled_at, CURRENT_TIMESTAMP) ELSE fulfilled_at END,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_order_id;

        INSERT INTO public.order_status_history (
            order_id,
            from_status,
            to_status,
            actor_id,
            notes
        ) VALUES (
            p_order_id,
            v_current_parent_status::text,
            v_target_parent_status::text,
            auth.uid(),
            'Composite parent status updated to ' || v_target_parent_status::text || ' from sub-order fulfillment progression'
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 4. RPC: SELLER ACCEPT SUB-ORDER
CREATE OR REPLACE FUNCTION public.seller_accept_sub_order(p_sub_order_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_sub_order RECORD;
    v_seller RECORD;
    v_is_admin BOOLEAN := FALSE;
BEGIN
    SELECT (has_role('admin_super') OR has_role('admin_support'))
    INTO v_is_admin;

    SELECT * INTO v_sub_order
    FROM public.seller_sub_orders
    WHERE id = p_sub_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'sub_order_not_found: seller sub-order does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    IF NOT v_is_admin THEN
        SELECT * INTO v_seller
        FROM public.sellers
        WHERE user_id = auth.uid() AND id = v_sub_order.seller_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'access_denied: caller does not own this seller sub-order'
                USING ERRCODE = '42501';
        END IF;

        IF v_seller.status != 'active' THEN
            RAISE EXCEPTION 'seller_not_active: seller account is not active'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_sub_order.status = 'cancelled' THEN
        RAISE EXCEPTION 'invalid_state_transition: cannot accept a cancelled sub-order'
            USING ERRCODE = '22023';
    END IF;

    IF v_sub_order.status != 'pending_acceptance' THEN
        RETURN jsonb_build_object(
            'success', true,
            'sub_order_id', v_sub_order.id,
            'status', v_sub_order.status,
            'is_idempotent', true,
            'message', 'Sub-order is already accepted or in downstream fulfillment'
        );
    END IF;

    UPDATE public.seller_sub_orders
    SET
        status = 'accepted',
        accepted_at = COALESCE(accepted_at, CURRENT_TIMESTAMP),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_sub_order_id;

    INSERT INTO public.order_status_history (
        order_id,
        sub_order_id,
        from_status,
        to_status,
        actor_id,
        notes
    ) VALUES (
        v_sub_order.order_id,
        v_sub_order.id,
        'pending_acceptance',
        'accepted',
        auth.uid(),
        'Sub-order accepted by seller'
    );

    RETURN jsonb_build_object(
        'success', true,
        'sub_order_id', v_sub_order.id,
        'status', 'accepted',
        'accepted_at', CURRENT_TIMESTAMP
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 5. RPC: SELLER UPDATE SUB-ORDER STATUS
CREATE OR REPLACE FUNCTION public.seller_update_sub_order_status(
    p_sub_order_id UUID,
    p_status sub_order_status,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_sub_order RECORD;
    v_seller RECORD;
    v_is_admin BOOLEAN := FALSE;
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
    v_delivered_at TIMESTAMPTZ;
BEGIN
    SELECT (has_role('admin_super') OR has_role('admin_support'))
    INTO v_is_admin;

    SELECT * INTO v_sub_order
    FROM public.seller_sub_orders
    WHERE id = p_sub_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'sub_order_not_found: seller sub-order does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    IF NOT v_is_admin THEN
        SELECT * INTO v_seller
        FROM public.sellers
        WHERE user_id = auth.uid() AND id = v_sub_order.seller_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'access_denied: caller does not own this seller sub-order'
                USING ERRCODE = '42501';
        END IF;

        IF v_seller.status != 'active' THEN
            RAISE EXCEPTION 'seller_not_active: seller account is not active'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_sub_order.status = p_status THEN
        RETURN jsonb_build_object(
            'success', true,
            'sub_order_id', v_sub_order.id,
            'status', v_sub_order.status,
            'is_idempotent', true
        );
    END IF;

    IF p_status = 'pending_acceptance' THEN
        RAISE EXCEPTION 'invalid_state_transition: cannot revert sub-order to pending_acceptance'
            USING ERRCODE = '22023';
    END IF;

    IF v_sub_order.status IN ('delivered', 'cancelled') THEN
        RAISE EXCEPTION 'invalid_state_transition: sub-order is in terminal state %', v_sub_order.status
            USING ERRCODE = '22023';
    END IF;

    IF p_status = 'dispatched' THEN
        RAISE EXCEPTION 'forbidden_status_transition: shipping must be performed via seller_ship_sub_order with valid AWB and courier'
            USING ERRCODE = '42501';
    ELSIF p_status = 'delivered' THEN
        IF NOT v_is_admin THEN
            RAISE EXCEPTION 'forbidden_status_transition: delivered is a courier-controlled milestone and cannot be directly set by seller'
                USING ERRCODE = '42501';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM public.shipments
            WHERE sub_order_id = p_sub_order_id AND status = 'delivered'
        ) THEN
            RAISE EXCEPTION 'missing_delivered_shipment: sub-order cannot be marked delivered without a confirmed delivered shipment'
                USING ERRCODE = '22023';
        END IF;
        v_delivered_at := COALESCE(v_sub_order.delivered_at, v_now);
    ELSIF p_status = 'cancelled' THEN
        IF v_sub_order.status IN ('dispatched', 'delivered') THEN
            RAISE EXCEPTION 'cancellation_blocked_post_dispatch: cannot cancel sub-order that has already been dispatched'
                USING ERRCODE = '22023';
        END IF;
    ELSIF p_status = 'accepted' THEN
        IF v_sub_order.status != 'pending_acceptance' THEN
            RAISE EXCEPTION 'invalid_state_transition: cannot transition from % to accepted', v_sub_order.status
                USING ERRCODE = '22023';
        END IF;
    ELSIF p_status = 'in_crafting' THEN
        IF v_sub_order.status != 'accepted' THEN
            RAISE EXCEPTION 'invalid_state_transition: cannot transition from % to in_crafting', v_sub_order.status
                USING ERRCODE = '22023';
        END IF;
    ELSIF p_status = 'packed' THEN
        IF v_sub_order.status NOT IN ('accepted', 'in_crafting') THEN
            RAISE EXCEPTION 'invalid_state_transition: cannot transition from % to packed', v_sub_order.status
                USING ERRCODE = '22023';
        END IF;
    ELSIF p_status = 'ready_for_pickup' THEN
        IF v_sub_order.status NOT IN ('packed', 'accepted', 'in_crafting') THEN
            RAISE EXCEPTION 'invalid_state_transition: cannot transition from % to ready_for_pickup', v_sub_order.status
                USING ERRCODE = '22023';
        END IF;
    END IF;

    UPDATE public.seller_sub_orders
    SET
        status = p_status,
        accepted_at = CASE WHEN p_status = 'accepted' THEN COALESCE(accepted_at, v_now) ELSE accepted_at END,
        delivered_at = COALESCE(v_delivered_at, delivered_at),
        cancellation_reason = CASE WHEN p_status = 'cancelled' THEN COALESCE(p_notes, 'Cancelled by seller') ELSE cancellation_reason END,
        updated_at = v_now
    WHERE id = p_sub_order_id;

    INSERT INTO public.order_status_history (
        order_id,
        sub_order_id,
        from_status,
        to_status,
        actor_id,
        notes
    ) VALUES (
        v_sub_order.order_id,
        v_sub_order.id,
        v_sub_order.status::text,
        p_status::text,
        auth.uid(),
        p_notes
    );

    PERFORM public.sync_parent_order_fulfillment_status(v_sub_order.order_id);

    RETURN jsonb_build_object(
        'success', true,
        'sub_order_id', v_sub_order.id,
        'from_status', v_sub_order.status,
        'to_status', p_status,
        'updated_at', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 6. RPC: SELLER SHIP SUB-ORDER
CREATE OR REPLACE FUNCTION public.seller_ship_sub_order(
    p_sub_order_id UUID,
    p_shipping_mode VARCHAR DEFAULT 'manual',
    p_carrier VARCHAR DEFAULT NULL,
    p_awb_number VARCHAR DEFAULT NULL,
    p_tracking_url TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_sub_order RECORD;
    v_seller RECORD;
    v_existing_shipment RECORD;
    v_shipment_id UUID;
    v_is_admin BOOLEAN := FALSE;
    v_mode VARCHAR;
    v_carrier VARCHAR;
    v_awb VARCHAR;
    v_tracking_url TEXT;
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
BEGIN
    SELECT (has_role('admin_super') OR has_role('admin_support'))
    INTO v_is_admin;

    SELECT * INTO v_sub_order
    FROM public.seller_sub_orders
    WHERE id = p_sub_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'sub_order_not_found: seller sub-order does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    IF NOT v_is_admin THEN
        SELECT * INTO v_seller
        FROM public.sellers
        WHERE user_id = auth.uid() AND id = v_sub_order.seller_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'access_denied: caller does not own this seller sub-order'
                USING ERRCODE = '42501';
        END IF;

        IF v_seller.status != 'active' THEN
            RAISE EXCEPTION 'seller_not_active: seller account is not active'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_sub_order.status = 'pending_acceptance' THEN
        RAISE EXCEPTION 'sub_order_not_accepted: sub-order must be accepted before shipping'
            USING ERRCODE = '22023';
    END IF;

    IF v_sub_order.status = 'cancelled' THEN
        RAISE EXCEPTION 'invalid_state_transition: cannot ship a cancelled sub-order'
            USING ERRCODE = '22023';
    END IF;

    IF v_sub_order.status = 'delivered' THEN
        RAISE EXCEPTION 'invalid_state_transition: sub-order is already delivered'
            USING ERRCODE = '22023';
    END IF;

    v_mode := LOWER(COALESCE(TRIM(p_shipping_mode), 'manual'));
    IF v_mode NOT IN ('manual', 'aggregator') THEN
        RAISE EXCEPTION 'invalid_shipping_mode: shipping mode must be manual or aggregator'
            USING ERRCODE = '22023';
    END IF;

    IF v_mode = 'aggregator' THEN
        v_carrier := COALESCE(NULLIF(TRIM(p_carrier), ''), 'Delhivery');
        IF p_awb_number IS NOT NULL AND TRIM(p_awb_number) != '' THEN
            v_awb := TRIM(p_awb_number);
        ELSE
            v_awb := 'AGY-DEL-' || UPPER(SUBSTRING(REPLACE(p_sub_order_id::text, '-', ''), 1, 10)) || '-' || TO_CHAR(v_now, 'SSMS');
        END IF;
        v_tracking_url := COALESCE(p_tracking_url, 'https://track.delhivery.com/track?awb=' || v_awb);
    ELSE
        v_carrier := NULLIF(TRIM(p_carrier), '');
        v_awb := NULLIF(TRIM(p_awb_number), '');

        IF v_carrier IS NULL THEN
            RAISE EXCEPTION 'invalid_carrier: carrier name cannot be blank for manual AWB'
                USING ERRCODE = '22023';
        END IF;

        IF v_awb IS NULL OR LENGTH(v_awb) < 5 THEN
            RAISE EXCEPTION 'invalid_awb: AWB number cannot be blank and must be at least 5 characters'
                USING ERRCODE = '22023';
        END IF;

        v_tracking_url := COALESCE(p_tracking_url, 'https://track.ogura.com/manual/' || v_awb);
    END IF;

    SELECT * INTO v_existing_shipment
    FROM public.shipments
    WHERE sub_order_id = p_sub_order_id;

    IF FOUND THEN
        IF v_existing_shipment.awb_number = v_awb THEN
            RETURN jsonb_build_object(
                'success', true,
                'shipment_id', v_existing_shipment.id,
                'sub_order_id', v_existing_shipment.sub_order_id,
                'seller_id', v_existing_shipment.seller_id,
                'carrier', v_existing_shipment.carrier,
                'awb_number', v_existing_shipment.awb_number,
                'tracking_url', v_existing_shipment.tracking_url,
                'status', v_existing_shipment.status,
                'sub_order_status', v_sub_order.status,
                'is_idempotent', true,
                'message', 'Sub-order already shipped with this AWB'
            );
        ELSE
            RAISE EXCEPTION 'shipment_already_exists: sub-order already has an active shipment with AWB %', v_existing_shipment.awb_number
                USING ERRCODE = '22023';
        END IF;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.shipments
        WHERE awb_number = v_awb AND sub_order_id != p_sub_order_id
    ) THEN
        RAISE EXCEPTION 'duplicate_awb_number: AWB % is already registered to another shipment', v_awb
            USING ERRCODE = '23505';
    END IF;

    INSERT INTO public.shipments (
        sub_order_id,
        seller_id,
        carrier,
        awb_number,
        tracking_url,
        status,
        dispatched_at
    ) VALUES (
        v_sub_order.id,
        v_sub_order.seller_id,
        v_carrier,
        v_awb,
        v_tracking_url,
        'awb_assigned',
        v_now
    ) RETURNING id INTO v_shipment_id;

    UPDATE public.seller_sub_orders
    SET
        status = 'dispatched',
        awb = v_awb,
        courier = v_carrier,
        ship_by = COALESCE(ship_by, v_now + INTERVAL '2 days'),
        dispatched_at = COALESCE(dispatched_at, v_now),
        updated_at = v_now
    WHERE id = p_sub_order_id;

    INSERT INTO public.order_status_history (
        order_id,
        sub_order_id,
        from_status,
        to_status,
        actor_id,
        notes
    ) VALUES (
        v_sub_order.order_id,
        v_sub_order.id,
        v_sub_order.status::text,
        'dispatched',
        auth.uid(),
        'Sub-order shipped via ' || v_carrier || ' (AWB: ' || v_awb || ', Mode: ' || v_mode || ')'
    );

    PERFORM public.sync_parent_order_fulfillment_status(v_sub_order.order_id);

    RETURN jsonb_build_object(
        'success', true,
        'shipment_id', v_shipment_id,
        'sub_order_id', v_sub_order.id,
        'seller_id', v_sub_order.seller_id,
        'carrier', v_carrier,
        'awb_number', v_awb,
        'tracking_url', v_tracking_url,
        'shipping_mode', v_mode,
        'status', 'awb_assigned',
        'sub_order_status', 'dispatched',
        'dispatched_at', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 7. RPC: CREATE SHIPMENT (BACKWARD-COMPATIBLE ALIAS)
CREATE OR REPLACE FUNCTION public.create_shipment(
    p_sub_order_id UUID,
    p_carrier VARCHAR,
    p_awb_number VARCHAR,
    p_tracking_url TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    RETURN public.seller_ship_sub_order(
        p_sub_order_id,
        'manual',
        p_carrier,
        p_awb_number,
        p_tracking_url
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 8. RPC: UPDATE SHIPMENT STATUS
DROP FUNCTION IF EXISTS public.update_shipment_status(UUID, shipment_status, TEXT);
DROP FUNCTION IF EXISTS public.update_shipment_status(UUID, shipment_status, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.update_shipment_status(
    p_shipment_id UUID,
    p_status shipment_status,
    p_notes TEXT DEFAULT NULL,
    p_webhook_secret TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_shipment RECORD;
    v_sub_order RECORD;
    v_expected_secret TEXT;
    v_is_authorized BOOLEAN := FALSE;
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
    v_new_sub_order_status sub_order_status;
BEGIN
    v_expected_secret := COALESCE(current_setting('app.settings.webhook_secret', true), 'ogura_carrier_webhook_secret_p9');

    IF p_webhook_secret IS NOT NULL THEN
        IF p_webhook_secret != v_expected_secret THEN
            RAISE EXCEPTION 'invalid_webhook_secret: unauthorized webhook signature or secret'
                USING ERRCODE = '42501';
        END IF;
        v_is_authorized := TRUE;
    ELSIF (public.has_role('admin_super') OR public.has_role('admin_support') OR current_user = 'service_role' OR session_user = 'service_role') THEN
        v_is_authorized := TRUE;
    END IF;

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'access_denied: direct shipment status mutation is prohibited. Only carrier webhooks with valid secret or administrators may update shipment tracking'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_shipment
    FROM public.shipments
    WHERE id = p_shipment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'shipment_not_found: shipment record does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_shipment.status = p_status THEN
        RETURN jsonb_build_object(
            'success', true,
            'shipment_id', v_shipment.id,
            'sub_order_id', v_shipment.sub_order_id,
            'status', v_shipment.status,
            'is_idempotent', true
        );
    END IF;

    IF v_shipment.status IN ('delivered', 'rto_delivered') THEN
        RAISE EXCEPTION 'invalid_shipment_transition: cannot transition from terminal state % to %', v_shipment.status, p_status
            USING ERRCODE = '22023';
    END IF;

    IF v_shipment.status IN ('awb_assigned', 'pickup_scheduled', 'manifest_created') AND p_status = 'delivered' THEN
        RAISE EXCEPTION 'invalid_shipment_transition: parcel cannot jump from % directly to delivered without entering transit', v_shipment.status
            USING ERRCODE = '22023';
    END IF;

    UPDATE public.shipments
    SET
        status = p_status,
        pickup_scheduled_at = CASE WHEN p_status = 'pickup_scheduled' THEN COALESCE(pickup_scheduled_at, v_now) ELSE pickup_scheduled_at END,
        dispatched_at = CASE WHEN p_status IN ('in_transit', 'out_for_delivery') THEN COALESCE(dispatched_at, v_now) ELSE dispatched_at END,
        delivered_at = CASE WHEN p_status = 'delivered' THEN COALESCE(delivered_at, v_now) ELSE delivered_at END,
        updated_at = v_now
    WHERE id = p_shipment_id;

    SELECT * INTO v_sub_order
    FROM public.seller_sub_orders
    WHERE id = v_shipment.sub_order_id
    FOR UPDATE;

    IF p_status = 'delivered' THEN
        v_new_sub_order_status := 'delivered';
    ELSIF p_status IN ('in_transit', 'out_for_delivery') THEN
        v_new_sub_order_status := 'dispatched';
    ELSE
        v_new_sub_order_status := v_sub_order.status;
    END IF;

    IF v_new_sub_order_status IS DISTINCT FROM v_sub_order.status THEN
        UPDATE public.seller_sub_orders
        SET
            status = v_new_sub_order_status,
            dispatched_at = CASE WHEN v_new_sub_order_status = 'dispatched' THEN COALESCE(dispatched_at, v_now) ELSE dispatched_at END,
            delivered_at = CASE WHEN v_new_sub_order_status = 'delivered' THEN COALESCE(delivered_at, v_now) ELSE delivered_at END,
            updated_at = v_now
        WHERE id = v_sub_order.id;

        INSERT INTO public.order_status_history (
            order_id,
            sub_order_id,
            from_status,
            to_status,
            actor_id,
            notes
        ) VALUES (
            v_sub_order.order_id,
            v_sub_order.id,
            v_sub_order.status::text,
            v_new_sub_order_status::text,
            auth.uid(),
            COALESCE(p_notes, 'Sub-order status synchronized to ' || v_new_sub_order_status::text || ' via carrier event ' || p_status::text)
        );

        PERFORM public.sync_parent_order_fulfillment_status(v_sub_order.order_id);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'shipment_id', v_shipment.id,
        'sub_order_id', v_shipment.sub_order_id,
        'status', p_status,
        'sub_order_status', COALESCE(v_new_sub_order_status, v_sub_order.status),
        'updated_at', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 8B. RPC: PROCESS TRACKING WEBHOOK
CREATE OR REPLACE FUNCTION public.process_tracking_webhook(
    p_provider TEXT,
    p_event_id TEXT,
    p_event_type TEXT,
    p_payload JSONB,
    p_webhook_secret TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_expected_secret TEXT;
    v_webhook_event_id BIGINT;
    v_shipment_id UUID;
    v_awb TEXT;
    v_status shipment_status;
    v_notes TEXT;
    v_res JSONB;
BEGIN
    v_expected_secret := COALESCE(current_setting('app.settings.webhook_secret', true), 'ogura_carrier_webhook_secret_p9');

    IF p_webhook_secret IS NULL OR p_webhook_secret != v_expected_secret THEN
        IF NOT (public.has_role('admin_super') OR current_user = 'service_role' OR session_user = 'service_role') THEN
            RAISE EXCEPTION 'invalid_webhook_secret: unauthorized webhook signature or secret'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_provider IS NULL OR trim(p_provider) = '' THEN
        RAISE EXCEPTION 'invalid_provider: provider is required' USING ERRCODE = '22023';
    END IF;
    IF p_event_id IS NULL OR trim(p_event_id) = '' THEN
        RAISE EXCEPTION 'invalid_event_id: event_id is required' USING ERRCODE = '22023';
    END IF;
    IF p_payload IS NULL THEN
        RAISE EXCEPTION 'invalid_payload: payload is required' USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.webhook_events
        WHERE provider = p_provider AND event_id = p_event_id
    ) THEN
        RETURN jsonb_build_object(
            'success', true,
            'is_idempotent', true,
            'duplicate_event', true,
            'event_id', p_event_id,
            'message', 'Duplicate provider event ignored'
        );
    END IF;

    INSERT INTO public.webhook_events (
        provider,
        event_id,
        event_type,
        payload,
        signature,
        processed,
        processed_at
    ) VALUES (
        p_provider,
        p_event_id,
        COALESCE(p_event_type, 'tracking.status_updated'),
        p_payload,
        p_webhook_secret,
        false,
        NULL
    ) RETURNING id INTO v_webhook_event_id;

    v_shipment_id := (p_payload->>'shipment_id')::UUID;
    v_awb := p_payload->>'awb';
    v_status := (p_payload->>'status')::shipment_status;
    v_notes := p_payload->>'notes';

    IF v_shipment_id IS NULL AND v_awb IS NOT NULL THEN
        SELECT id INTO v_shipment_id FROM public.shipments WHERE awb_number = v_awb;
    END IF;

    IF v_shipment_id IS NULL THEN
        UPDATE public.webhook_events
        SET error_message = 'shipment_not_found for event payload'
        WHERE id = v_webhook_event_id;

        RAISE EXCEPTION 'shipment_not_found: cannot locate shipment record for event %', p_event_id
            USING ERRCODE = 'P0002';
    END IF;

    v_res := public.update_shipment_status(
        v_shipment_id,
        v_status,
        COALESCE(v_notes, 'Carrier tracking event ' || p_provider || ':' || p_event_id),
        v_expected_secret
    );

    UPDATE public.webhook_events
    SET
        processed = true,
        processed_at = CURRENT_TIMESTAMP
    WHERE id = v_webhook_event_id;

    RETURN jsonb_build_object(
        'success', true,
        'event_id', p_event_id,
        'provider', p_provider,
        'shipment_id', v_shipment_id,
        'status', v_status,
        'sub_order_status', v_res->>'sub_order_status',
        'is_idempotent', false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 9. RPC: GET SUB-ORDER FULFILLMENT DETAILS
CREATE OR REPLACE FUNCTION public.get_sub_order_fulfillment_details(p_sub_order_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_sub_order RECORD;
    v_shipment RECORD;
    v_items JSONB;
    v_history JSONB;
    v_is_admin BOOLEAN := FALSE;
    v_is_seller BOOLEAN := FALSE;
    v_is_customer BOOLEAN := FALSE;
BEGIN
    SELECT (has_role('admin_super') OR has_role('admin_support') OR has_role('admin_finance') OR has_role('admin_viewer'))
    INTO v_is_admin;

    SELECT * INTO v_sub_order
    FROM public.seller_sub_orders
    WHERE id = p_sub_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'sub_order_not_found: seller sub-order does not exist'
            USING ERRCODE = 'P0002';
    END IF;

    IF NOT v_is_admin THEN
        SELECT EXISTS (
            SELECT 1 FROM public.sellers
            WHERE user_id = auth.uid() AND id = v_sub_order.seller_id
        ) INTO v_is_seller;

        SELECT EXISTS (
            SELECT 1 FROM public.orders
            WHERE user_id = auth.uid() AND id = v_sub_order.order_id
        ) INTO v_is_customer;

        IF NOT (v_is_seller OR v_is_customer) THEN
            RAISE EXCEPTION 'access_denied: caller cannot inspect this sub-order'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT * INTO v_shipment
    FROM public.shipments
    WHERE sub_order_id = p_sub_order_id
    ORDER BY created_at DESC
    LIMIT 1;

    SELECT jsonb_agg(jsonb_build_object(
        'id', id,
        'variant_id', variant_id,
        'product_title', product_title,
        'variant_sku', variant_sku,
        'size', size,
        'color', color,
        'unit_price_paise', unit_price_paise,
        'quantity', quantity,
        'total_price_paise', total_price_paise
    )) INTO v_items
    FROM public.order_items
    WHERE sub_order_id = p_sub_order_id;

    SELECT jsonb_agg(jsonb_build_object(
        'from_status', from_status,
        'to_status', to_status,
        'actor_id', actor_id,
        'notes', notes,
        'created_at', created_at
    ) ORDER BY created_at ASC) INTO v_history
    FROM public.order_status_history
    WHERE sub_order_id = p_sub_order_id;

    RETURN jsonb_build_object(
        'sub_order_id', v_sub_order.id,
        'sub_order_number', v_sub_order.sub_order_number,
        'order_id', v_sub_order.order_id,
        'seller_id', v_sub_order.seller_id,
        'status', v_sub_order.status,
        'total_amount_paise', v_sub_order.total_amount_paise,
        'net_seller_payable_paise', v_sub_order.net_seller_payable_paise,
        'awb', v_sub_order.awb,
        'courier', v_sub_order.courier,
        'ship_by', v_sub_order.ship_by,
        'accepted_at', v_sub_order.accepted_at,
        'dispatched_at', v_sub_order.dispatched_at,
        'delivered_at', v_sub_order.delivered_at,
        'cancellation_reason', v_sub_order.cancellation_reason,
        'shipment', CASE WHEN v_shipment.id IS NOT NULL THEN jsonb_build_object(
            'id', v_shipment.id,
            'carrier', v_shipment.carrier,
            'awb_number', v_shipment.awb_number,
            'tracking_url', v_shipment.tracking_url,
            'status', v_shipment.status,
            'pickup_scheduled_at', v_shipment.pickup_scheduled_at,
            'dispatched_at', v_shipment.dispatched_at,
            'delivered_at', v_shipment.delivered_at
        ) ELSE NULL END,
        'items', COALESCE(v_items, '[]'::jsonb),
        'status_history', COALESCE(v_history, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;


-- 10. RPC GRANTS
GRANT EXECUTE ON FUNCTION public.seller_accept_sub_order(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.seller_update_sub_order_status(UUID, sub_order_status, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.seller_ship_sub_order(UUID, VARCHAR, VARCHAR, VARCHAR, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_shipment(UUID, VARCHAR, VARCHAR, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_shipment_status(UUID, shipment_status, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_tracking_webhook(TEXT, TEXT, TEXT, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_sub_order_fulfillment_details(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_parent_order_fulfillment_status(UUID) TO authenticated;

-- 11. RLS POLICIES FOR ORDER_STATUS_HISTORY
DO $$ BEGIN
    ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DROP POLICY IF EXISTS p_order_status_history_read ON public.order_status_history;
CREATE POLICY p_order_status_history_read ON public.order_status_history
    FOR SELECT TO authenticated
    USING (
        (order_id IN (SELECT id FROM public.orders WHERE user_id = auth.uid())) OR
        (sub_order_id IN (
            SELECT so.id FROM public.seller_sub_orders so
            JOIN public.sellers s ON s.id = so.seller_id
            WHERE s.user_id = auth.uid()
        )) OR
        has_role('admin_super') OR
        has_role('admin_support') OR
        has_role('admin_finance') OR
        has_role('admin_viewer')
    );

GRANT SELECT ON public.shipments TO authenticated;
GRANT SELECT ON public.order_status_history TO authenticated;
GRANT SELECT ON public.sellers TO authenticated;
GRANT SELECT ON public.profiles TO authenticated;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.seller_accept_sub_order(UUID) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.seller_update_sub_order_status(UUID, sub_order_status, TEXT) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.seller_ship_sub_order(UUID, VARCHAR, VARCHAR, VARCHAR, TEXT) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.create_shipment(UUID, VARCHAR, VARCHAR, TEXT) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_shipment_status(UUID, shipment_status, TEXT, TEXT) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_tracking_webhook(TEXT, TEXT, TEXT, JSONB, TEXT) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_sub_order_fulfillment_details(UUID) TO service_role';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_parent_order_fulfillment_status(UUID) TO service_role';
        EXECUTE 'GRANT SELECT ON public.shipments TO service_role';
        EXECUTE 'GRANT SELECT ON public.order_status_history TO service_role';
        EXECUTE 'GRANT SELECT ON public.sellers TO service_role';
        EXECUTE 'GRANT SELECT ON public.profiles TO service_role';
        EXECUTE 'GRANT SELECT, INSERT, UPDATE ON public.webhook_events TO service_role';
    END IF;
END $$;