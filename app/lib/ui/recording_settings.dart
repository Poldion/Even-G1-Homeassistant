import 'package:flutter/material.dart';

import '../bridge.dart';

/// WhisperNotes server and the recording dot.
class RecordingSettings extends StatefulWidget {
  const RecordingSettings({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<RecordingSettings> createState() => _RecordingSettingsState();
}

class _RecordingSettingsState extends State<RecordingSettings> {
  late final _url = TextEditingController(
    text: widget.bridge.settings.whisperUrl,
  );
  late final _key = TextEditingController(
    text: widget.bridge.settings.whisperApiKey,
  );

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  void _save() {
    final s = widget.bridge.settings;
    s.whisperUrl = _url.text;
    s.whisperApiKey = _key.text;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Gespeichert')));
    widget.bridge.recorder.sendPending();
  }

  @override
  Widget build(BuildContext context) {
    final bridge = widget.bridge;
    final r = bridge.recorder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aufnahmen mit dem Brillen-Mikrofon gehen an WhisperNotes, werden '
          'dort transkribiert und zusammengefasst und landen im Eingang von '
          'BasaltNotes, wenn in WhisperNotes unter Einstellungen → BasaltNotes '
          'ein Standard-Vault gewählt ist.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'WhisperNotes-Adresse',
            hintText: 'http://192.168.1.10:8000',
          ),
        ),
        TextField(
          controller: _key,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'API-Schlüssel (optional)',
            helperText: 'Nur nötig, wenn in WhisperNotes einer gesetzt ist.',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(onPressed: _save, child: const Text('Speichern')),
            const SizedBox(width: 8),
            if (r.pending > 0)
              TextButton(
                onPressed: r.uploading ? null : r.sendPending,
                child: Text('${r.pending} ausstehende senden'),
              ),
          ],
        ),
        if (bridge.g1.evenFirmware)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Punkt auf der Brille'),
            subtitle: const Text(
              'Kleiner Punkt oben rechts, solange aufgenommen wird und nichts '
              'anderes angezeigt wird.',
            ),
            value: bridge.settings.recordingDot,
            onChanged: bridge.setRecordingDot,
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Während einer Aufnahme zeigt ScouterKit selbst ein kleines '
              'Quadrat oben rechts im rechten Auge, solange das Mikrofon an '
              'ist. Es lässt sich nicht ausschalten.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
