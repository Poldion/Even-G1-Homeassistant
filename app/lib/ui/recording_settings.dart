import 'package:flutter/material.dart';

import '../bridge.dart';
import '../l10n/l10n.dart';

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
        .showSnackBar(SnackBar(content: Text(tr.saved)));
    widget.bridge.recorder.sendPending();
  }

  @override
  Widget build(BuildContext context) {
    final bridge = widget.bridge;
    final r = bridge.recorder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr.recSetIntro, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: tr.recSetUrl,
            hintText: 'http://192.168.1.10:8000',
          ),
        ),
        TextField(
          controller: _key,
          obscureText: true,
          decoration: InputDecoration(
            labelText: tr.recSetKey,
            helperText: tr.recSetKeyHelp,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(onPressed: _save, child: Text(tr.save)),
            const SizedBox(width: 8),
            if (r.pending > 0)
              TextButton(
                onPressed: r.uploading ? null : r.sendPending,
                child: Text(tr.recSetSendPending(r.pending)),
              ),
          ],
        ),
        if (bridge.g1.evenFirmware)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr.recSetDot),
            subtitle: Text(tr.recSetDotHelp),
            value: bridge.settings.recordingDot,
            onChanged: bridge.setRecordingDot,
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              tr.recSetScouterDot,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
