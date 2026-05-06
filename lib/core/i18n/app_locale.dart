import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final StateNotifierProvider<AppLocaleController, Locale> appLocaleProvider =
    StateNotifierProvider<AppLocaleController, Locale>(
      (Ref ref) => AppLocaleController(),
    );

class AppLocaleController extends StateNotifier<Locale> {
  AppLocaleController() : super(_defaultLocale) {
    unawaited(_restoreLocale());
  }

  static const String _localePrefKey = 'app.locale';
  static const Locale _defaultLocale = Locale('zh');
  static const Locale zh = Locale('zh');
  static const Locale en = Locale('en');

  Future<void> _restoreLocale() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_localePrefKey);
    if (saved == 'zh' || saved == 'en') {
      state = Locale(saved!);
      return;
    }
    final String systemCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    state = systemCode.toLowerCase().startsWith('en') ? en : zh;
  }

  Future<void> setLocale(Locale locale) async {
    state = locale.languageCode == 'en' ? en : zh;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, state.languageCode);
  }

  Future<void> toggleLocale() async {
    final Locale next = state.languageCode == 'zh' ? en : zh;
    await setLocale(next);
  }
}
