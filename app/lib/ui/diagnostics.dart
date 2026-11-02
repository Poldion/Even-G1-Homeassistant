import 'package:flutter/material.dart';

import '../bridge.dart';

/// Test display, left/right check and the log.
class Diagnostics extends StatefulWidget {
  const Diagnostics({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<Diagnostics> createState() => _DiagnosticsState();
}

class _DiagnosticsState extends State<Diagnostics> {
  final _testText = TextEditingController(text: 'Hallo von Home Assistant!');

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
          decoration: const InputDecoration(labelText: 'Testtext'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: connected
                    ? () => bridge.sendTestText(_testText.text)
                    : null,
                child: const Text('Auf Brille anzeigen'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: connected ? bridge.display.clear : null,
              child: const Text('Schließen'),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: connected
              ? () async {
                  final text = await bridge.checkDisplay();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(text)));
                }
              : null,
          icon: const Icon(Icons.compare),
          label: const Text('Anzeige links/rechts prüfen'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Assist-Antworten im Even-AI-Modus (Test)'),
          subtitle: const Text(
            'Zeigt Antworten wie die offizielle Even-App an. Ausprobieren, '
            'falls ein Auge etwas anderes zeigt als das andere.',
          ),
          value: bridge.settings.evenAiAnswers,
          onChanged: bridge.setEvenAiAnswers,
        ),
        const SizedBox(height: 8),
        Text('Protokoll', style: Theme.of(context).textTheme.titleSmall),
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
