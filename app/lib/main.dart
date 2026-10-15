import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// Requests the runtime permissions and keeps the app alive in the background.
Future<void> ensureBackgroundOperation() async {
  if (Platform.isAndroid) {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // only needed up to Android 11
      Permission.notification,
    ].request();

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
      await FlutterForegroundTask.startService(
        serviceId: 4711,
        serviceTypes: [ForegroundServiceTypes.connectedDevice],
        notificationTitle: 'Even G1 ↔ Home Assistant',
        notificationText: 'Verbindung aktiv',
      );
    }
  } else {
    await Permission.bluetooth.request();
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
