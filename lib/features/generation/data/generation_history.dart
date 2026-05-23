import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';

class HistoryEntry {
  final String id;
  final String flowSlug;
  final String? flowName;
  final String userMessage;
  final String? templateName;
  final String output;
  final DateTime createdAt;

  const HistoryEntry({
    required this.id,
    required this.flowSlug,
    this.flowName,
    required this.userMessage,
    this.templateName,
    required this.output,
    required this.createdAt,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        flowSlug: j['flow_slug'] as String,
        flowName: j['flow_name'] as String?,
        userMessage: j['user_message'] as String,
        templateName: j['template_name'] as String?,
        output: j['output'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(
        HistoryNotifier.new);

class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() => _fetch();

  Future<List<HistoryEntry>> _fetch() async {
    final data = await supabase
        .from('generation_history')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((e) => HistoryEntry.fromJson(e)).toList();
  }

  Future<void> add({
    required String flowSlug,
    String? flowName,
    required String userMessage,
    String? templateName,
    required String output,
  }) async {
    final inserted = await supabase
        .from('generation_history')
        .insert({
          'flow_slug': flowSlug,
          'flow_name': flowName,
          'user_message': userMessage,
          'template_name': templateName,
          'output': output,
        })
        .select()
        .single();

    final entry = HistoryEntry.fromJson(inserted);
    final current = state.valueOrNull ?? [];
    state = AsyncData([entry, ...current]);
  }

  Future<void> remove(String id) async {
    await supabase.from('generation_history').delete().eq('id', id);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((e) => e.id != id).toList());
  }

  Future<void> clear() async {
    await supabase.from('generation_history').delete().neq('id', '');
    state = const AsyncData([]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
