import 'package:flutter/widgets.dart';

/// 应用文案：随 [MaterialApp.locale] / `appLocaleProvider` 切换中英文。
class AppStrings {
  const AppStrings._(this.isZh);

  final bool isZh;

  static AppStrings of(BuildContext context) {
    final String code = Localizations.localeOf(context).languageCode.toLowerCase();
    return AppStrings._(code.startsWith('zh'));
  }

  String get navPractice => isZh ? '练习' : 'Practice';
  String get navSocial => isZh ? '社区' : 'Social';
  String get navStore => isZh ? '商城' : 'Store';
  String get navProfile => isZh ? '我的' : 'Profile';

  String get languageTitle => isZh ? '语言' : 'Language';
  String get languageSubtitle => isZh ? '切换中文 / English' : 'Switch English / 中文';
  String get languageSwitchToEnglish => isZh ? '切换到 English' : 'Switch to English';
  String get languageSwitchToChinese => isZh ? '切换到中文' : 'Switch to 中文';

  String get myPostsTitle => isZh ? '我的发布' : 'My Posts';
  String get myPostsSubtitle => isZh ? '管理个人动态 · 发布新帖子' : 'Manage posts and publish new ones';
  String get contractRingTitle => isZh ? '契约与星环' : 'Contracts & Star Ring';
  String get contractRingSubtitle => isZh ? '管理契约好友 · 公会群聊' : 'Manage friends and guild chats';
  String get leaderboardTitle => isZh ? '排行榜 (词塔 & 财富)' : 'Leaderboard (Tower & Wealth)';
  String get leaderboardSubtitle => isZh ? '无尽词塔 · 财富榜' : 'Tower ranking and wealth ranking';
  String get wrongNotesTitle => isZh ? '错题笔记档案' : 'Wrong Notes Archive';
  String get wrongNotesSubtitle => isZh ? '爬词塔错词 · 听说读写错题' : 'Mistakes from tower and all modules';
  String get wrongNotesProOnlySubtitle => isZh ? 'Pro 会员专属 · 订阅后解锁' : 'Pro only · Subscribe to unlock';
  String get wrongNotesProOnlySnack => isZh
      ? '错题笔记档案为 Pro 会员专属，请在上方订阅 Pro。'
      : 'Wrong notes are a Pro feature. Please subscribe above.';

  // —— Profile stats & banner ——
  String get profileGuestBanner => isZh ? '游客模式 · 数据仅保存在本机演示' : 'Guest · Data stored locally for demo only';
  String get statLabelEPoints => isZh ? 'E点' : 'E-Points';
  String get statLabelWordTower => isZh ? '词塔层数' : 'Tower floors';
  String get statLabelCheckInDays => isZh ? '签到天数' : 'Check-in days';

  String get proCardTitlePro => isZh ? 'Pro 会员' : 'Pro member';
  String get proCardTitleUpgrade => isZh ? '升级 Pro 会员' : 'Upgrade to Pro';
  String get proCardButtonSubscribe => isZh ? '订阅 Pro' : 'Subscribe';
  String get proCardActivatedSnack => isZh ? '已开通 Pro（测试阶段 · 无需支付）' : 'Pro enabled (test phase · no payment)';
  String get proCardBodyPro => isZh
      ? '你已享有：环球快讯模考不限 + 往期语料；写作/口语 AI 无限次；错题笔记档案。'
      : 'You have: unlimited Global News mock + past papers; unlimited writing/speaking AI; wrong notes archive.';
  String get proCardBodyFree => isZh
      ? '普通用户：环球快讯模考每月 1 次；写作/口语 AI 批改每月各 1 次；无错题笔记。\n测试阶段点击「订阅 Pro」即可开通。'
      : 'Free: 1 news mock / month; 1 writing & 1 speaking AI review / month; no wrong notes.\nTap Subscribe for Pro in test.';

  String get checkInDevMockSnack => isZh ? '演示模式下签到不同步至云端' : 'Check-in is local only in demo mode';
  String get checkInFailed => isZh ? '签到失败，请确认已登录且云端已部署签到接口' : 'Check-in failed. Please sign in and ensure the API is available.';
  String checkInAlreadyMessage(int totalDays, int balance) => isZh
      ? '今日已签到 · 累计 $totalDays 天 · 余额 $balance E点'
      : 'Already checked in today · $totalDays days total · Balance $balance E-Points';
  String checkInSuccessMessage(int granted, int streak, int totalDays, int balance) => isZh
      ? '+$granted E点 · 连续 $streak 天 · 累计签到 $totalDays 天 · 余额 $balance'
      : '+$granted E-Points · Streak $streak days · Total check-ins $totalDays · Balance $balance';
  String get loginToCheckInDaily => isZh ? '登录后每日签到领 E点' : 'Sign in to check in daily for E-Points';
  String get devModeCheckInNote => isZh ? '演示模式：签到与云端不同步' : 'Demo: check-in does not sync to cloud';

  String get checkInBannerTitleActive => isZh ? '今日签到' : 'Check in today';
  String get checkInBannerSubtitleActive => isZh ? '点按领取 E 点 · 连续签到奖励更多' : 'Tap to claim E-Points · Longer streaks earn more';
  String get checkInBannerTitleDone => isZh ? '今日已签到' : 'Checked in today';
  String checkInBannerSubtitleDone(String totalDays) =>
      isZh ? '累计 $totalDays 天 · 明日可再领' : '$totalDays days total · Come back tomorrow';

