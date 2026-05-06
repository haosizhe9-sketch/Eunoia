import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/community_social_providers.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';
import 'community_feed_bump.dart';
import 'community_social_repository.dart';
import 'social_avatar.dart';

/// 全屏渐变起点，用于 Scaffold 底色与内容区衔接。
const Color _kDetailScreenTopBlend = Color(0xFF1A103C);

/// 帖子详情顶栏（含状态栏区域）统一实色，与半透明毛玻璃分段造成的「上浅下深」区分。
const Color _kDetailNavBarSolid = Color(0xFF1C172D);

const Color _kPinkGlow = Color(0xFFFF61D2);
const Color _kDangerRed = Color(0xFFEF4444);

/// 动态详情入参（他人帖子 vs 本人帖子由 [isOwnPost] 区分，与 `post.html` 两种视角一致）。
class FeedPostDetailArgs {
  const FeedPostDetailArgs({
    required this.emoji,
    required this.avatarGradient,
    required this.authorDisplayName,
    required this.timeLabel,
    required this.contentSpans,
    required this.likesDisplay,
    required this.commentsDisplay,
    required this.isOwnPost,
    this.tagsLine,
    this.viewsDisplay,
    this.liked = false,
    this.requireLoginToInteract = false,
    this.serverPostId,
    this.authorUserId,
    this.plainTextBody = '',
  });

  final String emoji;
  final Gradient avatarGradient;
  /// 列表与详情顶部展示的作者名（本人动态仍为 「You」）。
  final String authorDisplayName;
  final String timeLabel;
  final List<InlineSpan> contentSpans;
  final String likesDisplay;
  final String commentsDisplay;
  final bool isOwnPost;
  final String? tagsLine;
  /// 仅本人帖子展示浏览量；他人帖子传 null。
  final String? viewsDisplay;
  final bool liked;
  /// 游客态：点赞、评论、收藏、关注等需先登录。
  final bool requireLoginToInteract;
  /// 服务端帖子 id；非空时点赞/评论/删除走后端同步逻辑。
  final String? serverPostId;
  final String? authorUserId;
  final String plainTextBody;

  /// 从服务端 [CommunityFeedPost] 构造详情参数（广场 / 收件箱 / 我的发布共用）。
  static FeedPostDetailArgs fromCommunityFeedPost(
    CommunityFeedPost post,
    String? myUserId, {
    bool requireLoginToInteract = false,
  }) {
    final bool own = myUserId != null && post.authorId == myUserId;
    final String rel = CommunitySocialRepository.formatRelativeTime(post.createdAt);
    return FeedPostDetailArgs(
      emoji: socialEmojiForUserId(post.authorId),
      avatarGradient: socialGradientForUserId(post.authorId),
      authorDisplayName: own ? 'You' : post.authorDisplayName,
      timeLabel: rel,
      contentSpans: <InlineSpan>[TextSpan(text: post.body)],
      likesDisplay: '${post.likeCount}',
      commentsDisplay: '${post.commentCount}',
      isOwnPost: own,
      liked: post.likedByMe,
      requireLoginToInteract: requireLoginToInteract,
      serverPostId: post.id,
      authorUserId: post.authorId,
      plainTextBody: post.body,
    );
  }
}

class FeedPostDetailPage extends ConsumerStatefulWidget {
  const FeedPostDetailPage({super.key, required this.args});

  final FeedPostDetailArgs args;

  @override
  ConsumerState<FeedPostDetailPage> createState() => _FeedPostDetailPageState();
}

class _FeedPostDetailPageState extends ConsumerState<FeedPostDetailPage> {
  final ScrollController _scroll = ScrollController();
  bool _showHeaderTitle = false;
  late bool _liked;
  late String _likesDisplay;
  late String _commentsDisplay;
  List<CommunityCommentRow> _comments = <CommunityCommentRow>[];
  bool _loadingComments = false;

  FeedPostDetailArgs get _a => widget.args;

