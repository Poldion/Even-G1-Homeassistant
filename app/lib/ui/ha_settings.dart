import 'package:flutter/material.dart';

import '../bridge.dart';
import '../ha/ha_client.dart';
import '../l10n/l10n.dart';

/// Connection to Home Assistant: URL, token and the glasses entry.
class HaSettings extends StatefulWidget {
  const HaSettings({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<HaSettings> createState() => _HaSettingsState();
}

class _HaSettingsState extends State<HaSettings> {
  late final _url = TextEditingController(text: widget.bridge.settings.haUrl);
  late final _token = TextEditingController(
    text: widget.bridge.settings.haToken,
  );

  List<Map<String, dynamic>> _entries = [];
  String? _entryId;
  String? _error;
  bool _busy = false;

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
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = HaClient(_url.text, _token.text);
    try {
      await client.connect();
      final result = await client.call({'type': 'even_g1/devices'}) as List;
      final entries = result.cast<Map<String, dynamic>>();
      setState(() {
        _entries = entries;
        if (entries.isEmpty) {
          _error = tr.haSetNoGlasses;
        }
        if (!entries.any((e) => e['entry_id'] == _entryId)) {
          _entryId = entries.isEmpty ? null : entries.first['entry_id'];
        }
      });
    } on HaException catch (e) {
      setState(() {
        _error = e.code == 'unknown_command'
            ? tr.haSetNotInstalled
            : e.toString();
      });
    } catch (e) {
      setState(() => _error = tr.haSetConnectFailed('$e'));
    } finally {
      await client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
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
          .showSnackBar(SnackBar(content: Text(tr.saved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          decoration: InputDecoration(
            labelText: tr.haSetToken,
            helperText: tr.haSetTokenHelp,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _loadEntries,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(tr.haSetLoad),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_entries.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _entryId,
            decoration: InputDecoration(labelText: tr.haSetGlasses),
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
          onPressed: _entryId == null ? null : _save,
          child: Text(tr.save),
        ),
      ],
    );
  }
}
