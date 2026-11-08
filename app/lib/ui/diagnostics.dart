import 'package:flutter/material.dart';

import '../bridge.dart';
import '../l10n/l10n.dart';

/// Test display, left/right check and the log.
class Diagnostics extends StatefulWidget {
  const Diagnostics({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<Diagnostics> createState() => _DiagnosticsState();
}

class _DiagnosticsState extends State<Diagnostics> {
  final _testText = TextEditingController(text: tr.diagTestTextDefault);

  @override
  void dispose() {
    _testText.dispose();
    super.dispose();
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
        Text(tr.diagLog, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
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
