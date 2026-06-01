import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'instagram_post_style.dart';

final instagramPostProvider =
    StateNotifierProvider.autoDispose<InstagramPostNotifier, PostStyle>(
      (ref) => InstagramPostNotifier(),
    );

/// Bridge: slides vindos do N3 aguardando serem aplicados no Instagram Post.
final pendingN3SlidesProvider =
    StateProvider<List<SlideContent>?>((ref) => null);

class InstagramPostNotifier extends StateNotifier<PostStyle> {
  InstagramPostNotifier() : super(const PostStyle());

  void setSlides(List<SlideContent> slides) =>
      state = state.copyWith(slides: slides);

  void updateSlide(int index, {String? headline, String? body}) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = updated[index].copyWith(headline: headline, body: body);
    state = state.copyWith(slides: updated);
  }

  void setSlideImage(int index, Uint8List? bytes) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] =
        bytes == null
            ? updated[index].copyWith(clearImage: true)
            : updated[index].copyWith(imageBytes: bytes);
    state = state.copyWith(slides: updated);
  }

  void setSlideImageAbove(int index, bool above) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = updated[index].copyWith(imageAbove: above);
    state = state.copyWith(slides: updated);
  }

  void setSlideShowHeader(int index, bool show) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = updated[index].copyWith(showHeader: show);
    state = state.copyWith(slides: updated);
  }

  void setSlideLayout(int index, SlideLayout layout) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = updated[index].copyWith(layout: layout);
    state = state.copyWith(
      slides: updated,
      centerContent:
          layout == SlideLayout.textPost ? true : state.centerContent,
    );
  }

  void setSlideCoverImage(int index, Uint8List? bytes) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] =
        bytes == null
            ? updated[index].copyWith(clearCoverImage: true)
            : updated[index].copyWith(coverImageBytes: bytes);
    state = state.copyWith(slides: updated);
  }

  void setSlideCoverVariant(int index, ImageCoverVariant v) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = updated[index].copyWith(coverVariant: v);
    state = state.copyWith(slides: updated);
  }

  void setSlideSwipeText(int index, String text) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = updated[index].copyWith(swipeText: text);
    state = state.copyWith(slides: updated);
  }

  void setSlideBgColor(int index, Color? color) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = color == null
        ? updated[index].copyWith(clearSlideBgColor: true)
        : updated[index].copyWith(slideBgColor: color);
    state = state.copyWith(slides: updated);
  }

  void setSlideTextColor(int index, Color? color) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = color == null
        ? updated[index].copyWith(clearSlideTextColor: true)
        : updated[index].copyWith(slideTextColor: color);
    state = state.copyWith(slides: updated);
  }

  void setSlideHeadlineColor(int index, Color? color) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = color == null
        ? updated[index].copyWith(clearSlideHeadlineColor: true)
        : updated[index].copyWith(slideHeadlineColor: color);
    state = state.copyWith(slides: updated);
  }

  void setSlideBodyColor(int index, Color? color) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = color == null
        ? updated[index].copyWith(clearSlideBodyColor: true)
        : updated[index].copyWith(slideBodyColor: color);
    state = state.copyWith(slides: updated);
  }

  void setSlideSwipeTextColor(int index, Color? color) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = color == null
        ? updated[index].copyWith(clearSwipeTextColor: true)
        : updated[index].copyWith(swipeTextColor: color);
    state = state.copyWith(slides: updated);
  }

  void clearSlideColors(int index) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = updated[index].copyWith(
      clearSlideBgColor: true,
      clearSlideTextColor: true,
      clearSlideHeadlineColor: true,
      clearSlideBodyColor: true,
      clearSwipeTextColor: true,
    );
    state = state.copyWith(slides: updated);
  }

  void setGridBold(int index, int blockIdx, bool bold) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    final bolds = List<bool>.from(updated[index].gridBolds);
    while (bolds.length <= blockIdx) bolds.add(false);
    bolds[blockIdx] = bold;
    updated[index] = updated[index].copyWith(gridBolds: bolds);
    state = state.copyWith(slides: updated);
  }

  void setGridSpacing(int index, double spacing) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = updated[index].copyWith(gridSpacing: spacing);
    state = state.copyWith(slides: updated);
  }

  void setGridText(int index, int blockIdx, String text) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    final texts = List<String>.from(updated[index].gridTexts);
    while (texts.length <= blockIdx) texts.add('');
    texts[blockIdx] = text;
    updated[index] = updated[index].copyWith(gridTexts: texts);
    state = state.copyWith(slides: updated);
  }

  void setSlideTextAlign(int index, TextAlign align) {
    if (index < 0 || index >= state.slides.length) return;
    final updated = [...state.slides];
    updated[index] = updated[index].copyWith(textAlign: align);
    state = state.copyWith(slides: updated);
  }

  // Perfil
  void setAvatar(Uint8List? bytes) =>
      bytes == null
          ? state = state.copyWith(clearAvatar: true)
          : state = state.copyWith(avatarBytes: bytes);

  void setLogo(Uint8List? bytes) =>
      bytes == null
          ? state = state.copyWith(clearLogo: true)
          : state = state.copyWith(logoBytes: bytes);
  void setProfileName(String v) => state = state.copyWith(profileName: v);
  void setHandle(String v) => state = state.copyWith(handle: v);
  void setAvatarRadius(double v) => state = state.copyWith(avatarRadius: v);
  void toggleVerifiedBadge() =>
      state = state.copyWith(showVerifiedBadge: !state.showVerifiedBadge);
  void setDefaultLayout(SlideLayout v) =>
      state = state.copyWith(
        defaultLayout: v,
        centerContent: v == SlideLayout.textPost ? true : state.centerContent,
      );
  void toggleCenterContent() =>
      state = state.copyWith(centerContent: !state.centerContent);

  // Fontes
  void setNameFont(String v) => state = state.copyWith(nameFont: v);
  void setHandleFont(String v) => state = state.copyWith(handleFont: v);
  void setBodyFont(String v) => state = state.copyWith(bodyFont: v);
  void setCounterFont(String v) => state = state.copyWith(counterFont: v);

  // Ênfase headline
  void toggleBold() => state = state.copyWith(bold: !state.bold);
  void toggleItalic() => state = state.copyWith(italic: !state.italic);
  void toggleUnderline() => state = state.copyWith(underline: !state.underline);

  // Ênfase body
  void toggleBodyBold() => state = state.copyWith(bodyBold: !state.bodyBold);
  void toggleBodyItalic() =>
      state = state.copyWith(bodyItalic: !state.bodyItalic);
  void toggleBodyUnderline() =>
      state = state.copyWith(bodyUnderline: !state.bodyUnderline);

  // Cor de destaque inline
  void setHighlightColor(Color v) => state = state.copyWith(highlightColor: v);

  // Cores
  void setBgColor(Color v) => state = state.copyWith(bgColor: v);
  void setTextColor(Color v) => state = state.copyWith(textColor: v);
  void setHeadlineColor(Color v) => state = state.copyWith(headlineColor: v);
  void resetHeadlineColor() => state = state.copyWith(clearHeadlineColor: true);
  void setBodyColor(Color v) => state = state.copyWith(bodyColor: v);
  void resetBodyColor() => state = state.copyWith(clearBodyColor: true);

  // Extras
  void toggleArrows() => state = state.copyWith(showArrows: !state.showArrows);
  void setBodyFontSize(double v) => state = state.copyWith(bodyFontSize: v);

  void applyPreset(CreatorPreset p) => state = state.applyPreset(p);

  /// Restaura completamente o estado a partir de um entry do histórico.
  /// Avatar e logo não são restaurados (binários não são salvos no histórico).
  void restoreFromHistory(PostStyle restoredStyle, List<SlideContent> slides) {
    state = restoredStyle.copyWith(
      clearAvatar: true,
      clearLogo: true,
      slides: slides,
    );
  }

  /// Restaura apenas as configurações de estilo, preservando slides e binários atuais.
  void restoreStyleOnly(PostStyle saved) {
    state = saved.copyWith(
      avatarBytes: state.avatarBytes,
      logoBytes: state.logoBytes,
      slides: state.slides,
    );
  }
}