  // —— Practice page & daily tasks ——
  String get practiceGuestName => isZh ? '同学' : 'there';
  String get practiceDailyTaskBadge => isZh ? '每日任务' : 'Daily tasks';
  String get practiceDailyTaskLoginHint =>
      isZh ? '登录后完成批改可记录今日雅思估分并获得 E 点（与商城同步）' : 'Sign in to save today’s band scores and earn E-Points (synced with Store).';
  String get practiceDailyTaskTitle => isZh ? '今日真题任务' : 'Today’s exam tasks';
  String get practiceDailyTaskLoadError => isZh ? '加载每日任务失败' : 'Failed to load daily tasks';
  String practiceDailyTaskPoints(int got, int pot) =>
      isZh ? '$got / $pot E点' : '$got / $pot E-Points';
  String practiceDailyTaskRewardLine(int l, int r, int w, int t) => isZh
      ? '各科当日首次批改与每日一局爬词塔可得奖励（听力 $l · 阅读 $r · 写作 $w · 词塔 $t）'
      : 'First daily graded attempt per skill + one Word Tower run: L $l · R $r · W $w · Tower $t E-Points';
  String get dailyTaskWordTowerTitle => isZh ? '爬词塔' : 'Word Tower';
  String get dailyTaskWordTowerSubtitlePending =>
      isZh ? '完成一局即可领取（每日一次）' : 'Finish one run to claim (once per day)';
  String dailyTaskWordTowerBestToday(int floor) =>
      isZh ? '今日最高 $floor 层 · 奖励已领' : 'Best today: floor $floor · Reward claimed';
  String get dailyTaskWordTowerRewardDoneShort => isZh ? '今日奖励已领' : 'Reward claimed today';
  String get skillListening => isZh ? '听力' : 'Listening';
  String get skillReading => isZh ? '阅读' : 'Reading';
  String get skillWriting => isZh ? '写作' : 'Writing';
  String get practiceTodayBand => isZh ? '今日估分' : 'Today’s band';

  String get profileTodayPracticeTitle => isZh ? '今日练习 · 雅思估分' : 'Today · IELTS band';
  String profileTodayPracticeRewardLine(int l, int r, int w) => isZh
      ? '奖励：听力 $l · 阅读 $r · 写作 $w（各科当日首次批改）'
      : 'Rewards: L $l · R $r · W $w E-Points (first submission per skill / day)';

  String get dailyTasksHubTitle => isZh ? '今日任务' : "Today's Tasks";
  String get dailyTasksHubStreak => isZh ? '🔥 已连续 3 天' : '🔥 3-day streak';
  String get dailyTasksHubAppBar => isZh ? '真题练习' : 'Practice';
  String get moduleListeningTitle => isZh ? '听力模拟' : 'Listening';
  String get moduleListeningSubtitle => isZh ? '剑雅真题 · Part 1 笔记 + Part 2 选择' : 'Cambridge-style · Part 1 notes + Part 2 MCQ';
  String get moduleReadingTitle => isZh ? '阅读演练' : 'Reading';
  String get moduleReadingSubtitle => isZh ? 'Test 1 · 40 题' : 'Test 1 · 40 questions';
  String get moduleWritingTitle => isZh ? '写作批改' : 'Writing';
  String get moduleWritingSubtitle => isZh ? 'Task 1 图表 + Task 2 议论文' : 'Task 1 chart + Task 2 essay';
  String get moduleSpeakingTitle => isZh ? '口语练习' : 'Speaking';
  String get moduleSpeakingSubtitle => isZh ? '雅思口语真题演练' : 'IELTS speaking practice';

  // —— Daily task set pick (listening / reading / writing) ——
  String get setPickListeningTitle => isZh ? '听力 · 选择套题' : 'Listening · Choose a set';
  String get setPickReadingTitle => isZh ? '阅读 · 选择套题' : 'Reading · Choose a set';
  String get setPickWritingTitle => isZh ? '写作 · 选择套题' : 'Writing · Choose a set';
  String setPickSetLabel(int n) => isZh ? '套题 $n' : 'Set $n';
  String get setPickReadingPassages => isZh ? '三篇文章 · 40 题' : '3 passages · 40 questions';
  String setPickListeningSubtitle(int index1Based) {
    if (!isZh) {
      return switch (index1Based) {
        1 => 'Cambridge-style · 40 questions · Parts 1–4',
        2 => 'Academic section 1–4 · note & MCQ focus',
        3 => 'Mixed accents · maps & diagrams',
        4 => 'Long dialogue practice · form filling',
        _ => 'Full test · timing same as exam',
      };
    }
    return switch (index1Based) {
      1 => '剑雅真题 · 40 题 · Part 1–4',
      2 => '学术场景 · 填空与选择强化',
      3 => '混合口音 · 地图与示意图',
      4 => '长对话演练 · 表格填空',
      _ => '全真模拟 · 计时与考试一致',
    };
  }

  String setPickWritingSubtitle(int index1Based) {
    if (!isZh) {
      return switch (index1Based) {
        1 => 'Task 1 chart + Task 2 essay',
        2 => 'Task 1 process diagram + Task 2 opinion',
        3 => 'Task 1 maps + Task 2 discussion',
        _ => 'Task 1 mixed + Task 2 argument',
      };
    }
    return switch (index1Based) {
      1 => 'Task 1 图表 + Task 2 议论文',
      2 => 'Task 1 流程图 + Task 2 观点类',
      3 => 'Task 1 地图 + Task 2 讨论类',
      _ => 'Task 1 混合 + Task 2 论证类',
    };
  }

  String tr(String zh, String en) => isZh ? zh : en;

  // —— Web 麦克风权限失败（与 [resolveRecorderMicPermission] 对齐）——
  String get micWebNotSecure => isZh
      ? '当前页面不是安全连接：远程站点必须使用 https:// 打开；本地调试请使用 http://localhost 或 http://127.0.0.1。浏览器仅允许在安全环境下使用麦克风。'
      : 'Not a secure context: use https:// for remote sites, or http://localhost / http://127.0.0.1 locally. The microphone requires a secure context.';

