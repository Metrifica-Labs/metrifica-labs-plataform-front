import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'instagram_n3_card.dart';

final instagramN3Provider =
    StateNotifierProvider.autoDispose<InstagramN3Notifier, N3Post>(
  (ref) => InstagramN3Notifier(),
);

class InstagramN3Notifier extends StateNotifier<N3Post> {
  InstagramN3Notifier() : super(const N3Post());

  void setPostType(N3PostType type) => state = state.copyWith(postType: type);

  void setCards(List<N3Card> cards) => state = state.copyWith(cards: cards);

  void updateCard(int index, {String? headline, String? body}) {
    if (index < 0 || index >= state.cards.length) return;
    final updated = List<N3Card>.from(state.cards);
    updated[index] = state.cards[index].copyWith(headline: headline, body: body);
    state = state.copyWith(cards: updated);
  }

  void clear() => state = N3Post(postType: state.postType);
}
