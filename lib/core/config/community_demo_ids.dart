/// 社交 / 匿名语聊演示用 NPC（UUID 与账号约定见 [CommunitySocialRepository.ensureDemoSocialScenario]）。
abstract final class CommunityDemoIds {
  CommunityDemoIds._();

  static const String npcMia = 'f1000000-0000-4000-8000-000000000001';
  static const String npcAlex = 'f2000000-0000-4000-8000-000000000002';
  static const String npcDiary = 'f3000000-0000-4000-8000-000000000003';

  /// 语聊模拟结束后「加好友」指向的用户（烤鸭_Mia）。
  static const String voicePeerUserId = npcMia;
}
