import 'dart:async';
import 'dart:html' as html;

Future<bool> requestBrowserMicrophoneAccess() async {
  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) {
    return false;
  }

  try {
    final stream = await mediaDevices.getUserMedia(<String, dynamic>{
      'audio': true,
      'video': false,
    });
    for (final track in stream.getTracks()) {
      track.stop();
    }
    return true;
  } catch (_) {
    return false;
  }
}
