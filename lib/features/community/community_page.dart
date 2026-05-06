// 好友/群聊演示行与私聊页仍保留供后续接数据；当前新号界面为空列表故未引用。
// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_session.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/navigation/shell_branch_activation.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/community_social_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_data_service.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';
import 'community_feed_bump.dart';
import 'community_social_repository.dart';
import 'feed_post_detail_page.dart';
import 'guild_glass_modals.dart';
import 'social_avatar.dart';
import 'social_inbox_sheet.dart';
import 'social_inbox_unread.dart';

const Color _kPinkGlow = Color(0xFFFF61D2);

/// 本会话内广场动态列表（主 Social 与 Profile「我的发布」共享）。
List<_FeedPost>? _sessionCommunityFeedPosts;

/// 与 `social.html` / `group.html` 布局与色板对齐的 Social 主界面。
class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  int _tabIndex = 0;
  late final ScrollController _feedScrollController;
  late final ScrollController _friendsScrollController;
  late final ScrollController _groupsScrollController;

  @override
  void initState() {
    super.initState();
    _feedScrollController = ScrollController();
    _friendsScrollController = ScrollController();
    _groupsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _feedScrollController.dispose();
    _friendsScrollController.dispose();
    _groupsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final List<String> tabs = <String>[
      s.tr('广场动态', 'Feed'),
      s.tr('好友', 'Friends'),
      s.tr('群聊', 'Groups'),
    ];
    ref.listen<AsyncValue<User?>>(authUserProvider, (AsyncValue<User?>? prev, AsyncValue<User?> next) {
      next.whenData((User? _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          unawaited(refreshSocialInboxUnreadBadge(ref));
        });
      });
    });
    ref.listen<Map<int, int>>(shellBranchActivationProvider, (
      Map<int, int>? previous,
      Map<int, int> next,
    ) {
      final int prevVal = previous?[1] ?? 0;
      final int nextVal = next[1] ?? 0;
      if (nextVal > prevVal) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          for (final ScrollController c in <ScrollController>[
            _feedScrollController,
            _friendsScrollController,
            _groupsScrollController,
          ]) {
            if (c.hasClients) {
              c.jumpTo(0);
            }
          }
        });
      }
    });
    final bool guest = !isLoggedIn(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text(
              'Social',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: HtmlDesignTokens.textMain,
                letterSpacing: 0.5,
                fontFamily: 'system-ui',
              ),
            ),
            const SocialInboxTriggerButton(),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: HtmlDesignTokens.glassBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                offset: const Offset(0, 2),
                blurRadius: 5,
                spreadRadius: -1,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: CommunitySegmentTab(
                    label: tabs[i],
                    active: i == _tabIndex,
                    onTap: () => setState(() => _tabIndex = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: <Widget>[
              CommunityFeedTab(
                isGuest: guest,
                scrollController: _feedScrollController,
              ),
              CommunityFriendsTab(
                isGuest: guest,
                scrollController: _friendsScrollController,
              ),
              CommunityGroupsTab(
                isGuest: guest,
                scrollController: _groupsScrollController,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Social 顶部分段标签（主 Tab 与 Profile「契约与星环」子页共用样式）。
class CommunitySegmentTab extends StatelessWidget {
  const CommunitySegmentTab({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: active
                ? Border.all(color: Colors.white.withValues(alpha: 0.05))
                : null,
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? HtmlDesignTokens.textMain : HtmlDesignTokens.textSub,
              fontFamily: 'system-ui',
            ),
          ),
        ),
      ),
    );
  }
}

// ——— 广场动态 ———

/// Social 广场动态 Tab；可从 Profile「我的发布」全屏复用，与主 Social 为同一套交互与数据。
class CommunityFeedTab extends ConsumerStatefulWidget {
  CommunityFeedTab({
    super.key,
    this.isGuest = false,
    required this.scrollController,
  });

  /// 游客仅可浏览他人公开帖子；互动需登录。
  final bool isGuest;
  final ScrollController scrollController;

  static final List<_FeedPost> _seedPosts = <_FeedPost>[
    _FeedPost(
      emoji: '🦊',
      avatarGradient: const LinearGradient(
        colors: <Color>[Color(0xFFFF61D2), Color(0xFFFE9090)],
      ),
      name: '烤鸭_8921',
      time: '2 hours ago',
      detailTimeLabel: 'Yesterday at 10:42 AM',
      isOwnPost: false,
      contentSpans: const <InlineSpan>[
        TextSpan(
          text: '终于考完了！口语遇到了超级友善的考官，分享一下保命句型～ ',
        ),
        TextSpan(
          text: '#雅思口语',
          style: TextStyle(color: Color(0xFFA78BFA)),
        ),
      ],
      detailContentSpans: const <InlineSpan>[
        TextSpan(
          text:
              '终于考完了！口语遇到了超级友善的考官，虽然 Part 2 稍微卡壳了一下，但是感觉总体发挥还可以。\n\n'
              '给大家分享一下考场的保命句型和几个极其高级的替换词，大家可以长按保存图片哦～ 希望大家都能早日上岸！',
        ),
      ],
      tagsLine: '#雅思口语 #上岸祈愿 #高分素材',
      likes: 128,
      comments: 32,
      liked: false,
      likesDisplay: '10.5k',
      commentsDisplay: '342',
    ),
  ];

  @override
  ConsumerState<CommunityFeedTab> createState() => _CommunityFeedTabState();
}

class _CommunityFeedTabState extends ConsumerState<CommunityFeedTab> with WidgetsBindingObserver {
  bool _composeExpanded = false;
  final TextEditingController _composeController = TextEditingController();
  final FocusNode _composeFocus = FocusNode();

  List<_FeedPost> _remotePosts = <_FeedPost>[];
  bool _loadingRemoteFeed = false;
  Object? _feedRealtimeChannel;
  Timer? _feedRealtimeDebounce;

  bool _useRemoteFeed() {
    if (widget.isGuest) {
      return false;
    }
    final AppDataService svc = ref.read(appDataServiceProvider);
    return svc.isBackendAvailable && svc.currentUser != null;
  }

  List<_FeedPost> get _posts {
    if (_useRemoteFeed()) {
      return _remotePosts;
    }
    _sessionCommunityFeedPosts ??= List<_FeedPost>.from(CommunityFeedTab._seedPosts);
    return _sessionCommunityFeedPosts!;
  }

  List<_FeedPost> get _visiblePosts {
    if (!widget.isGuest) {
      return _posts;
    }
    return _posts.where((_FeedPost p) => !p.isOwnPost).toList();
  }

