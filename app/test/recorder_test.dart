import 'dart:convert';
import 'dart:io';

import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/recording/recorder.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('writes a 16 kHz mono PCM16 WAV header', () {
    final h = VoiceRecorder.wavHeader(32000);
    expect(ascii.decode(h.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(h.sublist(8, 16)), 'WAVEfmt ');
    final b = h.buffer.asByteData();
    expect(b.getUint32(4, Endian.little), 36 + 32000);
    expect(b.getUint16(22, Endian.little), 1); // mono
    expect(b.getUint32(24, Endian.little), 16000);
    expect(b.getUint32(40, Endian.little), 32000);
  });

  test('sends pending recordings to WhisperNotes and removes them', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <(String, String?, String)>[];
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add((
        request.uri.path,
        request.headers.value(HttpHeaders.authorizationHeader),
        body,
      ));
      request.response
        ..statusCode = 201
        ..write(jsonEncode({'id': 'job42'}));
      await request.response.close();
    });
    settings.whisperUrl = 'http://127.0.0.1:${server.port}/';
    settings.whisperApiKey = 'geheim';

    final dir = await Directory.systemTemp.createTemp('rec');
    final wav = File('${dir.path}/Brillen-Notiz 2026-11-02 14-35-00.wav');
    await wav.writeAsBytes(VoiceRecorder.wavHeader(0));
    await File('${wav.path}.json').writeAsString(
      jsonEncode({'recorded_at': '2026-11-02T14:35:00'}),
    );

    final recorder = VoiceRecorder(
      G1Connection.fake((side, data) async {}),
      settings,
      (_) {},
      folder: dir,
    );
    await recorder.sendPending();
    await server.close();

    expect(requests, hasLength(1));
    final (path, auth, body) = requests.single;
    expect(path, '/api/jobs');
    expect(auth, 'Bearer geheim');
    expect(body, contains('name="kind"\r\n\r\nstandard'));
    expect(body, contains('name="recorded_at"\r\n\r\n2026-11-02T14:35:00'));
    expect(body, contains('filename="Brillen-Notiz 2026-11-02 14-35-00.wav"'));
    expect(recorder.pending, 0);
    expect(recorder.lastResult, contains('job42'));
    expect(await dir.list().isEmpty, isTrue);
  });

  test('keeps recordings when WhisperNotes is not set up', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final dir = await Directory.systemTemp.createTemp('rec');
    await File('${dir.path}/a.wav').writeAsBytes(VoiceRecorder.wavHeader(0));
    final recorder = VoiceRecorder(
      G1Connection.fake((side, data) async {}),
      settings,
      (_) {},
      folder: dir,
    );
    await recorder.sendPending();
    expect(recorder.pending, 1);
    expect(File('${dir.path}/a.wav').existsSync(), isTrue);
  });
}