  bool get _useRemote =>
      _a.serverPostId != null && _a.serverPostId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _liked = _a.liked;
    _likesDisplay = _a.likesDisplay;
    _commentsDisplay = _a.commentsDisplay;
    _scroll.addListener(_onScroll);
    if (_useRemote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_bootstrapRemote());
      });
    }
  }

  Future<void> _bootstrapRemote() async {
    await Future.wait(<Future<void>>[
      _reloadCounts(),
      _reloadComments(),
    ]);
  }

  Future<void> _reloadCounts() async {
    if (!_useRemote) {
      return;
    }
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    final int? lc = await repo.fetchLikeCount(_a.serverPostId!);
    final int? cc = await repo.fetchCommentCount(_a.serverPostId!);
    if (!mounted) {
      return;
    }
    setState(() {
      if (lc != null) {
        _likesDisplay = '$lc';
      }
      if (cc != null) {
        _commentsDisplay = '$cc';
      }
    });
  }

  Future<void> _sendFriendRequestToAuthor() async {
    final String? target = _a.authorUserId?.trim();
    if (target == null || target.isEmpty) {
      return;
    }
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    final String? err = await repo.sendFriendRequest(target);
    if (!mounted) {
      return;
    }
    if (err == null) {
      showAppTopSnackBar(context, const Text('好友请求已发送'));
    } else {
      showAppTopSnackBar(context, Text(err));
    }
  }

  Future<void> _reloadComments() async {
    if (!_useRemote) {
      return;
    }
    setState(() => _loadingComments = true);
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    final List<CommunityCommentRow> list = await repo.fetchComments(_a.serverPostId!);
    if (!mounted) {
      return;
    }
    setState(() {
      _comments = list;
      _loadingComments = false;
    });
  }

  Future<void> _toggleLike() async {
    if (_a.requireLoginToInteract) {
      context.push('/profile/auth');
      return;
    }
    if (!_useRemote) {
      setState(() => _liked = !_liked);
      return;
    }
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    final bool? next = await repo.toggleLike(postId: _a.serverPostId!, currentlyLiked: _liked);
    if (!mounted || next == null) {
      return;
    }
    setState(() => _liked = next);
    await _reloadCounts();
    communityFeedBumpNotifier.value++;
  }

  Future<void> _submitComment(String text) async {
    if (!_useRemote) {
      return;
    }
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    final bool ok = await repo.addComment(postId: _a.serverPostId!, body: text);
    if (!mounted) {
      return;
    }
    if (ok) {
      showAppTopSnackBar(context, const Text('已发送评论'));
      await _reloadComments();
      await _reloadCounts();
      communityFeedBumpNotifier.value++;
    } else {
      showAppTopSnackBar(context, const Text('评论失败'));
    }
  }

  Future<void> _deletePost() async {
    if (!_useRemote) {
      return;
    }
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    final bool ok = await repo.deletePost(_a.serverPostId!);
    if (!mounted) {
      return;
    }
    if (ok) {
      communityFeedBumpNotifier.value++;
      Navigator.of(context).pop();
      showAppTopSnackBar(context, const Text('已删除'));
    } else {
      showAppTopSnackBar(context, const Text('删除失败'));
    }
  }

  void _openCommentSheet() {
    if (_a.requireLoginToInteract) {
      context.push('/profile/auth');
      return;
    }
    if (!_useRemote) {
      return;
    }
    final TextEditingController controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final double inset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFA1A103C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(HtmlDesignTokens.radiusXl)),
              border: Border(top: BorderSide(color: HtmlDesignTokens.glassBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.white, fontFamily: 'system-ui'),
                  cursorColor: HtmlDesignTokens.primaryLight,
                  decoration: const InputDecoration(
                    hintText: '写下评论…',
                    hintStyle: TextStyle(color: Colors.white54, fontFamily: 'system-ui'),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final String t = controller.text.trim();
                    if (t.isEmpty) {
                      return;
                    }
                    Navigator.of(ctx).pop();
                    await _submitComment(t);
                  },
                  child: const Text('发送'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMoreSheet() {
    if (_a.requireLoginToInteract) {
      context.push('/profile/auth');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => _PostActionSheet(
        isOwnPost: _a.isOwnPost,
        showDelete: _useRemote && _a.isOwnPost,
        onDeletePost: _useRemote && _a.isOwnPost ? _deletePost : null,
      ),
    );
  }

  void _guardGuest(VoidCallback whenAllowed) {
    if (_a.requireLoginToInteract) {
      context.push('/profile/auth');
      return;
    }
    whenAllowed();
  }

  void _onScroll() {
    final bool next = _scroll.offset > 50;
    if (next != _showHeaderTitle) {
      setState(() => _showHeaderTitle = next);
    }
  }

  String get _headerTitle {
    if (_a.isOwnPost) {
      return 'Your Post';
    }
    return _a.authorDisplayName;
  }

  String get _commentPlaceholder =>
      _a.isOwnPost ? 'Add to your post...' : 'Add a comment...';

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.viewPaddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _kDetailNavBarSolid,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF0D071C),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kDetailScreenTopBlend,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(gradient: HtmlDesignTokens.backgroundGradient),
            ),
            Positioned(
              top: -40,
              left: -60,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: HtmlDesignTokens.primary.withValues(alpha: 0.2),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: <Widget>[
                _DetailHeader(
                  topInset: topInset,
                  showTitle: _showHeaderTitle,
                  title: _headerTitle,
                  onBack: () => Navigator.of(context).pop(),
                  onMore: _openMoreSheet,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _AuthorRow(
                                args: _a,
                                onFollowTap: _a.isOwnPost
                                    ? null
                                    : () => _guardGuest(() {
                                          unawaited(_sendFriendRequestToAuthor());
                                        }),
                              ),
                              const SizedBox(height: 16),
                              Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.7,
                                    color: Color(0xF2FFFFFF),
                                    fontFamily: 'system-ui',
                                  ),
                                  children: _a.contentSpans,
                                ),
                              ),
                              if (_a.tagsLine != null) ...<Widget>[
                                const SizedBox(height: 20),
                                Text(
                                  _a.tagsLine!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: HtmlDesignTokens.primaryLight,
                                    height: 1.5,
                                    fontFamily: 'system-ui',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              _ImageGridPlaceholder(),
                              const SizedBox(height: 24),
                              _StatsBar(
                                likes: _likesDisplay,
                                comments: _commentsDisplay,
                                views: _a.viewsDisplay,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1, color: Color(0x0DFFFFFF)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: _CommentsSection(
                            isOwnPost: _a.isOwnPost,
                            guestLocked: _a.requireLoginToInteract,
                            useRemote: _useRemote,
                            loading: _loadingComments,
                            comments: _comments,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomInteractionBar(
                placeholder: _commentPlaceholder,
                likesDisplay: _likesDisplay,
                liked: _liked,
                guestLocked: _a.requireLoginToInteract,
                onToggleLike: () {
                  unawaited(_toggleLike());
                },
                onCommentTap: () => _guardGuest(_openCommentSheet),
                onFavoriteTap: () => _guardGuest(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.topInset,
    required this.showTitle,
    required this.title,
    required this.onBack,
    required this.onMore,
  });

  /// 状态栏 / 刘海高度（与 [MediaQuery.viewPadding] 一致）。
  final double topInset;
  final bool showTitle;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    // 整段顶栏（刘海～按钮行）同一实色，避免「浅紫状态区 + 深毛玻璃按钮区」两段不协调。
    // 不再使用 BackdropFilter：半透明叠在渐变上会与上方纯色带形成可见色差。
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 15,
        top: topInset + 12,
      ),
      decoration: BoxDecoration(
        color: _kDetailNavBarSolid,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
          children: <Widget>[
            _CircleHeaderButton(icon: Icons.chevron_left, onPressed: onBack),
            Expanded(
              child: AnimatedOpacity(
                opacity: showTitle ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: AnimatedSlide(
                  offset: showTitle ? Offset.zero : const Offset(0, 0.15),
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HtmlDesignTokens.textMain,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onMore,
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _CircleHeaderButton extends StatelessWidget {
  const _CircleHeaderButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HtmlDesignTokens.glassCard,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: HtmlDesignTokens.glassBorder),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.args, this.onFollowTap});

  final FeedPostDetailArgs args;
  /// 他人帖子：发起好友请求；为 null 时不展示关注按钮。
  final VoidCallback? onFollowTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: args.avatarGradient,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(args.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            args.authorDisplayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: HtmlDesignTokens.textMain,
                              fontFamily: 'system-ui',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (args.isOwnPost) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Author',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontFamily: 'system-ui',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      args.timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: HtmlDesignTokens.textSub,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!args.isOwnPost && onFollowTap != null)
          Material(
            color: HtmlDesignTokens.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onFollowTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: HtmlDesignTokens.accent.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '＋ 加好友',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HtmlDesignTokens.accent,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageGridPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _gridCell(const Color(0xFF2C3E50), const Color(0xFF3498DB), '📝')),
        const SizedBox(width: 10),
        Expanded(child: _gridCell(const Color(0xFF141E30), const Color(0xFF243B55), '📚')),
      ],
    );
  }

  static Widget _gridCell(Color a, Color b, String emoji) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: <Color>[a, b]),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.likes,
    required this.comments,
    this.views,
  });

  final String likes;
  final String comments;
  final String? views;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0x0DFFFFFF)),
          bottom: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      child: Row(
        children: <Widget>[
          _stat('$likes Likes'),
          const SizedBox(width: 20),
          _stat('$comments Comments'),
          if (views != null) ...<Widget>[
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('👁‍🗨 ', style: TextStyle(fontSize: 13)),
                Text(
                  '$views Views',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HtmlDesignTokens.accent,
                    fontFamily: 'system-ui',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _stat(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: HtmlDesignTokens.textSub,
        fontFamily: 'system-ui',
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.isOwnPost,
    this.guestLocked = false,
    this.useRemote = false,
    this.loading = false,
    this.comments = const <CommunityCommentRow>[],
  });

  final bool isOwnPost;
  final bool guestLocked;
  final bool useRemote;
  final bool loading;
  final List<CommunityCommentRow> comments;

  @override
  Widget build(BuildContext context) {
    if (guestLocked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: <Widget>[
              Icon(Icons.lock_outline, size: 36, color: HtmlDesignTokens.textSub.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text(
                '登录后查看评论、点赞与收藏',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: HtmlDesignTokens.textSub,
                  height: 1.4,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (useRemote) {
      if (loading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      if (comments.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            '暂无评论，来做第一条吧',
            style: TextStyle(fontSize: 14, color: HtmlDesignTokens.textSub.withValues(alpha: 0.9)),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: HtmlDesignTokens.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'All Comments',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: HtmlDesignTokens.textMain,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < comments.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 20),
            _CommentThread(
              avatarDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: socialGradientForUserId(comments[i].authorId),
              ),
              avatarEmoji: socialEmojiForUserId(comments[i].authorId),
              name: comments[i].authorDisplayName,
              time: CommunitySocialRepository.formatRelativeTime(comments[i].createdAt),
              text: comments[i].body,
              liked: false,
              likeCount: '0',
              reply: null,
            ),
          ],
        ],
      );
    }
    final String opName = isOwnPost ? 'You' : '烤鸭_8921';
    final String opEmoji = isOwnPost ? '👾' : '🦊';
    final Gradient opGradient = isOwnPost
        ? const LinearGradient(colors: <Color>[HtmlDesignTokens.primary, HtmlDesignTokens.accent])
        : const LinearGradient(colors: <Color>[Color(0xFFFF61D2), Color(0xFFFE9090)]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: HtmlDesignTokens.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'All Comments',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HtmlDesignTokens.textMain,
                fontFamily: 'system-ui',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _CommentThread(
          avatarDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: <Color>[Color(0xFF10B981), Color(0xFF059669)]),
          ),
          avatarEmoji: '🐼',
          name: 'Simon Fan',
          time: '2h ago',
          text: '这个替换词确实很高级，我昨天口语考试刚好用上了！感谢楼主分享！',
          liked: true,
          likeCount: '12',
          reply: _NestedReply(
            emoji: opEmoji,
            gradient: opGradient,
            name: opName,
            showAuthorTag: true,
            time: '1h ago',
            text: '能帮到你就好！祝早日拿 7！',
            likeCount: '2',
          ),
        ),
        const SizedBox(height: 24),
        _CommentThread(
          avatarDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: <Color>[Color(0xFFFBBF24), Color(0xFFF59E0B)]),
          ),
          avatarEmoji: '🐱',
          name: '雅思冲刺者',
          time: '5h ago',
          text: '接好运！下周就要去考了，紧张死我了... 楼主有没有遇到很难追问的考官？',
          liked: false,
          likeCount: '8',
          reply: null,
        ),
      ],
    );
  }
}