  Future<void> _loadRemoteFeed() async {
    if (!_useRemoteFeed()) {
      return;
    }
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    await repo.ensureDemoSocialScenario();
    if (!mounted) {
      return;
    }
    setState(() => _loadingRemoteFeed = true);
    final String? uid = ref.read(appDataServiceProvider).currentUser?.id;
    final List<CommunityFeedPost> list = await repo.fetchFeed();
    if (!mounted) {
      return;
    }
    setState(() {
      _remotePosts = list.map((CommunityFeedPost e) => _postFromRemote(e, uid)).toList();
      _loadingRemoteFeed = false;
    });
  }

  static _FeedPost _postFromRemote(CommunityFeedPost e, String? myUid) {
    final bool own = myUid != null && e.authorId == myUid;
    final String rel = CommunitySocialRepository.formatRelativeTime(e.createdAt);
    return _FeedPost(
      emoji: socialEmojiForUserId(e.authorId),
      avatarGradient: socialGradientForUserId(e.authorId),
      name: own ? 'You' : e.authorDisplayName,
      time: rel,
      detailTimeLabel: rel,
      isOwnPost: own,
      contentSpans: <InlineSpan>[TextSpan(text: e.body)],
      detailContentSpans: <InlineSpan>[TextSpan(text: e.body)],
      likes: e.likeCount,
      comments: e.commentCount,
      liked: e.likedByMe,
      likesDisplay: '${e.likeCount}',
      commentsDisplay: '${e.commentCount}',
      serverPostId: e.id,
      authorUserId: e.authorId,
      plainBody: e.body,
      createdAt: e.createdAt,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionCommunityFeedPosts ??= List<_FeedPost>.from(CommunityFeedTab._seedPosts);
    _composeController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_useRemoteFeed()) {
        unawaited(_loadRemoteFeed());
      }
      _attachFeedRealtimeIfNeeded();
    });
  }

  @override
  void didUpdateWidget(CommunityFeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGuest != widget.isGuest) {
      if (_useRemoteFeed()) {
        unawaited(_loadRemoteFeed());
      }
    }
    _attachFeedRealtimeIfNeeded();
    if (!_useRemoteFeed()) {
      _tearDownFeedRealtime();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _useRemoteFeed()) {
      unawaited(_loadRemoteFeed());
      unawaited(refreshSocialInboxUnreadBadge(ref));
    }
  }

  void _onFeedTablesChanged() {
    _feedRealtimeDebounce?.cancel();
    _feedRealtimeDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted && _useRemoteFeed()) {
        unawaited(_loadRemoteFeed());
      }
    });
  }

  void _attachFeedRealtimeIfNeeded() {
    // JSON 本地存储模式下不使用实时订阅。
  }

  void _tearDownFeedRealtime() {
    _feedRealtimeDebounce?.cancel();
    _feedRealtimeDebounce = null;
    final Object? ch = _feedRealtimeChannel;
    _feedRealtimeChannel = null;
    if (ch != null) {
      // no-op
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tearDownFeedRealtime();
    _composeController.dispose();
    _composeFocus.dispose();
    super.dispose();
  }

  void _closeCompose() {
    setState(() => _composeExpanded = false);
    _composeFocus.unfocus();
  }

  void _toggleComposeHeader() {
    if (widget.isGuest) {
      pushLoginPage(context);
      return;
    }
    setState(() {
      if (_composeExpanded) {
        _composeExpanded = false;
        _composeFocus.unfocus();
      } else {
        _composeExpanded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _composeFocus.requestFocus();
          }
        });
      }
    });
  }

  Future<void> _submitPost(BuildContext context) async {
    if (widget.isGuest) {
      pushLoginPage(context);
      return;
    }
    final String text = _composeController.text.trim();
    if (text.isEmpty) {
      return;
    }
    if (_useRemoteFeed()) {
      final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
      final String? id = await repo.createPost(text);
      if (!context.mounted) {
        return;
      }
      if (id == null) {
        showAppTopSnackBar(context, const Text('发布失败，请检查网络与登录状态'));
        return;
      }
      _composeController.clear();
      setState(() => _composeExpanded = false);
      _composeFocus.unfocus();
      await _loadRemoteFeed();
      if (!context.mounted) {
        return;
      }
      communityFeedBumpNotifier.value++;
      showAppTopSnackBar(context, const Text('已发布到广场动态'));
      return;
    }

    final _FeedPost newPost = _FeedPost(
      emoji: '👾',
      avatarGradient: LinearGradient(
        colors: <Color>[HtmlDesignTokens.primary, HtmlDesignTokens.accent],
      ),
      name: 'You',
      time: 'Just now',
      detailTimeLabel: 'Just now',
      isOwnPost: true,
      contentSpans: <InlineSpan>[TextSpan(text: text)],
      likes: 0,
      comments: 0,
      liked: false,
      likesDisplay: '0',
      commentsDisplay: '0',
      plainBody: text,
    );
    setState(() {
      _sessionCommunityFeedPosts ??= List<_FeedPost>.from(CommunityFeedTab._seedPosts);
      _sessionCommunityFeedPosts!.insert(0, newPost);
      _composeController.clear();
      _composeExpanded = false;
    });
    communityFeedBumpNotifier.value++;
    _composeFocus.unfocus();
    showAppTopSnackBar(context, const Text('已发布到广场动态'));
  }

  @override
  Widget build(BuildContext context) {
    final bool publishReady = _composeController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: _composeExpanded ? 16 : 12,
            ),
            decoration: BoxDecoration(
              color: _composeExpanded ? const Color(0xF51A103C) : HtmlDesignTokens.glassCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _composeExpanded
                    ? HtmlDesignTokens.primary.withValues(alpha: 0.35)
                    : HtmlDesignTokens.glassBorder,
              ),
              boxShadow: _composeExpanded
                  ? <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: HtmlDesignTokens.primary.withValues(alpha: 0.12),
                        blurRadius: 24,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                InkWell(
                  onTap: _toggleComposeHeader,
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: <Color>[HtmlDesignTokens.primary, HtmlDesignTokens.accent],
                          ),
                        ),
                        child: const Text('👾', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      if (!_composeExpanded)
                        Expanded(
                          child: Text(
                            widget.isGuest
                                ? AppStrings.of(context).tr('登录后发布动态…', 'Login to post...')
                                : AppStrings.of(context).tr('分享你的想法...', 'Share your thoughts...'),
                            style: TextStyle(
                              fontSize: 14,
                              color: HtmlDesignTokens.textSub,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      AnimatedRotation(
                        turns: _composeExpanded ? 0.125 : 0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.add,
                          color: _composeExpanded ? HtmlDesignTokens.textSub : HtmlDesignTokens.primaryLight,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _composeExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _composeController,
                              focusNode: _composeFocus,
                              minLines: 3,
                              maxLines: 6,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: HtmlDesignTokens.textMain,
                                fontFamily: 'system-ui',
                              ),
                              cursorColor: HtmlDesignTokens.primaryLight,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: AppStrings.of(context).tr('你在想什么？在这里输入...', "What's on your mind? Type here..."),
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.32),
                                  fontSize: 15,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                _ComposeToolButton(
                                  icon: Icons.photo_camera_outlined,
                                  onTap: () => showAppTopSnackBar(
                                    context,
                                    Text(AppStrings.of(context).tr('图片（演示）', 'Image (demo)')),
                                  ),
                                ),
                                _ComposeToolButton(
                                  icon: Icons.tag,
                                  onTap: () => showAppTopSnackBar(
                                    context,
                                    Text(AppStrings.of(context).tr('话题标签（演示）', 'Hashtag (demo)')),
                                  ),
                                ),
                                _ComposeToolButton(
                                  icon: Icons.alternate_email_rounded,
                                  onTap: () => showAppTopSnackBar(
                                    context,
                                    Text(AppStrings.of(context).tr('@ 提及（演示）', '@ mention (demo)')),
                                  ),
                                ),
                                const Spacer(),
                                Material(
                                  color: publishReady
                                      ? HtmlDesignTokens.primary
                                      : HtmlDesignTokens.primary.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    onTap: publishReady ? () => unawaited(_submitPost(context)) : null,
                                    borderRadius: BorderRadius.circular(999),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      child: Text(
                                        AppStrings.of(context).tr('发布', 'Publish'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: publishReady ? Colors.white : HtmlDesignTokens.primaryLight,
                                          fontFamily: 'system-ui',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Colors.transparent,
                HtmlDesignTokens.glassBorder,
                Colors.transparent,
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_loadingRemoteFeed && _useRemoteFeed() && _remotePosts.isEmpty)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else
                ListView.builder(
                  controller: widget.scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: _visiblePosts.length,
                  itemBuilder: (BuildContext context, int i) {
                    return _FeedPostCard(
                      post: _visiblePosts[i],
                      guestLockedInteractions: widget.isGuest,
                      onRemoteLikeToggle: _useRemoteFeed()
                          ? (_FeedPost p) async {
                              final CommunitySocialRepository repo =
                                  ref.read(communitySocialRepositoryProvider);
                              final bool? next =
                                  await repo.toggleLike(postId: p.serverPostId!, currentlyLiked: p.liked);
                              if (!mounted || next == null) {
                                return;
                              }
                              await _loadRemoteFeed();
                              communityFeedBumpNotifier.value++;
                            }
                          : null,
                    );
                  },
                ),
              if (_composeExpanded)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeCompose,
                    child: ColoredBox(
                      color: const Color(0x9E0D071C),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComposeToolButton extends StatelessWidget {
  const _ComposeToolButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: HtmlDesignTokens.textSub),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _FeedPost {
  const _FeedPost({
    required this.emoji,
    required this.avatarGradient,
    required this.name,
    required this.time,
    required this.contentSpans,
    required this.likes,
    required this.comments,
    required this.liked,
    this.isOwnPost = false,
    this.detailTimeLabel,
    this.detailContentSpans,
    this.tagsLine,
    this.likesDisplay,
    this.commentsDisplay,
    this.viewsDisplay,
    this.serverPostId,
    this.authorUserId,
    this.plainBody = '',
    this.createdAt,
  });

  final String emoji;
  final Gradient avatarGradient;
  final String name;
  final String time;
  final List<InlineSpan> contentSpans;
  final int likes;
  final int comments;
  final bool liked;
  /// 与 `post.html` 一致：本人动态为 true，决定详情页关注/Author/浏览量/菜单/占位文案。
  final bool isOwnPost;
  final String? detailTimeLabel;
  final List<InlineSpan>? detailContentSpans;
  final String? tagsLine;
  final String? likesDisplay;
  final String? commentsDisplay;
  final String? viewsDisplay;
  final String? serverPostId;
  final String? authorUserId;
  final String plainBody;
  final DateTime? createdAt;

  FeedPostDetailArgs toDetailArgs({bool requireLoginToInteract = false}) {
    return FeedPostDetailArgs(
      emoji: emoji,
      avatarGradient: avatarGradient,
      authorDisplayName: name,
      timeLabel: detailTimeLabel ?? time,
      contentSpans: detailContentSpans ?? contentSpans,
      likesDisplay: likesDisplay ?? '$likes',
      commentsDisplay: commentsDisplay ?? '$comments',
      isOwnPost: isOwnPost,
      tagsLine: tagsLine,
      viewsDisplay: isOwnPost ? viewsDisplay : null,
      liked: liked,
      requireLoginToInteract: requireLoginToInteract,
      serverPostId: serverPostId,
      authorUserId: authorUserId,
      plainTextBody: plainBody,
    );
  }
}

String _inlineSpansToPlain(List<InlineSpan> spans) {
  final StringBuffer b = StringBuffer();
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      final String? t = s.text;
      if (t != null && t.isNotEmpty) {
        b.write(t);
      }
      final List<InlineSpan>? ch = s.children;
      if (ch != null) {
        for (final InlineSpan c in ch) {
          walk(c);
        }
      }
    }
  }
  for (final InlineSpan s in spans) {
    walk(s);
  }
  return b.toString().trim();
}

/// 供 Profile「我的发布」读取，与 [CommunityFeedTab] 会话数据一致。
class CommunityOwnPostLine {
  const CommunityOwnPostLine({
    required this.timeLabel,
    required this.preview,
    required this.likes,
    required this.comments,
  });

  final String timeLabel;
  final String preview;
  final int likes;
  final int comments;
}

List<CommunityOwnPostLine> listCommunityOwnPostsForProfile() {
  final List<_FeedPost>? s = _sessionCommunityFeedPosts;
  if (s == null) {
    return <CommunityOwnPostLine>[];
  }
  return s
      .where((_FeedPost p) => p.isOwnPost)
      .map(
        (_FeedPost p) => CommunityOwnPostLine(
          timeLabel: p.detailTimeLabel ?? p.time,
          preview: _inlineSpansToPlain(p.contentSpans),
          likes: p.likes,
          comments: p.comments,
        ),
      )
      .toList();
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.post,
    this.guestLockedInteractions = false,
    this.onRemoteLikeToggle,
  });

  final _FeedPost post;
  final bool guestLockedInteractions;
  final Future<void> Function(_FeedPost post)? onRemoteLikeToggle;

  void _openDetail(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FeedPostDetailPage(
          args: post.toDetailArgs(requireLoginToInteract: guestLockedInteractions),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openDetail(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: post.avatarGradient,
                          ),
                          child: Text(post.emoji, style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                post.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: HtmlDesignTokens.textMain,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                              Text(
                                post.time,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HtmlDesignTokens.textSub,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _openDetail(context);
                          },
                          child: Icon(Icons.more_horiz, color: HtmlDesignTokens.textSub, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Color(0xE6FFFFFF),
                          fontFamily: 'system-ui',
                        ),
                        children: post.contentSpans,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: guestLockedInteractions
                              ? () => pushLoginPage(context)
                              : post.serverPostId != null && onRemoteLikeToggle != null
                                  ? () {
                                      unawaited(onRemoteLikeToggle!(post));
                                    }
                                  : null,
                          child: Row(
                            children: <Widget>[
                              _ActionChip(
                                icon: post.liked ? Icons.favorite : Icons.favorite_border,
                                label: '${post.likes}',
                                iconColor: post.liked ? _kPinkGlow : HtmlDesignTokens.textSub,
                              ),
                              const SizedBox(width: 20),
                              _ActionChip(
                                icon: Icons.chat_bubble_outline,
                                label: '${post.comments}',
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.rocket_launch_outlined, color: HtmlDesignTokens.textSub, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.03)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: iconColor ?? HtmlDesignTokens.textSub),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HtmlDesignTokens.textSub,
            fontFamily: 'system-ui',
          ),
        ),
      ],
    );
  }
}

// ——— 好友：Eunoia ID 搜索页（交互参考 `friend.html`）———

enum _FriendSearchPhase { idle, loading, found, notFound }

class _FriendIdSearchPage extends ConsumerStatefulWidget {
  const _FriendIdSearchPage();

  @override
  ConsumerState<_FriendIdSearchPage> createState() => _FriendIdSearchPageState();
}

class _FriendIdSearchPageState extends ConsumerState<_FriendIdSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  _FriendSearchPhase _phase = _FriendSearchPhase.idle;
  PublicProfileBrief? _resultProfile;
  List<String> _recentIds = <String>[];
  String? _myEunoiaId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
      unawaited(_loadMyEunoiaId());
    });
  }

  Future<void> _loadMyEunoiaId() async {
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    final String? id = await repo.currentUserEunoiaId();
    if (!mounted) {
      return;
    }
    setState(() => _myEunoiaId = id);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_controller.text.trim().isEmpty) {
      setState(() => _phase = _FriendSearchPhase.idle);
    } else {
      setState(() {});
    }
  }

  Future<void> _search(String uid) async {
    FocusScope.of(context).unfocus();
    setState(() => _phase = _FriendSearchPhase.loading);
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    final PublicProfileBrief? profile = await repo.findProfileByEunoiaId(uid);
    if (!mounted) {
      return;
    }
    if (profile != null) {
      final String key = uid.trim().toLowerCase();
      _recentIds.remove(key);
      _recentIds.insert(0, key);
      if (_recentIds.length > 10) {
        _recentIds = _recentIds.sublist(0, 10);
      }
      setState(() {
        _resultProfile = profile;
        _phase = _FriendSearchPhase.found;
      });
    } else {
      setState(() => _phase = _FriendSearchPhase.notFound);
    }
  }

  void _clearInput() {
    _controller.clear();
    setState(() => _phase = _FriendSearchPhase.idle);
    _focusNode.requestFocus();
  }

  void _submitCurrent() {
    final String uid = _controller.text.trim();
    if (uid.isEmpty) {
      return;
    }
    unawaited(_search(uid));
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg.withValues(alpha: 0.98),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left_rounded, color: HtmlDesignTokens.textSub, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: HtmlDesignTokens.glassCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: HtmlDesignTokens.accent.withValues(alpha: 0.35)),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: HtmlDesignTokens.accent.withValues(alpha: 0.12),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.radar, color: HtmlDesignTokens.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              keyboardType: TextInputType.text,
                              style: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 15),
                              cursorColor: HtmlDesignTokens.primaryLight,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _submitCurrent(),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: '输入 Eunoia ID 搜索...',
                                hintStyle: TextStyle(color: Color(0x4DFFFFFF), fontSize: 15),
                              ),
                            ),
                          ),
                          if (hasText)
                            IconButton(
                              onPressed: _clearInput,
                              icon: const Icon(Icons.close_rounded, size: 18, color: HtmlDesignTokens.textSub),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                              ),
                            )
                          else
                            IconButton(
                              onPressed: () {
                                showAppTopSnackBar(context, const Text('扫码添加（演示）'));
                              },
                              icon: Icon(Icons.qr_code_scanner_rounded, color: HtmlDesignTokens.primaryLight, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _FriendSearchPhase.idle:
        return _FriendSearchIdleBody(
          key: const ValueKey<String>('idle'),
          recentIds: _recentIds,
          myEunoiaId: _myEunoiaId,
          onPickRecent: (String id) {
            _controller.text = id;
            unawaited(_search(id));
          },
          onClearRecent: () => setState(() => _recentIds = <String>[]),
          onOpenQr: () {
            final String? id = _myEunoiaId;
            showAppTopSnackBar(
              context,
              Text(id == null ? '正在读取你的 ID…' : '你的 Eunoia ID：$id'),
            );
          },
        );
      case _FriendSearchPhase.loading:
        return const _FriendSearchLoadingBody(key: ValueKey<String>('loading'));
      case _FriendSearchPhase.found:
        final PublicProfileBrief? p = _resultProfile;
        if (p == null) {
          return const _FriendSearchNotFoundBody(key: ValueKey<String>('foundNull'));
        }
        return _FriendSearchResultBody(
          key: ValueKey<String>('found${p.userId}'),
          profile: p,
          onAddFriend: () async {
            final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
            final String? err = await repo.sendFriendRequest(p.userId);
            if (!mounted) {
              return;
            }
            if (err == null) {
              showAppTopSnackBar(context, const Text('契约请求已发送！'));
            } else {
              showAppTopSnackBar(context, Text(err));
            }
          },
        );
      case _FriendSearchPhase.notFound:
        return const _FriendSearchNotFoundBody(key: ValueKey<String>('notFound'));
    }
  }
}

