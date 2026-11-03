import 'dart:async';

import 'g1_connection.dart';
import 'protocol.dart';

/// Automatic brightness with an offset, managed by the app.
///
/// The firmware's automatic brightness steps the level towards a fixed
/// light-sensor table (g1-reverse `compute_lux_brightness_bucket`) and has no
/// offset. It writes the level it uses into the same field that 0x29 reads.
/// So the app lets the glasses measure in auto mode for a moment, reads the
/// level once it is stable and then sets level + offset manually. This only
/// happens while nothing is on the display, so the change is not visible,
/// and is repeated every [holdTime].
class AutoBrightness {
  AutoBrightness(this.g1, {required this.idle, required this.log});

  final G1Connection g1;

  /// True while nothing is shown (measuring is invisible then).
  final bool Function() idle;
  final void Function(String) log;

  static const holdTime = Duration(minutes: 2);
  static const retryTime = Duration(seconds: 10);
  Duration readInterval = const Duration(seconds: 1);
  static const maxReads = 45;

  /// Offset in brightness levels (-42..42); 0 = plain firmware auto mode.
  int offset = 0;

  /// Level chosen by the glasses' light sensor at the last measurement.
  int? sensorLevel;

  /// Level currently set by the app.
  int? appliedLevel;

  bool get running => _running;
  bool _running = false;
  int _generation = 0;
  Timer? _timer;

  /// Starts (or restarts) the offset mode.
  void start(int offsetLevels) {
    offset = offsetLevels;
    _running = true;
    final generation = ++_generation;
    _timer?.cancel();
    final sensor = sensorLevel;
    if (sensor != null) {
      // Known light level: apply the new offset right away.
      unawaited(_apply(sensor, generation));
    } else {
      unawaited(_measure(generation));
    }
  }

  void stop() {
    _running = false;
    _generation++;
    _timer?.cancel();
  }

  /// Glasses reconnected: measure again.
  void restart() {
    if (!_running) return;
    sensorLevel = null;
    start(offset);
  }

  void _schedule(Duration after, int generation) {
    _timer?.cancel();
    _timer = Timer(after, () => unawaited(_measure(generation)));
  }

  Future<void> _measure(int generation) async {
    if (generation != _generation) return;
    if (!g1.connected || !idle()) {
      _schedule(retryTime, generation);
      return;
    }
    // Auto on, starting from the current level so nothing jumps.
    await g1.sendSetting(
      G1Packets.brightnessLevel(appliedLevel ?? 21, auto: true),
    );
    int? last;
    var stable = 0;
    for (var i = 0; i < maxReads; i++) {
      await Future<void>.delayed(readInterval);
      if (generation != _generation) return;
      if (!g1.connected || !idle()) {
        // Something is shown: back to the last level, try again later.
        final applied = appliedLevel;
        if (applied != null && g1.connected) {
          await g1.sendSetting(G1Packets.brightnessLevel(applied, auto: false));
        }
        _schedule(retryTime, generation);
        return;
      }
      final level = await g1.readBrightnessLevel();
      if (level == null) continue;
      stable = level == last ? stable + 1 : 0;
      last = level;
      if (stable >= 2) break;
    }
    if (last == null) {
      _schedule(retryTime, generation);
      return;
    }
    await _apply(last, generation);
  }

  Future<void> _apply(int sensor, int generation) async {
    if (generation != _generation) return;
    sensorLevel = sensor;
    final level = (sensor + offset).clamp(0, G1Packets.maxBrightness);
    appliedLevel = level;
    if (g1.connected) {
      await g1.sendSetting(G1Packets.brightnessLevel(level, auto: false));
      log(
        'Auto-Helligkeit: Sensor ${G1Packets.brightnessPercent(sensor)} %, '
        'gesetzt ${G1Packets.brightnessPercent(level)} %',
      );
    }
    _schedule(holdTime, generation);
  }
}
