INSERT INTO public.profiles (id, email, full_name, is_active)
VALUES ('923f8d49-19e0-4b19-9350-f333e0e7277b', 'seed.seller@ogura.demo', 'Ogura Seed Atelier', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.sellers (id, user_id, business_name, legal_entity_name, seller_slug, status, approved_at)
VALUES ('22222222-2222-4222-8222-222222222222', '923f8d49-19e0-4b19-9350-f333e0e7277b', 'Ogura Seed Atelier', 'Ogura Seed Atelier Pvt Ltd', 'ogura-seed-atelier', 'active', now())
ON CONFLICT (id) DO NOTHING;