class _FriendSearchIdleBody extends StatelessWidget {
  const _FriendSearchIdleBody({
    super.key,
    required this.recentIds,
    this.myEunoiaId,
    required this.onPickRecent,
    required this.onClearRecent,
    required this.onOpenQr,
  });

  final List<String> recentIds;
  final String? myEunoiaId;
  final void Function(String id) onPickRecent;
  final VoidCallback onClearRecent;
  final VoidCallback onOpenQr;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenQr,
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    HtmlDesignTokens.primary.withValues(alpha: 0.15),
                    HtmlDesignTokens.accent.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                border: Border.all(color: HtmlDesignTokens.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: <Widget>[
                  const Text('📱', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Text(
                              'My Eunoia QR Code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: HtmlDesignTokens.textMain,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ID: ${myEunoiaId ?? '…'}',
                              style: TextStyle(fontSize: 12, color: HtmlDesignTokens.primaryLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: HtmlDesignTokens.primaryLight, size: 22),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: <Widget>[
            const Text(
              'RECENT SEARCHES',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: HtmlDesignTokens.textSub,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            if (recentIds.isNotEmpty)
              IconButton(
                onPressed: onClearRecent,
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: HtmlDesignTokens.textSub),
                tooltip: '清空',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final String id in recentIds)
              ActionChip(
                label: Text(id),
                labelStyle: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 13),
                backgroundColor: HtmlDesignTokens.glassCard,
                side: BorderSide(color: HtmlDesignTokens.glassBorder),
                onPressed: () => onPickRecent(id),
              ),
          ],
        ),
      ],
    );
  }
}

