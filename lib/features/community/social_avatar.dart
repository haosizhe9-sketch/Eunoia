import 'package:flutter/material.dart';

import '../../core/theme/html_design_tokens.dart';

const List<String> kSocialAvatarEmojis = <String>[
  '🦊', '🐼', '👾', '🐱', '🐢', '🐳', '🦆', '🐙', '🦄', '🐺',
];

/// 由用户 id 稳定映射头像 emoji。
String socialEmojiForUserId(String userId) {
  if (userId.isEmpty) {
    return '👤';
  }
  return kSocialAvatarEmojis[userId.hashCode.abs() % kSocialAvatarEmojis.length];
}

/// 由用户 id 稳定映射头像渐变。
LinearGradient socialGradientForUserId(String userId) {
  final int h = userId.isEmpty ? 0 : userId.hashCode.abs();
  final List<List<Color>> palettes = <List<Color>>[
    <Color>[const Color(0xFFFF61D2), const Color(0xFFFE9090)],
    <Color>[HtmlDesignTokens.primary, HtmlDesignTokens.accent],
    <Color>[const Color(0xFF10B981), const Color(0xFF059669)],
    <Color>[const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
    <Color>[const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
    <Color>[const Color(0xFFA78BFA), const Color(0xFF6366F1)],
  ];
  final List<Color> pair = palettes[h % palettes.length];
  return LinearGradient(colors: pair);
}
