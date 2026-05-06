import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/community/community_page.dart';
import '../../features/practice/anonymous_voice_match_page.dart';
import '../../features/practice/daily_task_module_page.dart';
import '../../features/practice/daily_task_set_pick_page.dart';
import '../../features/practice/daily_tasks_hub_page.dart';
import '../../features/practice/news_brief_mock_page.dart';
import '../../features/practice/practice_page.dart';
import '../../features/practice/word_tower_page.dart';
import '../../features/profile/leaderboard_page.dart';
import '../../features/profile/profile_contract_star_ring_page.dart';
import '../../features/profile/auth_page.dart';
import '../../features/profile/profile_my_posts_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/wrong_notes_archive_page.dart';
import '../../features/shell/main_shell.dart';
import '../../features/store/direct_store_page.dart';
import '../../features/store/gacha_page.dart';
import '../../features/store/store_page.dart';
import 'eunoia_transitions.dart';

abstract final class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/practice',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        redirect: (BuildContext context, GoRouterState state) => '/practice',
      ),
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/practice',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return eunoiaTabPage(key: state.pageKey, child: const PracticePage());
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'word-tower',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(key: state.pageKey, child: const WordTowerPage());
                    },
                  ),
                  GoRoute(
                    path: 'anonymous-voice-match',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(key: state.pageKey, child: const AnonymousVoiceMatchPage());
                    },
                  ),
                  GoRoute(
                    path: 'news-brief-mock',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(key: state.pageKey, child: const NewsBriefMockPage());
                    },
                  ),
                  GoRoute(
                    path: 'daily-tasks',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(key: state.pageKey, child: const DailyTasksHubPage());
                    },
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'pick',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (BuildContext context, GoRouterState state) {
                          final String skill = state.uri.queryParameters['skill'] ?? 'listening';
                          return eunoiaPushPage(
                            key: state.pageKey,
                            child: DailyTaskSetPickPage(skill: skill),
                          );
                        },
                      ),
                      GoRoute(
                        path: ':kind',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (BuildContext context, GoRouterState state) {
                          final String kind = state.pathParameters['kind']!;
                          final int paperSet =
                              int.tryParse(state.uri.queryParameters['set'] ?? '1') ?? 1;
                          return eunoiaPushPage(
                            key: state.pageKey,
                            child: DailyTaskModulePage(kind: kind, paperSet: paperSet),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/community',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return eunoiaTabPage(key: state.pageKey, child: const CommunityPage());
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/store',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return eunoiaTabPage(key: state.pageKey, child: const StorePage());
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'gacha',
                    parentNavigatorKey: AppRouter.rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(key: state.pageKey, child: const GachaPage());
                    },
                  ),
                  GoRoute(
                    path: 'shop',
                    parentNavigatorKey: AppRouter.rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(key: state.pageKey, child: const DirectStorePage());
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return eunoiaTabPage(key: state.pageKey, child: const ProfilePage());
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'auth',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(key: state.pageKey, child: const AuthPage());
                    },
                  ),
                  GoRoute(
                    path: 'leaderboard',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(key: state.pageKey, child: const LeaderboardPage());
                    },
                  ),
                  GoRoute(
                    path: 'my-posts',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(key: state.pageKey, child: const ProfileMyPostsPage());
                    },
                  ),
                  GoRoute(
                    path: 'contract-star-ring',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(
                        key: state.pageKey,
                        child: const ProfileContractStarRingPage(),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'wrong-notes',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (BuildContext context, GoRouterState state) {
                      return eunoiaPushPage(
                        key: state.pageKey,
                        child: const WrongNotesArchivePage(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