class _FriendSearchLoadingBody extends StatelessWidget {
  const _FriendSearchLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  color: HtmlDesignTokens.accent.withValues(alpha: 0.45),
                  strokeWidth: 2,
                ),
              ),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HtmlDesignTokens.accent,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: HtmlDesignTokens.accent.withValues(alpha: 0.5), blurRadius: 18),
                  ],
                ),
                child: const Icon(Icons.radar, color: Color(0xFF0D071C), size: 22),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Locating Signal...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: HtmlDesignTokens.accent,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendSearchResultBody extends StatelessWidget {
  const _FriendSearchResultBody({
    super.key,
    required this.profile,
    required this.onAddFriend,
  });

  final PublicProfileBrief profile;
  final Future<void> Function() onAddFriend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const Text(
          'RESULT FOUND',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: HtmlDesignTokens.textSub,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF18112C),
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
            border: Border.all(color: HtmlDesignTokens.glassBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF3B82F6), Color(0xFF06B6D4)],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14),
                      ],
                    ),
                    child: Text(
                      socialEmojiForUserId(profile.userId),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: HtmlDesignTokens.textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${profile.eunoiaId}',
                          style: const TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MiniStat(
                      value: '${profile.wordTowerMaxFloor ?? 0}',
                      label: '词塔层数',
                      valueColor: HtmlDesignTokens.accent,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('|', style: TextStyle(color: HtmlDesignTokens.glassBorder)),
                  ),
                  Expanded(
                    child: _MiniStat(value: '45/50', label: '手办收集', valueColor: HtmlDesignTokens.primaryLight),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  unawaited(onAddFriend());
                },
                style: FilledButton.styleFrom(
                  backgroundColor: HtmlDesignTokens.accent.withValues(alpha: 0.15),
                  foregroundColor: HtmlDesignTokens.accent,
                  side: BorderSide(color: HtmlDesignTokens.accent.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('＋ 缔结契约 (Add Friend)', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.glassCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Column(
        children: <Widget>[
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor)),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: HtmlDesignTokens.textSub),
          ),
        ],
      ),
    );
  }
}

