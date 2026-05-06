import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/providers/community_social_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_data_service.dart';
import '../../core/theme/html_design_tokens.dart';
import '../community/community_feed_bump.dart';
import '../community/community_page.dart';
import '../community/community_social_repository.dart';
import '../community/feed_post_detail_page.dart';

class ProfileMyPostsPage extends ConsumerStatefulWidget {
  const ProfileMyPostsPage({super.key});

  @override
  ConsumerState<ProfileMyPostsPage> createState() => _ProfileMyPostsPageState();
}

class _ProfileMyPostsPageState extends ConsumerState<ProfileMyPostsPage> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: communityFeedBumpNotifier,
      builder: (BuildContext context, int bump, Widget? _) {
        final AppDataService svc = ref.read(appDataServiceProvider);
        final bool remote =
            svc.isBackendAvailable && svc.currentUser != null;

        if (!remote) {
          final List<CommunityOwnPostLine> own = listCommunityOwnPostsForProfile();
          return _MyPostsScaffold(
            body: own.isEmpty
                ? const _MyPostsEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    physics: const BouncingScrollPhysics(),
                    itemCount: own.length,
                    separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 16),
                    itemBuilder: (BuildContext context, int i) {
                      final CommunityOwnPostLine line = own[i];
                      return _MyPostCard(
                        item: _MyPostItem(
                          timeLabel: line.timeLabel,
                          visibilityLabel: AppStrings.of(context).visibilityPublic,
                          visibilityAccent: HtmlDesignTokens.accent,
                          content: line.preview,
                          likes: line.likes,
                          comments: line.comments,
                        ),
                      );
                    },
                  ),
          );
        }

        final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
        return FutureBuilder<List<CommunityFeedPost>>(
          key: ValueKey<int>(bump),
          future: repo.fetchMyPosts(),
          builder: (BuildContext context, AsyncSnapshot<List<CommunityFeedPost>> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _MyPostsScaffold(
                body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final List<CommunityFeedPost> rows = snap.data ?? <CommunityFeedPost>[];
            if (rows.isEmpty) {
              return _MyPostsScaffold(body: const _MyPostsEmpty());
            }
            return _MyPostsScaffold(
              body: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                physics: const BouncingScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 16),
                itemBuilder: (BuildContext context, int i) {
                  final CommunityFeedPost p = rows[i];
                  final String rel = CommunitySocialRepository.formatRelativeTime(p.createdAt);
                  final String? myUid = svc.currentUser?.id;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext ctx) => FeedPostDetailPage(
                              args: FeedPostDetailArgs.fromCommunityFeedPost(p, myUid),
                            ),
                          ),
                        );
                      },
                      child: _MyPostCard(
                        item: _MyPostItem(
                          timeLabel: rel,
                          visibilityLabel: AppStrings.of(context).visibilityPublic,
                          visibilityAccent: HtmlDesignTokens.accent,
                          content: p.body,
                          likes: p.likeCount,
                          comments: p.commentCount,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _MyPostsScaffold extends StatelessWidget {
  const _MyPostsScaffold({required this.body});

  final Widget body;

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
                        s.myPostsTitle,
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Material(
                color: HtmlDesignTokens.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () => context.go('/community'),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: HtmlDesignTokens.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('＋ ', style: TextStyle(color: HtmlDesignTokens.accent, fontWeight: FontWeight.w700)),
                        Text(
                          s.myPostsPublishNew,
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
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _MyPostsEmpty extends StatelessWidget {
  const _MyPostsEmpty();

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 120),
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        Text('📝', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, color: Colors.white.withValues(alpha: 0.35))),
        const SizedBox(height: 12),
        Text(
          s.myPostsEmptyTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: HtmlDesignTokens.textMain,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.myPostsEmptySubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
            fontFamily: 'system-ui',
          ),
        ),
      ],
    );
  }
}

class _MyPostItem {
  const _MyPostItem({
    required this.timeLabel,
    required this.visibilityLabel,
    required this.visibilityAccent,
    required this.content,
    required this.likes,
    required this.comments,
  });

  final String timeLabel;
  final String visibilityLabel;
  final Color visibilityAccent;
  final String content;
  final int likes;
  final int comments;
}

class _MyPostCard extends StatelessWidget {
  const _MyPostCard({required this.item});

  final _MyPostItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.glassCard,
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.timeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: HtmlDesignTokens.textSub,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.visibilityAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.visibilityLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: item.visibilityAccent,
                          fontFamily: 'system-ui',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz, color: HtmlDesignTokens.textSub, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xE6FFFFFF),
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0x14FFFFFF)),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                '♡ ${item.likes}',
                style: const TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
              ),
              const SizedBox(width: 16),
              Text(
                '💬 ${item.comments}',
                style: const TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
              ),
            ],
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
