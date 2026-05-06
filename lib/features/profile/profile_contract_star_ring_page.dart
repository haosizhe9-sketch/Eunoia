import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';

class ProfileContractStarRingPage extends StatefulWidget {
  const ProfileContractStarRingPage({super.key});

  @override
  State<ProfileContractStarRingPage> createState() => _ProfileContractStarRingPageState();
}

class _ProfileContractStarRingPageState extends State<ProfileContractStarRingPage> {
  bool _contractsSelected = true;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: HtmlDesignTokens.backgroundGradient),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: Padding(
                padding: HtmlDesignTokens.subpageAppBarPadding,
                child: Row(
                  children: <Widget>[
                    _ProfileCircleIconButton(
                      icon: Icons.chevron_left,
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        s.contractRingAppBarTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: HtmlDesignTokens.textMain,
                          fontFamily: 'system-ui',
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _ContractStarTabBar(
                contractsLabel: s.contractRingTabContracts,
                guildsLabel: s.contractRingTabStarRing,
                contractsSelected: _contractsSelected,
                onContracts: () => setState(() => _contractsSelected = true),
                onGuilds: () => setState(() => _contractsSelected = false),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _contractsSelected
                    ? const _ContractsPanel(key: ValueKey<String>('c'))
                    : const _StarRingPanel(key: ValueKey<String>('g')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractStarTabBar extends StatelessWidget {
  const _ContractStarTabBar({
    required this.contractsLabel,
    required this.guildsLabel,
    required this.contractsSelected,
    required this.onContracts,
    required this.onGuilds,
  });

  final String contractsLabel;
  final String guildsLabel;
  final bool contractsSelected;
  final VoidCallback onContracts;
  final VoidCallback onGuilds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double w = (c.maxWidth - 8) / 2;
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: contractsSelected ? 0 : w,
                top: 0,
                width: w,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HtmlDesignTokens.glassCard,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: HtmlDesignTokens.glassBorder),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TabChip(
                      text: contractsLabel,
                      selected: contractsSelected,
                      onTap: onContracts,
                    ),
                  ),
                  Expanded(
                    child: _TabChip(
                      text: guildsLabel,
                      selected: !contractsSelected,
                      onTap: onGuilds,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? HtmlDesignTokens.textMain : HtmlDesignTokens.textSub,
                fontFamily: 'system-ui',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContractsPanel extends StatelessWidget {
  const _ContractsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        _FakeSearchBar(leading: '⚲', hint: s.contractRingSearchContractsHint),
        const SizedBox(height: 28),
        Text('🤝', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, color: Colors.white.withValues(alpha: 0.35))),
        const SizedBox(height: 12),
        Text(
          s.contractRingEmptyFriendsTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: HtmlDesignTokens.textSub,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.contractRingEmptyFriendsSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: HtmlDesignTokens.textSub.withValues(alpha: 0.9),
            fontFamily: 'system-ui',
          ),
        ),
      ],
    );
  }
}

class _StarRingPanel extends StatelessWidget {
  const _StarRingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        _FakeSearchBar(leading: '🪐', hint: s.contractRingSearchGuildsHint),
        const SizedBox(height: 12),
        Material(
          color: HtmlDesignTokens.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => showAppTopSnackBar(
                  context,
                  Text(s.contractRingCreateGuildSnack),
                ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HtmlDesignTokens.accent.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('＋ ', style: TextStyle(color: HtmlDesignTokens.accent, fontWeight: FontWeight.w700)),
                  Text(
                    s.contractRingCreateGuild,
                    style: const TextStyle(
                      color: HtmlDesignTokens.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('🪐', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, color: Colors.white.withValues(alpha: 0.35))),
        const SizedBox(height: 12),
        Text(
          s.contractRingEmptyGuildsTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: HtmlDesignTokens.textSub,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.contractRingEmptyGuildsSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: HtmlDesignTokens.textSub.withValues(alpha: 0.9),
            fontFamily: 'system-ui',
          ),
        ),
      ],
    );
  }
}

class _FakeSearchBar extends StatelessWidget {
  _FakeSearchBar({required this.leading, required this.hint});

  final String leading;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Row(
        children: <Widget>[
          Text(leading, style: const TextStyle(fontSize: 16, color: HtmlDesignTokens.accent)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(fontSize: 14, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCircleIconButton extends StatelessWidget {
  const _ProfileCircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HtmlDesignTokens.glassCard,
      shape: CircleBorder(side: BorderSide(color: HtmlDesignTokens.glassBorder)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: HtmlDesignTokens.textMain, size: 22),
        ),
      ),
    );
  }
}
