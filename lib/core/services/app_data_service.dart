import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/community_demo_ids.dart';
import '../demo_e_points.dart';

const int _kDailyPracticeRewardListening = 50;
const int _kDailyPracticeRewardReading = 50;
const int _kDailyPracticeRewardWriting = 50;
const int _kDailyPracticeRewardWordTower = 50;

String? _normalizePgDateColumn(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final String s = value.trim();
    if (s.length >= 10) {
      return s.substring(0, 10);
    }
    return s.isEmpty ? null : s;
  }
  return null;
}

/// `profiles` 表中与展示相关的列（不含敏感字段）。
class ProfilePublicFields {
  const ProfilePublicFields({
    this.displayName,
    this.bio,
    this.wordTowerMaxFloor,
    this.checkInTotal,
    this.lastCheckInDate,
    this.ePoints,
    this.checkInStreak,
  });

  final String? displayName;
  final String? bio;
  final int? wordTowerMaxFloor;

  /// 累计签到天数（每个日历日最多 +1）。
  final int? checkInTotal;

  /// `YYYY-MM-DD`，与 `daily_check_in` 传入的日期一致时视为今日已签。
  final String? lastCheckInDate;

  /// 当前 E 点余额（商城 / 补给舱）。
  final int? ePoints;

  /// 当前连续签到天数（中断后从 1 重计）。
  final int? checkInStreak;
}

/// 今日练习快照（用于练习页 / 「我的」展示；按日历日重置）。
class DailyPracticeTodayView {
  const DailyPracticeTodayView({
    required this.dayIso,
    this.listeningBand,
    this.readingBand,
    this.writingBand,
    this.listeningRewarded = false,
    this.readingRewarded = false,
    this.writingRewarded = false,
    this.wordTowerRewarded = false,
    this.wordTowerBestFloor,
  });

  final String dayIso;
  final double? listeningBand;
  final double? readingBand;
  final double? writingBand;
  final bool listeningRewarded;
  final bool readingRewarded;
  final bool writingRewarded;
  /// 当日是否已领取爬词塔每日 E 点。
  final bool wordTowerRewarded;
  /// 当日各局结束时的最高抵达层（挑战失败前）。
  final int? wordTowerBestFloor;

  int pointsEarnedToday({
    int listeningPts = _kDailyPracticeRewardListening,
    int readingPts = _kDailyPracticeRewardReading,
    int writingPts = _kDailyPracticeRewardWriting,
    int wordTowerPts = _kDailyPracticeRewardWordTower,
  }) {
    int s = 0;
    if (listeningRewarded) {
      s += listeningPts;
    }
    if (readingRewarded) {
      s += readingPts;
    }
    if (writingRewarded) {
      s += writingPts;
    }
    if (wordTowerRewarded) {
      s += wordTowerPts;
    }
    return s;
  }

  int potentialPointsPerDay({
    int listeningPts = _kDailyPracticeRewardListening,
    int readingPts = _kDailyPracticeRewardReading,
    int writingPts = _kDailyPracticeRewardWriting,
    int wordTowerPts = _kDailyPracticeRewardWordTower,
  }) {
    return listeningPts + readingPts + writingPts + wordTowerPts;
  }
}

/// [applyDailyPracticeModule] 的返回。
class DailyPracticeApplyResult {
  const DailyPracticeApplyResult({
    required this.ePointsGranted,
    required this.balanceAfter,
  });

  final int ePointsGranted;
  final int balanceAfter;
}

/// [performDailyCheckIn] 的返回结果。
class DailyCheckInResult {
  const DailyCheckInResult({
    required this.success,
    required this.totalDays,
    required this.alreadyToday,
    this.ePointsGranted = 0,
    this.ePointsBalance = 0,
    this.checkInStreak = 0,
  });

  final bool success;
  final int totalDays;
  final bool alreadyToday;

  /// 本次发放的 E 点（已签过当日为 0）。
  final int ePointsGranted;

  /// 发放后的 E 点余额。
  final int ePointsBalance;
  final int checkInStreak;
}

/// 爬词塔错题（与服务端 `word_tower_wrong_words` 对应）。
class WordTowerWrongRow {
  const WordTowerWrongRow({
    required this.english,
    required this.chinese,
    required this.wrongChinese,
    required this.updatedAt,
  });

  final String english;
  final String chinese;
  final String wrongChinese;
  final DateTime? updatedAt;
}

/// 听力 / 阅读练习错题（`practice_exam_wrongs`）。
class PracticeExamWrongRow {
  const PracticeExamWrongRow({
    required this.skill,
    required this.questionKey,
    required this.title,
    required this.description,
    required this.userAnswer,
    required this.correctAnswer,
    required this.updatedAt,
  });

  final String skill;
  final String questionKey;
  final String title;
  final String description;
  final String userAnswer;
  final String correctAnswer;
  final DateTime? updatedAt;
}

class User {
  const User({
    required this.id,
    required this.email,
    Map<String, dynamic>? userMetadata,
  }) : userMetadata = userMetadata ?? const <String, dynamic>{};

  final String id;
  final String email;
  final Map<String, dynamic> userMetadata;
}

class AuthSession {
  const AuthSession({required this.user});

  final User user;
}

class AuthResponse {
  const AuthResponse({this.session});

  final AuthSession? session;
}