  String get micWebPermissionDenied => isZh
      ? '麦克风权限被拒绝或未授予：请在地址栏「网站设置」中将本站麦克风设为「允许」，若曾拒绝过请先改为允许后刷新页面。'
      : 'Microphone access was denied or not granted. In the address bar, open Site settings and allow the microphone for this site, then refresh.';

  String get micWebNoDevice => isZh
      ? '未检测到可用的麦克风输入设备，请检查系统是否已连接麦克风并选择正确的输入设备。'
      : 'No microphone input device was found. Connect a microphone and select the correct input in system settings.';

  String micWebOther(String detail) => isZh
      ? '无法使用麦克风：$detail'
      : 'Cannot use the microphone: $detail';

  String get micWebUnknownShort => isZh
      ? '无法访问麦克风，请刷新页面或更换浏览器后重试。'
      : 'Cannot access the microphone. Refresh the page or try another browser.';

  String get micNativeDenied => isZh ? '需要麦克风权限才能录音' : 'Microphone permission is required to record';

  // —— Inbox ——
  String get inboxTooltip => isZh ? '消息' : 'Messages';
  String get inboxTabInteract => isZh ? '互动' : 'Interact';
  String get inboxTabFriends => isZh ? '好友' : 'Friends';
  String get inboxTabGroups => isZh ? '群聊' : 'Groups';
  String get inboxEmptyInteract => isZh ? '暂无互动消息' : 'No notifications yet';
  String get inboxEmptyFriends => isZh ? '暂无好友请求' : 'No friend requests';
  String get inboxGroupsPlaceholder => isZh
      ? '以下为演示占位：完整群聊列表与入口与 Social → 星环 同步。'
      : 'Demo placeholder: full group list syncs with Social → Star Ring.';
  String get inboxMarkAllRead => isZh ? '全部已读' : 'Mark all read';

  // —— My posts ——
  String get myPostsPublishNew => isZh ? '发布新动态' : 'New post';
  String get myPostsEmptyTitle => isZh ? '暂无个人动态' : 'No posts yet';
  String get myPostsEmptySubtitle =>
      isZh ? '在 Social 广场发布第一条帖子后，将显示在这里' : 'Publish on Social and your posts will appear here.';
  String get visibilityPublic => isZh ? '🌐 公开 (Public)' : '🌐 Public';

  // —— Contract & Star Ring ——
  String get contractRingAppBarTitle => isZh ? '契约与星环' : 'Contracts & Star Ring';
  String get contractRingTabContracts => isZh ? '契约' : 'Contracts';
  String get contractRingTabStarRing => isZh ? '星环' : 'Star Ring';
  String get contractRingSearchContractsHint =>
      isZh ? '输入契约 ID 或昵称…' : 'Enter contract ID or nickname…';
  String get contractRingSearchGuildsHint =>
      isZh ? '输入群 ID 或扫码加入…' : 'Enter group ID or scan to join…';
  String get contractRingEmptyFriendsTitle => isZh ? '暂无契约好友' : 'No contract friends yet';
  String get contractRingEmptyFriendsSubtitle =>
      isZh ? '缔结契约或接受请求后，将在此管理与私聊' : 'After pairing or accepting requests, manage and chat here.';
  String get contractRingCreateGuild => isZh ? '创建新星环公会' : 'Create guild';
  String get contractRingCreateGuildSnack => isZh ? '创建新星环公会（演示）' : 'Create guild (demo)';
  String get contractRingEmptyGuildsTitle => isZh ? '暂无星环公会' : 'No guilds yet';
  String get contractRingEmptyGuildsSubtitle => isZh
      ? '创建或加入公会后，星环与群聊入口会出现在这里'
      : 'After creating or joining a guild, Star Ring and groups appear here.';

  // —— Wrong notes archive ——
  String get wrongNotesProSnack =>
      isZh ? '错题笔记档案为 Pro 会员专属，请先订阅。' : 'Wrong notes are Pro-only. Please subscribe.';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get delete => isZh ? '删除' : 'Delete';
  String wrongNotesDeleteWordTitle(String word) =>
      isZh ? '删除错词' : 'Delete wrong word';
  String wrongNotesDeleteWordBody(String word) =>
      isZh ? '确认删除 $word 这条错词记录吗？' : 'Delete this wrong-word entry for "$word"?';
  String get wrongNotesDeletedWord => isZh ? '已删除错词记录' : 'Wrong-word entry deleted';
  String get wrongNotesDeleteExamTitle => isZh ? '删除错题' : 'Delete mistake';
  String get wrongNotesDeleteExamBody =>
      isZh ? '确认删除这条听说读写错题记录吗？' : 'Delete this practice exam mistake entry?';
  String get wrongNotesDeletedExam => isZh ? '已删除错题记录' : 'Mistake entry deleted';
  String get wrongNotesClearTitle => isZh ? '一键删除错题' : 'Clear mistakes';
  String wrongNotesClearBody(String tabName) =>
      isZh ? '确认清空当前页签下的全部$tabName吗？此操作不可撤销。'
          : 'Clear all $tabName on this tab? This cannot be undone.';
  String get wrongNotesClearConfirm => isZh ? '一键清空' : 'Clear all';
  String wrongNotesCleared(String tabName) => isZh ? '已清空$tabName' : 'Cleared $tabName';
  String get wrongNotesTabVocabName => isZh ? '爬词塔错词' : 'Word Tower mistakes';
  String get wrongNotesTabExamName => isZh ? '听说读写错题' : 'Exam mistakes';
  String get wrongNotesWrongPick => isZh ? '（错选）' : '(wrong pick)';
  String get wrongNotesAppBar => isZh ? '错题笔记档案' : 'Wrong Notes';
  String get wrongNotesLoginHintTitle => isZh ? '登录后同步错题笔记' : 'Sign in to sync notes';
  String get wrongNotesLoginHintBody =>
      isZh ? '游客模式下不展示爬词塔与听说读写错题数据。' : 'Guest mode does not show tower or exam mistakes.';
  String get wrongNotesLoginCta => isZh ? '登录/注册' : 'Sign in / Register';
  String get wrongNotesToolbarClear => isZh ? '一键删除错题' : 'Clear mistakes';
  String get wrongNotesProcessing => isZh ? '处理中' : 'Working…';
  String get wrongNotesEmptyVocab => isZh ? '暂无爬词塔错词记录' : 'No Word Tower mistakes';
  String get wrongNotesFilterAll => isZh ? '全部' : 'All';
  String get wrongNotesFilterListening => isZh ? '🎧 听力' : '🎧 Listening';
  String get wrongNotesFilterReading => isZh ? '📖 阅读' : '📖 Reading';
  String get wrongNotesFilterWriting => isZh ? '✍️ 写作' : '✍️ Writing';
  String get wrongNotesFilterSpeaking => isZh ? '🗣️ 口语' : '🗣️ Speaking';
  String get wrongNotesEmptyFiltered => isZh ? '该分类下暂无错题记录' : 'No mistakes in this filter';
  String get wrongNotesPracticeTag => isZh ? '📝 练习' : '📝 Practice';
  String get wrongNotesTooltipDelete => isZh ? '删除' : 'Delete';
  String get wrongNotesReviewPending => isZh ? '待复习' : 'To review';
  String get wrongNotesActionView => isZh ? '查看' : 'View';

