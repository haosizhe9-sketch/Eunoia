import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Primary CTA with neon glow using layered [BoxShadow]s.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.minHeight = 52,
    this.expanded = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final double minHeight;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final glow = <BoxShadow>[
      BoxShadow(
        color: AppTheme.accent.withValues(alpha: enabled ? 0.45 : 0.12),
        blurRadius: 22,
        spreadRadius: 0,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: AppTheme.primary.withValues(alpha: enabled ? 0.35 : 0.1),
        blurRadius: 28,
        spreadRadius: -4,
        offset: const Offset(0, 10),
      ),
    ];

    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppTheme.accent.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: enabled
                  ? <Color>[
                      AppTheme.primary,
                      AppTheme.primary.withValues(alpha: 0.82),
                    ]
                  : <Color>[
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.08),
                    ],
            ),
            boxShadow: enabled ? glow : null,
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: enabled ? Colors.white : Colors.white54),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: enabled ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}