class _LocalUserRecord {
  const _LocalUserRecord({
    required this.id,
    required this.account,
    required this.password,
    required this.displayName,
    required this.bio,
    required this.wordTowerMaxFloor,
    required this.checkInTotal,
    required this.lastCheckInDate,
    required this.ePoints,
    required this.blindBoxTickets,
    required this.checkInStreak,
    required this.eunoiaId,
    this.isPro = false,
  });

  final String id;
  final String account;
  final String password;
  final String displayName;
  final String bio;
  final int wordTowerMaxFloor;
  final int checkInTotal;
  final String? lastCheckInDate;
  final int ePoints;
  final int blindBoxTickets;
  final int checkInStreak;
  final String eunoiaId;
  /// Pro 会员（测试阶段可通过订阅接口开通）。
  final bool isPro;

  User toUser() => User(
    id: id,
    email: '$account@eunoia.app',
    userMetadata: <String, dynamic>{'display_name': displayName},
  );

  _LocalUserRecord copyWith({
    String? displayName,
    String? bio,
    int? wordTowerMaxFloor,
    int? checkInTotal,
    String? lastCheckInDate,
    int? ePoints,
    int? blindBoxTickets,
    int? checkInStreak,
    bool? isPro,
  }) {
    return _LocalUserRecord(
      id: id,
      account: account,
      password: password,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      wordTowerMaxFloor: wordTowerMaxFloor ?? this.wordTowerMaxFloor,
      checkInTotal: checkInTotal ?? this.checkInTotal,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
      ePoints: ePoints ?? this.ePoints,
      blindBoxTickets: blindBoxTickets ?? this.blindBoxTickets,
      checkInStreak: checkInStreak ?? this.checkInStreak,
      eunoiaId: eunoiaId,
      isPro: isPro ?? this.isPro,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'account': account,
    'password': password,
    'display_name': displayName,
    'bio': bio,
    'word_tower_max_floor': wordTowerMaxFloor,
    'check_in_total': checkInTotal,
    'last_check_in_date': lastCheckInDate,
    'e_points': ePoints,
    'blind_box_tickets': blindBoxTickets,
    'check_in_streak': checkInStreak,
    'eunoia_id': eunoiaId,
    'is_pro': isPro,
  };

  static _LocalUserRecord fromJson(Map<String, dynamic> json) {
    return _LocalUserRecord(
      id: '${json['id'] ?? ''}',
      account: '${json['account'] ?? ''}',
      password: '${json['password'] ?? ''}',
      displayName: '${json['display_name'] ?? ''}',
      bio: '${json['bio'] ?? ''}',
      wordTowerMaxFloor: (json['word_tower_max_floor'] as num?)?.toInt() ?? 0,
      checkInTotal: (json['check_in_total'] as num?)?.toInt() ?? 0,
      lastCheckInDate: _normalizePgDateColumn(json['last_check_in_date']),
      ePoints: (json['e_points'] as num?)?.toInt() ?? 0,
      blindBoxTickets: (json['blind_box_tickets'] as num?)?.toInt() ?? 0,
      checkInStreak: (json['check_in_streak'] as num?)?.toInt() ?? 0,
      eunoiaId: '${json['eunoia_id'] ?? ''}',
      isPro: json['is_pro'] == true,
    );
  }
}

/// 本地账号与练习数据（SharedPreferences JSON）；不依赖远端托管后端。
class AppDataService {
  AppDataService();

  static const String _kStoreKey = 'eunoia_local_json_store_v1';
  /// 以下 E 点规则以本服务为准（用户数据经 [SharedPreferences] 持久化，非远程数据库）。
  static const int _kDailyCheckInReward = 100;
  static const int _kRegistrationBonusEPoints = 1000;

  /// 每日真题任务：各科首次提交批改后发放的 E 点（与商城 / 个人中心同步）。
  static const int dailyRewardListening = _kDailyPracticeRewardListening;
  static const int dailyRewardReading = _kDailyPracticeRewardReading;
  static const int dailyRewardWriting = _kDailyPracticeRewardWriting;
  static const int dailyRewardWordTower = _kDailyPracticeRewardWordTower;

  /// 与登录页 [AuthPage] 校验一致：仅英文字母与数字，长度 6～12。
  static final RegExp _kCredentialFormat = RegExp(r'^[a-zA-Z0-9]{6,12}$');

  bool _initialized = false;
  SharedPreferences? _prefs;
  final StreamController<User?> _authController =
      StreamController<User?>.broadcast();
  List<_LocalUserRecord> _users = <_LocalUserRecord>[];
  List<Map<String, dynamic>> _wordTowerWrongs = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _practiceExamWrongs = <Map<String, dynamic>>[];
  /// `userId -> { day, listening: { band, rewarded }, ... }`
  Map<String, Map<String, dynamic>> _dailyPracticeByUser =
      <String, Map<String, dynamic>>{};
  /// 普通用户按月配额：`userId -> { ym, news_brief, writing_ai, speaking_ai }`
  Map<String, Map<String, dynamic>> _monthlyFreeTierByUser =
      <String, Map<String, dynamic>>{};
  String? _currentUserId;

