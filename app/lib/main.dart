import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'bridge.dart';
import 'settings.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final settings = await Settings.load();
  final bridge = Bridge(settings);
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

class EvenG1App extends StatelessWidget {
  const EvenG1App({super.key, required this.bridge});

  final Bridge bridge;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF18BCF2));
    return WithForegroundTask(
      child: MaterialApp(
        title: 'Even G1 für Home Assistant',
        theme: ThemeData(colorScheme: scheme, useMaterial3: true),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF18BCF2),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: HomePage(bridge: bridge),
      ),
    );
  }
}
