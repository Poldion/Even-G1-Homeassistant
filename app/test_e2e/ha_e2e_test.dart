// End-to-end test against a running Home Assistant with the even_g1
// integration. Run with HA_URL and HA_TOKEN set. HA_STT_ENGINE names the STT
// entity for the test pipeline (default stt.fake). The test pipeline becomes
// the preferred one, so only use a test instance.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:even_g1_ha/ha/assist_session.dart';
import 'package:even_g1_ha/ha/ha_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final env = Platform.environment;
  final url = env['HA_URL'];
  final token = env['HA_TOKEN'];
  final skip = url == null || token == null;

  test(
    'app <-> integration <-> assist',
    () async {
      final client = HaClient(url!, token!);
      await client.connect();

      final devices = (await client.call({'type': 'even_g1/devices'}) as List)
          .cast<Map<String, dynamic>>();
      expect(devices, isNotEmpty);
      final entryId = devices.first['entry_id'] as String;

      final sub = await client.subscribe({
        'type': 'even_g1/subscribe',
        'entry_id': entryId,
      });
      final events = StreamIterator(sub.events);
      expect(await events.moveNext(), isTrue);
      expect(events.current['type'], 'config');
      final deviceId = events.current['device_id'] as String?;
      expect(deviceId, isNotNull);

      // Service call via REST -> pushed to the app
      final http = HttpClient();
      final req = await http.postUrl(
        Uri.parse('$url/api/services/even_g1/show_text'),
      );
      req.headers.set('Authorization', 'Bearer $token');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'title': 'Tür', 'message': 'Haustür ist offen'}));
      final res = await req.close();
      expect(res.statusCode, 200);
      expect(await events.moveNext(), isTrue);
      expect(events.current['type'], 'show_text');
      expect(events.current['message'], 'Haustür ist offen');

      await client.call({
        'type': 'even_g1/update_state',
        'entry_id': entryId,
        'glasses_connected': true,
        'battery_left': 55,
      });
      await client.call({
        'type': 'even_g1/gesture',
        'entry_id': entryId,
        'gesture': 'single_tap_right',
        'side': 'right',
        'code': 1,
      });

      // Assist pipeline with audio
      final pipeline = await client.call({
        'type': 'assist_pipeline/pipeline/create',
        'conversation_engine': 'conversation.home_assistant',
        'conversation_language': 'en',
        'language': 'en',
        'name': 'e2e ${DateTime.now().millisecondsSinceEpoch}',
        'stt_engine': env['HA_STT_ENGINE'] ?? 'stt.fake',
        'stt_language': 'en',
        'tts_engine': null,
        'tts_language': null,
        'tts_voice': null,
        'wake_word_entity': null,
        'wake_word_id': null,
      }) as Map;

      // The integration uses the preferred pipeline unless configured.
      await client.call({
        'type': 'assist_pipeline/pipeline/set_preferred',
        'pipeline_id': pipeline['id'],
      });

      String? transcript;
      final session = AssistSession(
        client,
        entryId: entryId,
        onTranscript: (t) => transcript = t,
      );
      // Audio before start() is buffered until the integration is ready.
      session.addAudio(_sine(0.2));
      await session.start();
      for (var i = 0; i < 10; i++) {
        session.addAudio(_sine(0.1));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      // A pause while speaking must not end the recording.
      session.addAudio(Uint8List(16000 * 2 * 2));
      session.addAudio(_sine(0.5));
      session.finishAudio();
      final result = await session.result.timeout(const Duration(seconds: 30));
      // ignore: avoid_print
      print(
        'query="${result.query}" response="${result.response}" '
        'error=${result.error} conversation=${result.conversationId}',
      );
      expect(result.error, isNull);
      expect(transcript, isNotEmpty);
      expect(result.response, isNotEmpty);
      expect(result.conversationId, isNotNull);

      await sub.cancel();
      await client.close();
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

Uint8List _sine(double seconds) {
  final n = (16000 * seconds).round();
  final data = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    data.setInt16(
      i * 2,
      (8000 * sin(2 * pi * 440 * i / 16000)).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}