  static String currentCalendarYearMonth() {
    final DateTime n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  /// 当前会话用户是否为 Pro（未登录为 false）。
  bool get currentUserIsPro {
    final _LocalUserRecord? u = _findUserById(_currentUserId);
    return u?.isPro == true;
  }

  Map<String, dynamic> _mutableMonthlyQuotaBucket(String uid) {
    final String ym = currentCalendarYearMonth();
    Map<String, dynamic>? m = _monthlyFreeTierByUser[uid];
    if (m == null || m['ym'] != ym) {
      m = <String, dynamic>{
        'ym': ym,
        'news_brief': 0,
        'writing_ai': 0,
        'speaking_ai': 0,
      };
      _monthlyFreeTierByUser[uid] = m;
    }
    return m;
  }

  /// 测试阶段：一键开通 Pro（正式环境可改为支付回调）。
  Future<void> subscribeProTestPhase() async {
    await _ensureInit();
    final _LocalUserRecord u = _requireCurrentRecord();
    if (u.isPro) {
      return;
    }
    _replaceUser(u.copyWith(isPro: true));
    await _saveToPrefs();
  }

  /// 环球快讯模考：非 Pro 每月仅 1 次；Pro 不限。
  Future<bool> canAccessNewsBriefMock() async {
    await _ensureInit();
    if (currentUserIsPro) {
      return true;
    }
    final String uid = _requireCurrentRecord().id;
    final Map<String, dynamic> m = _mutableMonthlyQuotaBucket(uid);
    final int n = (m['news_brief'] as num?)?.toInt() ?? 0;
    return n < 1;
  }

  /// 模考提交成功后调用（非 Pro 计 1 次/月）。
  Future<void> recordNewsBriefMockCompleted() async {
    await _ensureInit();
    if (currentUserIsPro) {
      return;
    }
    final String uid = _requireCurrentRecord().id;
    final Map<String, dynamic> m = _mutableMonthlyQuotaBucket(uid);
    m['news_brief'] = ((m['news_brief'] as num?)?.toInt() ?? 0) + 1;
    await _saveToPrefs();
  }

  /// 写作模块 AI 批改：非 Pro 每月 1 次；Pro 不限。
  Future<bool> canUseWritingAiThisMonth() async {
    await _ensureInit();
    if (currentUserIsPro) {
      return true;
    }
    final String uid = _requireCurrentRecord().id;
    final Map<String, dynamic> m = _mutableMonthlyQuotaBucket(uid);
    final int n = (m['writing_ai'] as num?)?.toInt() ?? 0;
    return n < 1;
  }

  Future<void> recordWritingAiReviewCompleted() async {
    await _ensureInit();
    if (currentUserIsPro) {
      return;
    }
    final String uid = _requireCurrentRecord().id;
    final Map<String, dynamic> m = _mutableMonthlyQuotaBucket(uid);
    m['writing_ai'] = ((m['writing_ai'] as num?)?.toInt() ?? 0) + 1;
    await _saveToPrefs();
  }

  /// 口语练习 AI 点评：非 Pro 每月 1 次；Pro 不限。
  Future<bool> canUseSpeakingAiThisMonth() async {
    await _ensureInit();
    if (currentUserIsPro) {
      return true;
    }
    final String uid = _requireCurrentRecord().id;
    final Map<String, dynamic> m = _mutableMonthlyQuotaBucket(uid);
    final int n = (m['speaking_ai'] as num?)?.toInt() ?? 0;
    return n < 1;
  }

  Future<void> recordSpeakingAiReviewCompleted() async {
    await _ensureInit();
    if (currentUserIsPro) {
      return;
    }
    final String uid = _requireCurrentRecord().id;
    final Map<String, dynamic> m = _mutableMonthlyQuotaBucket(uid);
    m['speaking_ai'] = ((m['speaking_ai'] as num?)?.toInt() ?? 0) + 1;
    await _saveToPrefs();
  }

  /// 错题笔记档案仅 Pro 可用。
  bool get canAccessWrongNotesArchive => currentUserIsPro;

  /// 保留原接口；url/key 参数已不再使用。
  Future<void> initialize({String? url, String? anonKey}) async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
    _initialized = true;
    _authController.add(currentUser);
  }

  User? get currentUser {
    final String? uid = _currentUserId;
    if (uid == null) return null;
    for (final _LocalUserRecord r in _users) {
      if (r.id == uid) {
        return r.toUser();
      }
    }
    return null;
  }

  /// JSON 模式下始终可用。
  bool get isBackendAvailable => true;

  /// 会话变化流（含初始状态）。
  Stream<User?> watchAuthUser() {
    return _authController.stream;
  }

