import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/test_credentials.dart';
import 'core/i18n/app_locale.dart';
import 'core/providers/community_social_providers.dart';
import 'core/providers/service_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/app_data_service.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_snackbar.dart';
import 'widgets/phone_chrome_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppDataService appData = AppDataService();
  await appData.initialize();
  if (kDebugMode) {
    unawaited(_ensureDebugTestAccount(appData));
  }
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appDataServiceProvider.overrideWithValue(appData),
    ],
  );
  await container.read(communitySocialRepositoryProvider).ensureDemoSocialScenario();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EunoiaApp(),
    ),
  );
}

/// 调试模式下尝试写入本地测试账号（[AppDataService] JSON）；已存在或校验失败时静默忽略。
Future<void> _ensureDebugTestAccount(AppDataService svc) async {
  try {
    await svc.signUpWithPassword(
      email: TestCredentials.account,
      password: TestCredentials.password,
      displayName: TestCredentials.displayName,
    );
  } catch (_) {
    // 用户已存在或格式不符等：可改用手动登录或注册页。
  }
}

/// 隐藏系统/材质默认滚动条滑块，避免上下滑动时出现长条（更接近原生 app）。
class EunoiaScrollBehavior extends MaterialScrollBehavior {
  const EunoiaScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class EunoiaApp extends ConsumerWidget {
  const EunoiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Locale locale = ref.watch(appLocaleProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: appScaffoldMessengerKey,
      title: 'Eunoia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: locale,
      supportedLocales: const <Locale>[
        Locale('zh'),
        Locale('en'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const EunoiaScrollBehavior(),
      routerConfig: AppRouter.router,
      builder: (BuildContext context, Widget? child) {
        return PhoneChromeFrame(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
