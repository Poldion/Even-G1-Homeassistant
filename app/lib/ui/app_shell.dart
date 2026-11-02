import 'package:flutter/material.dart';

import '../bridge.dart';
import '../main.dart';
import 'overview_page.dart';
import 'settings_tab.dart';
import 'update_settings.dart';

/// Main screen with the tabs "Übersicht" and "Einstellungen".
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final s = widget.bridge.settings;
    if (!s.haConfigured || !s.glassesConfigured) _tab = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ensureBackgroundOperation();
      await widget.bridge.start();
      if (mounted) await checkForAppUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Even G1 · Home Assistant' : 'Einstellungen'),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          OverviewPage(bridge: widget.bridge),
          SettingsTab(bridge: widget.bridge),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Übersicht',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}
