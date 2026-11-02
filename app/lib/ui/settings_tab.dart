import 'package:flutter/material.dart';

import '../bridge.dart';
import 'diagnostics.dart';
import 'glasses_settings.dart';
import 'ha_settings.dart';
import 'notification_settings.dart';
import 'recording_settings.dart';
import 'update_settings.dart';

/// All settings, grouped in collapsible sections.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, required this.bridge});

  final Bridge bridge;

  @override
  Widget build(BuildContext context) {
    final s = bridge.settings;
    return ListenableBuilder(
      listenable: bridge,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(
            icon: Icons.home,
            title: 'Home Assistant',
            subtitle: s.haConfigured
                ? '${s.entryName.isEmpty ? 'Brille' : s.entryName} · ${bridge.haStatus}'
                : 'Nicht eingerichtet',
            initiallyExpanded: !s.haConfigured,
            child: HaSettings(bridge: bridge),
          ),
          _Section(
            icon: Icons.bluetooth,
            title: 'Brille koppeln',
            subtitle: s.glassesConfigured
                ? '${s.glassesName} · ${bridge.g1.status}'
                : 'Noch keine Brille gekoppelt',
            initiallyExpanded: !s.glassesConfigured,
            child: GlassesPairing(bridge: bridge),
          ),
          _Section(
            icon: Icons.straighten,
            title: 'Anzeige & Aktivierung',
            subtitle: 'Aktivierungswinkel, Höhe, Distanz, Even-Dashboard',
            child: DisplaySettings(bridge: bridge),
          ),
          _Section(
            icon: Icons.notifications,
            title: 'Benachrichtigungen',
            subtitle: s.forwardNotifications
                ? 'Handy-Benachrichtigungen werden weitergeleitet'
                : 'Weiterleitung aus',
            child: NotificationSettings(bridge: bridge),
          ),
          _Section(
            icon: Icons.mic_none,
            title: 'Aufnahmen',
            subtitle: s.whisperUrl.isEmpty
                ? 'WhisperNotes nicht eingerichtet'
                : 'WhisperNotes: ${s.whisperUrl}',
            child: RecordingSettings(bridge: bridge),
          ),
          _Section(
            icon: Icons.bug_report_outlined,
            title: 'Diagnose',
            subtitle: 'Testanzeige, Anzeige prüfen, Protokoll',
            child: Diagnostics(bridge: bridge),
          ),
          const _Section(
            icon: Icons.system_update,
            title: 'App-Update',
            subtitle: 'Version und neue Versionen von GitHub',
            child: UpdateSettings(),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }
}