  /// 将应用内账号（6～12 位字母数字）转为内部登录用的合成邮箱格式。
  static String accountToSyntheticEmail(String account) {
    final String t = account.trim();
    return '$t@eunoia.app';
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _ensureInit();
    final String account = email.trim();
    final String pw = password.trim();
    _assertCredentialFormat(account, pw);
    final _LocalUserRecord? existing = _users.cast<_LocalUserRecord?>().firstWhere(
      (_LocalUserRecord? x) => x != null && x.account == account,
      orElse: () => null,
    );
    if (existing != null) {
      return _finishAuthSession(existing);
    }
    final _LocalUserRecord created = _LocalUserRecord(
      id: _randomId(),
      account: account,
      password: pw,
      displayName: '烤鸭${_randomShortId()}',
      bio: '',
      wordTowerMaxFloor: 0,
      checkInTotal: 0,
      lastCheckInDate: null,
      ePoints: _kRegistrationBonusEPoints,
      blindBoxTickets: 0,
      checkInStreak: 0,
      eunoiaId: _randomEunoiaId(),
    );
    _users.add(created);
    return _finishAuthSession(created);
  }

  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _ensureInit();
    final String account = email.trim();
    final String pw = password.trim();
    if (account.isEmpty || pw.isEmpty) {
      throw StateError('账号或密码不能为空');
    }
    _assertCredentialFormat(account, pw);
    final _LocalUserRecord? existing = _users.cast<_LocalUserRecord?>().firstWhere(
      (_LocalUserRecord? x) => x != null && x.account == account,
      orElse: () => null,
    );
    if (existing != null) {
      return _finishAuthSession(existing);
    }
    final String? name = displayName?.trim();
    final _LocalUserRecord record = _LocalUserRecord(
      id: _randomId(),
      account: account,
      password: pw,
      displayName: name == null || name.isEmpty
          ? '烤鸭${_randomShortId()}'
          : name,
      bio: '',
      wordTowerMaxFloor: 0,
      checkInTotal: 0,
      lastCheckInDate: null,
      ePoints: _kRegistrationBonusEPoints,
      blindBoxTickets: 0,
      checkInStreak: 0,
      eunoiaId: _randomEunoiaId(),
    );
    _users.add(record);
    return _finishAuthSession(record);
  }

  Future<ProfilePublicFields?> fetchProfilePublicFields(String userId) async {
    await _ensureInit();
    final _LocalUserRecord? row = _findUserById(userId);
    if (row == null) {
      return null;
    }
    return ProfilePublicFields(
      displayName: row.displayName,
      bio: row.bio,
      wordTowerMaxFloor: row.wordTowerMaxFloor,
      checkInTotal: row.checkInTotal,
      lastCheckInDate: row.lastCheckInDate,
      ePoints: row.ePoints,
      checkInStreak: row.checkInStreak,
    );
  }

  Future<String?> fetchProfileDisplayName(String userId) async {
    final ProfilePublicFields? f = await fetchProfilePublicFields(userId);
    return f?.displayName;
  }

  Future<void> updateProfileDisplayNameAndBio({
    required String displayName,
    required String bio,
  }) async {
    await _ensureInit();
    final _LocalUserRecord user = _requireCurrentRecord();
    final String d = displayName.trim();
    final String b = bio.trim();
    if (d.isEmpty) {
      throw ArgumentError('昵称不能为空');
    }
    _replaceUser(user.copyWith(displayName: d, bio: b));
    await _saveToPrefs();
    _authController.add(currentUser);
  }

  /// E点 / 财富值等以 `profiles` 或专用表为准，此处仅占位。
  Future<int?> fetchEPoints() async {
    await _ensureInit();
    final _LocalUserRecord? user = _findUserById(_currentUserId);
    return user?.ePoints;
  }

  /// 扣除当前用户 E 点并返回最新余额；余额不足或参数非法会抛错。
  Future<int> spendEPoints(int amount) async {
    await _ensureInit();
    if (amount <= 0) {
      throw ArgumentError('amount must be > 0');
    }
    final _LocalUserRecord user = _requireCurrentRecord();
    if (user.ePoints < amount) {
      throw StateError('E点不足');
    }
    final int next = user.ePoints - amount;
    _replaceUser(user.copyWith(ePoints: next));
    await _saveToPrefs();
    _publishEPointsToDemoNotifier();
    return next;
  }

  /// 增加当前用户 E 点并返回最新余额；参数非法会抛错。
  Future<int> addEPoints(int amount) async {
    await _ensureInit();
    if (amount <= 0) {
      throw ArgumentError('amount must be > 0');
    }
    final _LocalUserRecord user = _requireCurrentRecord();
    final int next = user.ePoints + amount;
    _replaceUser(user.copyWith(ePoints: next));
    await _saveToPrefs();
    _publishEPointsToDemoNotifier();
    return next;
  }

  /// 当前抽卡盲盒券余额。
  Future<int?> fetchBlindBoxTickets() async {
    await _ensureInit();
    final _LocalUserRecord? user = _findUserById(_currentUserId);
    return user?.blindBoxTickets;
  }

  /// 增加当前用户抽卡盲盒券并返回最新余额；参数非法会抛错。
  Future<int> addBlindBoxTickets(int amount) async {
    await _ensureInit();
    if (amount <= 0) {
      throw ArgumentError('amount must be > 0');
    }
    final _LocalUserRecord user = _requireCurrentRecord();
    final int next = user.blindBoxTickets + amount;
    _replaceUser(user.copyWith(blindBoxTickets: next));
    await _saveToPrefs();
    return next;
  }

  /// 扣除当前用户抽卡盲盒券并返回最新余额；余额不足或参数非法会抛错。
  Future<int> spendBlindBoxTickets(int amount) async {
    await _ensureInit();
    if (amount <= 0) {
      throw ArgumentError('amount must be > 0');
    }
    final _LocalUserRecord user = _requireCurrentRecord();
    if (user.blindBoxTickets < amount) {
      throw StateError('盲盒券不足');
    }
    final int next = user.blindBoxTickets - amount;
    _replaceUser(user.copyWith(blindBoxTickets: next));
    await _saveToPrefs();
    return next;
  }

  double? _bandFromSkillEntry(Object? raw) {
    if (raw is Map) {
      final Object? b = raw['band'];
      if (b is num) {
        return b.toDouble();
      }
    }
    return null;
  }

  bool _rewardedFromSkillEntry(Object? raw) {
    if (raw is Map) {
      return raw['rewarded'] == true;
    }
    return false;
  }

