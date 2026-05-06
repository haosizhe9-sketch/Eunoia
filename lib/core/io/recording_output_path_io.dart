import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 原生端优先临时目录；`path_provider` 未注册时退回系统临时目录（仍落在本机可写路径）。
Future<String> recordingOutputFilePath(String ext) async {
  final int ts = DateTime.now().millisecondsSinceEpoch;
  try {
    final dynamic dir = await getTemporaryDirectory();
    return '${dir.path}/eunoia_speaking_$ts.$ext';
  } on Object catch (_) {
    return '${Directory.systemTemp.path}/eunoia_speaking_$ts.$ext';
  }
}
