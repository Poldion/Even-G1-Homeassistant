import 'package:flutter/material.dart';

import '../bridge.dart';
import '../l10n/l10n.dart';
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
                ? '${s.entryName.isEmpty ? tr.glasses : s.entryName} · ${bridge.haStatus}'
                : tr.settingsNotSetUp,
            initiallyExpanded: !s.haConfigured,
            child: HaSettings(bridge: bridge),
          ),
          _Section(
            icon: Icons.bluetooth,
            title: tr.settingsPairGlasses,
            subtitle: s.glassesConfigured
                ? '${s.glassesName} · ${bridge.g1.status}'
                : tr.settingsNoGlassesPaired,
            initiallyExpanded: !s.glassesConfigured,
            child: GlassesPairing(bridge: bridge),
          ),
          _Section(
            icon: Icons.straighten,
            title: tr.settingsDisplay,
            subtitle: tr.settingsDisplaySubtitle,
            child: DisplaySettings(bridge: bridge),
          ),
          _Section(
            icon: Icons.notifications,
            title: tr.settingsNotifications,
            subtitle: s.forwardNotifications
                ? tr.settingsNotificationsOn
                : tr.settingsNotificationsOff,
            child: NotificationSettings(bridge: bridge),
          ),
          _Section(
            icon: Icons.mic_none,
            title: tr.settingsRecordings,
            subtitle: s.whisperUrl.isEmpty
                ? tr.settingsWhisperNotSetUp
                : 'WhisperNotes: ${s.whisperUrl}',
            child: RecordingSettings(bridge: bridge),
          ),
          _Section(
            icon: Icons.bug_report_outlined,
            title: tr.settingsDiagnostics,
            subtitle: tr.settingsDiagnosticsSubtitle,
            child: Diagnostics(bridge: bridge),
          ),
          _Section(
            icon: Icons.system_update,
            title: tr.settingsAppUpdate,
            subtitle: tr.settingsAppUpdateSubtitle,
            child: UpdateSettings(bridge: bridge),
          ),
          _Section(
            icon: Icons.language,
            title: tr.languageSetting,
            subtitle: _languageName(L10n.setting),
            child: _LanguageChoice(bridge: bridge),
          ),
        ],
      ),
    );
  }
}

String _languageName(String setting) => switch (setting) {
  'en' => tr.languageEnglish,
  'de' => tr.languageGerman,
  _ => tr.languageSystem(
    L10n.systemCode == 'de' ? tr.languageGerman : tr.languageEnglish,
  ),
};

/// System language (default), English or German.
class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({required this.bridge});

  final Bridge bridge;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: L10n.setting,
      onChanged: (v) => bridge.setLanguage(v ?? 'system'),
      child: Column(
        children: [
          for (final v in const ['system', 'en', 'de'])
            RadioListTile<String>(
              value: v,
              title: Text(_languageName(v)),
              contentPadding: EdgeInsets.zero,
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
