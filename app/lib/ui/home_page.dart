import 'package:flutter/material.dart';

import '../bridge.dart';
import '../main.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _testText = TextEditingController(text: 'Hallo von Home Assistant!');

  Bridge get bridge => widget.bridge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ensureBackgroundOperation();
      await bridge.start();
      if (mounted &&
          !bridge.settings.haConfigured &&
          !bridge.settings.glassesConfigured) {
        _openSettings();
      }
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SettingsPage(bridge: bridge)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Even G1 ↔ Home Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Einstellungen',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: bridge,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(
              icon: Icons.visibility,
              title: bridge.settings.glassesName.isEmpty
                  ? 'Brille'
                  : bridge.settings.glassesName,
              status: bridge.settings.glassesConfigured
                  ? bridge.g1.status
                  : 'nicht eingerichtet',
              ok: bridge.g1.connected,
              details: [
                if (bridge.g1.batteryLeft != null)
                  'Akku L ${bridge.g1.batteryLeft}% · R ${bridge.g1.batteryRight ?? '?'}%',
              ],
              action: TextButton(
                onPressed: bridge.settings.glassesConfigured
                    ? bridge.reconnectGlasses
                    : _openSettings,
                child: const Text('Neu verbinden'),
              ),
            ),
            _StatusCard(
              icon: Icons.home,
              title: bridge.settings.entryName.isEmpty
                  ? 'Home Assistant'
                  : 'Home Assistant · ${bridge.settings.entryName}',
              status: bridge.settings.haConfigured
                  ? bridge.haStatus
                  : 'nicht eingerichtet',
              ok: bridge.haConnected,
              details: [
                if (bridge.haConnected)
                  'Assist: ${bridge.haConfig.assistPipeline ?? 'bevorzugte Pipeline'}',
              ],
              action: TextButton(
                onPressed: bridge.settings.haConfigured
                    ? bridge.restartHomeAssistant
                    : _openSettings,
                child: const Text('Neu verbinden'),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          bridge.assistRunning
                              ? Icons.mic
                              : Icons.record_voice_over,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bridge.assistRunning ? 'Assist hört zu…' : 'Assist',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Linke Touchbar gedrückt halten, sprechen, loslassen.',
                    ),
                    if (bridge.lastQuery != null) ...[
                      const SizedBox(height: 8),
                      Text('Frage: ${bridge.lastQuery}'),
                    ],
                    if (bridge.lastResponse != null)
                      Text('Antwort: ${bridge.lastResponse}'),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Testanzeige',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextField(controller: _testText, maxLines: 3),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: bridge.g1.connected
                                ? () => bridge.sendTestText(_testText.text)
                                : null,
                            child: const Text('Auf Brille anzeigen'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: bridge.g1.connected
                              ? bridge.display.clear
                              : null,
                          child: const Text('Schließen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ExpansionTile(
              title: const Text('Protokoll'),
              children: [
                for (final line in bridge.logLines.reversed.take(100))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.ok,
    required this.details,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool ok;
  final List<String> details;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green : Theme.of(context).colorScheme.outline;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text([status, ...details].join('\n')),
        isThreeLine: details.isNotEmpty,
        trailing: action,
      ),
    );
  }
}
