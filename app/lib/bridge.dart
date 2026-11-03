import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lc3_codec/lc3_codec.dart';

import 'g1/auto_brightness.dart';
import 'g1/display.dart';
import 'g1/g1_connection.dart';
import 'g1/protocol.dart';
import 'ha/assist_session.dart';
import 'ha/ha_client.dart';
import 'notifications/phone_notifications.dart';
import 'recording/recorder.dart';
import 'settings.dart';

/// Configuration pushed by the Home Assistant integration.
class HaConfig {
  HaConfig.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String? ?? '',
      deviceId = json['device_id'] as String?,
      displayDuration = (json['display_duration'] as num?)?.toInt() ?? 10,
      assistPipeline = json['assist_pipeline'] as String?,
      assistName = json['assist_pipeline_name'] as String?,
      showTranscript = json['show_transcript'] as bool? ?? true,
      dashboardGesture =
          json['dashboard_gesture'] as String? ??
          ((json['dashboard_on_head_up'] as bool? ?? false)
              ? 'head_up'
              : 'none');

  HaConfig.defaults()
    : name = '',
      deviceId = null,
      displayDuration = 10,
      assistPipeline = null,
      assistName = null,
      showTranscript = true,
      dashboardGesture = 'none';

  final String name;
  final String? deviceId;
  final int displayDuration;
  final String? assistPipeline;

  /// Name of the Assist pipeline the glasses talk to.
  final String? assistName;
  final bool showTranscript;

  /// Gesture that shows the Home Assistant dashboard: "head_up",
  /// "single_tap_left", "single_tap_right" or "none".
  final String dashboardGesture;

  /// Show the Home Assistant dashboard when the head is raised.
  bool get dashboardOnHeadUp => dashboardGesture == 'head_up';
}

/// Connects the glasses with Home Assistant.
class Bridge extends ChangeNotifier {
  Bridge(this.settings, {G1Connection? g1}) : g1 = g1 ?? G1Connection() {
    display = G1Display(this.g1)..evenAiAnswers = settings.evenAiAnswers;
    autoBrightnessOffset = AutoBrightness(
      this.g1,
      idle: () => !display.active && !assistRunning,
      log: _log,
    );
    recorder = VoiceRecorder(this.g1, settings, _log)
      ..addListener(notifyListeners);
    this.g1.addListener(_onGlassesChanged);
    this.g1.events.listen(_onGlassesEvent);
    this.g1.log.listen(_log);
    PhoneNotifications.stream.listen(
      _onPhoneNotification,
      onError: (Object e) => _log('Benachrichtigungen: $e'),
    );
  }

  static const notificationAppId = 'io.github.poldion.even_g1_ha';
  static const followUpWindow = Duration(minutes: 5);
  static const maxRecording = Duration(seconds: 30);

  // Shown after the touch bar was released. While it is held, the glasses
  // firmware shows its own Even AI listening screen: the right (master) arm
  // redraws it continuously, so drawing over it only reached the left arm.
  static const thinkingText = 'Home Assistant\nEinen Moment …';

  final Settings settings;
  final G1Connection g1;
  late final G1Display display;
  late final VoiceRecorder recorder;
  late final AutoBrightness autoBrightnessOffset;

  HaClient? _ha;
  int _haGeneration = 0;
  bool haConnected = false;
  String haStatus = 'getrennt';
  HaConfig haConfig = HaConfig.defaults();

  final List<String> logLines = [];
  String? lastQuery;
  String? lastResponse;
  bool assistRunning = false;

  /// Silent mode of the glasses (null = unknown until switched or reported
  /// by a triple tap). While on, no texts, notifications or dashboards are
  /// pushed; Assist still works.
  bool? silentMode;

  AssistSession? _assist;
  Lc3Decoder? _decoder;
  StreamSubscription<Uint8List>? _audioSub;
  Timer? _recordTimer;
  String? _conversationId;
  DateTime? _conversationTime;
  bool _whitelistSent = false;
  int _notificationId = 0;
  Map<String, Object?>? _lastReported;

