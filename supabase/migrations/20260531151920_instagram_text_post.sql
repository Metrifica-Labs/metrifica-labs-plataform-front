-- ============================================================
-- Módulo "Instagram Text Post" — Metrifica Labs
-- ------------------------------------------------------------
-- Cria o módulo de diretrizes + flow que a IA usa para gerar o
-- TEXTO do carrossel. A imagem é renderizada por código no app.
--
-- O content do módulo tem acentos; `supabase db push` corrompe
-- UTF-8 no Windows, então é embutido em base64 e decodificado no
-- servidor (mesmo padrão de 20260530142500_fix_modules_encoding_base64.sql).
-- ============================================================

-- 1. Módulo de diretrizes (conteúdo em base64 -> imune ao bug de encoding)
INSERT INTO modules (slug, name, module_ref, content)
VALUES (
  'instagram-text-post-guidelines',
  'Instagram Text Post - Diretrizes',
  'IG',
  convert_from(decode('IyBJbnN0YWdyYW0gVGV4dCBQb3N0IOKAlCBEaXJldHJpemVzIGRlIENvbnRlw7pkbwoKVm9jw6ogZ2VyYSBvICoqdGV4dG8vY29udGXDumRvKiogZGUgdW0gY2Fycm9zc2VsIGVzdGlsbyAidGV4dCBwb3N0IiBkbyBJbnN0YWdyYW0gKHRleHRvIHNvYnJlIGZ1bmRvIGRlIGNvciBzw7NsaWRhLCBjb20gY2FiZcOnYWxobyBkZSBwZXJmaWwpLiBBIGltYWdlbSBmaW5hbCDDqSByZW5kZXJpemFkYSBwb3IgY8OzZGlnbyDigJQgdm9jw6ogY3VpZGEgQVBFTkFTIGRvIHRleHRvLgoKIyMgRm9ybWF0byBkZSBzYcOtZGEgKE9CUklHQVTDk1JJTykKCkRldm9sdmEgKip1bSDDum5pY28gYmxvY28gZGUgY8OzZGlnbyBgYGBqc29uKiosIGUgbmFkYSBhbMOpbSBkZWxlLCBubyBmb3JtYXRvIGV4YXRvOgoKYGBganNvbgp7CiAgInNsaWRlcyI6IFsKICAgIHsgImhlYWRsaW5lIjogIkZyYXNlIGRlIGltcGFjdG8gZG8gc2xpZGUiLCAiYm9keSI6ICJUZXh0byBkZSBhcG9pbyBjdXJ0by4iIH0KICBdCn0KYGBgCgpSZWdyYXMgZG8gSlNPTjoKLSBgc2xpZGVzYDogbGlzdGEgZGUgNSBhIDggb2JqZXRvcywgbmEgb3JkZW0gZG8gY2Fycm9zc2VsLgotIGBoZWFkbGluZWA6IG3DoXhpbW8gfjggcGFsYXZyYXMuIMOJIGEgZnJhc2UgcHJpbmNpcGFsIGRvIHNsaWRlLgotIGBib2R5YDogbcOheGltbyB+MjUgcGFsYXZyYXMuIFBvZGUgc2VyIHN0cmluZyB2YXppYSAiIiBxdWFuZG8gbyBzbGlkZSBmb3Igc8OzIGhlYWRsaW5lLgotIE5hZGEgZGUgbWFya2Rvd24gZGVudHJvIGRvcyBjYW1wb3MgKHNlbSBgKipgLCBgI2AsIGxpc3RhcykuIEFwZW5hcyB0ZXh0byBwdXJvLgotIEVtb2ppcyBlIHNldGFzICjihpIpIHPDo28gcGVybWl0aWRvcyBjb20gbW9kZXJhw6fDo28sIGRlbnRybyBkbyB0ZXh0by4KLSBKU09OIHbDoWxpZG86IGFzcGFzIGR1cGxhcywgc2VtIHbDrXJndWxhIHNvYnJhbmRvLCBzZW0gY29tZW50w6FyaW9zLgoKIyMgRXN0cnV0dXJhIG5hcnJhdGl2YQoKLSAqKlNsaWRlIDEg4oCUIEhvb2s6KiogcGVyZ3VudGEgcHJvdm9jYXRpdmEgb3UgZnJhc2UgZGUgaW1wYWN0byBxdWUgZ2VyYSBjdXJpb3NpZGFkZS4KLSAqKlNsaWRlcyBkbyBtZWlvOioqIGRlc2Vudm9sdmltZW50byAoZG9yIOKGkiBhZ3JhdmFtZW50byDihpIgdmlyYWRhIOKGkiBzb2x1w6fDo28pLiBVbWEgaWRlaWEgcG9yIHNsaWRlLgotICoqw5psdGltbyBzbGlkZSDigJQgQ1RBOioqIGNoYW1hZGEgcGFyYSBhw6fDo28gY2xhcmEuCgojIyBUb20KCi0gQ29uc3VsdGl2bywgZGlyZXRvIGUgY29uZmlhbnRlLiBGcmFzZXMgY3VydGFzIGUgbWVtb3LDoXZlaXMuCi0gTsOjbyBpbnZlbnRlIGRhZG9zLCBuw7ptZXJvcyBvdSBmYXRvcyBxdWUgbsOjbyBlc3RlamFtIG5vIGJyaWVmaW5nIGRvIHVzdcOhcmlvLgotIEVzY3JldmEgZW0gcG9ydHVndcOqcyBkbyBCcmFzaWwgKGEgbWVub3MgcXVlIG8gYnJpZWZpbmcgcGXDp2Egb3V0cm8gaWRpb21hKS4K', 'base64'), 'UTF8')
)
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, content = EXCLUDED.content;

-- 2. Flow que referencia o módulo de diretrizes
INSERT INTO flows (slug, name, description, module_slugs)
VALUES (
  'instagram-text-post',
  'Instagram Text Post',
  convert_from(decode('R2VyYSBvIHRleHRvIGRlIHVtIGNhcnJvc3NlbCBkZSBwb3N0cyBkZSB0ZXh0byBwYXJhIEluc3RhZ3JhbS4gQSBpbWFnZW0gw6kgbW9udGFkYSBwb3IgY8OzZGlnbyBubyBlZGl0b3IgdmlzdWFsLg==', 'base64'), 'UTF8'),
  ARRAY['instagram-text-post-guidelines']
)
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, module_slugs = EXCLUDED.module_slugs;

-- Obs.: o flow NÃO é habilitado em organization_flows de propósito — ele existe
-- apenas para o run-flow montar o prompt. A navegação acontece pela página
-- dedicada /instagram-post, controlada pela feature 'instagram_post' abaixo.

-- 3. Ativa a feature da página dedicada para a org metrifica
UPDATE organizations
SET config = jsonb_set(
  COALESCE(config, '{}'::jsonb),
  '{enabled_features}',
  (
    SELECT to_jsonb(array(
      SELECT DISTINCT e
      FROM unnest(
        COALESCE(
          ARRAY(SELECT jsonb_array_elements_text(config->'enabled_features')),
          ARRAY[]::text[]
        ) || ARRAY['instagram_post']
      ) AS e
    ))
  )
)
WHERE slug = 'metrifica';
