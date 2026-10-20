import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lc3_codec/lc3_codec.dart';

import 'g1/display.dart';
import 'g1/g1_connection.dart';
import 'g1/protocol.dart';
import 'ha/assist_session.dart';
import 'ha/ha_client.dart';
import 'settings.dart';

/// Configuration pushed by the Home Assistant integration.
class HaConfig {
  HaConfig.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String? ?? '',
      deviceId = json['device_id'] as String?,
      displayDuration = (json['display_duration'] as num?)?.toInt() ?? 10,
      assistPipeline = json['assist_pipeline'] as String?,
      showTranscript = json['show_transcript'] as bool? ?? true;

  HaConfig.defaults()
    : name = '',
      deviceId = null,
      displayDuration = 10,
      assistPipeline = null,
      showTranscript = true;

  final String name;
  final String? deviceId;
  final int displayDuration;
  final String? assistPipeline;
  final bool showTranscript;
}

/// Connects the glasses with Home Assistant.
class Bridge extends ChangeNotifier {
  Bridge(this.settings) {
    display = G1Display(g1);
    g1.addListener(_onGlassesChanged);
    g1.events.listen(_onGlassesEvent);
    g1.log.listen(_log);
  }

  static const notificationAppId = 'io.github.poldion.even_g1_ha';
  static const followUpWindow = Duration(minutes: 5);
  static const maxRecording = Duration(seconds: 30);

  // Own screens shown during Assist. They replace the Even AI screens of the
  // glasses firmware (e.g. its "release to ask" hint).
  static const listeningText = 'Home Assistant\nIch höre zu …';
  static const thinkingText = 'Home Assistant\nEinen Moment …';

  final Settings settings;
  final G1Connection g1 = G1Connection();
  late final G1Display display;

  HaClient? _ha;
  int _haGeneration = 0;
  bool haConnected = false;
  String haStatus = 'getrennt';
  HaConfig haConfig = HaConfig.defaults();

  final List<String> logLines = [];
  String? lastQuery;
  String? lastResponse;
  bool assistRunning = false;

  AssistSession? _assist;
  Lc3Decoder? _decoder;
  StreamSubscription<Uint8List>? _audioSub;
  Timer? _recordTimer;
  String? _conversationId;
  DateTime? _conversationTime;
  bool _whitelistSent = false;
  int _notificationId = 0;
  Map<String, Object?>? _lastReported;

