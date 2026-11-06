/// Clock model of one arm (VM.md §7): `PING` samples give the offset of the
/// arm's device time (u32 µs since its boot) from the host's clock, so both
/// eyes can be told to draw at the same moment.
class SkClock {
  /// The host's monotonic clock in µs, wrapped like the arms' clocks.
  static final Stopwatch _host = Stopwatch()..start();
  static int hostNow() => _host.elapsedMicroseconds & 0xffffffff;

  static const keep = 16;

  final List<({int offset, int delay})> _samples = [];

  static int _s32(int v) => (v & 0xffffffff).toSigned(32);

  /// Adds a `PING` round: sent at host time [sent], received by the arm at
  /// [armRx], answered at [armTx] (arm time), the reply arrived at
  /// [received] (host time).
  void add({
    required int sent,
    required int armRx,
    required int armTx,
    required int received,
  }) {
    final a = _s32(armRx - sent);
    final b = _s32(armTx - received);
    final delay = _s32(received - sent) - _s32(armTx - armRx);
    if (delay < 0) return;
    _samples.add((offset: a + (b - a) ~/ 2, delay: delay));
    if (_samples.length > keep) _samples.removeAt(0);
  }

  ({int offset, int delay})? get _best {
    if (_samples.isEmpty) return null;
    return _samples.reduce((x, y) => y.delay < x.delay ? y : x);
  }

  bool get known => _samples.isNotEmpty;

  /// Upper bound of the offset's error, µs (half the best round's delay).
  int get errorUs => (_best?.delay ?? 0) ~/ 2;

  /// [hostUs] in the arm's clock.
  int toArm(int hostUs) => (hostUs + (_best?.offset ?? 0)) & 0xffffffff;

  /// The arm rebooted: its clock started again.
  void reset() => _samples.clear();
}