class _FriendSearchNotFoundBody extends StatelessWidget {
  const _FriendSearchNotFoundBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('🛰️', style: TextStyle(fontSize: 40, color: Colors.white.withValues(alpha: 0.35))),
            const SizedBox(height: 12),
            const Text(
              'Signal Lost',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HtmlDesignTokens.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              '未找到匹配的 Eunoia ID\n请检查输入是否正确',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: HtmlDesignTokens.textSub, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ——— 好友 ———

class _GuestSocialLockView extends StatelessWidget {
  const _GuestSocialLockView({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.lock_outline, size: 48, color: HtmlDesignTokens.textSub.withValues(alpha: 0.65)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: HtmlDesignTokens.textMain,
                fontFamily: 'system-ui',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: HtmlDesignTokens.textSub,
                fontFamily: 'system-ui',
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => pushLoginPage(context),
              style: FilledButton.styleFrom(
                backgroundColor: HtmlDesignTokens.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
                ),
              ),
              child: const Text('登录/注册', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'system-ui')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Social 好友 Tab；可从 Profile「契约与星环」复用。
class CommunityFriendsTab extends ConsumerStatefulWidget {
  CommunityFriendsTab({
    super.key,
    this.isGuest = false,
    required this.scrollController,
  });

  final bool isGuest;
  final ScrollController scrollController;

  @override
  ConsumerState<CommunityFriendsTab> createState() => _CommunityFriendsTabState();
}

class _CommunityFriendsTabState extends ConsumerState<CommunityFriendsTab> {
  List<FriendListEntry> _friends = <FriendListEntry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadFriends());
    });
  }

