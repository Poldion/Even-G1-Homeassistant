import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge.dart';
import '../l10n/l10n.dart';
import '../update/app_update.dart';

/// Test display, left/right check and the log.
class Diagnostics extends StatefulWidget {
  const Diagnostics({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<Diagnostics> createState() => _DiagnosticsState();
}

class _DiagnosticsState extends State<Diagnostics> {
  final _testText = TextEditingController(text: tr.diagTestTextDefault);

  static const _share = MethodChannel('even_g1/share');

  @override
  void dispose() {
    _testText.dispose();
    super.dispose();
  }

  Future<String> _report() async {
    final version = AppUpdater.supported
        ? await AppUpdater.currentVersion()
        : '';
    return widget.bridge.logReport(appVersion: version);
  }

  /// The whole log into the clipboard.
  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: await _report()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr.diagLogCopied(widget.bridge.logLines.length))),
    );
  }

  /// The whole log to another app (Android's share sheet).
  Future<void> _shareLog() async {
    final text = await _report();
    try {
      await _share.invokeMethod('text', {
        'text': text,
        'subject': tr.diagLogSubject,
      });
    } on MissingPluginException {
      await _copy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bridge = widget.bridge;
    final connected = bridge.g1.connected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _testText,
          maxLines: 3,
          decoration: InputDecoration(labelText: tr.diagTestText),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: connected
                    ? () => bridge.sendTestText(_testText.text)
                    : null,
                child: Text(tr.diagShowOnGlasses),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: connected ? bridge.display.clear : null,
              child: Text(tr.diagClose),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                tr.diagLog,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: tr.diagLogCopy,
              icon: const Icon(Icons.copy),
              onPressed: _copy,
            ),
            IconButton(
              tooltip: tr.diagLogShare,
              icon: const Icon(Icons.share),
              onPressed: _shareLog,
            ),
          ],
        ),
        Container(
          height: 260,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView(
            children: [
              for (final line in bridge.logLines.reversed.take(150))
                Text(
                  line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
