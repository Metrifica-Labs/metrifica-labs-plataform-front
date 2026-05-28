import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/org_assets_repository.dart';

// Mapa alias → publicUrl para a org ativa.
// Usado para resolver {{asset:logo}} no markdown.
final assetMapProvider = Provider<Map<String, String>>((ref) {
  final assets = ref.watch(orgAssetsProvider).valueOrNull ?? [];
  return {
    for (final a in assets)
      if (a.alias != null && a.publicUrl != null) a.alias!: a.publicUrl!,
  };
});

// Substitui todas as ocorrências de {{asset:<alias>}} pelo URL real.
// Deixa o placeholder intacto se o alias não existir (evita quebrar o md).
String resolveAssetRefs(String markdown, Map<String, String> assetMap) {
  if (assetMap.isEmpty) return markdown;
  return markdown.replaceAllMapped(
    RegExp(r'\{\{asset:([^}]+)\}\}'),
    (m) {
      final alias = m.group(1)!.trim();
      return assetMap[alias] ?? m.group(0)!;
    },
  );
}
