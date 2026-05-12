import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

final _dataAvailableEvent = html.EventStreamProvider<html.BlobEvent>('dataavailable');
final _stopEvent = html.EventStreamProvider<html.Event>('stop');

bool isBrowserAudioRecordingSupported() {
  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) {
    return false;
  }
  return _preferredAudioMimeType() != null;
}

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

class BrowserAudioRecorder {
  html.MediaRecorder? _mediaRecorder;
  html.MediaStream? _stream;
  StreamSubscription<html.BlobEvent>? _dataSub;
  StreamSubscription<html.Event>? _errorSub;
  final List<html.Blob> _chunks = <html.Blob>[];
  String? _mimeType;

  bool get isSupported => isBrowserAudioRecordingSupported();

  String? get mimeType => _mimeType ?? _preferredAudioMimeType();

  Future<bool> requestAccess() => requestBrowserMicrophoneAccess();

  Future<void> start() async {
    if (!isSupported) {
      throw UnsupportedError('MediaRecorder is not supported in this browser.');
    }
    await cancel();
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw UnsupportedError('Microphone access is not available.');
    }
    final stream = await mediaDevices.getUserMedia(<String, dynamic>{
      'audio': true,
      'video': false,
    });
    final preferredMimeType = _preferredAudioMimeType();
    _mimeType = preferredMimeType;
    final recorder = preferredMimeType == null
        ? html.MediaRecorder(stream)
        : html.MediaRecorder(
            stream,
            <String, dynamic>{'mimeType': preferredMimeType},
          );
    _stream = stream;
    _mediaRecorder = recorder;
    _chunks.clear();
    _dataSub = _dataAvailableEvent.forTarget(recorder).listen((event) {
      final blob = event.data;
      if (blob != null && blob.size > 0) {
        _chunks.add(blob);
      }
    });
    _errorSub = recorder.onError.listen((_) {});
    recorder.start();
  }

  Future<Uint8List> stop() async {
    final recorder = _mediaRecorder;
    if (recorder == null) {
      return Uint8List(0);
    }
    final stopCompleter = Completer<Uint8List>();
    late StreamSubscription<html.Event> stopSub;
    stopSub = _stopEvent.forTarget(recorder).listen((_) async {
      await stopSub.cancel();
      final blob = html.Blob(
        List<html.Blob>.from(_chunks),
        _mimeType ?? 'audio/webm',
      );
      final bytes = await _blobToBytes(blob);
      _reset(stopTracks: true);
      if (!stopCompleter.isCompleted) {
        stopCompleter.complete(bytes);
      }
    });
    if (recorder.state != 'inactive') {
      recorder.stop();
    } else {
      await stopSub.cancel();
      _reset(stopTracks: true);
      return Uint8List(0);
    }
    return stopCompleter.future.timeout(const Duration(seconds: 5));
  }

  Future<void> cancel() async {
    final recorder = _mediaRecorder;
    if (recorder != null && recorder.state != 'inactive') {
      recorder.stop();
    }
    _reset(stopTracks: true);
  }

  void _reset({required bool stopTracks}) {
    _dataSub?.cancel();
    _dataSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    if (stopTracks) {
      final tracks = _stream?.getTracks() ?? const <html.MediaStreamTrack>[];
      for (final track in tracks) {
        track.stop();
      }
    }
    _mediaRecorder = null;
    _stream = null;
    _chunks.clear();
  }
}

String? _preferredAudioMimeType() {
  const candidates = <String>[
    'audio/ogg;codecs=opus',
    'audio/ogg',
    'audio/webm;codecs=opus',
    'audio/webm',
  ];
  try {
    for (final candidate in candidates) {
      if (html.MediaRecorder.isTypeSupported(candidate)) {
        return candidate;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<Uint8List> _blobToBytes(html.Blob blob) {
  final completer = Completer<Uint8List>();
  final reader = html.FileReader();
  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
      return;
    }
    if (result is Uint8List) {
      completer.complete(result);
      return;
    }
    completer.complete(Uint8List(0));
  });
  reader.onError.listen((_) {
    completer.completeError(StateError('Unable to read recorded audio bytes.'));
  });
  reader.readAsArrayBuffer(blob);
  return completer.future;
}
