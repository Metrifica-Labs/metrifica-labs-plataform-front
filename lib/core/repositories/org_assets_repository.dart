import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/org_asset_model.dart';
import '../providers/organization_provider.dart';
import '../supabase/supabase_client.dart';

const _bucket = 'org-assets';

class OrgAssetsRepository {
  final String orgId;
  OrgAssetsRepository(this.orgId);

  Future<List<OrgAssetModel>> list() async {
    final data = await supabase
        .from('org_assets')
        .select()
        .eq('organization_id', orgId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => OrgAssetModel.fromJson(e)).toList();
  }

  Future<OrgAssetModel> upload({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String assetType = 'image',
    String? alias,
  }) async {
    // Caminho no bucket: {org_id}/{timestamp}_{filename}
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = '$orgId/${ts}_$safeName';

    await supabase.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final signedUrl = await supabase.storage
        .from(_bucket)
        .createSignedUrl(storagePath, 60 * 60 * 24 * 365); // 1 ano

    final inserted = await supabase
        .from('org_assets')
        .insert({
          'organization_id': orgId,
          'name': fileName,
          'storage_path': storagePath,
          'public_url': signedUrl,
          'asset_type': assetType,
          'created_by': supabase.auth.currentUser?.id,
          if (alias != null && alias.isNotEmpty) 'alias': alias,
        })
        .select()
        .single();

    return OrgAssetModel.fromJson(inserted);
  }

  Future<void> delete(OrgAssetModel asset) async {
    await supabase.storage.from(_bucket).remove([asset.storagePath]);
    await supabase.from('org_assets').delete().eq('id', asset.id);
  }

  // Renova a signed URL de um asset (útil quando expirada)
  Future<String> refreshUrl(OrgAssetModel asset) async {
    return supabase.storage
        .from(_bucket)
        .createSignedUrl(asset.storagePath, 60 * 60 * 24 * 365);
  }
}

// Provider scoped na org ativa
final orgAssetsRepositoryProvider = Provider<OrgAssetsRepository?>((ref) {
  final org = ref.watch(activeOrgProvider);
  if (org == null) return null;
  return OrgAssetsRepository(org.id);
});

final orgAssetsProvider =
    AsyncNotifierProvider<OrgAssetsNotifier, List<OrgAssetModel>>(
        OrgAssetsNotifier.new);

class OrgAssetsNotifier extends AsyncNotifier<List<OrgAssetModel>> {
  @override
  Future<List<OrgAssetModel>> build() async {
    final repo = ref.watch(orgAssetsRepositoryProvider);
    if (repo == null) return [];
    return repo.list();
  }

  Future<OrgAssetModel?> upload({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String assetType = 'image',
    String? alias,
  }) async {
    final repo = ref.read(orgAssetsRepositoryProvider);
    if (repo == null) return null;
    final asset = await repo.upload(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      assetType: assetType,
      alias: alias,
    );
    final current = state.valueOrNull ?? [];
    state = AsyncData([asset, ...current]);
    return asset;
  }

  Future<void> delete(OrgAssetModel asset) async {
    final repo = ref.read(orgAssetsRepositoryProvider);
    if (repo == null) return;
    await repo.delete(asset);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((a) => a.id != asset.id).toList());
  }
}
