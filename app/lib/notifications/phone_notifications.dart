import 'dart:io';

import 'package:flutter/services.dart';

/// A notification posted on the phone (Android only).
class PhoneNotification {
  PhoneNotification.fromMap(Map<dynamic, dynamic> map)
    : key = map['key'] as String? ?? '',
      packageName = map['package'] as String? ?? '',
      appName = map['app'] as String? ?? '',
      title = map['title'] as String? ?? '',
      text = map['text'] as String? ?? '',
      subText = map['subText'] as String? ?? '';

  final String key;
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final String subText;
}

/// Access to the phone's notifications via the Android notification
/// listener (see PhoneNotificationListener.kt).
class PhoneNotifications {
  static const _events = EventChannel('even_g1/phone_notifications');
  static const _access = MethodChannel('even_g1/notification_access');

  static bool get supported => Platform.isAndroid;

  static Stream<PhoneNotification> get stream => supported
      ? _events.receiveBroadcastStream().map(
          (e) => PhoneNotification.fromMap(e as Map<dynamic, dynamic>),
        )
      : const Stream.empty();

  /// True if the user allowed the app to read notifications.
  static Future<bool> isGranted() async {
    if (!supported) return false;
    return await _access.invokeMethod<bool>('isGranted') ?? false;
  }

  /// Opens the Android settings page where the access is granted.
  static Future<void> openSettings() async {
    if (supported) await _access.invokeMethod<void>('openSettings');
  }
}
