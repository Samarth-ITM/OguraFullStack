DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid='public.profiles'::regclass AND polname='p_profiles_self_insert') THEN
    CREATE POLICY p_profiles_self_insert ON public.profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
  END IF;
END $$;