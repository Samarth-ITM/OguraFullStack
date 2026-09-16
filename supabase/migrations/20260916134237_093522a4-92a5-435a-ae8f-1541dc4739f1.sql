DO $$
DECLARE v_uid uuid := '11111111-1111-4111-8111-111111111111';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_uid) THEN
    INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous)
    VALUES (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'seed-seller@ogura.demo', crypt('OguraSeedDemo!2026', gen_salt('bf')), now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"OGURA Seed Atelier"}'::jsonb, false, false);
  END IF;

  INSERT INTO public.profiles (id, email, full_name, is_active)
  VALUES (v_uid, 'seed-seller@ogura.demo', 'OGURA Seed Atelier', true)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (v_uid, 'seller')
  ON CONFLICT (user_id, role) DO NOTHING;

  INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status, commission_rate_bps)
  VALUES ('22222222-2222-4222-8222-222222222222', v_uid, 'OGURA Seed Atelier (Demo)', 'OGURA Seed Atelier Demo Private Limited', 'ogura-seed-atelier', 'active', 1500)
  ON CONFLICT (id) DO NOTHING;
END $$;