class _NestedReply extends StatelessWidget {
  const _NestedReply({
    required this.emoji,
    required this.gradient,
    required this.name,
    required this.showAuthorTag,
    required this.time,
    required this.text,
    required this.likeCount,
  });

  final String emoji;
  final Gradient gradient;
  final String name;
  final bool showAuthorTag;
  final String time;
  final String text;
  final String likeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 2,
            margin: const EdgeInsets.only(right: 18, top: 4),
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: gradient,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xE6FFFFFF),
                                      fontFamily: 'system-ui',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (showAuthorTag) ...<Widget>[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      'Author',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontFamily: 'system-ui',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            time,
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
                        text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xCCFFFFFF),
                          fontFamily: 'system-ui',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Text(
                            '♡ $likeCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HtmlDesignTokens.textSub,
                              fontFamily: 'system-ui',
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HtmlDesignTokens.textSub,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentThread extends StatelessWidget {
  const _CommentThread({
    required this.avatarDecoration,
    required this.avatarEmoji,
    required this.name,
    required this.time,
    required this.text,
    required this.liked,
    required this.likeCount,
    required this.reply,
  });

  final Decoration avatarDecoration;
  final String avatarEmoji;
  final String name;
  final String time;
  final String text;
  final bool liked;
  final String likeCount;
  final Widget? reply;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: avatarDecoration,
          child: Text(avatarEmoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xE6FFFFFF),
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ),
                  Text(
                    time,
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
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xCCFFFFFF),
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Text(
                    liked ? '♥ $likeCount' : '♡ $likeCount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: liked ? _kPinkGlow : HtmlDesignTokens.textSub,
                      fontFamily: 'system-ui',
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Reply',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: HtmlDesignTokens.textSub,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ],
              ),
              if (reply case final Widget w) w,
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomInteractionBar extends StatelessWidget {
  const _BottomInteractionBar({
    required this.placeholder,
    required this.likesDisplay,
    required this.liked,
    required this.onToggleLike,
    required this.onCommentTap,
    required this.onFavoriteTap,
    this.guestLocked = false,
  });

  final String placeholder;
  final String likesDisplay;
  final bool liked;
  final VoidCallback onToggleLike;
  final VoidCallback onCommentTap;
  final VoidCallback onFavoriteTap;
  final bool guestLocked;

  static const String _favoriteDemoCount = '2.1k';

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
          decoration: BoxDecoration(
            color: const Color(0xF20D071C),
            border: Border(top: BorderSide(color: HtmlDesignTokens.glassBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCommentTap,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: HtmlDesignTokens.glassCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: HtmlDesignTokens.glassBorder),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          guestLocked ? '登录后评论…' : placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: HtmlDesignTokens.textSub,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggleLike,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          liked ? '♥' : '♡',
                          style: TextStyle(
                            fontSize: 20,
                            height: 1,
                            color: liked ? _kPinkGlow : HtmlDesignTokens.textMain,
                            shadows: liked
                                ? <Shadow>[
                                    Shadow(
                                      color: _kPinkGlow.withValues(alpha: 0.45),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          likesDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: liked ? _kPinkGlow : HtmlDesignTokens.textSub,
                            fontFamily: 'system-ui',
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onFavoriteTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          '⭐',
                          style: TextStyle(fontSize: 18, height: 1),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _favoriteDemoCount,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: HtmlDesignTokens.textSub,
                            fontFamily: 'system-ui',
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostActionSheet extends StatelessWidget {
  const _PostActionSheet({
    required this.isOwnPost,
    this.showDelete = false,
    this.onDeletePost,
  });

  final bool isOwnPost;
  final bool showDelete;
  final Future<void> Function()? onDeletePost;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.42,
      minChildSize: 0.32,
      maxChildSize: 0.75,
      builder: (BuildContext context, ScrollController c) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFA1A103C),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(HtmlDesignTokens.radiusXl)),
            border: Border(top: BorderSide(color: HtmlDesignTokens.glassBorder)),
          ),
          child: ListView(
            controller: c,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (isOwnPost) ...<Widget>[
                _postSheetBtn(icon: Icons.push_pin_outlined, label: 'Pin to Profile (置顶)'),
                _postSheetBtn(icon: Icons.lock_outline, label: 'Edit Visibility (修改可见性)'),
                _postSheetBtn(
                  icon: Icons.delete_outline,
                  label: 'Delete Post (删除帖子)',
                  danger: true,
                  filledDanger: showDelete && onDeletePost != null,
                  onTap: showDelete && onDeletePost != null
                      ? () async {
                          Navigator.of(context).pop();
                          await onDeletePost!();
                        }
                      : null,
                ),
              ] else ...<Widget>[
                _postSheetBtn(icon: Icons.rocket_launch_outlined, label: 'Share to Group (分享到星环)'),
                _postSheetBtn(icon: Icons.link, label: 'Copy Link (复制链接)'),
                _postSheetBtn(icon: Icons.block, label: 'Block User (屏蔽此人)', danger: true),
                _postSheetBtn(icon: Icons.flag_outlined, label: 'Report Post (举报违规)', danger: true),
              ],
            ],
          ),
        );
      },
    );
  }
}

Widget _postSheetBtn({
  required IconData icon,
  required String label,
  bool danger = false,
  bool filledDanger = false,
  VoidCallback? onTap,
}) {
    final Color border = danger
        ? _kDangerRed.withValues(alpha: filledDanger ? 0.3 : 0.2)
        : HtmlDesignTokens.glassBorder;
    final Color bg = filledDanger ? _kDangerRed.withValues(alpha: 0.05) : HtmlDesignTokens.glassCard;
    final Color fg = danger ? _kDangerRed : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: danger ? _kDangerRed : Colors.white,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
}