  @override
  void didUpdateWidget(CommunityFriendsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGuest != widget.isGuest && !widget.isGuest) {
      setState(() => _loading = true);
      unawaited(_loadFriends());
    }
  }

  Future<void> _loadFriends() async {
    if (widget.isGuest) {
      return;
    }
    final AppDataService svc = ref.read(appDataServiceProvider);
    if (!svc.isBackendAvailable || svc.currentUser == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    await repo.ensureDemoSocialScenario();
    final List<FriendListEntry> list = await repo.listFriends();
    if (!mounted) {
      return;
    }
    setState(() {
      _friends = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) {
      return _GuestSocialLockView(
        title: AppStrings.of(context).tr('好友与私聊', 'Friends & Chat'),
        subtitle: AppStrings.of(context).tr(
          '游客模式下无法查看好友列表与聊天记录。\n登录后可使用 Eunoia ID 搜索与私聊。',
          'Guest mode cannot access friend list or chat history.\nLogin to search and chat via Eunoia ID.',
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const _FriendIdSearchPage(),
                ),
              ).then((_) => unawaited(_loadFriends()));
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: HtmlDesignTokens.glassCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: HtmlDesignTokens.glassBorder),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.radar, color: HtmlDesignTokens.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.of(context).tr('输入 Eunoia ID 搜索...', 'Search by Eunoia ID...'),
                      style: TextStyle(color: HtmlDesignTokens.textSub, fontSize: 14),
                    ),
                  ),
                  Icon(Icons.qr_code_scanner_rounded, color: HtmlDesignTokens.primaryLight, size: 22),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => _FriendChatPage(
                    title: AppStrings.of(context).tr('演示好友 · 私聊', 'Demo · Direct message'),
                    online: true,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: HtmlDesignTokens.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                border: Border.all(color: HtmlDesignTokens.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.chat_bubble_rounded, color: HtmlDesignTokens.primaryLight, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppStrings.of(context).tr('示例：打开聊天界面', 'Sample: open chat'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HtmlDesignTokens.textMain,
                            fontFamily: 'system-ui',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.of(context).tr(
                            '点击查看私聊样式（演示数据）',
                            'Tap to preview DM layout (demo)',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: HtmlDesignTokens.textSub, size: 22),
                ],
              ),
            ),
          ),
        ),
        if (_friends.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: <Widget>[
                Text('🤝', style: TextStyle(fontSize: 40, color: Colors.white.withValues(alpha: 0.35))),
                const SizedBox(height: 12),
                Text(
                  AppStrings.of(context).tr('暂无好友', 'No friends yet'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HtmlDesignTokens.textSub),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    AppStrings.of(context).tr(
                      '用上方搜索缔结契约，或在广场上互动后加好友',
                      'Search above to add friends, or connect via feed interactions',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.45, color: HtmlDesignTokens.textSub.withValues(alpha: 0.9)),
                  ),
                ),
              ],
            ),
          )
        else ...<Widget>[
          const _SectionLabel('MY FRIENDS'),
          for (final FriendListEntry f in _friends)
            _FriendRow(
              emoji: socialEmojiForUserId(f.userId),
              gradient: socialGradientForUserId(f.userId),
              name: f.displayName,
              timeLabel: 'ID ${f.eunoiaId}',
              preview: AppStrings.of(context).tr('轻触进入私聊', 'Tap to open chat'),
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => _FriendChatPage(
                      title: f.displayName,
                      online: true,
                    ),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: HtmlDesignTokens.textSub,
          letterSpacing: 1,
          fontFamily: 'system-ui',
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.emoji,
    this.gradient,
    this.flatColor,
    required this.name,
    required this.timeLabel,
    required this.preview,
    this.previewEmphasized = false,
    this.unread,
    this.online = false,
    this.onlineBusy = false,
    this.muted = false,
    required this.onTap,
  });

  final String emoji;
  final Gradient? gradient;
  final Color? flatColor;
  final String name;
  final String timeLabel;
  final String preview;
  final bool previewEmphasized;
  final int? unread;
  final bool online;
  final bool onlineBusy;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: gradient,
                      color: flatColor,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  if (online || onlineBusy)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: online ? HtmlDesignTokens.accent : HtmlDesignTokens.primary,
                          border: Border.all(color: const Color(0xFF0D071C), width: 2),
                          boxShadow: online
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: HtmlDesignTokens.accent.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: HtmlDesignTokens.textMain.withValues(alpha: muted ? 0.7 : 1),
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: HtmlDesignTokens.textSub,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: previewEmphasized ? HtmlDesignTokens.textMain : HtmlDesignTokens.textSub,
                        fontWeight: previewEmphasized ? FontWeight.w500 : FontWeight.normal,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
              if (unread != null) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kPinkGlow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              Icon(Icons.more_horiz, color: HtmlDesignTokens.textSub, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendChatPage extends StatelessWidget {
  const _FriendChatPage({
    required this.title,
    required this.online,
  });

  final String title;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: _RadialGlowPainter()),
          Column(
            children: <Widget>[
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: HtmlDesignTokens.subpageAppBarPadding.copyWith(bottom: 12),
                  child: Row(
                    children: <Widget>[
                      _CircleIconButton(
                        icon: Icons.chevron_left,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HtmlDesignTokens.textMain,
                              ),
                            ),
                            if (online)
                              const Text(
                                '● Online',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: HtmlDesignTokens.accent,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _CircleIconButton(
                        icon: Icons.phone_outlined,
                        onPressed: () {},
                        iconColor: HtmlDesignTokens.accent,
                        background: HtmlDesignTokens.accent.withValues(alpha: 0.1),
                        borderless: true,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: HtmlDesignTokens.glassBorder),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: const <Widget>[
                    Center(
                      child: Text(
                        'Today 10:30 AM',
                        style: TextStyle(fontSize: 11, color: HtmlDesignTokens.textSub),
                      ),
                    ),
                    SizedBox(height: 16),
                    _DmBubble(isMe: true, text: 'We can start with Part 1.'),
                    SizedBox(height: 16),
                    _VoiceBubble(),
                  ],
                ),
              ),
              _ChatInputBar(placeholder: 'Message...', voiceButtonAccent: HtmlDesignTokens.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadialGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          HtmlDesignTokens.primary.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.shortestSide * 0.9));
    canvas.drawRect(Offset.zero & size, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.background,
    this.borderless = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final Color? background;
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? HtmlDesignTokens.glassCard,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: borderless
              ? null
              : BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HtmlDesignTokens.glassBorder),
                ),
          child: Icon(icon, color: iconColor ?? HtmlDesignTokens.textMain, size: 22),
        ),
      ),
    );
  }
}

class _DmBubble extends StatelessWidget {
  const _DmBubble({required this.isMe, required this.text});

