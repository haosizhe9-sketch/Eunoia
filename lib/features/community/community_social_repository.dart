import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/community_demo_ids.dart';
import '../../core/services/app_data_service.dart';

/// 广场帖子（服务端映射）。
class CommunityFeedPost {
  const CommunityFeedPost({
    required this.id,
    required this.authorId,
    required this.authorDisplayName,
    required this.body,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorDisplayName;
  final String body;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime createdAt;
}

/// 评论行。
class CommunityCommentRow {
  const CommunityCommentRow({
    required this.id,
    required this.authorId,
    required this.authorDisplayName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorDisplayName;
  final String body;
  final DateTime createdAt;
}

/// 公开资料摘要（搜索好友）。
class PublicProfileBrief {
  const PublicProfileBrief({
    required this.userId,
    required this.eunoiaId,
    required this.displayName,
    this.wordTowerMaxFloor,
  });

  final String userId;
  final String eunoiaId;
  final String displayName;
  final int? wordTowerMaxFloor;
}

/// 好友列表一行。
class FriendListEntry {
  const FriendListEntry({
    required this.userId,
    required this.displayName,
    required this.eunoiaId,
  });

  final String userId;
  final String displayName;
  final String eunoiaId;
}

/// 待处理好友请求。
class IncomingFriendRequest {
  const IncomingFriendRequest({
    required this.id,
    required this.requesterId,
    required this.requesterDisplayName,
    required this.createdAt,
  });

  final String id;
  final String requesterId;
  final String requesterDisplayName;
  final DateTime createdAt;
}

/// 收件箱通知。
class SocialInboxNotification {
  const SocialInboxNotification({
    required this.id,
    required this.kind,
    required this.actorUserId,
    required this.actorDisplayName,
    this.snippet,
    this.postId,
    required this.createdAt,
    required this.read,
  });

  final String id;
  /// `comment` | `like` | `friend_request`
  final String kind;
  final String actorUserId;
  final String actorDisplayName;
  final String? snippet;
  /// 点赞 / 评论关联的帖子；`friend_request` 时多为 null。
  final String? postId;
  final DateTime createdAt;
  final bool read;
}

/// 社交数据访问（依赖 [AppDataService] 已初始化且用户已登录）。
class CommunitySocialRepository {
  CommunitySocialRepository(this._svc);

  final AppDataService _svc;
  static const String _kStoreKey = 'eunoia_community_json_store_v1';
  static const String _kDemoSeedFlagPrefix = 'eunoia_social_demo_v1_';

  static bool isAuthUserUuid(String raw) {
    final String t = raw.trim();
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(t);
  }

  SharedPreferences? _prefs;
  bool _loaded = false;
  List<Map<String, dynamic>> _posts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _likes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _friendRequests = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];

  static String formatRelativeTime(DateTime t) {
    final DateTime now = DateTime.now();
    final Duration d = now.difference(t);
    if (d.inSeconds < 55) {
      return 'Just now';
    }
    if (d.inMinutes < 60) {
      return '${d.inMinutes}m ago';
    }
    if (d.inHours < 24) {
      return '${d.inHours}h ago';
    }
    if (d.inDays < 7) {
      return '${d.inDays}d ago';
    }
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  Future<List<CommunityFeedPost>> fetchFeed({int limit = 50}) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return <CommunityFeedPost>[];
    }
    final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(_posts)
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
          ('${b['created_at']}').compareTo('${a['created_at']}'));
    return rows.take(limit).map((Map<String, dynamic> m) => _mapPost(m, uid)).toList();
  }

  Future<List<CommunityFeedPost>> fetchMyPosts({int limit = 50}) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return <CommunityFeedPost>[];
    }
    final List<Map<String, dynamic>> rows = _posts
        .where((Map<String, dynamic> x) => x['author_id'] == uid)
        .toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
          ('${b['created_at']}').compareTo('${a['created_at']}'));
    return rows.take(limit).map((Map<String, dynamic> m) => _mapPost(m, uid)).toList();
  }

  Future<String?> createPost(String body) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return null;
    }
    final String t = body.trim();
    if (t.isEmpty) {
      return null;
    }
    final String id = _randomId();
    _posts.add(<String, dynamic>{
      'id': id,
      'author_id': uid,
      'body': t,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _save();
    return id;
  }

  Future<bool> deletePost(String postId) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return false;
    }
    _posts.removeWhere((Map<String, dynamic> x) => x['id'] == postId && x['author_id'] == uid);
    _likes.removeWhere((Map<String, dynamic> x) => x['post_id'] == postId);
    _comments.removeWhere((Map<String, dynamic> x) => x['post_id'] == postId);
    await _save();
    return true;
  }

  /// 返回切换后的点赞状态（true = 已点赞）。
  Future<bool?> toggleLike({required String postId, required bool currentlyLiked}) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return null;
    }
    if (currentlyLiked) {
      _likes.removeWhere((Map<String, dynamic> x) => x['post_id'] == postId && x['user_id'] == uid);
      await _save();
      return false;
    }
    _likes.add(<String, dynamic>{'post_id': postId, 'user_id': uid});
    await _save();
    return true;
  }

  Future<List<CommunityCommentRow>> fetchComments(String postId) async {
    await _ensureLoaded();
    if (_svc.currentUser == null) {
      return <CommunityCommentRow>[];
    }
    final List<Map<String, dynamic>> rows = _comments
        .where((Map<String, dynamic> x) => x['post_id'] == postId)
        .toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
          ('${a['created_at']}').compareTo('${b['created_at']}'));
    return rows.map((Map<String, dynamic> m) {
      final String authorId = '${m['author_id']}';
      final String name = _svc.displayNameByUserId(authorId) ?? '用户';
      return CommunityCommentRow(
        id: '${m['id']}',
        authorId: authorId,
        authorDisplayName: name,
        body: '${m['body'] ?? ''}'.trim(),
        createdAt: _parseTime(m['created_at']) ?? DateTime.now(),
      );
    }).toList();
  }

  /// 拉取单条帖子（详情页、通知跳转）；无权限或不存在时返回 null。
  Future<CommunityFeedPost?> fetchPostById(String postId) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return null;
    }
    final String pid = postId.trim();
    if (pid.isEmpty) {
      return null;
    }
    final Map<String, dynamic>? row = _posts.cast<Map<String, dynamic>?>().firstWhere(
      (Map<String, dynamic>? x) => x != null && x['id'] == pid,
      orElse: () => null,
    );
    if (row == null) {
      return null;
    }
    return _mapPost(row, uid);
  }

  Future<bool> addComment({required String postId, required String body}) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return false;
    }
    final String t = body.trim();
    if (t.isEmpty) {
      return false;
    }
    _comments.add(<String, dynamic>{
      'id': _randomId(),
      'post_id': postId,
      'author_id': uid,
      'body': t,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _save();
    return true;
  }

  Future<int?> fetchLikeCount(String postId) async {
    await _ensureLoaded();
    return _likes.where((Map<String, dynamic> x) => x['post_id'] == postId).length;
  }

  Future<int?> fetchCommentCount(String postId) async {
    await _ensureLoaded();
    return _comments.where((Map<String, dynamic> x) => x['post_id'] == postId).length;
  }

  Future<PublicProfileBrief?> findProfileByEunoiaId(String rawId) async {
    await _ensureLoaded();
    if (_svc.currentUser == null) {
      return null;
    }
    final String q = rawId.trim().toLowerCase();
    if (q.isEmpty) {
      return null;
    }
    final String? userId = _svc.findUserIdByEunoiaId(q);
    if (userId == null || userId == _svc.currentUser?.id) {
      return null;
    }
    final ProfilePublicFields? p = _svc.profileByUserId(userId);
    return PublicProfileBrief(
      userId: userId,
      eunoiaId: q,
      displayName: (p?.displayName?.trim().isNotEmpty ?? false) ? p!.displayName!.trim() : '用户',
      wordTowerMaxFloor: p?.wordTowerMaxFloor,
    );
  }

  Future<String?> currentUserEunoiaId() async {
    await _ensureLoaded();
    return _svc.currentUserEunoiaId();
  }

  /// 发送好友请求；失败时返回错误文案。
  Future<String?> sendFriendRequest(String targetUserId) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return '未登录';
    }
    if (targetUserId == uid) {
      return '不能添加自己';
    }
    final bool dup = _friendRequests.any((Map<String, dynamic> x) {
      final String a = '${x['requester_id']}';
      final String b = '${x['addressee_id']}';
      return (a == uid && b == targetUserId) || (a == targetUserId && b == uid);
    });
    if (dup) {
      return '已发送过请求或已是好友';
    }
    _friendRequests.add(<String, dynamic>{
      'id': _randomId(),
      'requester_id': uid,
      'addressee_id': targetUserId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    await _save();
    return null;
  }

  Future<List<FriendListEntry>> listFriends() async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return <FriendListEntry>[];
    }
    final List<String> others = <String>[];
    for (final Map<String, dynamic> row in _friendRequests) {
      if (row['status'] != 'accepted') continue;
      final String a = '${row['requester_id']}';
      final String b = '${row['addressee_id']}';
      if (a == uid) others.add(b);
      if (b == uid) others.add(a);
    }
    return others.map((String id) {
      final String name = _svc.displayNameByUserId(id) ?? '用户';
      final String eid = _svc.eunoiaIdForUser(id) ?? '';
      return FriendListEntry(userId: id, displayName: name, eunoiaId: eid);
    }).toList();
  }

  Future<List<IncomingFriendRequest>> listIncomingFriendRequests() async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return <IncomingFriendRequest>[];
    }
    final List<Map<String, dynamic>> rows = _friendRequests
        .where((Map<String, dynamic> x) => x['addressee_id'] == uid && x['status'] == 'pending')
        .toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
          ('${b['created_at']}').compareTo('${a['created_at']}'));
    return rows.map((Map<String, dynamic> m) {
      final String requesterId = '${m['requester_id']}';
      return IncomingFriendRequest(
        id: '${m['id']}',
        requesterId: requesterId,
        requesterDisplayName: _svc.displayNameByUserId(requesterId) ?? '用户',
        createdAt: _parseTime(m['created_at']) ?? DateTime.now(),
      );
    }).toList();
  }

  Future<bool> respondFriendRequest({required String requestId, required bool accept}) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return false;
    }
    final int idx = _friendRequests.indexWhere(
      (Map<String, dynamic> x) => x['id'] == requestId && x['addressee_id'] == uid,
    );
    if (idx < 0) return false;
    _friendRequests[idx] = <String, dynamic>{
      ..._friendRequests[idx],
      'status': accept ? 'accepted' : 'declined',
    };
    await _save();
    return true;
  }

  /// 注入一次性本地演示数据（广场 / 收件箱 / 好友请求），便于模拟真实使用场景。
  Future<void> ensureDemoSocialScenario() async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return;
    }
    final String flagKey = '$_kDemoSeedFlagPrefix$uid';
    if (_prefs?.getBool(flagKey) ?? false) {
      return;
    }

    await _svc.ensureCommunityNpcProfiles();

    final String t48 =
        DateTime.now().toUtc().subtract(const Duration(hours: 48)).toIso8601String();
    final String t30 =
        DateTime.now().toUtc().subtract(const Duration(hours: 30)).toIso8601String();
    final String t5 =
        DateTime.now().toUtc().subtract(const Duration(hours: 5)).toIso8601String();
    final String t2 =
        DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
    final String t1 =
        DateTime.now().toUtc().subtract(const Duration(minutes: 40)).toIso8601String();

    _posts.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'demo-feed-mia-1',
        'author_id': CommunityDemoIds.npcMia,
        'body':
            '今日 Speaking Part 2 抽到「描述一次团队合作」，直接用 STAR 展开，流利度明显上去啦～你们这周抽到什么题？',
        'created_at': t48,
      },
      <String, dynamic>{
        'id': 'demo-feed-alex-1',
        'author_id': CommunityDemoIds.npcAlex,
        'body':
            '刚跟外教 mock 了半小时雅思口语，Part 3 被连环追问到出汗……有没有兄弟愿意互换题库一起复盘？',
        'created_at': t30,
      },
      <String, dynamic>{
        'id': 'demo-feed-diary-1',
        'author_id': CommunityDemoIds.npcDiary,
        'body':
            '写作求批改：环境类大作文论点会不会太空？附了我的提纲，求路过的大佬顺手指点两句。',
        'created_at': t5,
      },
      <String, dynamic>{
        'id': 'demo-feed-my-1',
        'author_id': uid,
        'body':
            '刚肝完一篇大作文，论点写到手软……求路过的烤鸭点个赞鞭策我继续打卡 #雅思写作',
        'created_at': t2,
      },
    ]);

    _likes.addAll(<Map<String, dynamic>>[
      <String, dynamic>{'post_id': 'demo-feed-mia-1', 'user_id': uid},
      <String, dynamic>{
        'post_id': 'demo-feed-my-1',
        'user_id': CommunityDemoIds.npcAlex,
      },
      <String, dynamic>{'post_id': 'demo-feed-diary-1', 'user_id': uid},
    ]);

    _comments.add(<String, dynamic>{
      'id': 'demo-comment-mia-on-mine',
      'post_id': 'demo-feed-my-1',
      'author_id': CommunityDemoIds.npcMia,
      'body': '观点很清楚！结论段可以再收紧一点～要不要一起刷这周题库？',
      'created_at': t1,
    });

    _friendRequests.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'demo-fr-mia-accepted',
        'requester_id': CommunityDemoIds.npcMia,
        'addressee_id': uid,
        'status': 'accepted',
        'created_at':
            DateTime.now().toUtc().subtract(const Duration(days: 4)).toIso8601String(),
      },
      <String, dynamic>{
        'id': 'demo-fr-diary-pending',
        'requester_id': CommunityDemoIds.npcDiary,
        'addressee_id': uid,
        'status': 'pending',
        'created_at':
            DateTime.now().toUtc().subtract(const Duration(hours: 7)).toIso8601String(),
      },
    ]);

    _notifications.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'demo-notif-like',
        'recipient_id': uid,
        'actor_id': CommunityDemoIds.npcAlex,
        'kind': 'like',
        'post_id': 'demo-feed-my-1',
        'snippet': null,
        'created_at':
            DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String(),
        'read_at': null,
      },
      <String, dynamic>{
        'id': 'demo-notif-comment',
        'recipient_id': uid,
        'actor_id': CommunityDemoIds.npcMia,
        'kind': 'comment',
        'post_id': 'demo-feed-my-1',
        'snippet': '观点很清楚！结论段可以再收紧一点～',
        'created_at':
            DateTime.now().toUtc().subtract(const Duration(minutes: 36)).toIso8601String(),
        'read_at':
            DateTime.now().toUtc().subtract(const Duration(minutes: 12)).toIso8601String(),
      },
    ]);

    await _save();
    await _prefs?.setBool(flagKey, true);
  }

  Future<List<SocialInboxNotification>> fetchNotifications({int limit = 40}) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) return <SocialInboxNotification>[];
    final List<Map<String, dynamic>> rows = _notifications
        .where((Map<String, dynamic> x) => x['recipient_id'] == uid)
        .toList()
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
          ('${b['created_at']}').compareTo('${a['created_at']}'));
    return rows.take(limit).map((Map<String, dynamic> m) {
      final String actorId = '${m['actor_id']}';
      return SocialInboxNotification(
        id: '${m['id']}',
        kind: '${m['kind']}',
        actorUserId: actorId,
        actorDisplayName: _svc.displayNameByUserId(actorId) ?? '用户',
        snippet: m['snippet'] is String ? m['snippet'] as String : null,
        postId: m['post_id'] as String?,
        createdAt: _parseTime(m['created_at']) ?? DateTime.now(),
        read: m['read_at'] != null,
      );
    }).toList();
  }

  Future<int> countUnreadNotifications() async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) return 0;
    return _notifications
        .where((Map<String, dynamic> x) => x['recipient_id'] == uid && x['read_at'] == null)
        .length;
  }

  Future<void> markAllNotificationsRead() async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) return;
    final String readAt = DateTime.now().toUtc().toIso8601String();
    for (var i = 0; i < _notifications.length; i++) {
      final Map<String, dynamic> x = _notifications[i];
      if (x['recipient_id'] == uid && x['read_at'] == null) {
        _notifications[i] = <String, dynamic>{...x, 'read_at': readAt};
      }
    }
    await _save();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _ensureLoaded();
    final String? uid = _svc.currentUser?.id;
    if (uid == null) {
      return;
    }
    final int idx = _notifications.indexWhere(
      (Map<String, dynamic> x) => x['id'] == notificationId && x['recipient_id'] == uid,
    );
    if (idx < 0) return;
    _notifications[idx] = <String, dynamic>{
      ..._notifications[idx],
      'read_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _save();
  }

  CommunityFeedPost _mapPost(Map<String, dynamic> m, String myUid) {
    final String id = '${m['id']}';
    final String authorId = '${m['author_id']}';
    final String name = _svc.displayNameByUserId(authorId) ?? '用户';
    return CommunityFeedPost(
      id: id,
      authorId: authorId,
      authorDisplayName: name,
      body: '${m['body'] ?? ''}'.trim(),
      likeCount: _likes.where((Map<String, dynamic> x) => x['post_id'] == id).length,
      commentCount: _comments.where((Map<String, dynamic> x) => x['post_id'] == id).length,
      likedByMe: _likes.any((Map<String, dynamic> x) => x['post_id'] == id && x['user_id'] == myUid),
      createdAt: _parseTime(m['created_at']) ?? DateTime.now(),
    );
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    final String raw = _prefs?.getString(_kStoreKey) ?? '';
    if (raw.isNotEmpty) {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        final Map<String, dynamic> root =
            Map<String, dynamic>.from(decoded);
        _posts = _decodeList(root['posts']);
        _likes = _decodeList(root['likes']);
        _comments = _decodeList(root['comments']);
        _friendRequests = _decodeList(root['friend_requests']);
        _notifications = _decodeList(root['notifications']);
      }
    }
    _loaded = true;
  }

  List<Map<String, dynamic>> _decodeList(Object? v) {
    return ((v as List<dynamic>?) ?? <dynamic>[])
        .whereType<Map>()
        .map((Map x) => Map<String, dynamic>.from(x))
        .toList();
  }

  Future<void> _save() async {
    final Map<String, dynamic> root = <String, dynamic>{
      'posts': _posts,
      'likes': _likes,
      'comments': _comments,
      'friend_requests': _friendRequests,
      'notifications': _notifications,
    };
    await _prefs?.setString(_kStoreKey, jsonEncode(root));
  }

  static DateTime? _parseTime(Object? v) {
    if (v is String) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  static String _randomId() {
    final Random r = Random();
    return List<String>.generate(3, (_) => r.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')).join('-');
  }
}