  void _log(String line) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    logLines.add('$ts $line');
    if (logLines.length > 300) logLines.removeRange(0, logLines.length - 300);
    debugPrint('[Bridge] $line');
    notifyListeners();
  }

  /// Starts both connections with the stored settings.
  Future<void> start() async {
    if (settings.glassesConfigured) {
      unawaited(g1.connect(settings.leftId, settings.rightId));
    }
    if (settings.haConfigured) {
      unawaited(_runHomeAssistant());
    }
  }

  Future<void> restartHomeAssistant() async {
    _haGeneration++;
    haConnected = false;
    await _ha?.close();
    if (settings.haConfigured) {
      unawaited(_runHomeAssistant());
    } else {
      _setHaStatus('nicht eingerichtet');
    }
  }

  Future<void> reconnectGlasses() async {
    _whitelistSent = false;
    if (settings.glassesConfigured) {
      await g1.connect(settings.leftId, settings.rightId);
    } else {
      await g1.disconnect();
    }
  }

  // ---------------------------------------------------------------------------
  // Home Assistant
  // ---------------------------------------------------------------------------

  Future<void> _runHomeAssistant() async {
    final generation = ++_haGeneration;
    bool wanted() => generation == _haGeneration;
    var backoff = 2;
    while (wanted()) {
      final client = HaClient(settings.haUrl, settings.haToken);
      _ha = client;
      Timer? ping;
      try {
        _setHaStatus('verbinde…');
        await client.connect();
        final sub = await client.subscribe({
          'type': 'even_g1/subscribe',
          'entry_id': settings.entryId,
        });
        if (!wanted()) return;
        haConnected = true;
        backoff = 2;
        _setHaStatus('verbunden (HA ${client.haVersion ?? '?'})');
        _lastReported = null;
        unawaited(_reportState());
        ping = Timer.periodic(const Duration(seconds: 30), (_) async {
          try {
            await client.ping();
          } catch (_) {
            await client.close();
          }
        });
        await for (final event in sub.events) {
          if (event['type'] == 'reload') {
            _log('Integration neu geladen, verbinde neu');
            await client.close();
            break;
          }
          await _onHaCommand(event);
        }
      } on HaException catch (e) {
        _log('$e');
        if (e.code == 'auth_invalid') {
          _setHaStatus('Token ungültig');
          return;
        }
      } catch (e) {
        _log('Home Assistant: $e');
      } finally {
        ping?.cancel();
        if (wanted()) haConnected = false;
        await client.close();
        if (wanted()) notifyListeners();
      }
      if (!wanted()) return;
      _setHaStatus('getrennt, neuer Versuch in ${backoff}s');
      await Future<void>.delayed(Duration(seconds: backoff));
      backoff = min(backoff * 2, 60);
    }
  }

  void _setHaStatus(String status) {
    haStatus = status;
    notifyListeners();
  }

  Future<void> _onHaCommand(Map<String, dynamic> event) async {
    switch (event['type']) {
      case 'config':
        haConfig = HaConfig.fromJson(event);
        _log('Konfiguration erhalten (${haConfig.name})');
        notifyListeners();
      case 'show_text':
        final title = (event['title'] as String? ?? '').trim();
        final message = (event['message'] as String? ?? '').trim();
        final duration = (event['duration'] as num?)?.toInt() ?? 0;
        _log('Anzeige: ${title.isEmpty ? message : title}');
        if (!g1.connected) {
          _log('Brille nicht verbunden – Text verworfen');
          return;
        }
        if (event['mode'] == 'notification') {
          await _sendNotification(title, message);
        } else {
          await display.showText(
            title.isEmpty ? message : '$title\n$message',
            closeAfter: Duration(seconds: duration),
          );
        }
      case 'clear':
        if (g1.connected) await display.clear();
    }
  }

  Future<void> _sendNotification(String title, String message) async {
    if (!_whitelistSent) {
      _whitelistSent = await g1.sendWhitelist({
        notificationAppId: 'Home Assistant',
      });
    }
    _notificationId = (_notificationId + 1) & 0xff;
    await g1.sendNotification(
      G1Packets.notification(
        msgId: _notificationId,
        appIdentifier: notificationAppId,
        displayName: 'Home Assistant',
        title: title.isEmpty ? 'Home Assistant' : title,
        message: message,
      ),
    );
  }

  Future<void> _call(Map<String, dynamic> message) async {
    final client = _ha;
    if (client == null || !haConnected) return;
    try {
      await client.call({...message, 'entry_id': settings.entryId});
    } catch (e) {
      _log('HA ${message['type']}: $e');
    }
  }

  Future<void> _reportState() async {
    final state = <String, Object?>{
      'glasses_connected': g1.connected,
      'battery_left': g1.batteryLeft,
      'battery_right': g1.batteryRight,
    };
    if (mapEquals(state, _lastReported)) return;
    _lastReported = state;
    await _call({'type': 'even_g1/update_state', ...state});
  }

  // ---------------------------------------------------------------------------
  // Glasses
  // ---------------------------------------------------------------------------

  void _onGlassesChanged() {
    if (!g1.connected) _whitelistSent = false;
    unawaited(_reportState());
    notifyListeners();
  }

  Future<void> _onGlassesEvent(G1TouchEvent event) async {
    final gesture = gestureName(event.code, event.side);

    switch (event.code) {
      case G1Event.evenAiStart:
        unawaited(_startAssist());
      case G1Event.evenAiStop:
        unawaited(_finishAssist());
      case G1Event.singleTap:
        await display.onTap(event.side);
      case G1Event.doubleTap:
        display.onDismissed();
        if (assistRunning) await _abortAssist();
      case G1Event.worn:
        unawaited(_call({'type': 'even_g1/update_state', 'worn': true}));
      case G1Event.removed:
        unawaited(_call({'type': 'even_g1/update_state', 'worn': false}));
    }

    unawaited(
      _call({
        'type': 'even_g1/gesture',
        'gesture': gesture,
        'side': event.side.name,
        'code': event.code,
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Assist
  // ---------------------------------------------------------------------------

  Future<void> _startAssist() async {
    if (assistRunning) return;
    final client = _ha;
    if (client == null || !haConnected) {
      await display.showAiError('Keine Verbindung zu Home Assistant');
      return;
    }
    assistRunning = true;
    notifyListeners();
    _log('Assist gestartet');

    final followUp =
        _conversationTime != null &&
        DateTime.now().difference(_conversationTime!) < followUpWindow;

    _decoder?.dispose();
    final decoder = Lc3Decoder();
    _decoder = decoder;
    final session = AssistSession(
      client,
      entryId: settings.entryId,
      conversationId: followUp ? _conversationId : null,
      onTranscript: (text) {
        _log('Erkannt: $text');
        lastQuery = text;
        notifyListeners();
        if (haConfig.showTranscript && text.isNotEmpty) {
          display.showAiStatus('» $text «\nEinen Moment …');
        }
      },
    );
    _assist = session;

    // Start listening right away, audio is buffered until HA is ready.
    _audioSub = g1.audio.listen((lc3) {
      try {
        session.addAudio(decoder.decode(lc3));
      } catch (e) {
        _log('Audio: $e');
      }
    });
    // Mic first (it is on the right arm and starts the audio), then replace
    // the firmware's Even AI screen with our own.
    final micOn = g1.setMic(true);
    unawaited(display.showAiStatus(listeningText));
    if (!await micOn) _log('Mikrofon konnte nicht aktiviert werden');

    _recordTimer = Timer(maxRecording, _finishAssist);
    try {
      await session.start();
    } catch (e) {
      _log('Assist-Start fehlgeschlagen: $e');
      await _abortAssist();
      await display.showAiError('Assist nicht verfügbar:\n$e');
    }
  }

  Future<void> _finishAssist() async {
    final session = _assist;
    if (session == null) return;
    _recordTimer?.cancel();
    session.finishAudio();
    unawaited(g1.setMic(false));
    unawaited(display.showAiStatus(thinkingText));

    final result = await session.result.timeout(
      const Duration(seconds: 60),
      onTimeout: () => AssistResult(
        query: lastQuery ?? '',
        response: '',
        error: 'Zeitüberschreitung',
      ),
    );
    if (_assist != session) return; // aborted meanwhile
    _cleanupAssist();

    if (result.error != null) {
      _log('Assist-Fehler: ${result.error}');
      await display.showAiError(result.error!);
      return;
    }

    lastQuery = result.query;
    lastResponse = result.response;
    _conversationId = result.conversationId;
    _conversationTime = DateTime.now();
    _log('Antwort: ${result.response}');
    notifyListeners();

    final duration = haConfig.displayDuration;
    // The integration records question and answer in Home Assistant.
    await display.showAiAnswer(
      result.response.isEmpty ? 'Erledigt.' : result.response,
      closeAfter: duration > 0 ? Duration(seconds: max(duration, 8)) : null,
    );
  }

  Future<void> _abortAssist() async {
    final session = _assist;
    _cleanupAssist();
    await session?.cancel();
    await g1.setMic(false);
  }

  void _cleanupAssist() {
    _recordTimer?.cancel();
    _audioSub?.cancel();
    _audioSub = null;
    _decoder?.dispose();
    _decoder = null;
    _assist = null;
    assistRunning = false;
    notifyListeners();
  }

  /// Sends a test text to the glasses.
  Future<bool> sendTestText(String text) => display.showText(
    text,
    closeAfter: Duration(seconds: haConfig.displayDuration),
  );

  @override
  void dispose() {
    _haGeneration++;
    _ha?.close();
    g1.dispose();
    super.dispose();
  }
}
