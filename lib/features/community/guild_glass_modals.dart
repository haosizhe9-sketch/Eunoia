import 'package:flutter/material.dart';

import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';
import '../../widgets/html_phone_shell_layers.dart';

/// 群聊 Tab：创建星环 / 探索公会 全屏毛玻璃视窗（视觉对齐 `group_sc.html` 参考稿，该 HTML 文件本身不修改）。
abstract final class GuildGlassModals {
  GuildGlassModals._();

  static Future<void> showCreate(BuildContext context) {
    return _pushGlass(context, title: 'Create Guild', child: const _CreateGuildModalBody());
  }

  static Future<void> showExplore(BuildContext context) {
    return _pushGlass(context, title: 'Explore Guilds', child: const _ExploreGuildModalBody());
  }

  static Future<void> _pushGlass(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    // 使用根导航器，避免路由落在 Shell 内层（被 MainShell 的 Padding 裁成「中间一块」）。
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        fullscreenDialog: true,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
          return SizedBox.expand(
            child: _GuildGlassScaffold(title: title, child: child),
          );
        },
        transitionsBuilder:
            (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.16, 1, 0.3, 1),
          );
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
  }
}

class _GuildGlassScaffold extends StatelessWidget {
  const _GuildGlassScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.topCenter,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(gradient: HtmlDesignTokens.backgroundGradient),
          ),
          const HtmlBackgroundGlows(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: HtmlDesignTokens.narrowSubpageAppBarPadding,
                  child: Row(
                    children: <Widget>[
                      Material(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: HtmlDesignTokens.textMain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),
                Container(height: 1, color: HtmlDesignTokens.glassBorder),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateGuildModalBody extends StatefulWidget {
  const _CreateGuildModalBody();

  @override
  State<_CreateGuildModalBody> createState() => _CreateGuildModalBodyState();
}

class _CreateGuildModalBodyState extends State<_CreateGuildModalBody> {
  final TextEditingController _nameLookup = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _manifesto = TextEditingController();
  final Set<String> _tags = <String>{'# Speaking (口语)', '# Daily Check-in'};

  static const List<String> _allTags = <String>[
    '# Speaking (口语)',
    '# Writing (写作)',
    '# Daily Check-in',
    '# UK Application',
  ];

  @override
  void dispose() {
    _nameLookup.dispose();
    _name.dispose();
    _manifesto.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: HtmlDesignTokens.primary),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HtmlDesignTokens.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: HtmlDesignTokens.accent, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: HtmlDesignTokens.accent.withValues(alpha: 0.2), blurRadius: 20),
                  ],
                ),
                child: const Text('📷', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload Guild Logo',
                style: TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: HtmlDesignTokens.glassBorder),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.search, color: HtmlDesignTokens.textSub, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameLookup,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '搜索星环名或 ID，检查是否已被占用…',
                    hintStyle: TextStyle(color: HtmlDesignTokens.textSub),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _label('Guild Name'),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _decoration('e.g. 7.0 写作死磕群'),
        ),
        const SizedBox(height: 20),
        _label('Manifesto (宣言)'),
        const SizedBox(height: 8),
        TextField(
          controller: _manifesto,
          maxLines: 4,
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          decoration: _decoration('Describe the goal and rules of your guild...'),
        ),
        const SizedBox(height: 20),
        _label('Category Tags'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _allTags.map((String t) {
            final bool on = _tags.contains(t);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() {
                  if (on) {
                    _tags.remove(t);
                  } else {
                    _tags.add(t);
                  }
                }),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? HtmlDesignTokens.accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: on ? HtmlDesignTokens.accent : HtmlDesignTokens.glassBorder),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: 13,
                      color: on ? HtmlDesignTokens.accent : HtmlDesignTokens.textSub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: const LinearGradient(
                colors: <Color>[HtmlDesignTokens.primary, Color(0xFF9333EA)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(color: HtmlDesignTokens.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  showAppTopSnackBar(context, const Text('Guild Created Successfully!'));
                },
                borderRadius: BorderRadius.circular(100),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Create Guild',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        color: HtmlDesignTokens.primaryLight,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}

class _ExploreGuild {
  const _ExploreGuild({
    required this.name,
    required this.desc,
    required this.metaLeft,
    required this.metaTag,
    required this.emoji,
    required this.gradient,
    this.full = false,
  });

  final String name;
  final String desc;
  final String metaLeft;
  final String metaTag;
  final String emoji;
  final LinearGradient gradient;
  final bool full;
}

class _ExploreGuildModalBody extends StatefulWidget {
  const _ExploreGuildModalBody();

  @override
  State<_ExploreGuildModalBody> createState() => _ExploreGuildModalBodyState();
}

class _ExploreGuildModalBodyState extends State<_ExploreGuildModalBody> {
  final TextEditingController _search = TextEditingController();

  static final List<_ExploreGuild> _all = <_ExploreGuild>[
    const _ExploreGuild(
      name: '剑桥听力精听营',
      desc: '每天一套 Section 3/4 精听打卡，全员互助纠错。',
      metaLeft: '👥 142/200',
      metaTag: '# 听力',
      emoji: '🎧',
      gradient: LinearGradient(colors: <Color>[Color(0xFFF43F5E), Color(0xFFE11D48)]),
    ),
    const _ExploreGuild(
      name: '25 Fall 留学情报局',
      desc: '分享院校信息、申请进度、中介避坑指南。',
      metaLeft: '👥 198/200',
      metaTag: '# 申请',
      emoji: '🌍',
      gradient: LinearGradient(colors: <Color>[Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
      full: true,
    ),
    const _ExploreGuild(
      name: '外刊阅读分享群',
      desc: '经济学人、卫报精读，积累高级写作词汇。',
      metaLeft: '👥 56/200',
      metaTag: '# 阅读',
      emoji: '📚',
      gradient: LinearGradient(colors: <Color>[Color(0xFF10B981), Color(0xFF059669)]),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_ExploreGuild> get _filtered {
    final String q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where(
          (_ExploreGuild g) =>
              g.name.toLowerCase().contains(q) ||
              g.desc.toLowerCase().contains(q) ||
              g.metaTag.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: HtmlDesignTokens.glassBorder),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.search, color: HtmlDesignTokens.textSub, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _search,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search guild name or ID...',
                      hintStyle: TextStyle(color: HtmlDesignTokens.textSub),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            itemCount: _filtered.length,
            separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 16),
            itemBuilder: (BuildContext context, int i) {
              final _ExploreGuild g = _filtered[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
                  border: Border.all(color: HtmlDesignTokens.glassBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: g.gradient,
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Text(g.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            g.desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub, height: 1.4),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Text(g.metaLeft, style: const TextStyle(fontSize: 11, color: HtmlDesignTokens.primaryLight)),
                              const SizedBox(width: 8),
                              Text(g.metaTag, style: const TextStyle(fontSize: 11, color: HtmlDesignTokens.primaryLight)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: HtmlDesignTokens.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                      child: InkWell(
                        onTap: g.full
                            ? null
                            : () {
                                showAppTopSnackBar(
                                  context,
                                  Text('已申请加入 ${g.name}（演示）'),
                                );
                              },
                        borderRadius: BorderRadius.circular(100),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            g.full ? 'Full' : 'Join',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: g.full ? HtmlDesignTokens.textSub : HtmlDesignTokens.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
