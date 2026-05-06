// 运维：生成一份可上传分发的每日试卷 JSON（与 App 拉取的 schema 一致）。
// 用法（项目根目录）：
//   dart run --define=DASHSCOPE_API_KEY=sk-xxxx tool/gen_news_mock_daily.dart > news_mock_daily_2026-05-01.json
//
// 将文件放到静态资源或写入 news_mock_daily_papers.paper_json，路径约定见 NewsMockAIService。

import 'dart:convert';
import 'dart:io';

import 'package:eunoia/core/services/news_mock_ai_service.dart';

Future<void> main() async {
  final NewsMockAIService svc = NewsMockAIService();
  if (!svc.hasApiKey) {
    stderr.writeln('缺少 DASHSCOPE_API_KEY，无法调用模型。');
    exitCode = 64;
    return;
  }
  final NewsMockPaper paper = await svc.generatePaper();
  stdout.writeln(JsonEncoder.withIndent('  ').convert(paper.toJson()));
}