  Map<String, dynamic>? _readDailyBucket(String uid, String todayIso) {
    final Map<String, dynamic>? row = _dailyPracticeByUser[uid];
    if (row == null || row['day'] != todayIso) {
      return null;
    }
    return row;
  }

  Map<String, dynamic> _mutableDailyBucket(String uid, String todayIso) {
    Map<String, dynamic>? row = _dailyPracticeByUser[uid];
    if (row == null || row['day'] != todayIso) {
      row = <String, dynamic>{'day': todayIso};
      _dailyPracticeByUser[uid] = row;
    }
    return row;
  }

  int _rewardPtsForSkill(String skill) {
    switch (skill) {
      case 'listening':
        return _kDailyPracticeRewardListening;
      case 'reading':
        return _kDailyPracticeRewardReading;
      case 'writing':
        return _kDailyPracticeRewardWriting;
      default:
        return 0;
    }
  }

  /// 今日各科雅思估分与任务进度（未登录为 null）。
  Future<DailyPracticeTodayView?> fetchDailyPracticeTodayView() async {
    await _ensureInit();
    final String? uid = _currentUserId;
    if (uid == null) {
      return null;
    }
    final String day = localCalendarDayIso(DateTime.now());
    final Map<String, dynamic>? bucket = _readDailyBucket(uid, day);
    if (bucket == null) {
      return DailyPracticeTodayView(dayIso: day);
    }
    return DailyPracticeTodayView(
      dayIso: day,
      listeningBand: _bandFromSkillEntry(bucket['listening']),
      readingBand: _bandFromSkillEntry(bucket['reading']),
      writingBand: _bandFromSkillEntry(bucket['writing']),
      listeningRewarded: _rewardedFromSkillEntry(bucket['listening']),
      readingRewarded: _rewardedFromSkillEntry(bucket['reading']),
      writingRewarded: _rewardedFromSkillEntry(bucket['writing']),
      wordTowerRewarded: _rewardedFromSkillEntry(bucket['word_tower']),
      wordTowerBestFloor: _wordTowerBestFloorFromBucket(bucket),
    );
  }

  int? _wordTowerBestFloorFromBucket(Map<String, dynamic> bucket) {
    final Object? wt = bucket['word_tower'];
    if (wt is Map) {
      final Object? f = wt['best_floor'];
      if (f is num) {
        return f.toInt();
      }
    }
    return null;
  }

  /// 爬词塔一局结束（答错或超时）：更新当日最高层；当日首次结束时发放 E 点。
  Future<DailyPracticeApplyResult> applyDailyWordTowerRunCompleted({
    required int floorReached,
  }) async {
    await _ensureInit();
    final _LocalUserRecord user = _requireCurrentRecord();
    final String uid = user.id;
    final String day = localCalendarDayIso(DateTime.now());
    final Map<String, dynamic> bucket = _mutableDailyBucket(uid, day);
    final Map<String, dynamic> wt =
        Map<String, dynamic>.from((bucket['word_tower'] as Map<String, dynamic>?) ?? <String, dynamic>{});
    final int prevBest = (wt['best_floor'] as num?)?.toInt() ?? 0;
    if (floorReached > prevBest) {
      wt['best_floor'] = floorReached;
    }

    int granted = 0;
    if (wt['rewarded'] != true) {
      granted = _kDailyPracticeRewardWordTower;
      if (granted > 0) {
        wt['rewarded'] = true;
        wt['reward_pts'] = granted;
        _replaceUser(user.copyWith(ePoints: user.ePoints + granted));
        _publishEPointsToDemoNotifier();
      }
    }
    bucket['word_tower'] = wt;
    await _saveToPrefs();
    return DailyPracticeApplyResult(
      ePointsGranted: granted,
      balanceAfter: _requireCurrentRecord().ePoints,
    );
  }

  /// 记录一次听力 / 阅读 / 写作批改结果：写入当日估分；该科目当日首次完成时发放 E 点。
  Future<DailyPracticeApplyResult> applyDailyPracticeModule({
    required String skill,
    required double ieltsBand,
  }) async {
    await _ensureInit();
    final _LocalUserRecord user = _requireCurrentRecord();
    final String uid = user.id;
    final String sk = skill.trim().toLowerCase();
    if (sk != 'listening' && sk != 'reading' && sk != 'writing') {
      throw ArgumentError(skill);
    }
    final String day = localCalendarDayIso(DateTime.now());
    final Map<String, dynamic> bucket = _mutableDailyBucket(uid, day);
    final Map<String, dynamic> skillMap =
        Map<String, dynamic>.from((bucket[sk] as Map<String, dynamic>?) ?? <String, dynamic>{});
    final double bandRounded =
        double.parse(ieltsBand.clamp(0.0, 9.0).toStringAsFixed(1));
    skillMap['band'] = bandRounded;

    int granted = 0;
    if (skillMap['rewarded'] != true) {
      granted = _rewardPtsForSkill(sk);
      if (granted > 0) {
        skillMap['rewarded'] = true;
        skillMap['reward_pts'] = granted;
        _replaceUser(user.copyWith(ePoints: user.ePoints + granted));
        _publishEPointsToDemoNotifier();
      }
    }
    bucket[sk] = skillMap;
    await _saveToPrefs();
    return DailyPracticeApplyResult(
      ePointsGranted: granted,
      balanceAfter: _requireCurrentRecord().ePoints,
    );
  }

