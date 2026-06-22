import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'instagram_post_style.dart';

const _kKey = 'ig_post_history_v1';
const _kMax = 15;

// ── Modelo ────────────────────────────────────────────────────────────────────

class IgPostHistoryEntry {
  final String id;
  final DateTime createdAt;
  final String briefing;
  final List<SlideContent> slides;

  // Estilo serializado sem avatarBytes (binário/grande demais para localStorage).
  final Map<String, dynamic> styleJson;

  const IgPostHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.briefing,
    required this.slides,
    required this.styleJson,
  });

  factory IgPostHistoryEntry.fromJson(Map<String, dynamic> j) =>
      IgPostHistoryEntry(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        briefing: j['briefing'] as String? ?? '',
        slides:
            (j['slides'] as List<dynamic>? ?? []).map((s) {
              final layoutStr = (s['layout'] as String?) ?? 'textPost';
              final variantStr = (s['coverVariant'] as String?) ?? 'logoMid';
              final alignStr = (s['textAlign'] as String?) ?? 'left';
              final imagePositionStr = (s['imagePosition'] as String?) ??
                  ((s['imageAbove'] as bool?) == false ? 'below' : 'above');
              return SlideContent(
                headline: (s['headline'] as String?) ?? '',
                body: (s['body'] as String?) ?? '',
                imagePosition: SlideImagePosition.values.firstWhere(
                  (e) => e.name == imagePositionStr,
                  orElse: () => SlideImagePosition.above,
                ),
                showHeader: (s['showHeader'] as bool?) ?? true,
                layout: SlideLayout.values.firstWhere(
                  (e) => e.name == layoutStr,
                  orElse: () => SlideLayout.textPost,
                ),
                coverVariant: ImageCoverVariant.values.firstWhere(
                  (e) => e.name == variantStr,
                  orElse: () => ImageCoverVariant.logoMid,
                ),
                swipeText: (s['swipeText'] as String?) ?? '',
                gridTexts: (s['gridTexts'] as List<dynamic>?)
                        ?.map((e) => e as String)
                        .toList() ??
                    const ['', '', '', ''],
                gridBolds: (s['gridBolds'] as List<dynamic>?)
                        ?.map((e) => e as bool)
                        .toList() ??
                    const [false, false, false, false],
                gridSpacing: (s['gridSpacing'] as num?)?.toDouble() ?? 1.4,
                textAlign: TextAlign.values.firstWhere(
                  (e) => e.name == alignStr,
                  orElse: () => TextAlign.left,
                ),
                slideBgColor: s['slideBgColor'] != null
                    ? Color(s['slideBgColor'] as int)
                    : null,
                slideTextColor: s['slideTextColor'] != null
                    ? Color(s['slideTextColor'] as int)
                    : null,
                slideHeadlineColor: s['slideHeadlineColor'] != null
                    ? Color(s['slideHeadlineColor'] as int)
                    : null,
                slideBodyColor: s['slideBodyColor'] != null
                    ? Color(s['slideBodyColor'] as int)
                    : null,
                swipeTextColor: s['swipeTextColor'] != null
                    ? Color(s['swipeTextColor'] as int)
                    : null,
                showCounter: (s['showCounter'] as bool?) ?? true,
              );
            }).toList(),
        styleJson: (j['styleJson'] as Map<String, dynamic>?) ?? {},
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'briefing': briefing,
    'slides':
        slides
            .map(
              (s) => {
                'headline': s.headline,
                'body': s.body,
                'imagePosition': s.imagePosition.name,
                'showHeader': s.showHeader,
                'layout': s.layout.name,
                'coverVariant': s.coverVariant.name,
                'swipeText': s.swipeText,
                'gridTexts': s.gridTexts,
                'gridBolds': s.gridBolds,
                'gridSpacing': s.gridSpacing,
                'textAlign': s.textAlign.name,
                'slideBgColor': s.slideBgColor?.toARGB32(),
                'slideTextColor': s.slideTextColor?.toARGB32(),
                'slideHeadlineColor': s.slideHeadlineColor?.toARGB32(),
                'slideBodyColor': s.slideBodyColor?.toARGB32(),
                'swipeTextColor': s.swipeTextColor?.toARGB32(),
                'showCounter': s.showCounter,
                // imageBytes / coverImageBytes não são salvos (binário)
              },
            )
            .toList(),
    'styleJson': styleJson,
  };

  /// Reconstrói o PostStyle a partir do styleJson (sem avatar).
  PostStyle toPostStyle() => deserializeStyle(styleJson);

  String get preview =>
      slides.isNotEmpty ? slides.first.headline : '(sem conteúdo)';
}

// ── Serialização de PostStyle ─────────────────────────────────────────────────

