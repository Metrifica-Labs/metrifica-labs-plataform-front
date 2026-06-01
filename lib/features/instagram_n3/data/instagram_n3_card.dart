import 'dart:convert';

class N3Card {
  final int card;
  final String objetivo;
  final String headline;
  final String body;

  const N3Card({
    required this.card,
    required this.objetivo,
    required this.headline,
    required this.body,
  });

  N3Card copyWith({String? headline, String? body}) => N3Card(
        card: card,
        objetivo: objetivo,
        headline: headline ?? this.headline,
        body: body ?? this.body,
      );

  Map<String, dynamic> toJson() => {
        'card': card,
        'objetivo': objetivo,
        'headline': headline,
        'body': body,
      };

  factory N3Card.fromJson(Map<String, dynamic> json) => N3Card(
        card: json['card'] as int? ?? 0,
        objetivo: json['objetivo'] as String? ?? '',
        headline: json['headline'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
}

enum N3PostType {
  post1('1/9', 'O Método'),
  post2('2/9', 'A Vida Após'),
  post3('3/9', 'O Contraponto'),
  post10('10/9', 'Aplicação Real');

  const N3PostType(this.label, this.name);
  final String label;
  final String name;
}

class N3Post {
  final N3PostType postType;
  final List<N3Card> cards;

  const N3Post({
    this.postType = N3PostType.post1,
    this.cards = const [],
  });

  bool get hasCards => cards.isNotEmpty;

  N3Post copyWith({N3PostType? postType, List<N3Card>? cards}) => N3Post(
        postType: postType ?? this.postType,
        cards: cards ?? this.cards,
      );
}

N3Post parseN3Post(String output, {N3PostType defaultType = N3PostType.post1}) {
  try {
    final jsonMatch =
        RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(output);
    final jsonStr = jsonMatch?.group(1) ?? output.trim();
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

    final postTypeStr = decoded['post_type'] as String? ?? defaultType.label;
    final postType = N3PostType.values.firstWhere(
      (t) => t.label == postTypeStr,
      orElse: () => defaultType,
    );

    final cardsJson = decoded['cards'] as List<dynamic>? ?? [];
    final cards = cardsJson
        .map((c) => N3Card.fromJson(c as Map<String, dynamic>))
        .toList();

    return N3Post(postType: postType, cards: cards);
  } catch (_) {
    return N3Post(postType: defaultType);
  }
}
