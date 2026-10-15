import 'dart:async';

import 'package:flutter/material.dart';

import '../bridge.dart';
import '../g1/g1_connection.dart';
import '../ha/ha_client.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _url = TextEditingController(text: widget.bridge.settings.haUrl);
  late final _token = TextEditingController(
    text: widget.bridge.settings.haToken,
  );

  List<Map<String, dynamic>> _entries = [];
  String? _entryId;
  String? _haError;
  bool _haBusy = false;

  List<G1Pair> _pairs = [];
  bool _scanning = false;
  String? _scanError;
  StreamSubscription<List<G1Pair>>? _scanSub;

  @override
  void initState() {
    super.initState();
    final s = widget.bridge.settings;
    if (s.entryId.isNotEmpty) {
      _entryId = s.entryId;
      _entries = [
        {'entry_id': s.entryId, 'name': s.entryName},
      ];
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _haBusy = true;
      _haError = null;
    });
    final client = HaClient(_url.text, _token.text);
    try {
      await client.connect();
      final result = await client.call({'type': 'even_g1/devices'}) as List;
      final entries = result.cast<Map<String, dynamic>>();
      setState(() {
        _entries = entries;
        if (entries.isEmpty) {
          _haError =
              'Keine Brille in Home Assistant gefunden. Füge zuerst die '
              'Integration "Even Realities G1" hinzu.';
        }
        if (!entries.any((e) => e['entry_id'] == _entryId)) {
          _entryId = entries.isEmpty ? null : entries.first['entry_id'];
        }
      });
    } on HaException catch (e) {
      setState(() {
        _haError = e.code == 'unknown_command'
            ? 'Die Integration "Even Realities G1" ist in Home Assistant '
                  'nicht installiert.'
            : e.toString();
      });
    } catch (e) {
      setState(() => _haError = 'Verbindung fehlgeschlagen: $e');
    } finally {
      await client.close();
      if (mounted) setState(() => _haBusy = false);
    }
  }

  Future<void> _saveHa() async {
    final s = widget.bridge.settings;
    s.haUrl = _url.text;
    s.haToken = _token.text;
    final entry = _entries.firstWhere(
      (e) => e['entry_id'] == _entryId,
      orElse: () => {},
    );
    s.entryId = _entryId ?? '';
    s.entryName = entry['name'] as String? ?? '';
    await widget.bridge.restartHomeAssistant();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gespeichert')));
    }
  }

  void _scan() {
    _scanSub?.cancel();
    setState(() {
      _pairs = [];
      _scanning = true;
      _scanError = null;
    });
    _scanSub = G1Connection.scan().listen(
      (pairs) => setState(() => _pairs = pairs),
      onError: (Object e) => setState(() => _scanError = '$e'),
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  Future<void> _selectPair(G1Pair pair) async {
    await _scanSub?.cancel();
    setState(() => _scanning = false);
    final s = widget.bridge.settings;
    s.leftId = pair.leftId!;
    s.rightId = pair.rightId!;
    s.glassesName = 'G1 #${pair.channel}';
    await widget.bridge.reconnectGlasses();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.bridge.settings;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Home Assistant', style: text.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'http://homeassistant.local:8123',
            ),
          ),
          TextField(
            controller: _token,
            autocorrect: false,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Langlebiges Zugriffstoken',
              helperText: 'HA → Profil → Sicherheit → Token erstellen',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _haBusy ? null : _loadEntries,
            icon: _haBusy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text('Verbinden & Brillen aus HA laden'),
          ),
          if (_haError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _haError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_entries.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _entryId,
              decoration: const InputDecoration(
                labelText: 'Brille in Home Assistant',
              ),
              items: [
                for (final e in _entries)
                  DropdownMenuItem(
                    value: e['entry_id'] as String,
                    child: Text(e['name'] as String? ?? e['entry_id']),
                  ),
              ],
              onChanged: (v) => setState(() => _entryId = v),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _entryId == null ? null : _saveHa,
            child: const Text('Speichern'),
          ),
          const Divider(height: 48),
          Text('Brille', style: text.titleLarge),
          const SizedBox(height: 8),
          Text(
            s.glassesConfigured
                ? 'Gekoppelt: ${s.glassesName}'
                : 'Noch keine Brille gekoppelt.',
          ),
          const SizedBox(height: 4),
          const Text(
            'Die offizielle Even-App muss geschlossen sein, da sich die '
            'Brille nur mit einer App gleichzeitig verbindet.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching),
            label: Text(_scanning ? 'Suche…' : 'Nach Brillen suchen'),
          ),
          if (_scanError != null)
            Text(
              _scanError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final pair in _pairs)
            ListTile(
              leading: const Icon(Icons.visibility),
              title: Text('G1 #${pair.channel}'),
              subtitle: Text(
                'Links: ${pair.leftName ?? '–'}\nRechts: ${pair.rightName ?? '–'}',
              ),
              isThreeLine: true,
              enabled: pair.complete,
              onTap: pair.complete ? () => _selectPair(pair) : null,
            ),
        ],
      ),
    );
  }
}
