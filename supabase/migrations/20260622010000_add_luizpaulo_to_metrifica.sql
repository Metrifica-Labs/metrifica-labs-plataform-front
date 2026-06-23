-- ============================================================
-- Adiciona luizpaulo2016.lp@gmail.com na org metrifica
-- ============================================================

DO $$
DECLARE
  target_user_id UUID;
  metrifica_id    UUID;
BEGIN

  SELECT id INTO target_user_id
    FROM auth.users
   WHERE email = 'luizpaulo2016.lp@gmail.com';

  SELECT id INTO metrifica_id
    FROM organizations
   WHERE slug = 'metrifica';

  IF metrifica_id IS NULL THEN
    RAISE EXCEPTION 'Org metrifica nao encontrada.';
  END IF;

  IF target_user_id IS NULL THEN
    RAISE NOTICE 'Usuario luizpaulo2016.lp@gmail.com nao encontrado em auth.users — nada inserido.';
  ELSE
    INSERT INTO organization_members (user_id, organization_id, role)
    VALUES (target_user_id, metrifica_id, 'member')
    ON CONFLICT (user_id, organization_id) DO NOTHING;
  END IF;

END $$;
