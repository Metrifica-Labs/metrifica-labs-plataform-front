-- Asserts (server-side, cache-immune) that the two modules contain no UTF-8
-- mojibake. Needles are built from hex bytes so this file stays pure ASCII and
-- is not corrupted by the push encoding bug. If mojibake remains, push FAILS.
DO $$
DECLARE
  n_eacute text := convert_from('\xc383c2a9'::bytea, 'UTF8'); -- mojibake of e-acute
  n_oacute text := convert_from('\xc383c2b3'::bytea, 'UTF8'); -- mojibake of o-acute
  n_aacute text := convert_from('\xc383c2a1'::bytea, 'UTF8'); -- mojibake of a-acute
  n_uacute text := convert_from('\xc383c2ba'::bytea, 'UTF8'); -- mojibake of u-acute
  n_emdash text := convert_from('\xc3a2e282ac'::bytea, 'UTF8'); -- mojibake start of em dash
  bad int;
BEGIN
  SELECT count(*) INTO bad FROM modules
  WHERE slug IN ('template-prompt-imagem','regras-post-instagram')
    AND (content LIKE '%'||n_eacute||'%'
      OR content LIKE '%'||n_oacute||'%'
      OR content LIKE '%'||n_aacute||'%'
      OR content LIKE '%'||n_uacute||'%'
      OR content LIKE '%'||n_emdash||'%');
  IF bad > 0 THEN
    RAISE EXCEPTION 'MOJIBAKE still present in % module(s)', bad;
  END IF;
  RAISE NOTICE 'modules clean: no mojibake detected';
END $$;
