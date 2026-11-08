import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lc3_codec/lc3_codec.dart';

import 'g1/display.dart';
import 'g1/g1_connection.dart';
import 'g1/protocol.dart';
import 'ha/assist_session.dart';
import 'ha/ha_client.dart';
import 'notifications/phone_notifications.dart';
import 'scouter/scouter_connection.dart';
import 'scouter/sk_icons.dart';
import 'l10n/l10n.dart';
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
              : 'none'),
      dashboardStyle = G1TextStyle.fromId(json['dashboard_style'] as String?),
      labDesign = json['design_set'] == 'lab',
      localClock = json['local_clock'] == true;

  HaConfig.defaults()
    : name = '',
      deviceId = null,
      displayDuration = 10,
      assistPipeline = null,
      assistName = null,
      showTranscript = true,
      dashboardGesture = 'none',
      dashboardStyle = G1TextStyle.plain,
      labDesign = false,
      localClock = false;

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

  /// Design of the dashboard.
  final G1TextStyle dashboardStyle;

  /// Design set "lab" for the Assist status and the animations.
  final bool labDesign;

  /// The integration leaves the dashboard's clock to the app.
  final bool localClock;

  /// Show the Home Assistant dashboard when the head is raised.
  bool get dashboardOnHeadUp => dashboardGesture == 'head_up';
}

/// Connects the glasses with Home Assistant.
class Bridge extends ChangeNotifier {
  Bridge(this.settings, {G1Connection? g1}) : g1 = g1 ?? ScouterConnection() {
    display = G1Display(this.g1);
    recorder = VoiceRecorder(this.g1, settings, _log)
      ..addListener(notifyListeners);
    this.g1.addListener(_onGlassesChanged);
    this.g1.events.listen(_onGlassesEvent);
    this.g1.log.listen(_log);
    PhoneNotifications.stream.listen(
      _onPhoneNotification,
      onError: (Object e) => _log(tr.coreLogNotificationsError('$e')),
    );
  }

  static const notificationAppId = 'io.github.poldion.even_g1_ha';
  static const followUpWindow = Duration(minutes: 5);

  /// How long a notification stays on the display.
  static const notificationDuration = Duration(seconds: 8);
  static const maxRecording = Duration(seconds: 30);

  /// Shown after the touch bar was released, while Assist works.
  static String get thinkingText => tr.coreThinking;

  final Settings settings;
  final G1Connection g1;
  late final G1Display display;
  late final VoiceRecorder recorder;

  HaClient? _ha;
  int _haGeneration = 0;
  bool haConnected = false;
  String haStatus = tr.coreHaDisconnected;
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
  Map<String, Object?>? _lastReported;

  /// Rendered dashboard template, pushed by Home Assistant on changes.
  String _dashboardText = '';

  /// The dashboard as the app shows it, with the current time.
  String get _dashboardNow {
    final text = withClock(
      _dashboardText.isEmpty ? 'Home Assistant' : _dashboardText,
    );
    // The dashboard is as old as the last connection: say so.
    return haConnected || !settings.haConfigured
        ? text
        : '$text\n${tr.skStatusHaOffline}';
  }

  /// Home Assistant reachable or not; the glasses' own dashboard shows it.
  void _setHaConnected(bool connected) {
    haConnected = connected;
    if (g1.connected) unawaited(g1.setHomeAssistantOnline(connected));
  }

  Timer? _clockTimer;

  /// A dashboard with a clock that the app shows while the head is up gets
  /// the new time at each full minute.
  void _scheduleClock() {
    _clockTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    _clockTimer = Timer(next.difference(now), () {
      if (!_dashboardShown || !display.active || !g1.connected) return;
      unawaited(
        display.showText(_dashboardNow, style: haConfig.dashboardStyle),
      );
      _scheduleClock();
    });
  }

  /// Rendered listening template: shown while the touch bar is held.
  String? _listeningText;