  final bool isMe;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: <Color>[Color(0xFF7C3AED), Color(0xFF9333EA)],
                )
              : null,
          color: isMe ? null : HtmlDesignTokens.glassCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          border: isMe ? null : Border.all(color: HtmlDesignTokens.glassBorder),
          boxShadow: isMe
              ? <BoxShadow>[
                  BoxShadow(
                    color: HtmlDesignTokens.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: HtmlDesignTokens.glassCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: HtmlDesignTokens.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Row(
              children: <Widget>[
                _wave(8),
                _wave(16),
                _wave(10),
                _wave(20),
                _wave(12),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              '12"',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _wave(double h) {
    return Container(
      width: 3,
      height: h,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.placeholder,
    required this.voiceButtonAccent,
    this.groupStyle = false,
  });

  final String placeholder;
  final Color voiceButtonAccent;
  final bool groupStyle;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 15, 20, 16 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            color: const Color(0xF20D071C),
            border: Border(top: BorderSide(color: HtmlDesignTokens.glassBorder)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.add, size: 26, color: HtmlDesignTokens.textSub),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: HtmlDesignTokens.glassCard,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: HtmlDesignTokens.glassBorder),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: placeholder,
                            hintStyle: const TextStyle(color: HtmlDesignTokens.textSub),
                          ),
                        ),
                      ),
                      Icon(Icons.sentiment_satisfied_alt_outlined, color: HtmlDesignTokens.textSub, size: 22),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: voiceButtonAccent,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: voiceButtonAccent.withValues(alpha: groupStyle ? 0.4 : 0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: groupStyle ? Colors.white : Colors.black87,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ——— 群聊 ———

/// Social 群聊 Tab；可从 Profile「契约与星环」复用。
class CommunityGroupsTab extends StatelessWidget {
  CommunityGroupsTab({
    super.key,
    this.isGuest = false,
    required this.scrollController,
  });

  final bool isGuest;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return const _GuestSocialLockView(
        title: '星环与群聊',
        subtitle: '游客模式下无法查看或管理公会群聊。\n登录后加入车队、参与讨论。',
      );
    }
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: <Widget>[
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _GroupActionCard.create(context)),
              const SizedBox(width: 16),
              Expanded(child: _GroupActionCard.join(context)),
            ],
          ),
        ),
        const _SectionLabel('My Guilds (我的星环)'),
        _GroupListRow(
          emoji: '🌙',
          style: _GroupAvatarStyle.purple,
          name: '夜猫刷题组 · IELTS Band 7+',
          memberCount: 128,
          sender: '雅思日记本:',
          message: '今晚 21:30 口语圆桌谁来？Topic 已发群公告',
          time: '12m',
          unread: 3,
          onOpenChat: () => CommunityGroupsTab._openDemoGroupChat(
            context,
            name: '夜猫刷题组 · IELTS Band 7+',
            guildId: 'guild-demo-night',
            emoji: '🌙',
          ),
          onMore: () => CommunityGroupsTab._showGroupManage(
            context,
            '夜猫刷题组 · IELTS Band 7+',
            'guild-demo-night',
            '🌙',
          ),
        ),
        Divider(height: 1, color: HtmlDesignTokens.glassBorder.withValues(alpha: 0.6)),
        _GroupListRow(
          emoji: '🎯',
          style: _GroupAvatarStyle.blue,
          name: '写作急救小队',
          memberCount: 56,
          sender: '口语搭子_阿乐:',
          message: '我刚提交了批改范例，大家对照看看论点骨架～',
          time: '1h',
          muted: true,
          onOpenChat: () => CommunityGroupsTab._openDemoGroupChat(
            context,
            name: '写作急救小队',
            guildId: 'guild-demo-write',
            emoji: '🎯',
          ),
          onMore: () => CommunityGroupsTab._showGroupManage(
            context,
            '写作急救小队',
            'guild-demo-write',
            '🎯',
          ),
        ),
      ],
    );
  }

  static void _openDemoGroupChat(
    BuildContext context, {
    required String name,
    required String guildId,
    required String emoji,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _GroupChatPage(
          groupName: name,
          guildId: guildId,
          onManage: () => _showGroupManage(context, name, guildId, emoji),
        ),
      ),
    );
  }

  static void _showGroupManage(
    BuildContext context,
    String name,
    String guildId,
    String emoji,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => _GroupManageSheet(
        name: name,
        guildId: guildId,
        emoji: emoji,
      ),
    );
  }
}

enum _GroupAvatarStyle { blue, purple, muted }

class _GroupActionCard extends StatelessWidget {
  const _GroupActionCard._({required this.child, required this.borderTint});

  final Widget child;
  final Color borderTint;

  static Widget create(BuildContext context) {
    return _GroupActionCard._(
      borderTint: HtmlDesignTokens.accent.withValues(alpha: 0.3),
      child: _cardContent(
        icon: Icons.add,
        iconBg: HtmlDesignTokens.accent.withValues(alpha: 0.15),
        iconColor: HtmlDesignTokens.accent,
        title: '创建星环',
        subtitle: '组建专属学习车队',
        glow: HtmlDesignTokens.accent,
        alignGlowLeft: true,
        onTap: () => GuildGlassModals.showCreate(context),
      ),
    );
  }

  static Widget join(BuildContext context) {
    return _GroupActionCard._(
      borderTint: HtmlDesignTokens.primary.withValues(alpha: 0.3),
      child: _cardContent(
        icon: Icons.explore_outlined,
        iconBg: HtmlDesignTokens.primary.withValues(alpha: 0.15),
        iconColor: HtmlDesignTokens.primaryLight,
        title: '探索公会',
        subtitle: '输入ID或扫描加入',
        glow: HtmlDesignTokens.primary,
        alignGlowLeft: false,
        onTap: () => GuildGlassModals.showExplore(context),
      ),
    );
  }

  static Widget _cardContent({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color glow,
    required bool alignGlowLeft,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              top: -20,
              left: alignGlowLeft ? -20 : null,
              right: alignGlowLeft ? null : -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: glow.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: 10),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: HtmlDesignTokens.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: HtmlDesignTokens.textSub),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
          border: Border.all(color: borderTint),
        ),
        child: child,
      ),
    );
  }
}

class _GroupListRow extends StatelessWidget {
  const _GroupListRow({
    required this.emoji,
    required this.style,
    required this.name,
    required this.memberCount,
    required this.sender,
    required this.message,
    required this.time,
    this.unread,
    this.muted = false,
    required this.onOpenChat,
    required this.onMore,
  });

  final String emoji;
  final _GroupAvatarStyle style;
  final String name;
  final int memberCount;
  final String sender;
  final String message;
  final String time;
  final int? unread;
  final bool muted;
  final VoidCallback onOpenChat;
  final VoidCallback onMore;

