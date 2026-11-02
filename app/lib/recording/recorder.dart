import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:lc3_codec/lc3_codec.dart';

import '../g1/g1_connection.dart';
import '../settings.dart';

/// Records the glasses microphone into a WAV file and sends it to
/// WhisperNotes, which transcribes and summarises it and files the summary
/// in BasaltNotes (if a standard vault is set up there).
///
/// Unsent recordings stay in the app's cache folder and are sent again on
/// the next start or on request.
class VoiceRecorder extends ChangeNotifier {
  VoiceRecorder(this.g1, this.settings, this._log, {Directory? folder})
    : _folderOverride = folder;

  final G1Connection g1;
  final Settings settings;
  final void Function(String) _log;
  final Directory? _folderOverride;

  static const sampleRate = 16000;

  /// Shorter recordings are discarded.
  static const minDuration = Duration(seconds: 2);

  bool get recording => _file != null;
  DateTime? startedAt;
  Duration get elapsed => startedAt == null
      ? Duration.zero
      : DateTime.now().difference(startedAt!);

  /// Recordings waiting to be sent.
  int pending = 0;
  bool uploading = false;

  /// Result of the last upload, shown in the app.
  String? lastResult;

  RandomAccessFile? _file;
  File? _path;
  int _dataBytes = 0;
  Lc3Decoder? _decoder;
  StreamSubscription<Uint8List>? _audioSub;
  Timer? _keepAlive;
  DateTime _lastAudio = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _writes = Future.value();

