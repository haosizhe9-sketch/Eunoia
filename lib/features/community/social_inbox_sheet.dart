import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_session.dart';
import '../../core/providers/community_social_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_data_service.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/html_design_tokens.dart';
import 'community_social_repository.dart';
import 'feed_post_detail_page.dart';
import 'social_avatar.dart';
import 'social_inbox_unread.dart';

const Color _kInboxPink = Color(0xFFFF61D2);
const Color _kInboxCyan = Color(0xFF2DD4BF);

/// 与 `social.html` 消息抽屉一致的侧滑 Inbox（Flutter 内嵌页使用，非 WebView）。
/// Social 顶栏消息按钮（与 [CommunityPage] 顶栏一致）。
class SocialInboxTriggerButton extends ConsumerWidget {
  const SocialInboxTriggerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: AppStrings.of(context).inboxTooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isLoggedIn(ref)) {
              pushLoginPage(context);
              return;
            }
            showSocialInboxSheet(context);
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: ValueListenableBuilder<bool>(
              valueListenable: socialInboxUnreadNotifier,
              builder: (BuildContext context, bool unread, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: HtmlDesignTokens.textMain,
                      size: 26,
                    ),
                    if (unread)
                      Positioned(
                        top: 4,
                        right: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _kInboxPink,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: _kInboxPink.withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showSocialInboxSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder:
        (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
      return _SocialInboxDialogHost(animation: animation);
    },
    transitionBuilder: (BuildContext context, Animation<double> a1, Animation<double> a2, Widget child) {
      return child;
    },
  );
}