  // —— Anonymous voice match ——
  String get voiceMatchAppBarTitle => isZh ? '匿名电波' : 'Blind Box Radio';
  String get voiceMatchIdleHeadline =>
      isZh ? '匿名电波匹配' : 'Anonymous Radio Match';
  String get voiceMatchIdleBody => isZh
      ? '放下英语口语的包袱，我们为你连接全网同频烤鸭，进行 1 分钟随机话题交流。'
      : 'Drop the fear—match with IELTS learners worldwide for a 1-minute random-topic voice chat.';
  String get voiceMatchFeature1Title =>
      isZh ? '完全匿名' : 'Fully anonymous';
  String get voiceMatchFeature1Sub => isZh
      ? '使用虚拟化身，避免社交尴尬'
      : 'Avatars help you skip awkward small talk.';
  String get voiceMatchFeature2Title =>
      isZh ? '雅思全真题库' : 'IELTS cue bank';
  String get voiceMatchFeature2Sub => isZh
      ? '自动分发 Part 2 话题卡打破僵局'
      : 'Part 2 cue cards break the ice automatically.';
  String get voiceMatchEmitSignal =>
      isZh ? '发射连接信号' : 'Send match signal';
  String get voiceMatchCancelSignal =>
      isZh ? '终止信号发射' : 'Cancel matching';
  String get voiceMatchBackLobby =>
      isZh ? '返回电波大厅' : 'Back to lobby';
  String get voiceMatchSearchingHeadline =>
      isZh ? '搜寻中…' : 'SEARCHING…';
  String get voiceMatchSearchingSub =>
      isZh ? '正在寻找语音对象' : 'Finding a voice partner…';
  String voiceMatchSecondsLeft(int s) =>
      isZh ? '匹配剩余 $s 秒' : '$s s left to match';
  String get voiceMatchFriendSentOk =>
      isZh ? '已向对方发送好友请求' : 'Friend request sent';
  String get voiceMatchFriendSentToast =>
      isZh ? '已发送好友请求！' : 'Friend request sent!';
  String get voiceMatchSummaryTitle =>
      isZh ? '通话结束' : 'Call ended';
  String voiceMatchElapsedLabel(String mmss) =>
      isZh ? '交流时长: $mmss' : 'Duration: $mmss';
  String get voiceMatchAddFriend =>
      isZh ? '👋  加为好友' : '👋  Add friend';
  String get voiceMatchSignalConnected =>
      isZh ? '信号已接通' : 'SIGNAL CONNECTED';
  String get voiceMatchPart2TopicLabel =>
      isZh ? 'Part 2 讨论话题' : 'Part 2 Discussion Topic';
  String get voiceMatchYouLabel => isZh ? '你' : 'You';

