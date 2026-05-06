import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/shell_branch_activation.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../widgets/html_matched_bottom_nav.dart';
import '../../widgets/html_phone_shell_layers.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final void Function() _routerListener;
  String? _lastShellPathSeen;

  @override
  void initState() {
    super.initState();
    _routerListener = _onRouterChanged;
    AppRouter.router.routerDelegate.addListener(_routerListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBumpFromRouter());
  }

  @override
  void dispose() {
    AppRouter.router.routerDelegate.removeListener(_routerListener);
    super.dispose();
  }

  void _onRouterChanged() => _syncBumpFromRouter();

  void _syncBumpFromRouter() {
    final String path = AppRouter.router.state.uri.path;
    final int? branch = shellRootBranchIndexForPath(path);
    if (branch != null) {
      if (path != _lastShellPathSeen) {
        _lastShellPathSeen = path;
        ref.read(shellBranchActivationProvider.notifier).bump(branch);
      }
    } else {
      _lastShellPathSeen = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final StatefulNavigationShell navigationShell = widget.navigationShell;
    final MediaQueryData mq = MediaQuery.of(context);
    final double topGap = kIsWeb ? 10 : HtmlDesignTokens.shellEdgeGap;
    final double topPad = mq.padding.top + topGap;
    final double navBottomOffset = kIsWeb ? 10 : 30;
    final double navBarHeight = kIsWeb ? 56 : 72;
    final double bottomPad = kIsWeb
        ? navBottomOffset + navBarHeight + 6
        : 100;
    final double horizontalPad = kIsWeb ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(gradient: HtmlDesignTokens.backgroundGradient),
          ),
          const HtmlBackgroundGlows(),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPad, topPad, horizontalPad, bottomPad),
              child: navigationShell,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: navBottomOffset,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: kIsWeb ? 0.94 : 0.9,
                child: HtmlMatchedBottomNav(navigationShell: navigationShell),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
