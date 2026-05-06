import 'dart:convert';

import 'package:flutter/services.dart';

/// 爬词塔词库条目（与 `assets/data/words.json` 字段一致）。
class WordTowerEntry {
  const WordTowerEntry({required this.english, required this.chinese});

  final String english;
  final String chinese;

  static Future<List<WordTowerEntry>> load() async {
    final raw = await rootBundle.loadString('assets/data/words.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((dynamic e) => e as Map<String, dynamic>)
        .map(
          (Map<String, dynamic> m) => WordTowerEntry(
            english: m['english'] as String,
            chinese: m['chinese'] as String,
          ),
        )
        .toList(growable: false);
  }
}