  // —— News brief mock ——
  String get newsMockPaperLoadFailed => isZh ? '试卷加载失败，已使用演示卷：' : 'Paper load failed, using demo: ';
  String get newsMockGradeRequestFailed => isZh ? '批改请求失败，已使用本地核对：' : 'Grading failed, using local: ';
  String get newsMockExamTimeEnded =>
      isZh ? '模考时间已结束，仍可继续编辑并提交。' : 'Exam time is over; you may still edit and submit.';
  String newsMockSpeakingRecording(String elapsed, String max) => isZh
      ? '模拟录音中 $elapsed / $max · 点击麦克风停止'
      : 'Recording $elapsed / $max · Tap mic to stop';
  String get newsMockSpeakingDoneHint => isZh
      ? '已完成模拟录音 · 可在上方补充口述要点 · 演示模式无回放 · 点击麦克风将重新模拟'
      : 'Recording saved · Add notes above · No playback in demo · Tap mic to redo';
  String get newsMockSpeakingIdleHint => isZh
      ? '点击麦克风模拟录音（最长 2 分钟）· 提交后 AI 将给出口语详评'
      : 'Tap mic to simulate recording (max 2 min) · Submit for speaking feedback';
  String get newsMockPlaybackDemoOnly =>
      isZh ? '演示模式无音频文件，无法回放' : 'Demo mode: no audio to play back';
  String get newsMockTitleAccessDenied => isZh ? '环球快讯模考' : 'Global News Mock';
  String get newsMockMonthlyLimitTitle => isZh ? '本月环球快讯模考次数已用完' : 'Monthly mock attempts used';
  String get newsMockMonthlyLimitBody => isZh
      ? 'Pro 会员每日不限使用，并可选择往期语料模考。\n可在「我的」页订阅 Pro。'
      : 'Pro members get unlimited mocks and past papers.\nSubscribe to Pro in Profile.';
  String get newsMockGoSubscribe => isZh ? '前往「我的」订阅 Pro' : 'Go to Profile · Subscribe';
  String get newsMockHelpTitle => isZh ? '模考说明' : 'About this mock';
  String get newsMockHelpBody => isZh
      ? '每日全员共用同一份阅读语料（东八区日期）。构建时使用 NEWS_MOCK_DAILY_BASE_URL 指向静态目录（勿尾缀 /）；服务端可用 server/news-daily/generate.mjs 生成 JSON。提交批改需配置 DASHSCOPE_API_KEY。未配置分发地址时使用内置演示卷。'
      : 'Everyone shares the same daily paper (China timezone). Set NEWS_MOCK_DAILY_BASE_URL (no trailing slash); optional generate.mjs. Grading needs DASHSCOPE_API_KEY; otherwise a built-in demo paper is used.';
  String get newsMockPastPaperLabel => isZh ? '语料日期（往期）' : 'Paper date (past)';
  String get newsMockLoadingPaper => isZh ? '正在准备试卷…' : 'Loading paper…';
  String get newsMockSectionWritingTask2 => isZh ? '写作 Task 2' : 'Writing Task 2';
  String get newsMockSectionSpeakingPart2 => isZh ? '口语 Part 2' : 'Speaking Part 2';
  String get newsMockSectionReadingShort => isZh ? '阅读' : 'Reading';
  String get newsMockSectionWritingShort => isZh ? '写作' : 'Writing';
  String get newsMockSectionSpeakingShort => isZh ? '口语' : 'Speaking';
  String get newsMockAppBarBrand => isZh ? '今日快讯模考' : 'News Mock';
  String get newsMockSourceLabel => isZh ? '语料来源' : 'Source';
  String get newsMockExpandFull => isZh ? '展开全文' : 'Expand full text';
  String get newsMockEssayHint => isZh ? '在此输入作文' : 'Type your essay here';
  String get newsMockSpeakingNotesHint => isZh
      ? '口述要点（可选；模拟录音后留空提交时将自动附带题目上下文供 AI 详评）'
      : 'Speaking notes (optional; if empty after demo recording, context is auto-filled for AI)';
  String get newsMockClearText => isZh ? '清空文字' : 'Clear text';
  String get newsMockDeleteRecording => isZh ? '删除录音' : 'Delete recording';
  String get newsMockStopPlayback => isZh ? '停止回放' : 'Stop';
  String get newsMockPlayback => isZh ? '回放录音' : 'Play recording';
  String get newsMockMicLevelRecording => isZh ? '麦克风输入（实时电平）' : 'Mic input (level)';
  String get newsMockMicLevelIdle =>
      isZh ? '开始录音后显示实时输入' : 'Levels appear while recording';
  String get newsMockClearSpeaking => isZh ? '清空口语（文字 + 录音）' : 'Clear speaking (text + recording)';
  String get newsMockSubmitGrading => isZh ? '批改中…' : 'Grading…';
  String get newsMockSubmit => isZh ? '提交答卷' : 'Submit';

  /// 提交后等待模型返回评价（环球快讯 / 写作 AI / 口语演示延迟等共用）。
  String get practiceAiGeneratingFeedback =>
      isZh ? 'AI 正在生成评价…' : 'Generating AI feedback…';
  String get newsMockGradeTitle => isZh ? '批改结果' : 'Results';
  String get newsMockGradeFullExamBadge => isZh
      ? '全科模考报告 · 阅读 / 写作 / 口语合并展示（与「听说读写 · 写作专项」面板区分）'
      : 'Full mock report · Reading / Writing / Speaking (distinct from Daily Writing panel)';
  String newsMockReadingCorrectCount(int c, int t) =>
      isZh ? '正确 $c / $t' : 'Correct $c / $t';
  String newsMockGradeYourChoice(String q, bool ok, String user) => isZh
      ? '$q ${ok ? '✓' : '✗'}  你的选项：$user'
      : '$q ${ok ? '✓' : '✗'}  Your choice: $user';
  String newsMockGradeCorrectAnswer(String a) =>
      isZh ? '参考答案：$a' : 'Answer: $a';

