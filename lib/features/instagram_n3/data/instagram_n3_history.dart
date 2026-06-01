import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'instagram_n3_card.dart';

const _kHistoryKey = 'instagram_n3_history_v1';
const _kMaxHistory = 20;

class N3HistoryEntry {
  final String id;
  final DateTime createdAt;
  final String briefing;
  final N3Post post;

  const N3HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.briefing,
    required this.post,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'briefing': briefing,
        'postType': post.postType.label,
        'cards': post.cards.map((c) => c.toJson()).toList(),
      };

  factory N3HistoryEntry.fromJson(Map<String, dynamic> json) {
    final postTypeStr = json['postType'] as String? ?? '1/9';
    final postType = N3PostType.values.firstWhere(
      (t) => t.label == postTypeStr,
      orElse: () => N3PostType.post1,
    );
    final cardsJson = json['cards'] as List<dynamic>? ?? [];
    return N3HistoryEntry(
      id: json['id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      briefing: json['briefing'] as String? ?? '',
      post: N3Post(
        postType: postType,
        cards: cardsJson
            .map((c) => N3Card.fromJson(c as Map<String, dynamic>))
            .toList(),
      ),
    );
  }
}

final n3HistoryProvider =
    AsyncNotifierProvider<N3HistoryNotifier, List<N3HistoryEntry>>(
  N3HistoryNotifier.new,
);

class N3HistoryNotifier extends AsyncNotifier<List<N3HistoryEntry>> {
  @override
  Future<List<N3HistoryEntry>> build() => _load();

  Future<List<N3HistoryEntry>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => N3HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add({required String briefing, required N3Post post}) async {
    final entry = N3HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      briefing: briefing,
      post: post,
    );
    final current = state.valueOrNull ?? [];
    final updated = [entry, ...current].take(_kMaxHistory).toList();
    state = AsyncValue.data(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kHistoryKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> remove(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((e) => e.id != id).toList();
    state = AsyncValue.data(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kHistoryKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }
}
