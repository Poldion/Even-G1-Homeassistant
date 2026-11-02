import 'package:flutter/material.dart';

import '../bridge.dart';
import 'glasses_preview.dart';

/// Start tab: connection and battery status, silent mode, Assist and the
/// optional preview of the glasses display.
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.bridge});

  final Bridge bridge;

  static const _wearLabels = {
    'worn': 'Getragen',
    'not_worn': 'Abgesetzt',
    'case_open': 'Im Case (Deckel offen)',
    'case_closed': 'Im Case (Deckel zu)',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bridge,
      builder: (context, _) {
        final g1 = bridge.g1;
        final s = bridge.settings;
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // ---------------------------------------------------- glasses
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          color: g1.connected ? Colors.green : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.glassesName.isEmpty
                                    ? 'Brille'
                                    : s.glassesName,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                s.glassesConfigured
                                    ? g1.status
                                    : 'Nicht gekoppelt – siehe Einstellungen',
                              ),
                            ],
                          ),
                        ),
                        if (s.glassesConfigured && !g1.connected)
                          TextButton(
                            onPressed: bridge.reconnectGlasses,
                            child: const Text('Verbinden'),
                          ),
                      ],
                    ),
                    if (g1.connected) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _Battery(label: 'Links', percent: g1.batteryLeft),
                          _Battery(label: 'Rechts', percent: g1.batteryRight),
                          _Battery(
                            label: 'Case',
                            percent: g1.batteryCase,
                            charging: g1.caseCharging == true,
                          ),
                        ],
                      ),
                      if (g1.wearState != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _wearLabels[g1.wearState] ?? g1.wearState!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            // ---------------------------------------------------- silent mode
            Card(
              child: SwitchListTile(
                secondary: Icon(
                  bridge.silentMode == true
                      ? Icons.notifications_off
                      : Icons.notifications_active,
                ),
                title: const Text('Ruhemodus'),
                subtitle: const Text(
                  'Keine Texte, Benachrichtigungen oder Dashboards. Assist '
                  'funktioniert weiter.',
                ),
                value: bridge.silentMode ?? false,
                onChanged: g1.connected ? bridge.setSilentMode : null,
              ),
            ),
            // ---------------------------------------------------- brightness
            Card(child: _Brightness(bridge: bridge)),
            // ---------------------------------------------------- HA + Assist
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.home,
                          color: bridge.haConnected ? Colors.green : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Home Assistant',
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                s.haConfigured ? bridge.haStatus : 'Nicht eingerichtet – siehe Einstellungen',
                              ),
                            ],
                          ),
                        ),
                        if (s.haConfigured && !bridge.haConnected)
                          TextButton(
                            onPressed: bridge.restartHomeAssistant,
                            child: const Text('Verbinden'),
                          ),
                      ],
                    ),
                    if (bridge.haConnected) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(
                            bridge.assistRunning
                                ? Icons.mic
                                : Icons.record_voice_over,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Assistent: ${bridge.haConfig.assistName ?? 'bevorzugter Assistent'}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bridge.assistRunning
                            ? 'Hört zu …'
                            : 'Linke Touchbar gedrückt halten, sprechen, '
                                  'loslassen.',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (bridge.lastQuery != null) ...[
                        const SizedBox(height: 8),
                        Text('Frage: ${bridge.lastQuery}'),
                      ],
                      if (bridge.lastResponse != null)
                        Text('Antwort: ${bridge.lastResponse}'),
                    ],
                  ],
                ),
              ),
            ),
            // ---------------------------------------------------- preview
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: const Icon(Icons.preview_outlined),
                title: const Text('Vorschau der Brillenanzeige'),
                initiallyExpanded: s.showPreview,
                onExpansionChanged: (v) => s.showPreview = v,
                shape: const Border(),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [GlassesPreview(display: bridge.display)],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery({
    required this.label,
    required this.percent,
    this.charging = false,
  });

  final String label;
  final int? percent;
  final bool charging;

  IconData get _icon {
    final p = percent;
    if (charging) return Icons.battery_charging_full;
    if (p == null) return Icons.battery_unknown;
    if (p >= 90) return Icons.battery_full;
    if (p >= 60) return Icons.battery_5_bar;
    if (p >= 35) return Icons.battery_3_bar;
    if (p >= 15) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(_icon),
          Text(
            percent == null ? '–' : '$percent %',
            style: theme.textTheme.titleSmall,
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Brightness slider and automatic brightness switch.
class _Brightness extends StatelessWidget {
  const _Brightness({required this.bridge});

  final Bridge bridge;

  @override
  Widget build(BuildContext context) {
    final connected = bridge.g1.connected;
    final auto = bridge.autoBrightness ?? false;
    final percent = bridge.brightness;
    final applied = bridge.g1.brightnessPercent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(auto ? Icons.brightness_auto : Icons.brightness_6),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Helligkeit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                auto
                    ? 'Auto${applied == null ? '' : ' · $applied %'}'
                    : (percent == null ? '–' : '$percent %'),
              ),
              const SizedBox(width: 8),
              Switch(
                value: auto,
                onChanged: connected ? bridge.setAutoBrightness : null,
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.brightness_low, size: 20),
              Expanded(
                child: Slider(
                  value: (percent ?? 50).toDouble(),
                  max: 100,
                  divisions: 20,
                  label: '${percent ?? 50} %',
                  onChanged: connected
                      ? (v) => bridge.setBrightness(v.round())
                      : null,
                ),
              ),
              const Icon(Icons.brightness_high, size: 20),
              const SizedBox(width: 8),
            ],
          ),
          if (auto)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: Text(
                'Die Brille regelt die Helligkeit selbst über ihren '
                'Lichtsensor. Den Regler bewegen schaltet auf manuell.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
