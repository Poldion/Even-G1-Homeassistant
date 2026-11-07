import 'package:flutter/material.dart';

import '../bridge.dart';
import '../l10n/l10n.dart';
import '../notifications/phone_notifications.dart';

/// Settings for forwarding the phone's notifications to the glasses.
class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings>
    with WidgetsBindingObserver {
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the Android settings page.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = await PhoneNotifications.isGranted();
    if (mounted) setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    if (!PhoneNotifications.supported) {
      return Text(tr.notifSetAndroidOnly);
    }
    final settings = widget.bridge.settings;
    return ListenableBuilder(
      listenable: widget.bridge,
      builder: (context, _) {
        final apps = settings.notificationApps.entries.toList()
          ..sort(
            (a, b) => a.value.name.toLowerCase().compareTo(
              b.value.name.toLowerCase(),
            ),
          );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr.notifSetForward),
              value: settings.forwardNotifications,
              onChanged: (v) =>
                  setState(() => settings.forwardNotifications = v),
            ),
            if (!_granted)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_off),
                  title: Text(tr.notifSetNoAccess),
                  subtitle: Text(tr.notifSetNoAccessHelp),
                  isThreeLine: true,
                  trailing: FilledButton(
                    onPressed: PhoneNotifications.openSettings,
                    child: Text(tr.notifSetAllow),
                  ),
                ),
              ),
            if (apps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr.notifSetNoApps),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(tr.notifSetApps),
              ),
              for (final app in apps)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(app.value.name),
                  subtitle: Text(app.key),
                  value: app.value.enabled,
                  onChanged: settings.forwardNotifications
                      ? (v) =>
                            widget.bridge.setNotificationAppEnabled(app.key, v)
                      : null,
                ),
            ],
          ],
        );
      },
    );
  }
}