  static String _bandStr(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  String newsMockWritingBandsLine(double tr, double cc, double lr, double gra, double ov) {
    return isZh
        ? 'TR ${_bandStr(tr)}  CC ${_bandStr(cc)}  LR ${_bandStr(lr)}  GRA ${_bandStr(gra)}  总分 ${_bandStr(ov)}'
        : 'TR ${_bandStr(tr)}  CC ${_bandStr(cc)}  LR ${_bandStr(lr)}  GRA ${_bandStr(gra)}  Overall ${_bandStr(ov)}';
  }

  String newsMockSpeakingBandsLine(double fluency, double lexical, double grammar, double pronunciation, double ov) {
    return isZh
        ? '流利 ${_bandStr(fluency)}  词汇 ${_bandStr(lexical)}  语法 ${_bandStr(grammar)}  发音 ${_bandStr(pronunciation)}  总分 ${_bandStr(ov)}'
        : 'FL ${_bandStr(fluency)}  LR ${_bandStr(lexical)}  GR ${_bandStr(grammar)}  PR ${_bandStr(pronunciation)}  Overall ${_bandStr(ov)}';
  }

  String get newsMockNoWritingFeedback => isZh ? '（无写作点评）' : '(No writing feedback)';
  String get newsMockNoSpeakingFeedback => isZh ? '（无口语点评）' : '(No speaking feedback)';

  /// 环球快讯模考批改面板 · 口语区块：预设模拟 AI 长点评（与每日任务口语伪点评区分语境）
  String get newsMockSpeakingPseudoFeedbackBody => isZh
      ? '【流利度与连贯性】你在新闻语境下能抓住主线，表述较为连贯；可在例证与结论之间增加一句小结，使论证更紧凑。\n'
          '【词汇资源】话题词汇覆盖尚可；可将个别高频词替换为更精准的报刊用语（如 increase → surge/soar）。\n'
          '【语法范围与准确性】句子结构多样，注意长句中的指代一致与时态呼应。\n'
          '【发音】当前基于文本稿推断发音分项，仅供参考；朗读新闻时可刻意练习重读信息词与意群停顿。\n\n'
          '综合建议：用手机录音复述当日快讯要点 1–2 分钟，对照原文勾选 5 个关键词再即兴串联，有助于提升即兴口语与词汇准确度。'
      : 'Fluency & coherence: You keep the news thread clear; add one bridging sentence between examples and your takeaway.\n'
          'Lexical resource: Swap a few generic words for sharper news vocabulary (e.g. increase → surge).\n'
          'Grammar: Watch agreement in longer clauses when summarizing sources.\n'
          'Pronunciation: Score is illustrative from text—stress content words and chunk phrases like a newsreader.\n\n'
          'Next steps: Record 1–2 minutes summarizing the daily brief, pick five keywords from the article, then freewheel from those cues.';

  String get newsMockGradeClose => isZh ? '关闭' : 'Close';

  // —— Daily task module (listening/reading/writing/speaking UI) ——
  String get dailyUnknownTask => isZh ? '未知任务类型' : 'Unknown task type';
  String dailyLoadFailed(Object? err) =>
      isZh ? '加载题库失败：$err' : 'Failed to load question bank: $err';
  String dailyListeningMetaLine(int set) =>
      isZh ? '套题 $set · Part 1–4 · 40 题' : 'Set $set · Parts 1–4 · 40 questions';
  String dailyWritingMetaLine(int set) =>
      isZh ? '套题 $set · Task 1 & Task 2' : 'Set $set · Task 1 & Task 2';
  String dailyReadingMetaLine(int test) =>
      isZh ? 'Test $test · 40 题' : 'Test $test · 40 Questions';
  String get dailySpeakingTitle => isZh ? '口语练习' : 'Speaking';
  String get dailySpeakingSubtitle => isZh ? '真题演练' : 'Practice';
  String dailyAudioPlayFailed(Object e) =>
      isZh ? '音频播放失败：$e' : 'Playback failed: $e';
  String get dailyListeningReviewTitle => isZh ? '听力批改结果' : 'Listening results';
  String get dailyViewAnswers => isZh ? '查看答案与解析' : 'Answers & explanations';
  String get dailyListeningAnswersDialogTitle => isZh ? '听力答案与解析' : 'Listening answers';
  String get dailyListeningImageMissing =>
      isZh ? '请将 listening.png 放入 resource/ 文件夹' : 'Place listening.png in resource/';
  String get dailySubmitGrade => isZh ? '提交并批改' : 'Submit & review';
  String get dailyNoAnalysis => isZh ? '暂无解析' : 'No explanation';
  String dailyReadingReviewTitle(int test) =>
      isZh ? '阅读批改结果 · Test $test' : 'Reading results · Test $test';
  String get dailyReadingAnswersDialogTitle => isZh ? '阅读答案与解析' : 'Reading answers';
  String get dailyReadingBodyMissing =>
      isZh ? '（未解析到正文，请检查 resource/阅读.md）' : '(No passage text — check resource/阅读.md)';
  String get dailyFillAnswerHint => isZh ? '填写答案' : 'Your answer';
  String get dailyWritingImageMissing => isZh
      ? '请将 writing.png 放入 resource/ 文件夹（Task 1 示意图）'
      : 'Place writing.png in resource/ (Task 1 image)';
  String get dailyWritingTask1Hint => isZh ? '至少 150 词…' : 'At least 150 words…';
  String get dailyWritingTask2Hint => isZh ? '至少 250 词…' : 'At least 250 words…';
  String get dailyWritingAiQuotaExceeded =>
      isZh ? '本月写作 AI 批改次数已用完（Pro 无限）。已使用规则估分。'
          : 'Monthly writing AI reviews used (Pro: unlimited). Using rule-based scores.';
  String get dailyWritingAiGrading => practiceAiGeneratingFeedback;
  String get dailyWritingAiFailed =>
      isZh ? 'AI 批改失败，已退回规则估分：' : 'AI grading failed; using rules: ';
  String get dailyWritingViewModels => isZh ? '查看范文参考' : 'Model answers';
  String get dailyWritingModelsTitle => isZh ? 'Task1/Task2 范文' : 'Task 1 / Task 2 models';
  String get dailyWritingRulesTitle => isZh ? '写作解析' : 'Writing scoring notes';
  String get dailyWritingRulesBody => isZh
      ? '评分按 IELTS 四项标准估分：\n1) 字数是否达标（Task1≥150，Task2≥250）\n2) 段落组织与连接词\n3) 词汇多样性\n4) 句法多样性与基础准确性'
      : 'IELTS-style estimate:\n1) Word count (Task 1 ≥150, Task 2 ≥250)\n2) Paragraphing & cohesion\n3) Lexical range\n4) Grammar range & accuracy';
  String get dailyWritingViewModelsShort => isZh ? '查看范文' : 'Model answers';
  String dailyWritingHeuristicSummary(int w1, int w2) => isZh
      ? '当前为本地规则估分（未调用百炼模型）。依据字数、段落拆分、词汇多样性与标点粗略估算四项分数，仅供参考。\n\nTask 1 字数：$w1（建议≥150）；Task 2 字数：$w2（建议≥250）。'
      : 'Rule-based estimate (no cloud model). Based on length, paragraphs, vocabulary diversity, and punctuation.\n\nTask 1 words: $w1 (aim ≥150); Task 2 words: $w2 (aim ≥250).';
  String get dailyReviewIeltsEstimate => isZh ? 'IELTS 估分' : 'IELTS band';
  String dailyReviewCorrectSummary(String raw) =>
      isZh ? '答对 $raw（按雅思听力/阅读换算）' : 'Correct $raw (listening/reading conversion)';
  String get dailyReviewPerQuestion => isZh ? '逐题核对' : 'Review by question';
  String dailyReviewYourVsCorrect(int n, String u, String r) => isZh
      ? 'Q$n: 你的答案 $u / 正确答案 $r'
      : 'Q$n: Your answer $u / Correct $r';
  String get skillSpeaking => isZh ? '口语' : 'Speaking';

  // Daily writing AI review sheet (panel copy)
  String get dailyWritingPanelLine1 => isZh ? '听说读写 · 写作全真' : 'Practice · Writing full test';
  String get dailyWritingPanelLine2 => isZh ? 'AI 全方位评价' : 'AI full feedback';
  String get dailyWritingPanelBadge => isZh
      ? '专项报告：仅批改 Task 1 + Task 2。环球快讯模考使用另一套「全科」面板（阅读/写作/口语合一）。'
      : 'Writing-only report (Task 1+2). News mock uses a different full-test panel (Reading/Writing/Speaking).';
  String get dailyWritingPanelOverallTitle => isZh ? '写作总分 · Overall Band' : 'Overall band';
  String get dailyWritingPanelSubtitleAi =>
      isZh ? '阿里云百炼 · 雅思写作四维分项 + 综合详评' : 'DashScope · TR/CC/LR/GRA + summary';
  String get dailyWritingPanelSubtitleLocal =>
      isZh ? '本地规则估分 · 配置 DASHSCOPE_API_KEY 可启用全文 AI 批改'
          : 'Rule estimate · Set DASHSCOPE_API_KEY for full AI review';
  String get dailyWritingPanelFourDims => isZh ? '四项维度' : 'Four criteria';
  String get dailyWritingDimTaskResponse => isZh ? '任务回应' : 'Task response';
  String get dailyWritingDimCc => isZh ? '连贯衔接' : 'Cohesion';
  String get dailyWritingDimLr => isZh ? '词汇资源' : 'Lexical resource';
  String get dailyWritingDimGra => isZh ? '语法范围与准确' : 'Grammar range & accuracy';
  String get dailyWritingSectionSummaryTitle => isZh ? '综合点评' : 'Overview';
  String get dailyWritingSectionSummarySub =>
      isZh ? 'TR / CC / LR / GRA 交叉分析与备考建议' : 'Cross-skill analysis & study tips';
  String get dailyWritingSectionT1Title => isZh ? 'Task 1 · 深度解析' : 'Task 1 · Deep dive';
  String get dailyWritingSectionT1Sub =>
      isZh ? '图表/流程类任务回应与语言' : 'Charts/process — task response & language';
  String get dailyWritingSectionT2Title => isZh ? 'Task 2 · 深度解析' : 'Task 2 · Deep dive';
  String get dailyWritingSectionT2Sub =>
      isZh ? '议论文论点、论证与词汇语法' : 'Essay argumentation & language';
  String get dailyWritingPanelFootnoteAi => isZh
      ? '分项分数由模型按雅思标准估算；下方「深度解析」含可执行的修改思路与表达升级。'
      : 'Scores follow IELTS criteria; sections below include actionable edits.';
  String get dailyWritingPanelFootnoteLocal => isZh
      ? '当前未调用云端模型；启用百炼后可获得与上方相同结构的 AI 详评。'
      : 'No cloud model yet; with DashScope you get the same structured AI feedback.';
  String get dailyWritingNoneYet => isZh ? '（暂无）' : '(None)';
  String get dailySpeakingAiTitle => isZh ? '口语 AI 点评' : 'Speaking AI feedback';
  String get dailySpeakingAiSubtitleAi =>
      isZh ? '阿里云百炼 · 基于文本稿与题目（发音为推断）' : 'DashScope · from text & cue (pronunciation inferred)';
  String get dailySpeakingAiSubtitleLocal =>
      isZh ? '本地占位估分 · 配置 DASHSCOPE_API_KEY 启用百炼' : 'Local estimate · set API key for DashScope';
  String get dailySpeakingFeedbackLabel => isZh ? '详细反馈' : 'Detailed feedback';
  String get dailySpeakingRecordFirst =>
      isZh ? '请先点击麦克风完成一段模拟录音' : 'Finish a simulated recording first';
  String dailySpeakingTranscriptTooShort(int min) => isZh
      ? '请填写录音文本稿至少 $min 字（可回放后听写要点），以便 AI 点评'
      : 'Enter at least $min characters in the transcript for AI feedback';
  String get dailySpeakingAiQuotaExceeded =>
      isZh ? '本月口语 AI 点评次数已用完（Pro 无限），已使用本地规则估分。'
          : 'Monthly speaking AI reviews used (Pro: unlimited). Using local estimate.';
  String dailySpeakingAiFailed(Object e) =>
      isZh ? '口语 AI 点评失败：$e' : 'Speaking AI failed: $e';
  String get dailySpeakingCueMissing =>
      isZh ? '（未从 resource/口语.md 解析到题目，请检查资源文件）'
          : '(No cue in resource/口语.md — check files)';
  String get dailySpeakingPlaybackDemo =>
      isZh ? '演示模式无音频文件，无法回放' : 'Demo mode: no audio playback';
  String dailyPlaybackFailed(Object e) => isZh ? '无法播放：$e' : 'Cannot play: $e';
  String dailySpeakingRecordingHint(String elapsed, String max) => isZh
      ? '模拟录音中 $elapsed / $max · 点击麦克风停止'
      : 'Recording $elapsed / $max · Tap mic to stop';
  String get dailySpeakingRecordedHint => isZh
      ? '已完成模拟录音 · 可在下方补充文本要点 · 演示模式无回放 · 点击麦克风将重新模拟'
      : 'Saved · add notes below · no playback in demo · tap mic to redo';
  String get dailySpeakingIdleHint => isZh
      ? '点击麦克风开始模拟录音（最长 2 分钟）· 再次点击停止 · 提交 AI 将生成详细口语点评'
      : 'Tap mic to simulate (max 2 min) · tap again to stop · submit for AI feedback';
  String get dailySpeakingPanelLabel => isZh ? '真题演练 · 当前题目' : 'Practice · Current cue';
  String get dailySpeakingShuffle => isZh ? '随机换题' : 'Shuffle';
  String get dailySpeakingDeleteRecording => isZh ? '删除录音' : 'Delete clip';
  String get dailySpeakingMicLevelRecording =>
      isZh ? '模拟输入电平（演示）' : 'Simulated input level';
  String get dailySpeakingMicLevelIdle =>
      isZh ? '开始模拟录音后显示演示电平' : 'Levels show while simulating';
  String dailySpeakingTranscriptHint(int min) => isZh
      ? '口述要点（可选补充；留空提交时将附带题目由 AI 生成详评，≥$min 字可跳过合成稿）'
      : 'Notes (optional; ≥$min chars skips auto draft on submit)';
  String get dailySpeakingSubmitAi => isZh ? '百炼点评中…' : 'Grading…';
  String get dailySpeakingSubmitLabel =>
      isZh ? '提交 AI 点评（百炼）' : 'Submit for AI feedback';

  /// 每日任务口语：伪 AI 演示 — Sheet 副标题
  String get dailySpeakingPseudoSubtitle =>
      isZh ? '演示 · 模拟 AI 生成评价（预设范文）' : 'Demo · simulated AI feedback (canned)';

  /// 每日任务口语：伪 AI 演示 — 预设长点评正文
  String get dailySpeakingPseudoFeedbackBody => isZh
      ? '【流利度与连贯性】整体表达流畅，能围绕题目展开并适当使用连接词。建议在对比类问题上增加一两句总结性陈述，使逻辑闭环更清晰。\n'
          '【词汇资源】用词准确，学术与生活词汇有一定混合；可替换少量重复形容词（如 important → crucial/significant），提升多样性。\n'
          '【语法范围与准确性】复杂句使用得当，偶有时态呼应可再检查；条件句与从句结构继续保持。\n'
          '【发音】当前为文本稿点评，发音分项为演示估值；正式考试请注重句末降调与意群停顿。\n\n'
          '综合建议：坚持录音复述当天题目约 2 分钟，并将关键词写在卡片上做即兴串联；一周后复用同一逻辑骨架可提升连贯度与自信。'
      : 'Fluency & coherence: You stay on topic and link ideas clearly. Add a short closing sentence on contrast questions to tighten the arc.\n'
          'Lexical resource: Word choice is accurate; swap a few repeated words (e.g. important → crucial/significant) for range.\n'
          'Grammar: Complex sentences work well; double-check tense agreement on longer clauses.\n'
          'Pronunciation: Illustrative only from text—in practice focus on falling intonation and chunking.\n\n'
          'Next steps: Record ~2 minutes daily from cue keywords on cards; reuse the same outline weekly to build fluency and confidence.';

  String dailyListeningOfficialAnswerLine(String right) =>
      isZh ? '官方答案：$right' : 'Official answer: $right';
  String get dailyListeningPair2122 => isZh ? 'Part 3 · Questions 21–22（选两项）' : 'Part 3 · Q21–22 (pick two)';
  String get dailyListeningPair2324 => isZh ? 'Part 3 · Questions 23–24（选两项）' : 'Part 3 · Q23–24 (pick two)';
  String get dailyListeningPart2Mcq =>
      isZh ? 'Part 2 · Questions 11–15' : 'Part 2 · Questions 11–15';
  String get dailyListeningPart2Map =>
      isZh ? 'Part 2 · Questions 16–20 · Map' : 'Part 2 · Questions 16–20 · Map';
  String get dailyListeningPart3_25_30 =>
      isZh ? 'Part 3 · Questions 25–30' : 'Part 3 · Questions 25–30';
  String get dailyListeningPart4_31_40 =>
      isZh ? 'Part 4 · Questions 31–40' : 'Part 4 · Questions 31–40';

  String dailyReadingPassageTab(String letter) =>
      isZh ? 'Passage $letter' : 'Passage $letter';

  String dailyReadingAnalysisLine(String analysis) =>
      isZh ? '解析：$analysis' : 'Analysis: $analysis';

  String get dailyWritingSubmitForAiReview =>
      isZh ? '提交 AI 批改' : 'Submit for AI review';

  String dailyWritingWordsProgress(int words, int minPlus) =>
      isZh ? '字数：$words / $minPlus+' : 'Words: $words / $minPlus+';

  String get dailyWritingViewRulesLabel =>
      isZh ? '查看规则说明' : 'View scoring notes';

  String dailyWrongNoteListeningTitle(int q) =>
      isZh ? 'Q$q · 听力' : 'Q$q · Listening';

  String dailyWrongNoteReadingTitle(int q, int test) =>
      isZh ? 'Q$q · 阅读 · Test $test' : 'Q$q · Reading · Test $test';

  String dailyWrongNoteAnswerSummary(String user, String right) =>
      isZh ? '你的答案：$user；正确答案：$right'
          : 'Your answer: $user; Correct: $right';

  String dailyPracticeRewardSnackBar(int granted, int balance) =>
      isZh ? '每日任务 +$granted E点（余额 $balance）'
          : 'Daily task +$granted E-Points (balance $balance)';

  String get dailySpeakingFeedbackEmpty =>
      isZh ? '（无）' : '(None)';

  String dailyReadingLetterLabel(String letter) => isZh ? '阅读 $letter' : 'Reading $letter';
}
