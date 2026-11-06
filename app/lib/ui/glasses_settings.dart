import 'dart:async';

import 'package:flutter/material.dart';

import '../bridge.dart';
import '../g1/g1_connection.dart';
import '../main.dart';
import '../scouter/scouter_connection.dart';

/// Pairing with the glasses.
class GlassesPairing extends StatefulWidget {
  const GlassesPairing({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<GlassesPairing> createState() => _GlassesPairingState();
}

class _GlassesPairingState extends State<GlassesPairing> {
  List<G1Pair> _pairs = [];
  bool _scanning = false;
  String? _error;
  String? _restartNote;
  StreamSubscription<List<G1Pair>>? _scanSub;

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  /// Searches for glasses with Even's firmware or with ScouterKit (g1v0);
  /// Android runs one scan at a time, so g1v0 arms are looked for in the
  /// same scan by their names.
  void _scan() {
    _scanSub?.cancel();
    setState(() {
      _pairs = [];
      _scanning = true;
      _error = null;
    });
    final scouterKit = !widget.bridge.g1.evenFirmware;
    final scan = scouterKit ? ScouterConnection.scan() : G1Connection.scan();
    _scanSub = scan.listen(
      (pairs) => setState(() => _pairs = pairs),
      onError: (Object e) => setState(() => _error = '$e'),
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  /// Switches the firmware the app talks to; takes effect after a restart.
  void _setFirmware(G1Firmware firmware) {
    final s = widget.bridge.settings;
    s.glassesFirmware = firmware.id;
    s.leftId = '';
    s.rightId = '';
    s.glassesName = '';
    setState(() {
      _pairs = [];
      _restartNote = firmware.id == _running.id
          ? null
          : 'Bitte die App schließen und neu öffnen, dann nach der Brille '
                'suchen.';
    });
    unawaited(widget.bridge.reconnectGlasses());
  }

  G1Firmware get _running =>
      widget.bridge.g1.evenFirmware ? G1Firmware.even : G1Firmware.scouterKit;

  Future<void> _select(G1Pair pair) async {
    await _scanSub?.cancel();
    setState(() {
      _scanning = false;
      _pairs = [];
    });
    final s = widget.bridge.settings;
    s.leftId = pair.leftId!;
    s.rightId = pair.rightId!;
    s.glassesFirmware = pair.firmware.id;
    s.glassesName = pair.firmware == G1Firmware.scouterKit
        ? 'G1 (g1v0) ${pair.channel}'
        : 'G1 #${pair.channel}';
    await ensureBackgroundOperation();
    await widget.bridge.reconnectGlasses();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.bridge.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.glassesConfigured
              ? 'Gekoppelt: ${s.glassesName}'
              : 'Noch keine Brille gekoppelt.',
        ),
        const SizedBox(height: 4),
        Text(
          _running == G1Firmware.even
              ? 'Die offizielle Even-App muss geschlossen sein, da sich die '
                    'Brille nur mit einer App gleichzeitig verbindet.'
              : 'ScouterKit (g1v0): Zum ersten Koppeln die Brille ins offene '
                    'Ladeetui legen. Außerhalb des Etuis gehorcht sie nur '
                    'gekoppelten Geräten.',
        ),
        const SizedBox(height: 8),
        SegmentedButton<G1Firmware>(
          segments: const [
            ButtonSegment(value: G1Firmware.even, label: Text('Even')),
            ButtonSegment(
              value: G1Firmware.scouterKit,
              label: Text('ScouterKit'),
            ),
          ],
          selected: {G1Firmware.fromId(s.glassesFirmware)},
          onSelectionChanged: _scanning ? null : (v) => _setFirmware(v.first),
        ),
        if (_restartNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _restartNote!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _scanning || _restartNote != null ? null : _scan,
          icon: _scanning
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bluetooth_searching),
          label: Text(_scanning ? 'Suche…' : 'Nach Brillen suchen'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final pair in _pairs)
          ListTile(
            leading: const Icon(Icons.visibility),
            title: Text(
              pair.firmware == G1Firmware.scouterKit
                  ? 'G1 (g1v0) ${pair.channel}'
                  : 'G1 #${pair.channel}',
            ),
            subtitle: Text(
              'Links: ${pair.leftName ?? '–'}\nRechts: ${pair.rightName ?? '–'}',
            ),
            isThreeLine: true,
            enabled: pair.complete,
            onTap: pair.complete ? () => _select(pair) : null,
          ),
      ],
    );
  }
}

/// Activation angle, height and distance of the display content and what
/// the glasses show when looking up.
class DisplaySettings extends StatefulWidget {
  const DisplaySettings({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<DisplaySettings> createState() => _DisplaySettingsState();
}

class _DisplaySettingsState extends State<DisplaySettings> {
  late double _angle;
  late double _height;
  late double _depth;

  @override
  void initState() {
    super.initState();
    final s = widget.bridge.settings;
    _angle = (s.headUpAngle ?? Bridge.defaultHeadUpAngle).toDouble();
    _height = (s.displayHeight ?? Bridge.defaultDisplayHeight).toDouble();
    _depth = (s.displayDepth ?? Bridge.defaultDisplayDepth).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final bridge = widget.bridge;
    final connected = bridge.g1.connected;
    final s = bridge.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!connected)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Die Brille ist nicht verbunden. Änderungen werden beim '
              'nächsten Verbinden übertragen.',
            ),
          ),
        _SliderRow(
          label: 'Aktivierungswinkel',
          help:
              'Ab dieser Kopfneigung schaltet die Brille beim Hochschauen '
              'die Anzeige ein.',
          value: _angle,
          min: 0,
          max: 60,
          unit: '°',
          notSet: s.headUpAngle == null,
          onChanged: (v) => setState(() => _angle = v),
          onChangeEnd: (v) => bridge.setHeadUpAngle(v.round()),
        ),
        _SliderRow(
          label: 'Höhe',
          help:
              'Wie hoch der Text im Sichtfeld steht. Beim Loslassen zeigt '
              'die Brille die neue Position kurz an und übernimmt sie.',
          value: _height,
          min: 0,
          max: 8,
          notSet: s.displayHeight == null,
          onChanged: (v) => setState(() => _height = v),
          onChangeEnd: (v) => bridge.setDisplayPosition(height: v.round()),
        ),
        _SliderRow(
          label: 'Distanz',
          help: 'Wie weit entfernt der Text wirkt.',
          value: _depth,
          min: 1,
          max: 9,
          notSet: s.displayDepth == null,
          onChanged: (v) => setState(() => _depth = v),
          onChangeEnd: (v) => bridge.setDisplayPosition(depth: v.round()),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          initialValue: s.headUpMode,
          decoration: const InputDecoration(
            labelText: 'Even-Dashboard beim Hochschauen',
            helperText:
                '„Ausblenden“: Beim Hochschauen erscheint nur das '
                'Home-Assistant-Dashboard (falls in HA eingestellt).',
            helperMaxLines: 3,
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Unverändert lassen')),
            DropdownMenuItem(value: 0, child: Text('Anzeigen')),
            DropdownMenuItem(value: 2, child: Text('Ausblenden')),
          ],
          onChanged: (v) => bridge.setHeadUpMode(v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Trageerkennung'),
          subtitle: const Text(
            'Die Brille meldet, ob sie getragen wird (auch an Home '
            'Assistant: „Getragen“).',
          ),
          value: bridge.wearDetection ?? false,
          onChanged: bridge.g1.connected ? bridge.setWearDetection : null,
        ),
        if (bridge.g1.supportsHeadGestures)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kopfgesten'),
            subtitle: const Text(
              'Nicken und Kopfschütteln als Gesten für Home Assistant. Der '
              'Gyrosensor des rechten Bügels läuft dann ständig und braucht '
              'etwas mehr Akku.',
            ),
            value: bridge.settings.headGestures,
            onChanged: bridge.setHeadGestures,
          ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.help,
    required this.value,
    required this.min,
    required this.max,
    required this.notSet,
    required this.onChanged,
    required this.onChangeEnd,
    this.unit = '',
  });

  final String label;
  final String help;
  final double value;
  final double min;
  final double max;
  final String unit;
  final bool notSet;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(
              notSet ? 'nicht gesetzt' : '${value.round()}$unit',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          label: '${value.round()}$unit',
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        Text(help, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
      ],
    );
  }
}
