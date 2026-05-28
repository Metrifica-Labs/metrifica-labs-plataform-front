import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../models/organization_model.dart';
import '../supabase/supabase_client.dart';

const _kActiveOrgKey = 'metrifica_active_org_id';

final userOrgsProvider = FutureProvider<List<OrganizationModel>>((ref) async {
  final data = await supabase
      .from('organizations')
      .select('id, slug, name, config')
      .order('created_at');
  return (data as List).map((e) => OrganizationModel.fromJson(e)).toList();
});

class ActiveOrgNotifier extends StateNotifier<OrganizationModel?> {
  ActiveOrgNotifier(this._ref) : super(null) {
    _ref.listen<AsyncValue<List<OrganizationModel>>>(
      userOrgsProvider,
      (_, next) {
        if (state == null && next.valueOrNull?.isNotEmpty == true) {
          final orgs = next.valueOrNull!;
          final savedId = web.window.localStorage.getItem(_kActiveOrgKey);
          state = savedId != null
              ? orgs.firstWhere((o) => o.id == savedId,
                  orElse: () => orgs.first)
              : orgs.first;
        }
      },
      fireImmediately: true,
    );
  }

  final Ref _ref;

  void setOrg(OrganizationModel org) {
    web.window.localStorage.setItem(_kActiveOrgKey, org.id);
    state = org;
  }
}

final activeOrgProvider =
    StateNotifierProvider<ActiveOrgNotifier, OrganizationModel?>(
  (ref) => ActiveOrgNotifier(ref),
);

// Slugs de flows habilitados para a org ativa (null = não filtrar)
final orgEnabledFlowSlugsProvider = FutureProvider<Set<String>?>((ref) async {
  final org = ref.watch(activeOrgProvider);
  if (org == null) return null;
  final data = await supabase
      .from('organization_flows')
      .select('flow_slug')
      .eq('organization_id', org.id)
      .eq('enabled', true);
  final rows = data as List;
  if (rows.isEmpty) return null; // sem config = sem filtro
  return {for (final row in rows) row['flow_slug'] as String};
});

// Slugs de modules habilitados para a org ativa (null = não filtrar)
final orgEnabledModuleSlugsProvider =
    FutureProvider<Set<String>?>((ref) async {
  final org = ref.watch(activeOrgProvider);
  if (org == null) return null;
  final data = await supabase
      .from('organization_modules')
      .select('module_slug')
      .eq('organization_id', org.id)
      .eq('enabled', true);
  final rows = data as List;
  if (rows.isEmpty) return null;
  return {for (final row in rows) row['module_slug'] as String};
});
