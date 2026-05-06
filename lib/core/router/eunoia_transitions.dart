import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Secondary screens: slide from right + light scale/fade on the entering page.
/// Dimmer + scale of the shell behind the route can be layered later via shell listeners.
CustomTransitionPage<void> eunoiaPushPage({
  required LocalKey key,
  required Widget child,
}) {
  const duration = Duration(milliseconds: 320);
  const reverseDuration = Duration(milliseconds: 280);

  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          alignment: Alignment.centerRight,
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.85, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

NoTransitionPage<void> eunoiaTabPage({
  required LocalKey key,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: key, child: child);
}