  LinearGradient? get _gradient {
    switch (style) {
      case _GroupAvatarStyle.blue:
        return const LinearGradient(colors: <Color>[Color(0xFF3B82F6), Color(0xFF06B6D4)]);
      case _GroupAvatarStyle.purple:
        return const LinearGradient(colors: <Color>[Color(0xFF7C3AED), Color(0xFFD946EF)]);
      case _GroupAvatarStyle.muted:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenChat,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: _gradient,
                  color: style == _GroupAvatarStyle.muted ? const Color(0xFF374151) : null,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: HtmlDesignTokens.textMain.withValues(alpha: muted ? 0.8 : 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$memberCount',
                            style: const TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Text(
                          sender,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: HtmlDesignTokens.primaryLight,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: HtmlDesignTokens.textSub.withValues(alpha: muted ? 0.8 : 1),
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(fontSize: 11, color: HtmlDesignTokens.textSub),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (unread != null) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kPinkGlow,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: _kPinkGlow.withValues(alpha: 0.4), blurRadius: 8),
                    ],
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
              GestureDetector(
                onTap: onMore,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.more_horiz, color: HtmlDesignTokens.textSub, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupChatPage extends StatelessWidget {
  const _GroupChatPage({
    required this.groupName,
    required this.guildId,
    required this.onManage,
  });

  final String groupName;
  final String guildId;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: _GroupChatBgPainter()),
          Column(
            children: <Widget>[
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: HtmlDesignTokens.narrowSubpageAppBarPadding,
                  child: Row(
                    children: <Widget>[
                      _CircleIconButton(
                        icon: Icons.chevron_left,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Text(
                              groupName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HtmlDesignTokens.textMain,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                _TagChip('#口语'),
                                const SizedBox(width: 4),
                                _TagChip('12 人'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onManage,
                        icon: const Icon(Icons.menu, color: HtmlDesignTokens.textMain, size: 26),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: HtmlDesignTokens.glassBorder),
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: HtmlDesignTokens.accent.withValues(alpha: 0.1),
                      border: Border(
                        bottom: BorderSide(color: HtmlDesignTokens.accent.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              _LiveAvatar(emoji: '🦊', bg: HtmlDesignTokens.primary, overlap: false),
                              _LiveAvatar(emoji: '🐱', bg: const Color(0xFFF59E0B), overlap: true),
                              _LiveAvatar(emoji: '🐼', bg: const Color(0xFF10B981), overlap: true),
                              const SizedBox(width: 8),
                              const Text(
                                '3 人正在连麦中...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: HtmlDesignTokens.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: HtmlDesignTokens.accent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: HtmlDesignTokens.accent.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Join Live 🎧',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: const <Widget>[
                    Center(
                      child: Text(
                        'Today 10:30 AM',
                        style: TextStyle(fontSize: 11, color: HtmlDesignTokens.textSub),
                      ),
                    ),
                    SizedBox(height: 12),
                    _GroupMsgRow(
                      emoji: '🦊',
                      sender: '烤鸭_8921',
                      text: '大家昨天的模考口语成绩出啦！感觉评分有点严格哎。',
                      isMe: false,
                    ),
                    SizedBox(height: 12),
                    _GroupMsgRow(
                      emoji: '🐱',
                      sender: '雅思冲刺者',
                      text: '我也是... 今晚 8 点有人一起练 Part 2 吗？互相点评一下。',
                      isMe: false,
                    ),
                    SizedBox(height: 12),
                    _GroupMsgRow(
                      emoji: '',
                      sender: '',
                      text: '我可以加一个！我刚整理了一份 Part 2 的高频话题素材。',
                      isMe: true,
                    ),
                  ],
                ),
              ),
              _ChatInputBar(
                placeholder: 'Message in group...',
                voiceButtonAccent: HtmlDesignTokens.primary,
                groupStyle: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupChatBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..shader = RadialGradient(
        center: Alignment.topRight,
        radius: 1.2,
        colors: <Color>[
          const Color(0xFF3B82F6).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: HtmlDesignTokens.accent),
      ),
    );
  }
}

class _LiveAvatar extends StatelessWidget {
  const _LiveAvatar({required this.emoji, required this.bg, required this.overlap});

  final String emoji;
  final Color bg;
  final bool overlap;

  @override
  Widget build(BuildContext context) {
    // Flutter 禁止 Container 使用负 margin，重叠用 Transform 实现
    return Transform.translate(
      offset: Offset(overlap ? -8 : 0, 0),
      child: SizedBox(
        width: 24,
        height: 24,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: HtmlDesignTokens.gachaSubBg, width: 2),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 10))),
        ),
      ),
    );
  }
}

class _GroupMsgRow extends StatelessWidget {
  const _GroupMsgRow({
    required this.emoji,
    required this.sender,
    required this.text,
    required this.isMe,
  });

  final String emoji;
  final String sender;
  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: <Color>[Color(0xFF7C3AED), Color(0xFF9333EA)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HtmlDesignTokens.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white)),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF374151),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  sender,
                  style: const TextStyle(fontSize: 11, color: HtmlDesignTokens.textSub),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: HtmlDesignTokens.glassCard,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  border: Border.all(color: HtmlDesignTokens.glassBorder),
                ),
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupManageSheet extends StatelessWidget {
  const _GroupManageSheet({
    required this.name,
    required this.guildId,
    required this.emoji,
  });

  final String name;
  final String guildId;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFA1A103C),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(HtmlDesignTokens.radiusXl)),
                border: Border(top: BorderSide(color: HtmlDesignTokens.glassBorder)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFF3B82F6), Color(0xFF06B6D4)],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Guild ID: $guildId',
                            style: const TextStyle(fontSize: 13, color: HtmlDesignTokens.textSub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 40, color: Color(0x0DFFFFFF)),
                _SheetAction(
                  icon: Icons.groups_outlined,
                  title: '查看星环成员',
                  trailing: const Text('12/50 ›', style: TextStyle(fontSize: 13, color: HtmlDesignTokens.textSub)),
                ),
                _SheetAction(
                  icon: Icons.notifications_off_outlined,
                  title: '消息免打扰',
                  trailing: _MuteToggle(),
                ),
                const _SheetAction(
                  icon: Icons.push_pin_outlined,
                  title: '会话置顶',
                ),
                const SizedBox(height: 12),
                Material(
                  color: const Color(0x0DEF4444),
                  borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                        border: Border.all(color: const Color(0x33EF4444)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text('🚪 ', style: TextStyle(fontSize: 18)),
                          Text(
                            '退出星环 (Leave Group)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            );
          },
        ),
      ],
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HtmlDesignTokens.glassCard,
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
              border: Border.all(color: HtmlDesignTokens.glassBorder),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MuteToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: HtmlDesignTokens.textSub,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
