import 'dart:async';

import 'package:flutter/material.dart';

import '../bridge.dart';
import '../g1/g1_connection.dart';
import '../l10n/l10n.dart';
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
  StreamSubscription<List<G1Pair>>? _scanSub;

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  /// Searches for glasses with ScouterKit (g1v0).
  void _scan() {
    _scanSub?.cancel();
    setState(() {
      _pairs = [];
      _scanning = true;
      _error = null;
    });
    _scanSub = ScouterConnection.scan().listen(
      (pairs) => setState(() => _pairs = pairs),
      onError: (Object e) => setState(() => _error = '$e'),
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  Future<void> _select(G1Pair pair) async {
    await _scanSub?.cancel();
    setState(() {
      _scanning = false;
      _pairs = [];
    });
    final s = widget.bridge.settings;
    s.leftId = pair.leftId!;
    s.rightId = pair.rightId!;
    s.glassesFirmware = 'scouterkit';
    s.glassesName = 'G1 (g1v0) ${pair.channel}';
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
              ? tr.glassesSetPaired(s.glassesName)
              : tr.glassesSetNonePaired,
        ),
        const SizedBox(height: 4),
        Text(tr.glassesSetScouterHint),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _scanning ? null : _scan,
          icon: _scanning
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bluetooth_searching),
          label: Text(_scanning ? tr.glassesSetSearching : tr.glassesSetSearch),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final pair in _pairs)
          ListTile(
            leading: const Icon(Icons.visibility),
            title: Text('G1 (g1v0) ${pair.channel}'),
            subtitle: Text(
              tr.glassesSetArms(pair.leftName ?? '–', pair.rightName ?? '–'),
            ),
            isThreeLine: true,
            enabled: pair.complete,
            onTap: pair.complete ? () => _select(pair) : null,
          ),
      ],
    );
  }
}

/// Activation angle and head gestures.
class DisplaySettings extends StatefulWidget {
  const DisplaySettings({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<DisplaySettings> createState() => _DisplaySettingsState();
}

class _DisplaySettingsState extends State<DisplaySettings> {
  late double _angle;

  @override
  void initState() {
    super.initState();
    final s = widget.bridge.settings;
    _angle = (s.headUpAngle ?? Bridge.defaultHeadUpAngle).toDouble();
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(tr.glassesSetNotConnected),
          ),
        _SliderRow(
          label: tr.glassesSetAngle,
          help: tr.glassesSetAngleHelp,
          value: _angle,
          min: 0,
          max: 60,
          unit: '°',
          notSet: s.headUpAngle == null,
          onChanged: (v) => setState(() => _angle = v),
          onChangeEnd: (v) => bridge.setHeadUpAngle(v.round()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr.glassesSetHeadGestures),
          subtitle: Text(tr.glassesSetHeadGesturesHelp),
          value: bridge.settings.headGestures,
          onChanged: bridge.setHeadGestures,
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.only(left: 16),
          title: Text(tr.glassesSetGyroCheck),
          subtitle: Text(tr.glassesSetGyroCheckHelp),
          value: bridge.settings.headUpGyroCheck,
          onChanged: bridge.settings.headGestures
              ? bridge.setHeadUpGyroCheck
              : null,
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
              notSet ? tr.glassesSetNotSet : '${value.round()}$unit',
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
