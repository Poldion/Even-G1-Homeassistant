import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../update/app_update.dart';

/// Checks for a new version and offers to install it.
///
/// With [manual] false (on start) nothing is shown unless there is an update
/// and errors are ignored.
Future<void> checkForAppUpdate(
  BuildContext context, {
  bool manual = false,
}) async {
  if (!AppUpdater.supported) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!manual && (!kReleaseMode || !await AppUpdater.dailyCheckDue())) return;
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
      title: Text(
        !found.switchesChannel
            ? 'Version ${found.version} ist verfügbar'
            : found.channel == UpdateChannel.scouterKit
            ? 'ScouterKit-Version ${found.version}'
            : 'Stabile Version ${found.version}',
      ),
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
  UpdateChannel _channel = AppUpdater.buildChannel;

  @override
  void initState() {
    super.initState();
    if (AppUpdater.supported) {
      AppUpdater.currentVersion().then((v) {
        if (mounted) setState(() => _version = v);
      });
    }
    AppUpdater.channel().then((c) {
      if (mounted) setState(() => _channel = c);
    });
  }

  /// Switches the update channel; the ScouterKit channel only after a
  /// warning. Then looks for that channel's build right away.
  Future<void> _setChannel(UpdateChannel channel) async {
    if (channel == _channel) return;
    if (channel == UpdateChannel.scouterKit) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber),
          title: const Text('ScouterKit-Version installieren?'),
          content: const SingleChildScrollView(
            child: Text(
              'Diese experimentelle Version ist für Brillen mit der '
              'Ersatz-Firmware ScouterKit (g1v0) gedacht. Diese Firmware '
              'musst du selbst auf die Brille aufspielen. Das lässt sich '
              'nicht rückgängig machen, und die offizielle Even-App '
              'funktioniert danach nicht mehr (Anleitung: docs/SCOUTERKIT.md '
              'im GitHub-Projekt).\n\n'
              'Mit Evens Firmware arbeitet die ScouterKit-Version weiter wie '
              'bisher (Einstellung „Even“ unter Brille).\n\n'
              'Zurück zum stabilen Kanal geht es mit dem nächsten stabilen '
              'Release. Android installiert keine älteren Builds, sonst geht '
              'es nur über eine Neuinstallation.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Wechseln'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await AppUpdater.setChannel(channel);
    if (!mounted) return;
    setState(() => _channel = channel);
    await _check();
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
          _version.isEmpty
              ? 'Installierte Version unbekannt'
              : 'Installiert: $_version',
        ),
        const SizedBox(height: 4),
        Text(
          'Die App sucht einmal am Tag beim Start nach neuen Versionen auf '
          'GitHub.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text('Update-Kanal', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        SegmentedButton<UpdateChannel>(
          segments: const [
            ButtonSegment(value: UpdateChannel.stable, label: Text('Stabil')),
            ButtonSegment(
              value: UpdateChannel.scouterKit,
              label: Text('ScouterKit'),
              icon: Icon(Icons.science_outlined),
            ),
          ],
          selected: {_channel},
          onSelectionChanged: _checking ? null : (v) => _setChannel(v.first),
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
