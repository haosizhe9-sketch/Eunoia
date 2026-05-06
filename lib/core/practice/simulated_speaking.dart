// 演示模式：不采集真实麦克风，仅模拟录音 UI 与时长；提交时用合成文本供 AI 批改。

const String kSimulatedRecordingPathSentinel = '__eunoia_simulated_recording__';

bool isSimulatedRecordingPath(String? path) =>
    path != null && path == kSimulatedRecordingPathSentinel;

String formatSpeakingDurationMmSs(Duration d) {
  final int m = d.inMinutes.remainder(60);
  final int s = d.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 每日任务 · 真题演练口语：无真实音频时的合成「自述稿」。
String buildDailySpeakingSimulatedTranscript({
  required String cue,
  required Duration duration,
  required String userNotes,
}) {
  final String notes =
      userNotes.trim().isEmpty ? '（考生未在文本框补充要点）' : userNotes.trim();
  return '''
【模拟录音已完成｜演示模式】未采集真实麦克风音频，记录用时 ${formatSpeakingDurationMmSs(duration)}。
本场题目：$cue

考生在文本框中补充的内容：$notes

请基于题目与上述要点，按雅思口语四项给出评分与详尽反馈；发音项请说明：当前为演示流程且无音频文件，发音分宜视为基于文本连贯性与词汇难度的推断。
'''
      .trim();
}

/// 环球快讯模考 · 口语：无真实音频时的合成作答文本（写入批改 prompt）。
String buildNewsMockSimulatedSpeakingBody({
  required String cue,
  required String hints,
  required Duration duration,
  required String userNotes,
}) {
  final String notes =
      userNotes.trim().isEmpty ? '（考生未在文本框填写口述要点）' : userNotes.trim();
  return '''
【模拟录音已完成｜演示模式】未采集真实麦克风音频，演示用时 ${formatSpeakingDurationMmSs(duration)}。

口语题：$cue
提示：$hints

考生在文本框中的补充：$notes

请结合题目与上述文字进行雅思口语四维评分，并在反馈中说明：演示模式下无音频文件，发音评价为基于文本的推断。
'''
      .trim();
}
