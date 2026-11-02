import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../update/app_update.dart';

/// Checks for a new version and offers to install it.
///
/// With [manual] false (on start) nothing is shown unless there is an update
/// and errors are ignored.
Future<void> checkForAppUpdate(BuildContext context, {bool manual = false}) async {
  if (!AppUpdater.supported) return;
  if (!manual && (!kReleaseMode || !await AppUpdater.dailyCheckDue())) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  AppUpdate? update;
  try {
    update = await AppUpdater.check();
  } catch (_) {
    if (manual) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Konnte nicht nach Updates suchen.')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  if (update == null) {
    if (manual) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Die App ist aktuell.')),
      );
    }
    return;
  }
  final found = update;
  final install = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Version ${found.version} ist verfügbar'),
      content: SingleChildScrollView(
        child: Text(
          '${found.notes.isEmpty ? '' : '${found.notes}\n\n'}'
          'Jetzt laden und installieren? Deine Einstellungen bleiben erhalten.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Später'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Installieren'),
        ),
      ],
    ),
  );
  if (install == true && !await AppUpdater.install(found)) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Das Update konnte nicht geladen werden.')),
    );
  }
}

/// Settings section: installed version and manual update check.
class UpdateSettings extends StatefulWidget {
  const UpdateSettings({super.key});

  @override
  State<UpdateSettings> createState() => _UpdateSettingsState();
}

class _UpdateSettingsState extends State<UpdateSettings> {
  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (AppUpdater.supported) {
      AppUpdater.currentVersion().then((v) {
        if (mounted) setState(() => _version = v);
      });
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    await checkForAppUpdate(context, manual: true);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _version.isEmpty ? 'Installierte Version unbekannt' : 'Installiert: $_version',
        ),
        const SizedBox(height: 4),
        Text(
          'Die App sucht einmal am Tag beim Start nach neuen Versionen auf '
          'GitHub.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: !AppUpdater.supported || _checking ? null : _check,
          icon: _checking
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.system_update),
          label: const Text('Nach Updates suchen'),
        ),
      ],
    );
  }
}
