import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge.dart';
import '../l10n/l10n.dart';
import '../scouter/scouter_connection.dart';
import '../scouter/sk_video.dart';

/// The hidden video player (seven taps on the installed version): plays a
/// video from the phone in black and white on both eyes, the sound on the
/// phone.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.bridge});

  final Bridge bridge;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  static const _channel = MethodChannel('even_g1/video');

  /// The largest picture: centred on the panel, where both eyes see it.
  static const maxWidth = 480, maxHeight = 360;
  static const maxFps = 15.0;

  String? _uri, _name;
  bool _invert = false;
  bool _playing = false, _stop = false;
  String? _message;
  ({int width, int height, double fps, int frames, int durationMs})? _info;
  int _frame = 0, _skipped = 0;

  @override
  void dispose() {
    _stop = true;
    _channel.invokeMethod('close');
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await _channel.invokeMapMethod<String, Object?>('pick');
    if (picked == null || !mounted) return;
    setState(() {
      _uri = picked['uri'] as String?;
      _name = picked['name'] as String?;
      _info = null;
      _message = null;
    });
    await _open();
  }

  /// Opens the video (again: the frames start over) and reads its size.
  Future<bool> _open() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('open', {
        'uri': _uri,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
        'maxFps': maxFps,
        'invert': _invert,
      });
      if (m == null || !mounted) return false;
      setState(
        () => _info = (
          width: m['width'] as int,
          height: m['height'] as int,
          fps: (m['fps'] as num).toDouble(),
          frames: m['frames'] as int,
          durationMs: m['durationMs'] as int,
        ),
      );
      return true;
    } on PlatformException {
      if (mounted) setState(() => _message = tr.videoOpenFailed);
      return false;
    }
  }

  Future<void> _play() async {
    final g1 = widget.bridge.g1;
    if (g1 is! ScouterConnection || !g1.connected) {
      setState(() => _message = tr.videoNotConnected);
      return;
    }
    if (!await _open()) return;
    final info = _info!;
    setState(() {
      _playing = true;
      _stop = false;
      _frame = 0;
      _skipped = 0;
      _message = null;
    });
    final end = await g1.playVideo(
      width: info.width,
      height: info.height,
      fps: info.fps,
      frames: info.frames,
      read: (start, count) async =>
          await _channel.invokeMethod<Uint8List>('frames', {
            'start': start,
            'count': count,
          }) ??
          Uint8List(0),
      onStart: () => _channel.invokeMethod('audioStart'),
      onProgress: (frame, skipped) {
        if (!mounted) return;
        // A redraw now and then is enough.
        if (frame - _frame >= 5 || frame == info.frames - 1) {
          setState(() {
            _frame = frame;
            _skipped = skipped;
          });
        }
      },
      stopped: () => _stop,
    );
    await _channel.invokeMethod('audioStop');
    if (!mounted) return;
    setState(() {
      _playing = false;
      _message = switch (end) {
        SkVideoEnd.done => tr.videoDone,
        SkVideoEnd.stopped => null,
        SkVideoEnd.failed => tr.videoFailed,
        SkVideoEnd.unavailable => tr.videoNotConnected,
      };
    });
  }

  static String _time(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.videoTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr.videoIntro),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.movie_outlined),
            title: Text(_name ?? tr.videoNone),
            subtitle: info == null
                ? null
                : Text(
                    tr.videoInfo(
                      '${info.width}',
                      '${info.height}',
                      info.fps.toStringAsFixed(info.fps % 1 == 0 ? 0 : 1),
                      _time(info.durationMs),
                    ),
                  ),
            trailing: TextButton(
              onPressed: _playing ? null : _pick,
              child: Text(tr.videoPick),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr.videoInvert),
            value: _invert,
            onChanged: _playing ? null : (v) => setState(() => _invert = v),
          ),
          const SizedBox(height: 8),
          if (_playing && info != null) ...[
            LinearProgressIndicator(
              value: info.frames == 0 ? null : (_frame + 1) / info.frames,
            ),
            const SizedBox(height: 4),
            Text(
              tr.videoProgress(
                _time((_frame * 1000 / info.fps).round()),
                _time(info.durationMs),
                '$_skipped',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              FilledButton.icon(
                onPressed: _playing || _uri == null ? null : _play,
                icon: const Icon(Icons.play_arrow),
                label: Text(tr.videoPlay),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _playing ? () => setState(() => _stop = true) : null,
                icon: const Icon(Icons.stop),
                label: Text(tr.videoStop),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
        ],
      ),
    );
  }
}
