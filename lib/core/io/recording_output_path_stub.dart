/// Web：不向 `path_provider` 发通道调用（避免 MissingPluginException），
/// `record` 在 Web 上会忽略 path，仅用文件名占位。
Future<String> recordingOutputFilePath(String ext) async {
  return 'eunoia_speaking_${DateTime.now().millisecondsSinceEpoch}.$ext';
}