Map<String, dynamic> serializeStyle(PostStyle s) => {
  'profileName': s.profileName,
  'handle': s.handle,
  'avatarRadius': s.avatarRadius,
  'showVerifiedBadge': s.showVerifiedBadge,
  'centerContent': s.centerContent,
  'nameFont': s.nameFont,
  'handleFont': s.handleFont,
  'bodyFont': s.bodyFont,
  'counterFont': s.counterFont,
  'bold': s.bold,
  'italic': s.italic,
  'underline': s.underline,
  'bodyBold': s.bodyBold,
  'bodyItalic': s.bodyItalic,
  'bodyUnderline': s.bodyUnderline,
  'highlightColor': s.highlightColor.toARGB32(),
  'bgColor': s.bgColor.toARGB32(),
  'textColor': s.textColor.toARGB32(),
  'headlineColor': s.headlineColor?.toARGB32(),
  'bodyColor': s.bodyColor?.toARGB32(),
  'showArrows': s.showArrows,
  'bodyFontSize': s.bodyFontSize,
  'defaultLayout': s.defaultLayout.name,
};

PostStyle deserializeStyle(Map<String, dynamic> j) => PostStyle(
  profileName: (j['profileName'] as String?) ?? 'Seu Nome',
  handle: (j['handle'] as String?) ?? '@seuperfil',
  avatarRadius: (j['avatarRadius'] as num?)?.toDouble() ?? 26,
  showVerifiedBadge: (j['showVerifiedBadge'] as bool?) ?? false,
  centerContent: (j['centerContent'] as bool?) ?? true,
  nameFont: (j['nameFont'] as String?) ?? 'Inter',
  handleFont: (j['handleFont'] as String?) ?? 'Inter',
  bodyFont: (j['bodyFont'] as String?) ?? 'Inter',
  counterFont: (j['counterFont'] as String?) ?? 'Inter',
  bold: (j['bold'] as bool?) ?? true,
  italic: (j['italic'] as bool?) ?? false,
  underline: (j['underline'] as bool?) ?? false,
  bodyBold: (j['bodyBold'] as bool?) ?? false,
  bodyItalic: (j['bodyItalic'] as bool?) ?? false,
  bodyUnderline: (j['bodyUnderline'] as bool?) ?? false,
  highlightColor: Color((j['highlightColor'] as int?) ?? 0xFFFFF176),
  bgColor: Color((j['bgColor'] as int?) ?? 0xFFFFFFFF),
  textColor: Color((j['textColor'] as int?) ?? 0xFF101012),
  headlineColor:
      j['headlineColor'] != null ? Color(j['headlineColor'] as int) : null,
  bodyColor: j['bodyColor'] != null ? Color(j['bodyColor'] as int) : null,
  showArrows: (j['showArrows'] as bool?) ?? true,
  bodyFontSize: (j['bodyFontSize'] as num?)?.toDouble() ?? 30,
  defaultLayout: SlideLayout.values.firstWhere(
    (e) => e.name == ((j['defaultLayout'] as String?) ?? 'textPost'),
    orElse: () => SlideLayout.textPost,
  ),
);

// ── Provider ──────────────────────────────────────────────────────────────────

final igPostHistoryProvider =
    AsyncNotifierProvider<IgPostHistoryNotifier, List<IgPostHistoryEntry>>(
      IgPostHistoryNotifier.new,
    );

class IgPostHistoryNotifier extends AsyncNotifier<List<IgPostHistoryEntry>> {
  @override
  Future<List<IgPostHistoryEntry>> build() => _load();

  Future<List<IgPostHistoryEntry>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => IgPostHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<IgPostHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add({
    required String briefing,
    required List<SlideContent> slides,
    required PostStyle style,
  }) async {
    if (slides.isEmpty) return;
    final entry = IgPostHistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      briefing: briefing,
      slides: slides,
      styleJson: serializeStyle(style),
    );

    final current = state.valueOrNull ?? [];
    // Evita duplicata exata (mesmo briefing gerado segundos atrás)
    if (current.isNotEmpty &&
        current.first.briefing == briefing &&
        DateTime.now().difference(current.first.createdAt).inSeconds < 5) {
      return;
    }
    final updated = [entry, ...current].take(_kMax).toList();
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> remove(String id) async {
    final updated = (state.valueOrNull ?? []).where((e) => e.id != id).toList();
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}

// ── Preferências de estilo do usuário ─────────────────────────────────────────

const _kSavedStyleKey = 'ig_post_saved_style_v1';

Future<void> saveStyleToPrefs(PostStyle style) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kSavedStyleKey, jsonEncode(serializeStyle(style)));
}

Future<PostStyle?> loadStyleFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kSavedStyleKey);
  if (raw == null) return null;
  try {
    return deserializeStyle(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}