class _SocialInboxDialogHost extends StatelessWidget {
  const _SocialInboxDialogHost({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final Animation<Offset> slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: FadeTransition(
              opacity: animation,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SlideTransition(
              position: slide,
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.85,
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: const Color(0xF20D071C),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: HtmlDesignTokens.glassBorder)),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 40,
                            offset: const Offset(-12, 0),
                          ),
                        ],
                      ),
                      child: const _InboxPanelContent(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxPanelContent extends ConsumerStatefulWidget {
  const _InboxPanelContent();

  @override
  ConsumerState<_InboxPanelContent> createState() => _InboxPanelContentState();
}

class _InboxPanelContentState extends ConsumerState<_InboxPanelContent> {
  int _tab = 0;
  bool _loading = true;
  List<SocialInboxNotification> _notifications = <SocialInboxNotification>[];
  List<IncomingFriendRequest> _friendRequests = <IncomingFriendRequest>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    final AppDataService svc = ref.read(appDataServiceProvider);
    if (!svc.isBackendAvailable || svc.currentUser == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    await repo.ensureDemoSocialScenario();
    final List<SocialInboxNotification> n = await repo.fetchNotifications();
    final List<IncomingFriendRequest> fr = await repo.listIncomingFriendRequests();
    final int unread = await repo.countUnreadNotifications();
    if (!mounted) {
      return;
    }
    setState(() {
      _notifications = n;
      _friendRequests = fr;
      _loading = false;
    });
    socialInboxUnreadNotifier.value = unread > 0 || fr.isNotEmpty;
    unawaited(refreshSocialInboxUnreadBadge(ref));
  }

  Future<void> _markAllRead() async {
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    await repo.markAllNotificationsRead();
    if (!mounted) {
      return;
    }
    await _load();
  }

  List<SocialInboxNotification> get _interactItems => _notifications
      .where((SocialInboxNotification n) => n.kind == 'comment' || n.kind == 'like')
      .toList();

  bool get _interactUnread => _interactItems.any((SocialInboxNotification n) => !n.read);
  bool get _friendsUnread => _friendRequests.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final AppStrings str = AppStrings.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.deferToChild,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 16, 12),
            child: Row(
              children: <Widget>[
                const Text(
                  'Inbox',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: HtmlDesignTokens.textMain,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: str.inboxMarkAllRead,
                  onPressed: () {
                    unawaited(_markAllRead());
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: _kInboxCyan.withValues(alpha: 0.1),
                    foregroundColor: _kInboxCyan,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _SegmentTabs(
              labels: <String>[str.inboxTabInteract, str.inboxTabFriends, str.inboxTabGroups],
              index: _tab,
              onChanged: (int i) => setState(() => _tab = i),
              interactBadge: _interactUnread,
              friendsBadge: _friendsUnread,
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: <Widget>[
                _InteractList(
                  notifications: _interactItems,
                  onChanged: () {
                    unawaited(_load());
                  },
                ),
                _FriendsInboxList(
                  requests: _friendRequests,
                  onResponded: () {
                    unawaited(_load());
                  },
                ),
                _GroupsEmptyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.labels,
    required this.index,
    required this.onChanged,
    required this.interactBadge,
    required this.friendsBadge,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool interactBadge;
  final bool friendsBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double w = (c.maxWidth - 8) / 3;
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: 4 + index * w,
                top: 4,
                width: w,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HtmlDesignTokens.glassCard,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onChanged(i),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: <Widget>[
                                Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: index == i ? HtmlDesignTokens.textMain : HtmlDesignTokens.textSub,
                                  ),
                                ),
                                if (i == 0 && interactBadge)
                                  Positioned(
                                    top: 2,
                                    right: 10,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(color: Color(0x99EF4444), blurRadius: 6),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (i == 1 && friendsBadge)
                                  Positioned(
                                    top: 2,
                                    right: 10,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(color: Color(0x99EF4444), blurRadius: 6),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
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

class _InteractList extends ConsumerWidget {
  const _InteractList({required this.notifications, required this.onChanged});

  final List<SocialInboxNotification> notifications;
  final VoidCallback onChanged;

  Widget _notificationTile(BuildContext context, WidgetRef ref, SocialInboxNotification n) {
    final Widget inner = _MsgCard(
      unreadStripe: !n.read,
      avatar: socialEmojiForUserId(n.actorUserId),
      avatarGradient: socialGradientForUserId(n.actorUserId),
      cornerIcon: n.kind == 'comment' ? Icons.chat_bubble_outline_rounded : Icons.favorite_rounded,
      cornerBg: n.kind == 'comment' ? _kInboxCyan : _kInboxPink,
      title: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          children: <InlineSpan>[
            TextSpan(text: n.actorDisplayName, style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(
              text: n.kind == 'comment' ? ' commented on your post' : ' liked your post',
            ),
          ],
        ),
      ),
      quote: n.snippet,
      time: CommunitySocialRepository.formatRelativeTime(n.createdAt),
    );
    final String? pid = n.postId;
    if (pid == null || pid.isEmpty) {
      return inner;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        onTap: () => unawaited(_openPostFromNotification(context, ref, n)),
        child: inner,
      ),
    );
  }

  Future<void> _openPostFromNotification(
    BuildContext context,
    WidgetRef ref,
    SocialInboxNotification n,
  ) async {
    final String? postId = n.postId;
    if (postId == null || postId.isEmpty) {
      return;
    }
    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
    await repo.markNotificationRead(n.id);
    onChanged();
    final CommunityFeedPost? post = await repo.fetchPostById(postId);
    if (!context.mounted) {
      return;
    }
    if (post == null) {
      return;
    }
    final String? myUid = ref.read(appDataServiceProvider).currentUser?.id;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => FeedPostDetailPage(
          args: FeedPostDetailArgs.fromCommunityFeedPost(post, myUid),
        ),
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (notifications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: <Widget>[
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: <Widget>[
                Text('🔔', style: TextStyle(fontSize: 40, color: Colors.white.withValues(alpha: 0.35))),
                const SizedBox(height: 12),
                Text(
                  AppStrings.of(context).inboxEmptyInteract,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: HtmlDesignTokens.textSub),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: <Widget>[
        for (var i = 0; i < notifications.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          _notificationTile(context, ref, notifications[i]),
        ],
      ],
    );
  }
}

class _FriendsInboxList extends ConsumerWidget {
  const _FriendsInboxList({required this.requests, required this.onResponded});

  final List<IncomingFriendRequest> requests;
  final VoidCallback onResponded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('✨', style: TextStyle(fontSize: 40, color: Colors.white.withValues(alpha: 0.35))),
            const SizedBox(height: 12),
            Text(
              AppStrings.of(context).inboxEmptyFriends,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: HtmlDesignTokens.textSub),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: requests.length,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int i) {
        return _IncomingFriendRequestCard(
          request: requests[i],
          onDone: onResponded,
        );
      },
    );
  }
}

class _IncomingFriendRequestCard extends ConsumerWidget {
  const _IncomingFriendRequestCard({required this.request, required this.onDone});

  final IncomingFriendRequest request;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String timeLabel = CommunitySocialRepository.formatRelativeTime(request.createdAt);
    return _MsgCard(
      unreadStripe: true,
      avatar: socialEmojiForUserId(request.requesterId),
      avatarGradient: socialGradientForUserId(request.requesterId),
      title: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white, fontWeight: FontWeight.w500),
          children: <InlineSpan>[
            TextSpan(text: request.requesterDisplayName, style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' wants to be friends'),
          ],
        ),
      ),
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
                    await repo.respondFriendRequest(requestId: request.id, accept: true);
                    onDone();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: HtmlDesignTokens.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
                    await repo.respondFriendRequest(requestId: request.id, accept: false);
                    onDone();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: HtmlDesignTokens.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Ignore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            timeLabel,
            style: const TextStyle(fontSize: 11, color: HtmlDesignTokens.textSub),
          ),
        ],
      ),
    );
  }
}

