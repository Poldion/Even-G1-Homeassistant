import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'bridge.dart';
import 'g1/g1_connection.dart';
import 'l10n/l10n.dart';
import 'scouter/scouter_connection.dart';
import 'settings.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final settings = await Settings.load();
  L10n.apply(settings.language);
  final firmware = G1Firmware.fromId(settings.glassesFirmware);
  final bridge = Bridge(
    settings,
    g1: firmware == G1Firmware.scouterKit ? ScouterConnection() : null,
  );
  runApp(EvenG1App(bridge: bridge));
}

/// Keeps the app alive in the background (Android foreground service).
///
/// Bluetooth permissions are requested by flutter_blue_plus when scanning or
/// connecting. The connectedDevice service type needs them to be granted, so
/// this is called again after the glasses were paired.
Future<void> ensureBackgroundOperation() async {
  if (Platform.isAndroid) {
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'even_g1_bridge',
        channelName: 'Even G1 Verbindung',
        channelDescription: 'Hält die Verbindung zur Brille im Hintergrund',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    if (!await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.startService(
        serviceId: 4711,
        serviceTypes: [ForegroundServiceTypes.connectedDevice],
        notificationTitle: 'Even G1 ↔ Home Assistant',
        notificationText: 'Verbindung aktiv',
      );
      if (result is ServiceRequestFailure) {
        debugPrint('Foreground service not started: ${result.error}');
      }
    }
  }
}

class EvenG1App extends StatefulWidget {
  const EvenG1App({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<EvenG1App> createState() => _EvenG1AppState();
}

class _EvenG1AppState extends State<EvenG1App> with WidgetsBindingObserver {
  Bridge get bridge => widget.bridge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The phone's language changed: follow it with the "system" setting.
  @override
  void didChangeLocales(List<Locale>? locales) => L10n.apply(L10n.setting);

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder(valueListenable: L10n.locale, builder: _build);

  Widget _build(BuildContext context, Locale locale, Widget? _) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF18BCF2));
    return WithForegroundTask(
      // A new language rebuilds every screen (texts come from `tr`).
      child: MaterialApp(
        key: ValueKey(locale),
        title: tr.appTitle,
        locale: locale,
        supportedLocales: L10n.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(colorScheme: scheme, useMaterial3: true),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF18BCF2),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: AppShell(bridge: bridge),
      ),
    );
  }
}
