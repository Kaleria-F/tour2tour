import 'dart:typed_data';

bool isBrowserAudioRecordingSupported() => false;

Future<bool> requestBrowserMicrophoneAccess() async => false;

class BrowserAudioRecorder {
  bool get isSupported => false;

  String? get mimeType => null;

  Future<bool> requestAccess() async => false;

  Future<void> start() async {
    throw UnsupportedError('Browser audio recording is unavailable.');
  }

  Future<Uint8List> stop() async => Uint8List(0);

  Future<void> cancel() async {}
}