  /// 将历史最高层数与服务端取最大值（需已执行 `merge_word_tower_max_floor` 迁移）。
  Future<void> mergeWordTowerMaxFloor(int floor) async {
    await _ensureInit();
    final _LocalUserRecord user = _requireCurrentRecord();
    if (floor > user.wordTowerMaxFloor) {
      _replaceUser(user.copyWith(wordTowerMaxFloor: floor));
      await _saveToPrefs();
    }
  }

  /// 错选释义时写入 / 更新错题行。
  Future<void> upsertWordTowerWrong({
    required String english,
    required String chinese,
    required String wrongChinese,
  }) async {
    await _ensureInit();
    final String uid = _requireCurrentRecord().id;
    final String e = english.trim();
    final String c = chinese.trim();
    if (e.isEmpty || c.isEmpty) return;
    final int idx = _wordTowerWrongs.indexWhere(
      (Map<String, dynamic> x) => x['user_id'] == uid && x['english'] == e,
    );
    final Map<String, dynamic> row = <String, dynamic>{
      'user_id': uid,
      'english': e,
      'chinese': c,
      'wrong_chinese': wrongChinese.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (idx >= 0) {
      _wordTowerWrongs[idx] = row;
    } else {
      _wordTowerWrongs.add(row);
    }
    await _saveToPrefs();
  }

  /// 爬词塔错题列表（按最近更新时间倒序）。
  Future<List<WordTowerWrongRow>> fetchWordTowerWrongWords() async {
    await _ensureInit();
    final String uid = _requireCurrentRecord().id;
    final List<Map<String, dynamic>> rows = _wordTowerWrongs
        .where((Map<String, dynamic> x) => x['user_id'] == uid)
        .toList();
    rows.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime ta =
          DateTime.tryParse('${a['updated_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime tb =
          DateTime.tryParse('${b['updated_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return rows.map((Map<String, dynamic> m) {
      return WordTowerWrongRow(
        english: '${m['english'] ?? ''}',
        chinese: '${m['chinese'] ?? ''}',
        wrongChinese: '${m['wrong_chinese'] ?? ''}',
        updatedAt: DateTime.tryParse('${m['updated_at'] ?? ''}'),
      );
    }).toList();
  }

  /// 删除单条爬词塔错词（按英文词唯一键）。
  Future<void> deleteWordTowerWrongByEnglish(String english) async {
    await _ensureInit();
    final String uid = _requireCurrentRecord().id;
    final String e = english.trim();
    if (e.isEmpty) return;
    _wordTowerWrongs.removeWhere(
      (Map<String, dynamic> x) => x['user_id'] == uid && x['english'] == e,
    );
    await _saveToPrefs();
  }

  /// 清空当前用户全部爬词塔错词。
  Future<void> clearWordTowerWrongs() async {
    await _ensureInit();
    final String uid = _requireCurrentRecord().id;
    _wordTowerWrongs.removeWhere(
      (Map<String, dynamic> x) => x['user_id'] == uid,
    );
    await _saveToPrefs();
  }

  /// 提交听力 / 阅读错题（同一题再次做错则更新文案与时间）。
  Future<void> upsertPracticeExamWrong({
    required String skill,
    required String questionKey,
    required String title,
    required String description,
    required String userAnswer,
    required String correctAnswer,
  }) async {
    await _ensureInit();
    final String uid = _requireCurrentRecord().id;
    final String sk = skill.trim();
    if (sk != 'listening' && sk != 'reading') return;
    final String qk = questionKey.trim();
    if (qk.isEmpty) return;
    final int idx = _practiceExamWrongs.indexWhere(
      (Map<String, dynamic> x) =>
          x['user_id'] == uid && x['skill'] == sk && x['question_key'] == qk,
    );
    final Map<String, dynamic> row = <String, dynamic>{
      'user_id': uid,
      'skill': sk,
      'question_key': qk,
      'title': title.trim(),
      'description': description.trim(),
      'user_answer': userAnswer.trim(),
      'correct_answer': correctAnswer.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (idx >= 0) {
      _practiceExamWrongs[idx] = row;
    } else {
      _practiceExamWrongs.add(row);
    }
    await _saveToPrefs();
  }

  /// [skill] 为 `listening`、`reading` 或 `null`（全部）。
  Future<List<PracticeExamWrongRow>> fetchPracticeExamWrongs({
    String? skill,
  }) async {
    await _ensureInit();
    final String uid = _requireCurrentRecord().id;
    final String? filterSkill = skill?.trim();
    final List<Map<String, dynamic>> rows = _practiceExamWrongs.where((
      Map<String, dynamic> x,
    ) {
      if (x['user_id'] != uid) return false;
      if (filterSkill == 'listening' || filterSkill == 'reading') {
        return x['skill'] == filterSkill;
      }
      return true;
    }).toList();
    rows.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime ta =
          DateTime.tryParse('${a['updated_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime tb =
          DateTime.tryParse('${b['updated_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return rows.map((Map<String, dynamic> m) {
      return PracticeExamWrongRow(
        skill: '${m['skill'] ?? ''}',
        questionKey: '${m['question_key'] ?? ''}',
        title: '${m['title'] ?? ''}',
        description: '${m['description'] ?? ''}',
        userAnswer: '${m['user_answer'] ?? ''}',
        correctAnswer: '${m['correct_answer'] ?? ''}',
        updatedAt: DateTime.tryParse('${m['updated_at'] ?? ''}'),
      );
    }).toList();
  }

  /// 删除单条听说读写错题（按 skill + question_key 复合键）。
  Future<void> deletePracticeExamWrong({
    required String skill,
    required String questionKey,
  }) async {
    await _ensureInit();
    final String uid = _requireCurrentRecord().id;
    final String sk = skill.trim();
    final String qk = questionKey.trim();
    if ((sk != 'listening' && sk != 'reading') || qk.isEmpty) return;
    _practiceExamWrongs.removeWhere(
      (Map<String, dynamic> x) =>
          x['user_id'] == uid && x['skill'] == sk && x['question_key'] == qk,
    );
    await _saveToPrefs();
  }

  /// 清空当前用户听说读写错题；传入 listening/reading 时仅清空对应分类。
  Future<void> clearPracticeExamWrongs({String? skill}) async {
    await _ensureInit();
    final String uid = _requireCurrentRecord().id;
    final String? sk = skill?.trim();
    _practiceExamWrongs.removeWhere((Map<String, dynamic> x) {
      if (x['user_id'] != uid) return false;
      if (sk == 'listening' || sk == 'reading') {
        return x['skill'] == sk;
      }
      return true;
    });
    await _saveToPrefs();
  }

  /// 设备本地日历日 `YYYY-MM-DD`。
  static String localCalendarDayIso(DateTime now) {
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<DailyCheckInResult?> performDailyCheckIn() async {
    await _ensureInit();
    final _LocalUserRecord user = _requireCurrentRecord();
    final String day = localCalendarDayIso(DateTime.now());
    if (user.lastCheckInDate == day) {
      return DailyCheckInResult(
        success: true,
        totalDays: user.checkInTotal,
        alreadyToday: true,
        ePointsGranted: 0,
        ePointsBalance: user.ePoints,
        checkInStreak: user.checkInStreak,
      );
    }
    final int nextStreak = _calcNextStreak(
      user.lastCheckInDate,
      day,
      user.checkInStreak,
    );
    final _LocalUserRecord updated = user.copyWith(
      checkInTotal: user.checkInTotal + 1,
      lastCheckInDate: day,
      ePoints: user.ePoints + _kDailyCheckInReward,
      checkInStreak: nextStreak,
    );
    _replaceUser(updated);
    await _saveToPrefs();
    _publishEPointsToDemoNotifier();
    return DailyCheckInResult(
      success: true,
      totalDays: updated.checkInTotal,
      alreadyToday: false,
      ePointsGranted: _kDailyCheckInReward,
      ePointsBalance: updated.ePoints,
      checkInStreak: updated.checkInStreak,
    );
  }

  Future<void> signOut() async {
    await _ensureInit();
    _currentUserId = null;
    await _saveToPrefs();
    demoEPointsNotifier.value = 0;
    _authController.add(null);
  }

  String? currentUserDisplayName() {
    return _findUserById(_currentUserId)?.displayName;
  }

  String? currentUserEunoiaId() {
    return _findUserById(_currentUserId)?.eunoiaId;
  }

  String? displayNameByUserId(String userId) {
    return _findUserById(userId)?.displayName;
  }

  /// 好友列表等场景展示 TA 的 Eunoia ID。
  String? eunoiaIdForUser(String userId) {
    return _findUserById(userId)?.eunoiaId;
  }

  /// 注入社交演示用 NPC 本地资料（不参与真实登录校验）。
  Future<void> ensureCommunityNpcProfiles() async {
    await _ensureInit();
    bool changed = false;
    void addNpc({
      required String id,
      required String account,
      required String displayName,
      required String eunoiaId,
    }) {
      if (_findUserById(id) != null) {
        return;
      }
      _users.add(
        _LocalUserRecord(
          id: id,
          account: account,
          password: account,
          displayName: displayName,
          bio: '',
          wordTowerMaxFloor: 18,
          checkInTotal: 12,
          lastCheckInDate: null,
          ePoints: 3200,
          blindBoxTickets: 1,
          checkInStreak: 3,
          eunoiaId: eunoiaId,
          isPro: false,
        ),
      );
      changed = true;
    }

    addNpc(
      id: CommunityDemoIds.npcMia,
      account: 'npcmia001',
      displayName: '烤鸭_Mia',
      eunoiaId: '628441',
    );
    addNpc(
      id: CommunityDemoIds.npcAlex,
      account: 'npcalex02',
      displayName: '口语搭子_阿乐',
      eunoiaId: '715892',
    );
    addNpc(
      id: CommunityDemoIds.npcDiary,
      account: 'npcdiary3',
      displayName: '雅思日记本',
      eunoiaId: '903521',
    );
    if (changed) {
      await _saveToPrefs();
    }
  }

  ProfilePublicFields? profileByUserId(String userId) {
    final _LocalUserRecord? row = _findUserById(userId);
    if (row == null) return null;
    return ProfilePublicFields(
      displayName: row.displayName,
      bio: row.bio,
      wordTowerMaxFloor: row.wordTowerMaxFloor,
      checkInTotal: row.checkInTotal,
      lastCheckInDate: row.lastCheckInDate,
      ePoints: row.ePoints,
      checkInStreak: row.checkInStreak,
    );
  }

  String? findUserIdByEunoiaId(String rawId) {
    final String q = rawId.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final _LocalUserRecord x in _users) {
      if (x.eunoiaId.toLowerCase() == q) {
        return x.id;
      }
    }
    return null;
  }

  Future<void> _ensureInit() async {
    if (!_initialized) {
      await initialize();
    }
  }

  void _loadFromPrefs() {
    final String raw = _prefs?.getString(_kStoreKey) ?? '';
    if (raw.isEmpty) return;
    final Object? parsed = jsonDecode(raw);
    if (parsed is! Map) return;
    final Map<String, dynamic> root =
        Map<String, dynamic>.from(parsed);
    final List<dynamic> usersRaw =
        (root['users'] as List<dynamic>?) ?? <dynamic>[];
    _users = usersRaw
        .whereType<Map>()
        .map((Map x) => _LocalUserRecord.fromJson(Map<String, dynamic>.from(x)))
        .toList();
    _currentUserId = root['current_user_id'] as String?;
    _wordTowerWrongs =
        ((root['word_tower_wrongs'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<Map>()
            .map((Map x) => Map<String, dynamic>.from(x))
            .toList();
    _practiceExamWrongs =
        ((root['practice_exam_wrongs'] as List<dynamic>?) ?? <dynamic>[])
            .whereType<Map>()
            .map((Map x) => Map<String, dynamic>.from(x))
            .toList();
    _dailyPracticeByUser = <String, Map<String, dynamic>>{};
    final Object? dpRaw = root['daily_practice'];
    if (dpRaw is Map) {
      for (final MapEntry<Object?, Object?> e in dpRaw.entries) {
        final String uid = '${e.key ?? ''}';
        if (uid.isEmpty) {
          continue;
        }
        final Object? v = e.value;
        if (v is Map) {
          _dailyPracticeByUser[uid] =
              Map<String, dynamic>.from(Map<Object?, Object?>.from(v).map(
            (Object? k, Object? val) => MapEntry('$k', val),
          ));
        }
      }
    }
    _monthlyFreeTierByUser = <String, Map<String, dynamic>>{};
    final Object? mqRaw = root['monthly_free_tier'];
    if (mqRaw is Map) {
      for (final MapEntry<Object?, Object?> e in mqRaw.entries) {
        final String uid = '${e.key ?? ''}';
        if (uid.isEmpty) {
          continue;
        }
        final Object? v = e.value;
        if (v is Map) {
          _monthlyFreeTierByUser[uid] =
              Map<String, dynamic>.from(Map<Object?, Object?>.from(v).map(
            (Object? k, Object? val) => MapEntry('$k', val),
          ));
        }
      }
    }
    _publishEPointsToDemoNotifier();
  }

  /// 与商城 / 补给舱共用 [demoEPointsNotifier]，保证各处展示的 E点与 JSON 存档一致。
  void _publishEPointsToDemoNotifier() {
    final _LocalUserRecord? u = _findUserById(_currentUserId);
    demoEPointsNotifier.value = u?.ePoints ?? 0;
  }

  Future<void> _saveToPrefs() async {
    final Map<String, dynamic> root = <String, dynamic>{
      'users': _users.map((_LocalUserRecord x) => x.toJson()).toList(),
      'current_user_id': _currentUserId,
      'word_tower_wrongs': _wordTowerWrongs,
      'practice_exam_wrongs': _practiceExamWrongs,
      'daily_practice': _dailyPracticeByUser,
      'monthly_free_tier': _monthlyFreeTierByUser,
    };
    await _prefs?.setString(_kStoreKey, jsonEncode(root));
  }

  _LocalUserRecord? _findUserById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final _LocalUserRecord x in _users) {
      if (x.id == id) return x;
    }
    return null;
  }

  _LocalUserRecord _requireCurrentRecord() {
    final _LocalUserRecord? user = _findUserById(_currentUserId);
    if (user == null) {
      throw StateError('未登录');
    }
    return user;
  }

  void _replaceUser(_LocalUserRecord updated) {
    final int idx = _users.indexWhere(
      (_LocalUserRecord x) => x.id == updated.id,
    );
    if (idx >= 0) {
      _users[idx] = updated;
    }
  }

  void _assertCredentialFormat(String account, String password) {
    if (!_kCredentialFormat.hasMatch(account) ||
        !_kCredentialFormat.hasMatch(password)) {
      throw StateError('账号与密码须为 6～12 位英文字母或数字');
    }
  }

  Future<AuthResponse> _finishAuthSession(_LocalUserRecord user) async {
    _currentUserId = user.id;
    await _saveToPrefs();
    _publishEPointsToDemoNotifier();
    _authController.add(user.toUser());
    return AuthResponse(session: AuthSession(user: user.toUser()));
  }

  static int _calcNextStreak(String? lastDay, String today, int current) {
    if (lastDay == null || lastDay.isEmpty) return 1;
    final DateTime? last = DateTime.tryParse(lastDay);
    final DateTime? now = DateTime.tryParse(today);
    if (last == null || now == null) return 1;
    final int delta = now.difference(last).inDays;
    if (delta == 1) return current + 1;
    return 1;
  }

  static String _randomId() {
    final Random r = Random();
    return List<String>.generate(
      4,
      (_) => r.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'),
    ).join('-');
  }

  static String _randomShortId() {
    final Random r = Random();
    return r.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  }

  static String _randomEunoiaId() {
    final Random r = Random();
    return (100000 + r.nextInt(900000)).toString();
  }
}