class _GroupsEmptyTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: <Widget>[
        Text(
          AppStrings.of(context).inboxGroupsPlaceholder,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 18),
        _MsgCard(
          unreadStripe: true,
          avatar: '🌙',
          avatarGradient: const LinearGradient(
            colors: <Color>[Color(0xFF7C3AED), Color(0xFFD946EF)],
          ),
          title: const Text(
            '夜猫刷题组',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          quote: '雅思日记本：今晚 21:30 口语圆桌谁来？',
          time: '12m',
        ),
        const SizedBox(height: 14),
        _MsgCard(
          unreadStripe: false,
          avatar: '🎯',
          avatarGradient: const LinearGradient(
            colors: <Color>[Color(0xFF3B82F6), Color(0xFF06B6D4)],
          ),
          title: const Text(
            '写作急救小队',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          quote: '口语搭子_阿乐：批改范例已发群文件',
          time: '1h',
        ),
      ],
    );
  }
}

class _MsgCard extends StatelessWidget {
  const _MsgCard({
    required this.unreadStripe,
    required this.avatar,
    required this.avatarGradient,
    required this.title,
    this.cornerIcon,
    this.cornerBg,
    this.quote,
    this.time,
    this.extra,
  });

  final bool unreadStripe;
  final String avatar;
  final Gradient avatarGradient;
  final Widget title;
  final IconData? cornerIcon;
  final Color? cornerBg;
  final String? quote;
  final String? time;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        child: Stack(
          children: <Widget>[
            if (unreadStripe)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kInboxCyan,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: _kInboxCyan.withValues(alpha: 0.45), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: avatarGradient,
                          boxShadow: <BoxShadow>[
                            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Text(avatar, style: const TextStyle(fontSize: 18)),
                      ),
                      if (cornerIcon != null && cornerBg != null)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cornerBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0D071C), width: 2),
                            ),
                            child: Icon(cornerIcon, size: 10, color: cornerBg == _kInboxCyan ? Colors.black87 : Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        title,
                        if (quote != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(left: BorderSide(color: HtmlDesignTokens.glassBorder, width: 2)),
                            ),
                            child: Text(
                              quote!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                            ),
                          ),
                        ],
                        if (time != null && extra == null) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(time!, style: const TextStyle(fontSize: 11, color: HtmlDesignTokens.textSub)),
                        ],
                        ?extra,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