  Future<Directory> _folder() async {
    final dir =
        _folderOverride ??
        Directory('${Directory.systemTemp.path}/even_g1_recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Starts recording; the microphone is (re)enabled whenever the glasses
  /// are connected and no audio arrives.
  Future<void> start() async {
    if (recording) return;
    final now = DateTime.now();
    final dir = await _folder();
    String two(int v) => v.toString().padLeft(2, '0');
    final name =
        'Brillen-Notiz ${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    final path = File('${dir.path}/$name.wav');
    final file = await path.open(mode: FileMode.write);
    await file.writeFrom(_wavHeader(0));
    _file = file;
    _path = path;
    _dataBytes = 0;
    startedAt = now;
    await File('${path.path}.json').writeAsString(
      jsonEncode({'recorded_at': now.toIso8601String()}),
    );

    final decoder = Lc3Decoder();
    _decoder = decoder;
    _audioSub = g1.audio.listen((lc3) {
      _lastAudio = DateTime.now();
      final Uint8List pcm;
      try {
        pcm = decoder.decode(lc3);
      } catch (e) {
        _log('Aufnahme: $e');
        return;
      }
      _dataBytes += pcm.length;
      _writes = _writes.then((_) => file.writeFrom(pcm));
    });
    _keepAlive = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _ensureMic(),
    );
    _log('Aufnahme gestartet');
    notifyListeners();
    await _ensureMic(force: true);
  }

  Future<void> _ensureMic({bool force = false}) async {
    if (!recording || !g1.connected) return;
    final silent = DateTime.now().difference(_lastAudio);
    if (!force && silent < const Duration(seconds: 3)) return;
    if (!force) _log('Aufnahme: Mikrofon neu gestartet');
    await g1.setMic(true);
  }

  /// Stops recording and sends the file. Returns false if the recording was
  /// too short and was discarded.
  ///
  /// [releaseMic] is false while Assist still needs the microphone.
  Future<bool> stop({bool releaseMic = true}) async {
    final file = _file;
    final path = _path;
    if (file == null || path == null) return false;
    _keepAlive?.cancel();
    await _audioSub?.cancel();
    _audioSub = null;
    _file = null;
    _path = null;
    final duration = elapsed;
    startedAt = null;
    if (releaseMic && g1.connected) await g1.setMic(false);
    await _writes;
    await file.setPosition(0);
    await file.writeFrom(_wavHeader(_dataBytes));
    await file.close();
    _decoder?.dispose();
    _decoder = null;
    notifyListeners();

    final seconds = _dataBytes / (sampleRate * 2);
    if (seconds < minDuration.inSeconds) {
      _log('Aufnahme verworfen (zu kurz)');
      await _delete(path);
      return false;
    }
    _log(
      'Aufnahme beendet: ${_format(Duration(seconds: seconds.round()))} '
      '(Dauer ${_format(duration)})',
    );
    unawaited(sendPending());
    return true;
  }

  /// Sends all recordings that were not sent yet.
  Future<void> sendPending() async {
    if (uploading) return;
    final dir = await _folder();
    final files =
        (await dir.list().toList())
            .whereType<File>()
            .where((f) => f.path.endsWith('.wav') && f.path != _path?.path)
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    pending = files.length;
    notifyListeners();
    if (files.isEmpty) return;
    if (settings.whisperUrl.isEmpty) {
      lastResult = 'WhisperNotes ist nicht eingerichtet';
      notifyListeners();
      return;
    }
    uploading = true;
    notifyListeners();
    try {
      for (final file in files) {
        try {
          final job = await _upload(file);
          await _delete(file);
          pending--;
          lastResult = 'Gesendet an WhisperNotes (Job $job)';
          _log('Aufnahme gesendet: ${_name(file)}');
        } catch (e) {
          lastResult = 'Senden fehlgeschlagen: $e';
          _log('Aufnahme nicht gesendet: $e');
          break;
        }
        notifyListeners();
      }
    } finally {
      uploading = false;
      notifyListeners();
    }
  }

  /// POST /api/jobs (multipart) like the WhisperNotes dashboard upload.
  Future<String> _upload(File file) async {
    final base = settings.whisperUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/jobs');
    var recordedAt = '';
    final meta = File('${file.path}.json');
    if (await meta.exists()) {
      final json = jsonDecode(await meta.readAsString()) as Map;
      recordedAt = json['recorded_at'] as String? ?? '';
    }
    final boundary = 'evenG1${DateTime.now().microsecondsSinceEpoch}';
    String field(String name, String value) =>
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="$name"\r\n\r\n'
        '$value\r\n';
    final head = utf8.encode(
      field('kind', 'standard') +
          (recordedAt.isEmpty ? '' : field('recorded_at', recordedAt)) +
          '--$boundary\r\n'
              'Content-Disposition: form-data; name="file"; '
              'filename="${_name(file)}"\r\n'
              'Content-Type: audio/wav\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--\r\n');

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      if (settings.whisperApiKey.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${settings.whisperApiKey}',
        );
      }
      request.contentLength = head.length + await file.length() + tail.length;
      request.add(head);
      await request.addStream(file.openRead());
      request.add(tail);
      final response = await request.close().timeout(
        const Duration(minutes: 10),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw HttpException('HTTP ${response.statusCode}: $body');
      }
      try {
        return (jsonDecode(body) as Map)['id']?.toString() ?? '?';
      } catch (_) {
        return '?';
      }
    } finally {
      client.close();
    }
  }

  Future<void> _delete(File file) async {
    for (final f in [file, File('${file.path}.json')]) {
      if (await f.exists()) await f.delete();
    }
  }

  static String _name(File file) => file.uri.pathSegments.last;

  static String _format(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes % 60), s = two(d.inSeconds % 60);
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Formats [elapsed] for the app ("03:12" or "1:03:12").
  String get elapsedText => _format(elapsed);

  /// 44 byte RIFF header for 16 kHz mono PCM16.
  static Uint8List _wavHeader(int dataBytes) {
    final b = ByteData(44);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    b.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    b.setUint32(40, dataBytes, Endian.little);
    return b.buffer.asUint8List();
  }

  @visibleForTesting
  static Uint8List wavHeader(int dataBytes) => _wavHeader(dataBytes);

  @override
  void dispose() {
    _keepAlive?.cancel();
    _audioSub?.cancel();
    _decoder?.dispose();
    super.dispose();
  }
}
