import 'dart:async';

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
                      if (g1.firmwareVersion != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Firmware: ${g1.firmwareVersion}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
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
            // ---------------------------------------------------- recording
            Card(child: _Recording(bridge: bridge)),
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

/// Brightness slider and automatic brightness switch. With automatic
/// brightness the slider sets an offset.
class _Brightness extends StatelessWidget {
  const _Brightness({required this.bridge});

  final Bridge bridge;

  @override
  Widget build(BuildContext context) {
    final connected = bridge.g1.connected;
    final auto = bridge.autoBrightness ?? false;
    final percent = bridge.brightness;
    final offset = bridge.brightnessOffset;
    final applied = bridge.g1.brightnessPercent;
    String signed(int v) => v > 0 ? '+$v' : '$v';
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    ? 'Auto${offset == 0 ? '' : ' ${signed(offset)} %'}'
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
              Icon(auto ? Icons.remove : Icons.brightness_low, size: 20),
              Expanded(
                child: auto
                    ? Slider(
                        value: offset.toDouble(),
                        min: -50,
                        max: 50,
                        divisions: 20,
                        label: '${signed(offset)} %',
                        onChanged: connected
                            ? (v) => bridge.setBrightnessOffset(v.round())
                            : null,
                      )
                    : Slider(
                        value: (percent ?? 50).toDouble(),
                        max: 100,
                        divisions: 20,
                        label: '${percent ?? 50} %',
                        onChanged: connected
                            ? (v) => bridge.setBrightness(v.round())
                            : null,
                      ),
              ),
              Icon(auto ? Icons.add : Icons.brightness_high, size: 20),
              const SizedBox(width: 8),
            ],
          ),
          if (auto)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: Text(
                offset == 0
                    ? 'Die Brille regelt die Helligkeit über ihren '
                          'Lichtsensor. Der Regler verschiebt sie heller oder '
                          'dunkler.'
                    : 'Die App misst etwa alle zwei Minuten, wenn nichts angezeigt '
                          'wird, den Wert des Lichtsensors und stellt ihn '
                          '${signed(offset)} % ein'
                          '${applied == null ? '' : ' (gerade $applied %)'}.',
                style: small,
              ),
            ),
        ],
      ),
    );
  }
}

/// Start/stop of a recording for WhisperNotes.
class _Recording extends StatefulWidget {
  const _Recording({required this.bridge});

  final Bridge bridge;

  @override
  State<_Recording> createState() => _RecordingState();
}

class _RecordingState extends State<_Recording> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.bridge.recorder.recording && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bridge = widget.bridge;
    final r = bridge.recorder;
    final theme = Theme.of(context);
    final String subtitle;
    if (r.recording) {
      subtitle = 'Läuft · ${r.elapsedText}';
    } else if (r.uploading) {
      subtitle = 'Wird an WhisperNotes gesendet …';
    } else if (r.pending > 0) {
      subtitle = '${r.pending} Aufnahme(n) noch nicht gesendet';
    } else {
      subtitle =
          r.lastResult ??
          (bridge.settings.whisperUrl.isEmpty
              ? 'WhisperNotes in den Einstellungen eintragen'
              : 'Brillen-Mikrofon → WhisperNotes → BasaltNotes');
    }
    return ListTile(
      leading: Icon(
        r.recording ? Icons.fiber_manual_record : Icons.mic_none,
        color: r.recording ? theme.colorScheme.error : null,
      ),
      title: const Text('Aufnahme'),
      subtitle: Text(subtitle),
      trailing: r.recording
          ? FilledButton.tonalIcon(
              onPressed: () => bridge.setRecording(false),
              icon: const Icon(Icons.stop),
              label: const Text('Stopp'),
            )
          : FilledButton.icon(
              onPressed: () => bridge.setRecording(true),
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Start'),
            ),
    );
  }
}