  String get listeningText =>
      _listeningText ??
      tr.coreListening(haConfig.assistName ?? 'Home Assistant');
  bool _dashboardShown = false;
  bool _glassesSettingsApplied = false;

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
    _setHaConnected(false);
    await _ha?.close();
    if (settings.haConfigured) {
      unawaited(_runHomeAssistant());
    } else {
      _setHaStatus(tr.coreHaNotSetUp);
    }
  }

  Future<void> reconnectGlasses() async {
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
        _setHaStatus(tr.coreHaConnecting);
        await client.connect();
        final sub = await client.subscribe({
          'type': 'even_g1/subscribe',
          'entry_id': settings.entryId,
        });
        if (!wanted()) return;
        _setHaConnected(true);
        backoff = 2;
        _setHaStatus(tr.coreHaConnected(client.haVersion ?? '?'));
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
            _log(tr.coreLogIntegrationReloaded);
            await client.close();
            break;
          }
          await _onHaCommand(event);
        }
      } on HaException catch (e) {
        _log('$e');
        if (e.code == 'auth_invalid') {
          _setHaStatus(tr.coreHaTokenInvalid);
          return;
        }
      } catch (e) {
        _log('Home Assistant: $e');
      } finally {
        ping?.cancel();
        if (wanted()) _setHaConnected(false);
        await client.close();
        if (wanted()) notifyListeners();
      }
      if (!wanted()) return;
      _setHaStatus(tr.coreHaRetry(backoff));
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
        display.labDesign = haConfig.labDesign;
        // Tells an integration that offers it that the app keeps the clock.
        unawaited(_reportState());
        final listening = (event['listening_text'] as String? ?? '').trim();
        if (event.containsKey('listening_text')) {
          _listeningText = listening.isEmpty ? null : listening;
        }
        _log(tr.coreLogConfig(haConfig.name));
        if (haConfig.dashboardGesture == 'none' && _dashboardShown) {
          _dashboardShown = false;
          if (g1.connected) await display.clear();
        }
        notifyListeners();
        unawaited(_applyGlassesSettings());
        unawaited(_syncDashboard());
      case 'dashboard':
        _dashboardText = (event['text'] as String? ?? '').trim();
        unawaited(_syncDashboard());
        // Refresh only while it is on the display; otherwise the glasses
        // are not woken up for updates.
        if (_dashboardShown && display.active && g1.connected) {
          await display.showText(_dashboardNow, style: haConfig.dashboardStyle);
        }
      case 'listening':
        final text = (event['text'] as String? ?? '').trim();
        _listeningText = text.isEmpty ? null : text;
      case 'show_text':
        final title = withClock((event['title'] as String? ?? '').trim());
        final message = withClock((event['message'] as String? ?? '').trim());
        final duration = (event['duration'] as num?)?.toInt() ?? 0;
        _log(tr.coreLogShowText(title.isEmpty ? message : title));
        if (silentMode == true) {
          _log(tr.coreLogSilentTextSkipped);
          return;
        }
        _dashboardShown = false;
        if (!g1.connected) {
          _log(tr.coreLogTextDropped);
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

  /// Shows a notification as a text with the app's icon.
  Future<void> _sendGlassesNotification({
    required String appIdentifier,
    required String displayName,
    required String title,
    required String message,
    String subtitle = '',
  }) async {
    _dashboardShown = false;
    final head = title == displayName ? title : '$displayName: $title';
    final body = [subtitle, message].where((s) => s.isNotEmpty).join('\n');
    await display.showText(
      body.isEmpty ? head : '$head\n$body',
      closeAfter: notificationDuration,
      icon: SkIcons.forApp(appIdentifier, displayName),
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
      notifyListeners();
    }
    if (!settings.forwardNotifications || !(app?.enabled ?? true)) return;
    if (!g1.connected || silentMode == true) return;
    _log(tr.coreLogNotification(n.appName, n.title));
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
      // The app fills in the dashboard's time (only if the integration
      // offers it: older ones refuse unknown fields).
      if (haConfig.localClock) 'local_clock': true,
      // Home Assistant lays the dashboard out for this display.
      'display_lines': g1.displayLines,
      'display_columns': g1.displayColumns,
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
      _glassesSettingsApplied = false;
      _dashboardShown = false;
    } else {
      unawaited(_applyGlassesSettings());
      unawaited(g1.setHomeAssistantOnline(haConnected));
      if (recorder.recording && !display.active) unawaited(display.showIdle());
    }
    unawaited(_reportState());
    notifyListeners();
  }

  /// Sends the display settings stored in the app once per connection.
  Future<void> _applyGlassesSettings() async {
    if (!g1.connected || _glassesSettingsApplied) return;
    _glassesSettingsApplied = true;
    await g1.setHeadGestures(settings.headGestures);
    await _syncDashboard();
    final angle = settings.headUpAngle;
    if (angle != null) await _sendHeadUpAngle(angle);
    if (settings.displayHeight != null) await _sendDisplayHeight();
    final wear = settings.wearDetection;
    if (wear != null) {
      await g1.setWearDetection(wear);
    } else {
      wearDetection = await g1.readWearDetection();
    }
    unawaited(_reportState());
    if (settings.brightness != null || settings.autoBrightness != null) {
      // The app's setting is sent on every connection.
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
      _log(enabled ? tr.coreLogWearOn : tr.coreLogWearOff);
      await g1.setWearDetection(enabled);
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

  /// Sets the brightness and switches the automatic brightness off. Sent
  /// with a short delay so dragging the slider does not flood
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

  /// Sets the offset of the automatic brightness (the glasses apply it from
  /// their light sensor).
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
    if (!g1.connected) return;
    if (auto && brightnessOffset != 0) {
      final levels = (brightnessOffset * G1Brightness.max / 100).round();
      _log(
        tr.coreLogBrightnessOffset(
          '${brightnessOffset > 0 ? '+' : ''}$brightnessOffset',
        ),
      );
      await g1.setAutoBrightnessOffset(levels);
      return;
    }
    final percent = brightness ?? 50;
    _log(auto ? tr.coreLogBrightnessAuto : tr.coreLogBrightness(percent));
    await g1.setBrightness(percent, auto: auto);
  }

  Future<void> _sendHeadUpAngle(int angle) async {
    _log(tr.coreLogHeadUpAngle(angle));
    await g1.setHeadUpAngle(angle);
  }

  Future<void> _sendDisplayHeight() async {
    final height = settings.displayHeight ?? defaultDisplayHeight;
    _log(tr.coreLogDisplayHeight(height));
    await g1.setDisplayHeight(height);
  }

  static const defaultHeadUpAngle = 30;
  static const defaultDisplayHeight = 4;

  /// Changes the activation angle (stored in the app, sent to the glasses).
  Future<void> setHeadUpAngle(int angle) async {
    settings.headUpAngle = angle;
    notifyListeners();
    if (g1.connected) await _sendHeadUpAngle(angle);
  }

  /// Changes the height of the display content (0–8).
  Future<void> setDisplayHeight(int height) async {
    settings.displayHeight = height;
    notifyListeners();
    if (g1.connected) await _sendDisplayHeight();
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
      _log(tr.coreLogSilentDashboardSkipped);
      return true;
    }
    _log(tr.coreLogDashboardTap);
    _dashboardShown = true;
    final seconds = haConfig.displayDuration;
    await display.showText(
      _dashboardNow,
      closeAfter: seconds > 0 ? Duration(seconds: seconds) : null,
      style: haConfig.dashboardStyle,
    );
    return true;
  }

  /// Head raised: show the Home Assistant dashboard (when the glasses do
  /// not draw it themselves).
  /// Hands the dashboard to glasses that show it on head up themselves
  /// (ScouterKit's resident program); not in silent mode.
  Future<void> _syncDashboard() async {
    if (!g1.connected) return;
    await g1.setDashboard(
      onHeadUp: haConfig.dashboardOnHeadUp && silentMode != true,
      text: _dashboardText,
      style: haConfig.dashboardStyle,
    );
  }

  /// Nodding and shaking the head as gestures (ScouterKit).
  Future<void> setHeadGestures(bool enabled) async {
    settings.headGestures = enabled;
    _log(enabled ? tr.coreLogHeadGesturesOn : tr.coreLogHeadGesturesOff);
    notifyListeners();
    if (g1.connected) await g1.setHeadGestures(enabled);
  }

  Future<void> _onHeadUp() async {
    // The glasses draw it themselves, without a round trip to the phone.
    if (g1.showsDashboardItself) return;
    if (!haConfig.dashboardOnHeadUp || assistRunning) return;
    if (silentMode == true) return;
    // Do not cover a text or answer that is currently shown.
    if (display.active && !_dashboardShown) return;
    _dashboardShown = true;
    await display.showText(_dashboardNow, style: haConfig.dashboardStyle);
    // The time moves on while the head stays up.
    if (_dashboardText.contains(clockToken)) _scheduleClock();
  }

  Future<void> _onHeadDown() async {
    _clockTimer?.cancel();
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
      case G1Event.longPressStart:
        unawaited(_startAssist());
      case G1Event.longPressStop:
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
        _log(
          silentMode! ? tr.coreLogSilentOnGlasses : tr.coreLogSilentOffGlasses,
        );
        notifyListeners();
        unawaited(_silentModeFeedback(silentMode!));
        unawaited(_syncDashboard());
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
      await display.showAiError(tr.coreNoHaConnection);
      return;
    }
    assistRunning = true;
    _dashboardShown = false;
    notifyListeners();
    _log(tr.coreLogAssistStarted);

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
        _log(tr.coreLogRecognized(text));
        lastQuery = text;
        notifyListeners();
        if (haConfig.showTranscript && text.isNotEmpty) {
          display.showAiStatus(tr.coreTranscript(text));
        }
      },
    );
    _assist = session;

    // Start listening right away, audio is buffered until HA is ready.
    _audioSub = g1.audio.listen((lc3) {
      try {
        session.addAudio(decoder.decode(lc3));
      } catch (e) {
        _log(tr.coreLogAudio('$e'));
      }
    });
    _startFastConnection();
    unawaited(display.showAiStatus(listeningText));
    if (!await g1.setMic(true)) {
      _log(tr.coreLogMicFailed);
    }

    _recordTimer = Timer(maxRecording, _finishAssist);
    try {
      await session.start();
    } catch (e) {
      _log(tr.coreLogAssistStartFailed('$e'));
      await _abortAssist();
      await display.showAiError(tr.coreAssistUnavailable('$e'));
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
        error: tr.coreTimeout,
      ),
    );
    if (_assist != session) return; // aborted meanwhile
    _cleanupAssist();

    if (result.error != null) {
      _log(tr.coreLogAssistError(result.error!));
      await display.showAiError(result.error!);
      return;
    }

    lastQuery = result.query;
    lastResponse = result.response;
    _conversationId = result.conversationId;
    _conversationTime = DateTime.now();
    _log(tr.coreLogAnswer(result.response));
    notifyListeners();

    final duration = haConfig.displayDuration;
    // The integration records question and answer in Home Assistant.
    await display.showAiAnswer(
      result.response.isEmpty ? tr.coreDone : result.response,
      closeAfter: duration > 0 ? Duration(seconds: max(duration, 8)) : null,
      assistant: haConfig.assistName,
    );
  }

  // ---------------------------------------------------------------------------
  // Recording (WhisperNotes)
  // ---------------------------------------------------------------------------

  /// Starts or stops a recording with the glasses microphone. Finished
  /// recordings are sent to WhisperNotes. The glasses show a block in the
  /// right eye's top corner while the microphone is on.
  Future<void> setRecording(bool enabled) async {
    if (enabled == recorder.recording) return;
    if (enabled) {
      if (!g1.connected) {
        _log(tr.coreLogRecordingNoGlasses);
      }
      await recorder.start();
    } else {
      await recorder.stop(releaseMic: !assistRunning);
    }
    notifyListeners();
    await _reportState();
  }

  /// Switches the silent mode of the glasses.
  Future<void> setSilentMode(bool enabled) async {
    if (!g1.connected) {
      _log(tr.coreLogSilentNoGlasses);
      return;
    }
    _log(enabled ? tr.coreLogSilentOn : tr.coreLogSilentOff);
    if (enabled) {
      _dashboardShown = false;
      if (display.active) await display.clear();
    }
    await g1.setSilentMode(enabled);
    final changed = silentMode != enabled;
    silentMode = enabled;
    notifyListeners();
    if (changed) unawaited(_silentModeFeedback(enabled));
    await _syncDashboard();
    await _reportState();
  }

  /// Animation on the glasses when silent mode changes.
  Future<void> _silentModeFeedback(bool on) async {
    if (!g1.connected || assistRunning) return;
    // The animation draws only its region: the rest of the panel dark.
    _dashboardShown = false;
    await display.clear();
    await g1.playSilentModeAnimation(on, lab: haConfig.labDesign);
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

  /// App language: "system", "en" or "de" (also for texts on the glasses).
  void setLanguage(String language) {
    settings.language = language;
    L10n.apply(language);
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
    _clockTimer?.cancel();
    _ha?.close();
    recorder.dispose();
    g1.dispose();
    super.dispose();
  }
}
