-- OGURA P6: INVENTORY RESERVATION ENGINE
-- Source: 20260915000005_ogura_p6_inventory_reservation.sql (applied verbatim)

DROP POLICY IF EXISTS p_reservations_customer_select ON public.inventory_reservations;
CREATE POLICY p_reservations_customer_select ON public.inventory_reservations
FOR SELECT USING (
    (quote_id IN (SELECT id FROM public.checkout_quotes WHERE user_id = auth.uid()))
    OR public.has_role('admin_catalog')
    OR public.has_role('admin_super')
);

CREATE OR REPLACE FUNCTION public.get_variant_available_stock(p_variant_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_is_mto BOOLEAN;
    v_on_hand INTEGER;
    v_reserved INTEGER;
BEGIN
    SELECT p.is_made_to_order INTO v_is_mto
    FROM public.product_variants pv
    JOIN public.products p ON pv.product_id = p.id
    WHERE pv.id = p_variant_id;

    IF v_is_mto IS TRUE THEN
        RETURN 999999;
    END IF;

    SELECT quantity_on_hand, quantity_reserved
    INTO v_on_hand, v_reserved
    FROM public.inventory_items
    WHERE variant_id = p_variant_id;

    IF v_on_hand IS NULL THEN
        RETURN 0;
    END IF;

    RETURN GREATEST(0, v_on_hand - v_reserved);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.create_inventory_reservation(
    p_quote_id UUID,
    p_variant_id UUID,
    p_quantity INTEGER
)
RETURNS UUID AS $$
DECLARE
    v_caller_id UUID;
    v_quote_user_id UUID;
    v_quote_status checkout_quote_status;
    v_quote_expires_at TIMESTAMPTZ;
    v_is_mto BOOLEAN;
    v_inv_id UUID;
    v_on_hand INTEGER;
    v_reserved INTEGER;
    v_reservation_id UUID;
BEGIN
    v_caller_id := auth.uid();

    IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 10 THEN
        RAISE EXCEPTION 'invalid_quantity: reservation quantity must be an integer between 1 and 10'
            USING ERRCODE = '22003';
    END IF;

    SELECT user_id, status, expires_at
    INTO v_quote_user_id, v_quote_status, v_quote_expires_at
    FROM public.checkout_quotes
    WHERE id = p_quote_id;

    IF v_quote_status IS NULL THEN
        RAISE EXCEPTION 'quote_not_found: checkout quote % does not exist', p_quote_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_quote_status != 'pending'::checkout_quote_status THEN
        RAISE EXCEPTION 'invalid_quote_status: quote is in % status and cannot reserve inventory', v_quote_status
            USING ERRCODE = '22000';
    END IF;

    IF v_quote_expires_at <= CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'quote_expired: quote expired at %', v_quote_expires_at
            USING ERRCODE = '22000';
    END IF;

    IF v_caller_id IS NOT NULL AND v_quote_user_id IS NOT NULL AND v_caller_id != v_quote_user_id THEN
        IF NOT (public.has_role('admin_catalog') OR public.has_role('admin_super')) THEN
            RAISE EXCEPTION 'forbidden: cannot reserve inventory against another customer quote'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT p.is_made_to_order INTO v_is_mto
    FROM public.product_variants pv
    JOIN public.products p ON pv.product_id = p.id
    WHERE pv.id = p_variant_id;

    IF v_is_mto IS NULL THEN
        RAISE EXCEPTION 'variant_not_found: product variant % does not exist', p_variant_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_is_mto IS TRUE THEN
        INSERT INTO public.inventory_reservations (
            quote_id, variant_id, quantity, status, expires_at
        ) VALUES (
            p_quote_id, p_variant_id, p_quantity, 'held'::inventory_reservation_status, v_quote_expires_at
        ) RETURNING id INTO v_reservation_id;

        RETURN v_reservation_id;
    END IF;

    SELECT id, quantity_on_hand, quantity_reserved
    INTO v_inv_id, v_on_hand, v_reserved
    FROM public.inventory_items
    WHERE variant_id = p_variant_id
    FOR UPDATE;

    IF v_inv_id IS NULL THEN
        RAISE EXCEPTION 'inventory_item_not_found: no inventory record exists for variant %', p_variant_id
            USING ERRCODE = 'P0002';
    END IF;

    IF (v_on_hand - v_reserved) < p_quantity THEN
        RAISE EXCEPTION 'insufficient_inventory: requested % units but only % available',
            p_quantity, GREATEST(0, v_on_hand - v_reserved)
            USING ERRCODE = '55000';
    END IF;

    UPDATE public.inventory_items
    SET quantity_reserved = quantity_reserved + p_quantity,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_inv_id;

    INSERT INTO public.inventory_reservations (
        quote_id, variant_id, quantity, status, expires_at
    ) VALUES (
        p_quote_id, p_variant_id, p_quantity, 'held'::inventory_reservation_status, v_quote_expires_at
    ) RETURNING id INTO v_reservation_id;

    INSERT INTO public.inventory_audit_log (
        variant_id, change_type, quantity_delta, quantity_on_hand_after,
        quantity_reserved_after, reference_id, actor_id
    ) VALUES (
        p_variant_id, 'reservation_created', p_quantity, v_on_hand,
        v_reserved + p_quantity, v_reservation_id, v_caller_id
    );

    RETURN v_reservation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.reserve_inventory_for_quote(
    p_quote_id UUID,
    p_items JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_item RECORD;
    v_variant_id UUID;
    v_quantity INTEGER;
    v_res_id UUID;
    v_results JSONB := '[]'::jsonb;
BEGIN
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'empty_items: reservation items array cannot be empty'
            USING ERRCODE = '22000';
    END IF;

    FOR v_item IN
        SELECT (elem->>'variant_id')::UUID AS variant_id,
               (elem->>'quantity')::INTEGER AS quantity
        FROM jsonb_array_elements(p_items) AS elem
        ORDER BY (elem->>'variant_id')::UUID ASC
    LOOP
        v_res_id := public.create_inventory_reservation(p_quote_id, v_item.variant_id, v_item.quantity);
        v_results := v_results || jsonb_build_object(
            'variant_id', v_item.variant_id,
            'quantity', v_item.quantity,
            'reservation_id', v_res_id
        );
    END LOOP;

    RETURN v_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.release_inventory_reservation(p_reservation_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_quote_user_id UUID;
    v_variant_id UUID;
    v_quantity INTEGER;
    v_status inventory_reservation_status;
    v_is_mto BOOLEAN;
    v_on_hand INTEGER;
    v_reserved INTEGER;
BEGIN
    v_caller_id := auth.uid();

    SELECT ir.variant_id, ir.quantity, ir.status, cq.user_id, p.is_made_to_order
    INTO v_variant_id, v_quantity, v_status, v_quote_user_id, v_is_mto
    FROM public.inventory_reservations ir
    JOIN public.checkout_quotes cq ON ir.quote_id = cq.id
    JOIN public.product_variants pv ON ir.variant_id = pv.id
    JOIN public.products p ON pv.product_id = p.id
    WHERE ir.id = p_reservation_id
    FOR UPDATE OF ir;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'reservation_not_found: reservation % does not exist', p_reservation_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_caller_id IS NOT NULL AND v_quote_user_id IS NOT NULL AND v_caller_id != v_quote_user_id THEN
        IF NOT (public.has_role('admin_catalog') OR public.has_role('admin_super')) THEN
            RAISE EXCEPTION 'forbidden: cannot release another customer reservation'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_status = 'released'::inventory_reservation_status OR v_status = 'expired'::inventory_reservation_status THEN
        RETURN true;
    END IF;

    IF v_status = 'committed'::inventory_reservation_status THEN
        RAISE EXCEPTION 'cannot_release_committed: reservation % is committed/consumed and cannot be released', p_reservation_id
            USING ERRCODE = '22000';
    END IF;

    IF v_is_mto IS TRUE THEN
        UPDATE public.inventory_reservations
        SET status = 'released'::inventory_reservation_status,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_reservation_id;
        RETURN true;
    END IF;

    SELECT quantity_on_hand, quantity_reserved
    INTO v_on_hand, v_reserved
    FROM public.inventory_items
    WHERE variant_id = v_variant_id
    FOR UPDATE;

    UPDATE public.inventory_items
    SET quantity_reserved = GREATEST(0, quantity_reserved - v_quantity),
        updated_at = CURRENT_TIMESTAMP
    WHERE variant_id = v_variant_id;

    UPDATE public.inventory_reservations
    SET status = 'released'::inventory_reservation_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_reservation_id;

    INSERT INTO public.inventory_audit_log (
        variant_id, change_type, quantity_delta, quantity_on_hand_after,
        quantity_reserved_after, reference_id, actor_id
    ) VALUES (
        v_variant_id, 'reservation_released', -v_quantity, v_on_hand,
        GREATEST(0, v_reserved - v_quantity), p_reservation_id, v_caller_id
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.release_quote_reservations(p_quote_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_res RECORD;
    v_count INTEGER := 0;
BEGIN
    FOR v_res IN
        SELECT id FROM public.inventory_reservations
        WHERE quote_id = p_quote_id
          AND status = 'held'::inventory_reservation_status
        ORDER BY variant_id ASC
    LOOP
        PERFORM public.release_inventory_reservation(v_res.id);
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.expire_inventory_reservation(p_reservation_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_variant_id UUID;
    v_quantity INTEGER;
    v_status inventory_reservation_status;
    v_expires_at TIMESTAMPTZ;
    v_is_mto BOOLEAN;
    v_on_hand INTEGER;
    v_reserved INTEGER;
BEGIN
    SELECT ir.variant_id, ir.quantity, ir.status, ir.expires_at, p.is_made_to_order
    INTO v_variant_id, v_quantity, v_status, v_expires_at, v_is_mto
    FROM public.inventory_reservations ir
    JOIN public.product_variants pv ON ir.variant_id = pv.id
    JOIN public.products p ON pv.product_id = p.id
    WHERE ir.id = p_reservation_id
    FOR UPDATE OF ir;

    IF v_status IS NULL THEN
        RETURN false;
    END IF;

    IF v_status != 'held'::inventory_reservation_status THEN
        RETURN false;
    END IF;

    IF v_expires_at > CURRENT_TIMESTAMP THEN
        RETURN false;
    END IF;

    IF v_is_mto IS TRUE THEN
        UPDATE public.inventory_reservations
        SET status = 'expired'::inventory_reservation_status,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_reservation_id;
        RETURN true;
    END IF;

    SELECT quantity_on_hand, quantity_reserved
    INTO v_on_hand, v_reserved
    FROM public.inventory_items
    WHERE variant_id = v_variant_id
    FOR UPDATE;

    UPDATE public.inventory_items
    SET quantity_reserved = GREATEST(0, quantity_reserved - v_quantity),
        updated_at = CURRENT_TIMESTAMP
    WHERE variant_id = v_variant_id;

    UPDATE public.inventory_reservations
    SET status = 'expired'::inventory_reservation_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_reservation_id;

    INSERT INTO public.inventory_audit_log (
        variant_id, change_type, quantity_delta, quantity_on_hand_after,
        quantity_reserved_after, reference_id, actor_id
    ) VALUES (
        v_variant_id, 'reservation_expired', -v_quantity, v_on_hand,
        GREATEST(0, v_reserved - v_quantity), p_reservation_id, NULL
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.expire_stale_reservations(p_batch_limit INTEGER DEFAULT 100)
RETURNS INTEGER AS $$
DECLARE
    v_res RECORD;
    v_expired_count INTEGER := 0;
BEGIN
    FOR v_res IN
        SELECT id FROM public.inventory_reservations
        WHERE status = 'held'::inventory_reservation_status
          AND expires_at <= CURRENT_TIMESTAMP
        ORDER BY variant_id ASC
        LIMIT p_batch_limit
        FOR UPDATE SKIP LOCKED
    LOOP
        IF public.expire_inventory_reservation(v_res.id) THEN
            v_expired_count := v_expired_count + 1;
        END IF;
    END LOOP;

    RETURN v_expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.consume_inventory_reservation(p_reservation_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_caller_id UUID;
    v_quote_user_id UUID;
    v_variant_id UUID;
    v_quantity INTEGER;
    v_status inventory_reservation_status;
    v_expires_at TIMESTAMPTZ;
    v_is_mto BOOLEAN;
    v_on_hand INTEGER;
    v_reserved INTEGER;
BEGIN
    v_caller_id := auth.uid();

    SELECT ir.variant_id, ir.quantity, ir.status, ir.expires_at, cq.user_id, p.is_made_to_order
    INTO v_variant_id, v_quantity, v_status, v_expires_at, v_quote_user_id, v_is_mto
    FROM public.inventory_reservations ir
    JOIN public.checkout_quotes cq ON ir.quote_id = cq.id
    JOIN public.product_variants pv ON ir.variant_id = pv.id
    JOIN public.products p ON pv.product_id = p.id
    WHERE ir.id = p_reservation_id
    FOR UPDATE OF ir;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'reservation_not_found: reservation % does not exist', p_reservation_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_caller_id IS NOT NULL AND v_quote_user_id IS NOT NULL AND v_caller_id != v_quote_user_id THEN
        IF NOT (public.has_role('admin_catalog') OR public.has_role('admin_super')) THEN
            RAISE EXCEPTION 'forbidden: cannot consume another customer reservation'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_status = 'committed'::inventory_reservation_status THEN
        RETURN true;
    END IF;

    IF v_status = 'released'::inventory_reservation_status OR v_status = 'expired'::inventory_reservation_status THEN
        RAISE EXCEPTION 'cannot_consume_inactive_reservation: reservation % is % and cannot be consumed',
            p_reservation_id, v_status
            USING ERRCODE = '22000';
    END IF;

    IF v_expires_at < CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'reservation_expired: reservation % expired at % and cannot be consumed',
            p_reservation_id, v_expires_at
            USING ERRCODE = '22000';
    END IF;

    IF v_is_mto IS TRUE THEN
        UPDATE public.inventory_reservations
        SET status = 'committed'::inventory_reservation_status,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_reservation_id;
        RETURN true;
    END IF;

    SELECT quantity_on_hand, quantity_reserved
    INTO v_on_hand, v_reserved
    FROM public.inventory_items
    WHERE variant_id = v_variant_id
    FOR UPDATE;

    IF v_on_hand < v_quantity OR v_reserved < v_quantity THEN
        RAISE EXCEPTION 'inventory_corruption: on_hand (%) or reserved (%) is less than reservation quantity (%)',
            v_on_hand, v_reserved, v_quantity
            USING ERRCODE = '55000';
    END IF;

    UPDATE public.inventory_items
    SET quantity_on_hand = quantity_on_hand - v_quantity,
        quantity_reserved = quantity_reserved - v_quantity,
        updated_at = CURRENT_TIMESTAMP
    WHERE variant_id = v_variant_id;

    UPDATE public.inventory_reservations
    SET status = 'committed'::inventory_reservation_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_reservation_id;

    INSERT INTO public.inventory_audit_log (
        variant_id, change_type, quantity_delta, quantity_on_hand_after,
        quantity_reserved_after, reference_id, actor_id
    ) VALUES (
        v_variant_id, 'reservation_consumed', -v_quantity, v_on_hand - v_quantity,
        v_reserved - v_quantity, p_reservation_id, v_caller_id
    );

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

CREATE OR REPLACE FUNCTION public.consume_quote_reservations(p_quote_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_res RECORD;
    v_count INTEGER := 0;
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.inventory_reservations
        WHERE quote_id = p_quote_id
          AND status = 'held'::inventory_reservation_status
          AND expires_at < CURRENT_TIMESTAMP
    ) THEN
        RAISE EXCEPTION 'quote_has_expired_reservations: cannot consume reservations because one or more have expired'
            USING ERRCODE = '22000';
    END IF;

    FOR v_res IN
        SELECT id FROM public.inventory_reservations
        WHERE quote_id = p_quote_id
          AND status = 'held'::inventory_reservation_status
        ORDER BY variant_id ASC
    LOOP
        PERFORM public.consume_inventory_reservation(v_res.id);
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp;

GRANT EXECUTE ON FUNCTION public.get_variant_available_stock(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.create_inventory_reservation(UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_inventory_for_quote(UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_inventory_reservation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_quote_reservations(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_inventory_reservation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_reservations(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.consume_inventory_reservation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.consume_quote_reservations(UUID) TO authenticated;

GRANT SELECT ON public.inventory_reservations TO authenticated;
GRANT SELECT ON public.checkout_quotes TO authenticated;