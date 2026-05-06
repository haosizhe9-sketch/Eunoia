import 'recording_output_path_stub.dart'
    if (dart.library.io) 'recording_output_path_io.dart' as path_impl;

Future<String> recordingOutputFilePath(String ext) =>
    path_impl.recordingOutputFilePath(ext);