  /// Rendered dashboard template, pushed by Home Assistant on changes.
  String _dashboardText = '';
  bool _dashboardShown = false;
  bool _glassesSettingsApplied = false;
  int _dashboardCounter = 0;
  Timer? _positionPreview;

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
    unawaited(recorder.sendPending());
    if (settings.glassesConfigured && !g1.connected) {
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
        if (haConfig.dashboardGesture == 'none' && _dashboardShown) {
          _dashboardShown = false;
          if (g1.connected) await display.clear();
        }
        notifyListeners();
        unawaited(_applyGlassesSettings());
      case 'dashboard':
        _dashboardText = (event['text'] as String? ?? '').trim();
        // Refresh only while it is on the display; otherwise the glasses
        // are not woken up for updates.
        if (_dashboardShown && display.active && g1.connected) {
          await display.showText(_dashboardText);
        }
      case 'show_text':
        final title = (event['title'] as String? ?? '').trim();
        final message = (event['message'] as String? ?? '').trim();
        final duration = (event['duration'] as num?)?.toInt() ?? 0;
        _log('Anzeige: ${title.isEmpty ? message : title}');
        if (silentMode == true) {
          _log('Ruhemodus – Text nicht angezeigt');
          return;
        }
        _dashboardShown = false;
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
      case 'silent_mode':
        await setSilentMode(event['enabled'] == true);
      case 'recording':
        await setRecording(event['enabled'] == true);
      case 'wear_detection':
        await setWearDetection(event['enabled'] == true);
    }
  }

  Future<void> _sendNotification(String title, String message) async {
    await _sendGlassesNotification(
      appIdentifier: notificationAppId,
      displayName: 'Home Assistant',
      title: title.isEmpty ? 'Home Assistant' : title,
      message: message,
    );
  }

  /// Shows a notification with the glasses' own notification display
  /// (0x4B). Only apps on the whitelist (0x04) are shown by the firmware.
  Future<void> _sendGlassesNotification({
    required String appIdentifier,
    required String displayName,
    required String title,
    required String message,
    String subtitle = '',
  }) async {
    if (!_whitelistSent) {
      final apps = <String, String>{notificationAppId: 'Home Assistant'};
      settings.notificationApps.forEach((pkg, app) {
        if (app.enabled) apps[pkg] = app.name;
      });
      _whitelistSent = await g1.sendWhitelist(apps);
    }
    // Distinct ids: the glasses replace a notification with the same id.
    _notificationId = _notificationId % 255 + 1;
    String cut(String s, int max) =>
        s.length <= max ? s : '${s.substring(0, max - 1)}…';
    await g1.sendNotification(
      G1Packets.notification(
        msgId: _notificationId,
        appIdentifier: appIdentifier,
        displayName: cut(displayName, 40),
        title: cut(title, 80),
        subtitle: cut(subtitle, 80),
        message: cut(message, 500),
      ),
    );
  }

  /// A notification was posted on the phone.
  Future<void> _onPhoneNotification(PhoneNotification n) async {
    final apps = settings.notificationApps;
    final app = apps[n.packageName];
    if (app == null) {
      // New app: remember it (forwarded by default, can be switched off).
      settings.notificationApps = {
        ...apps,
        n.packageName: NotificationApp(n.appName, true),
      };
      _whitelistSent = false;
      notifyListeners();
    }
    if (!settings.forwardNotifications || !(app?.enabled ?? true)) return;
    if (!g1.connected || silentMode == true) return;
    _log('Benachrichtigung: ${n.appName} – ${n.title}');
    await _sendGlassesNotification(
      appIdentifier: n.packageName,
      displayName: n.appName,
      title: n.title.isEmpty ? n.appName : n.title,
      subtitle: n.subText,
      message: n.text,
    );
  }

  /// Enables or disables forwarding for one app.
  void setNotificationAppEnabled(String packageName, bool enabled) {
    final apps = settings.notificationApps;
    final app = apps[packageName];
    if (app == null) return;
    settings.notificationApps = {
      ...apps,
      packageName: NotificationApp(app.name, enabled),
    };
    _whitelistSent = false;
    notifyListeners();
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
      'silent_mode': silentMode,
      'battery_case': g1.batteryCase,
      'case_charging': g1.caseCharging,
      'wear_state': g1.wearState,
      'recording': recorder.recording,
      'wear_detection': wearDetection,
    };
    if (mapEquals(state, _lastReported)) return;
    _lastReported = state;
    await _call({'type': 'even_g1/update_state', ...state});
  }

  // ---------------------------------------------------------------------------
  // Glasses
  // ---------------------------------------------------------------------------

  void _onGlassesChanged() {
    if (!g1.connected) {
      _whitelistSent = false;
      _glassesSettingsApplied = false;
      _dashboardShown = false;
    } else {
      unawaited(_applyGlassesSettings());
      if (recorder.recording && !display.active) unawaited(display.showIdle());
    }
    unawaited(_reportState());
    notifyListeners();
  }

  /// Sends the display settings stored in the app once per connection.
  Future<void> _applyGlassesSettings() async {
    if (!g1.connected || _glassesSettingsApplied) return;
    _glassesSettingsApplied = true;
    final angle = settings.headUpAngle;
    if (angle != null) await _sendHeadUpAngle(angle);
    final mode = settings.headUpMode;
    if (mode != null) await _sendHeadUpMode(mode);
    if (settings.displayHeight != null || settings.displayDepth != null) {
      await _sendDisplayPosition();
    }
    final wear = settings.wearDetection;
    if (wear != null) {
      await g1.sendSetting(G1Packets.wearDetection(wear));
    } else {
      wearDetection = await g1.readWearDetection();
    }
    unawaited(_reportState());
    if (settings.brightness != null || settings.autoBrightness != null) {
      // Like MentraOS: the app's setting is sent on every connection.
      autoBrightnessOffset.sensorLevel = null;
      await _sendBrightness();
    } else {
      // Not set in this app yet: show what the glasses use.
      final current = await g1.readBrightness();
      if (current != null) {
        brightness = current.percent;
        autoBrightness = current.auto;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Wear detection
  // ---------------------------------------------------------------------------

  /// Wear detection of the glasses (null = unknown). Only while it is on,
  /// the glasses report whether they are worn.
  late bool? wearDetection = settings.wearDetection;

  Future<void> setWearDetection(bool enabled) async {
    wearDetection = enabled;
    settings.wearDetection = enabled;
    notifyListeners();
    if (g1.connected) {
      _log(enabled ? 'Trageerkennung an' : 'Trageerkennung aus');
      await g1.sendSetting(G1Packets.wearDetection(enabled));
    }
    await _reportState();
  }

  // ---------------------------------------------------------------------------
  // Brightness
  // ---------------------------------------------------------------------------

  /// Display brightness in percent (null = unknown).
  late int? brightness = settings.brightness;

  /// Automatic brightness by the light sensor of the glasses.
  late bool? autoBrightness = settings.autoBrightness;

  Timer? _brightnessTimer;

  /// Sets the brightness; switches the automatic brightness off like the
  /// Even app. Sent with a short delay so dragging the slider does not flood
  /// the glasses.
  void setBrightness(int percent) {
    brightness = percent.clamp(0, 100);
    autoBrightness = false;
    settings.brightness = brightness;
    settings.autoBrightness = false;
    notifyListeners();
    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(
      const Duration(milliseconds: 150),
      () => unawaited(_sendBrightness()),
    );
  }

  /// Switches the automatic brightness of the glasses on or off.
  Future<void> setAutoBrightness(bool enabled) async {
    autoBrightness = enabled;
    brightness ??= 50;
    settings.autoBrightness = enabled;
    settings.brightness = brightness;
    notifyListeners();
    _brightnessTimer?.cancel();
    await _sendBrightness();
  }

  /// Offset of the automatic brightness in percent (-50..50).
  late int brightnessOffset = settings.brightnessOffset;

  /// Sets the offset of the automatic brightness. With an offset the app
  /// manages the automatic brightness itself (see [AutoBrightness]).
  void setBrightnessOffset(int percent) {
    brightnessOffset = percent.clamp(-50, 50);
    settings.brightnessOffset = brightnessOffset;
    notifyListeners();
    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_sendBrightness()),
    );
  }

  Future<void> _sendBrightness() async {
    final auto = autoBrightness ?? false;
    if (!auto || brightnessOffset == 0) autoBrightnessOffset.stop();
    if (!g1.connected) return;
    if (auto && brightnessOffset != 0) {
      final levels = (brightnessOffset * G1Packets.maxBrightness / 100).round();
      _log(
        'Helligkeit: automatisch, '
        '${brightnessOffset > 0 ? '+' : ''}$brightnessOffset %',
      );
      autoBrightnessOffset.start(levels);
      return;
    }
    final percent = brightness ?? 50;
    _log(auto ? 'Helligkeit: automatisch' : 'Helligkeit: $percent %');
    await g1.sendSetting(G1Packets.brightness(percent, auto: auto));
  }

  Future<void> _sendHeadUpAngle(int angle) async {
    _log('Aktivierungswinkel: $angle°');
    await g1.sendSetting(G1Packets.headUpAngle(angle));
  }

  Future<void> _sendHeadUpMode(int mode) async {
    _log(
      mode == 0
          ? 'Hochschauen: Even-Dashboard anzeigen'
          : 'Hochschauen: Even-Dashboard ausblenden',
    );
    await g1.sendSetting(G1Packets.headUpMode(mode));
  }

  Future<void> _sendDisplayPosition({bool preview = false}) async {
    final height = settings.displayHeight ?? defaultDisplayHeight;
    final depth = settings.displayDepth ?? defaultDisplayDepth;
    _log(
      'Anzeigeposition: Höhe $height, Distanz $depth'
      '${preview ? ' (Vorschau)' : ''}',
    );
    await g1.sendSetting(
      G1Packets.dashboardPosition(
        height,
        depth,
        _dashboardCounter++,
        preview: preview,
      ),
    );
  }

  static const defaultHeadUpAngle = 30;
  static const defaultDisplayHeight = 4;
  static const defaultDisplayDepth = 5;

  /// Changes the activation angle (stored in the app, sent to the glasses).
  Future<void> setHeadUpAngle(int angle) async {
    settings.headUpAngle = angle;
    notifyListeners();
    if (g1.connected) await _sendHeadUpAngle(angle);
  }

  /// Shows (0) or hides (2) the Even dashboard on head up.
  Future<void> setHeadUpMode(int? mode) async {
    settings.headUpMode = mode;
    notifyListeners();
    if (g1.connected && mode != null) await _sendHeadUpMode(mode);
  }

  /// Changes height and distance of the display content. The glasses show
  /// their own position preview for a moment, then the position is applied
  /// (like the official app).
  Future<void> setDisplayPosition({int? height, int? depth}) async {
    if (height != null) settings.displayHeight = height;
    if (depth != null) settings.displayDepth = depth;
    notifyListeners();
    if (!g1.connected) return;
    _positionPreview?.cancel();
    await _sendDisplayPosition(preview: true);
    _positionPreview = Timer(
      const Duration(seconds: 3),
      () => unawaited(_sendDisplayPosition()),
    );
  }

  /// Single tap configured as dashboard gesture: show the dashboard, or
  /// close it if it is shown. Returns false if the tap is meant for paging
  /// (another text is on the display).
  Future<bool> _onTapDashboard(String gesture) async {
    if (haConfig.dashboardGesture != gesture || assistRunning) return false;
    if (_dashboardShown && display.active) {
      _dashboardShown = false;
      await display.clear();
      return true;
    }
    if (display.active) return false;
    if (silentMode == true) {
      _log('Ruhemodus – Dashboard nicht angezeigt');
      return true;
    }
    _log('Dashboard (Tippen)');
    _dashboardShown = true;
    final seconds = haConfig.displayDuration;
    await display.showText(
      _dashboardText.isEmpty ? 'Home Assistant' : _dashboardText,
      closeAfter: seconds > 0 ? Duration(seconds: seconds) : null,
    );
    return true;
  }

  /// Head raised: cover the Even dashboard with the Home Assistant one.
  Future<void> _onHeadUp() async {
    if (!haConfig.dashboardOnHeadUp || assistRunning) return;
    if (silentMode == true) return;
    // Do not cover a text or answer that is currently shown.
    if (display.active && !_dashboardShown) return;
    _dashboardShown = true;
    await display.showText(
      _dashboardText.isEmpty ? 'Home Assistant' : _dashboardText,
    );
  }

  Future<void> _onHeadDown() async {
    if (!_dashboardShown) return;
    _dashboardShown = false;
    if (display.active) await display.clear();
  }

  Future<void> _onGlassesEvent(G1TouchEvent event) async {
    final isHeadEvent =
        event.code == G1Event.headUp || event.code == G1Event.headDown;
    // Both arms report head movements; only the right one is used.
    if (isHeadEvent && event.side != G1Side.right) return;
    final gesture = gestureName(event.code, event.side);
    if (gesture == null) return; // status push (battery, case, wear)

    switch (event.code) {
      case G1Event.evenAiStart:
        unawaited(_startAssist());
      case G1Event.evenAiStop:
        unawaited(_finishAssist());
      case G1Event.singleTap:
        if (!await _onTapDashboard(gesture)) await display.onTap(event.side);
      case G1Event.doubleTap:
        display.onDismissed();
        _dashboardShown = false;
        if (assistRunning) await _abortAssist();
      case G1Event.headUp:
        unawaited(_onHeadUp());
      case G1Event.headDown:
        unawaited(_onHeadDown());
      case G1Event.silentModeOn:
      case G1Event.silentModeOff:
        // Triple tap: the glasses switched silent mode themselves.
        silentMode = event.code == G1Event.silentModeOn;
        _log(silentMode! ? 'Ruhemodus an (Brille)' : 'Ruhemodus aus (Brille)');
        notifyListeners();
        unawaited(_reportState());
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
    _dashboardShown = false;
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
    // Nothing is drawn while the touch bar is held (see thinkingText).
    _startFastConnection();
    if (!await g1.setMic(true)) {
      _log('Mikrofon konnte nicht aktiviert werden');
    }

    _recordTimer = Timer(maxRecording, _finishAssist);
    try {
      await session.start();
    } catch (e) {
      _log('Assist-Start fehlgeschlagen: $e');
      await _abortAssist();
      await display.showAiError('Assist nicht verfügbar:\n$e');
    }
  }

  Timer? _fastTimer;
  static const _fastMax = Duration(minutes: 3);

  /// High connection priority while Assist listens, works and shows the
  /// answer; back to balanced once the answer is closed (at the latest after
  /// [_fastMax]).
  void _startFastConnection() {
    unawaited(g1.setFastConnection(true));
    final started = DateTime.now();
    _fastTimer?.cancel();
    _fastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final done = !assistRunning && !display.active;
      if (done || DateTime.now().difference(started) > _fastMax) {
        timer.cancel();
        unawaited(g1.setFastConnection(false));
      }
    });
  }

  Future<void> _finishAssist() async {
    final session = _assist;
    if (session == null) return;
    _recordTimer?.cancel();
    session.finishAudio();
    if (!recorder.recording) unawaited(g1.setMic(false));
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
    // Logs what each arm shows, to spot left/right differences.
    unawaited(Future<void>.delayed(const Duration(seconds: 1), checkDisplay));
  }

  /// Experimental: Assist answers in the Even AI mode of the official app.
  void setEvenAiAnswers(bool enabled) {
    settings.evenAiAnswers = enabled;
    display.evenAiAnswers = enabled;
    _log(enabled ? 'Antworten im Even-AI-Modus' : 'Antworten im Textmodus');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Recording (WhisperNotes)
  // ---------------------------------------------------------------------------

  /// Dot in the upper right corner (glyph widths from MentraOS: a space is
  /// 6 px wide, the display about 488 px).
  static final recordingDotText = '${' ' * 74}o';

  /// Starts or stops a recording with the glasses microphone. Finished
  /// recordings are sent to WhisperNotes.
  Future<void> setRecording(bool enabled) async {
    if (enabled == recorder.recording) return;
    if (enabled) {
      if (!g1.connected) _log('Aufnahme: Brille nicht verbunden, Mikrofon folgt');
      await recorder.start();
      display.idleText = settings.recordingDot ? recordingDotText : null;
      if (g1.connected && !display.active) await display.showIdle();
    } else {
      display.idleText = null;
      await recorder.stop(releaseMic: !assistRunning);
      if (g1.connected && !display.active) await display.showIdle();
    }
    notifyListeners();
    await _reportState();
  }

  /// Shows or hides the recording dot while recording.
  Future<void> setRecordingDot(bool enabled) async {
    settings.recordingDot = enabled;
    notifyListeners();
    if (!recorder.recording) return;
    display.idleText = enabled ? recordingDotText : null;
    if (g1.connected && !display.active) await display.showIdle();
  }

  /// Switches the silent mode of the glasses.
  Future<void> setSilentMode(bool enabled) async {
    if (!g1.connected) {
      _log('Ruhemodus: Brille nicht verbunden');
      return;
    }
    _log(enabled ? 'Ruhemodus an' : 'Ruhemodus aus');
    if (enabled) {
      _dashboardShown = false;
      if (display.active) await display.clear();
    }
    await g1.sendSetting(G1Packets.silentMode(enabled));
    silentMode = enabled;
    notifyListeners();
    await _reportState();
  }

  /// Asks both arms which screen they show and writes it to the log.
  Future<String> checkDisplay() async {
    if (!g1.connected) return 'Brille nicht verbunden';
    final left = await g1.readScreenState(G1Side.left);
    final right = await g1.readScreenState(G1Side.right);
    String name(int? id) => id == null ? 'keine Antwort' : screenName(id);
    final text = 'Anzeige links: ${name(left)}, rechts: ${name(right)}';
    _log(left == right ? text : '$text – UNTERSCHIEDLICH');
    return text;
  }

  Future<void> _abortAssist() async {
    final session = _assist;
    _cleanupAssist();
    await session?.cancel();
    if (!recorder.recording) await g1.setMic(false);
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
    _fastTimer?.cancel();
    _ha?.close();
    recorder.dispose();
    autoBrightnessOffset.stop();
    g1.dispose();
    super.dispose();
  }
}
