import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../update/app_update.dart';
import '../l10n/l10n.dart';

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
      messenger?.showSnackBar(SnackBar(content: Text(tr.updateCheckFailed)));
    }
    return;
  }
  if (!context.mounted) return;
  if (update == null) {
    if (manual) {
      messenger?.showSnackBar(SnackBar(content: Text(tr.updateUpToDate)));
    }
    return;
  }
  final found = update;
  final install = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        !found.switchesChannel
            ? tr.updateAvailable(found.version)
            : found.channel == UpdateChannel.preview
            ? tr.updatePreviewVersion(found.version)
            : tr.updateStableVersion(found.version),
      ),
      content: SingleChildScrollView(
        child: Text(
          '${found.notes.isEmpty ? '' : '${found.notes}\n\n'}'
          '${tr.updateInstallQuestion}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr.updateLater),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr.updateInstall),
        ),
      ],
    ),
  );
  if (install == true && !await AppUpdater.install(found)) {
    messenger?.showSnackBar(SnackBar(content: Text(tr.updateDownloadFailed)));
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
  UpdateChannel _channel = UpdateChannel.stable;

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

  /// Switches the update channel; the preview channel only after a
  /// warning. Then looks for that channel's build right away.
  Future<void> _setChannel(UpdateChannel channel) async {
    if (channel == _channel) return;
    if (channel == UpdateChannel.preview) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber),
          title: Text(tr.updatePreviewQuestion),
          content: SingleChildScrollView(child: Text(tr.updatePreviewWarning)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr.updateCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr.updateSwitch),
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
              ? tr.updateVersionUnknown
              : tr.updateInstalled(_version),
        ),
        const SizedBox(height: 4),
        Text(tr.updateDailyCheck, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(tr.updateChannel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        SegmentedButton<UpdateChannel>(
          segments: [
            ButtonSegment(
              value: UpdateChannel.stable,
              label: Text(tr.updateChannelStable),
            ),
            ButtonSegment(
              value: UpdateChannel.preview,
              label: Text(tr.updateChannelPreview),
              icon: const Icon(Icons.science_outlined),
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
          label: Text(tr.updateCheck),
        ),
      ],
    );
  }
}
