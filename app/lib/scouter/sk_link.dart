import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

/// The packet window of one arm (VM.md §6.2): numbered `CMD` packets, sent
/// within the arm's credits, resent on a hole in the selective ack or after
/// the retransmission timeout (RFC 6298).
class SkLink {
  SkLink(this._write, {this.log});

  /// Writes one packet (u16 seq + host code) to `CMD`.
  final Future<void> Function(Uint8List packet) _write;
  final void Function(String)? log;

  static const window = 32;

  int maxPacket = 20;
  int _nextSeq = 0;
  int _rxNext = 0;
  int _execNext = 0;
  int _credits = 0;

  final List<_Packet> _unacked = [];
  final List<_Packet> _queued = [];
  final Set<int> _failed = {};

  int? _srttUs;
  int _rttvarUs = 0;
  int _backoff = 0;
  Timer? _rtoTimer;
  bool _up = false;
  bool _pumping = false;

  /// The window as the arm reported it (`HELLO`, `RESET_SESSION`).
  void start(int rxNext, int execNext, int credits, int maxPacket) {
    this.maxPacket = maxPacket;
    _up = true;
    final fresh = _unacked.isEmpty && _queued.isEmpty;
    if (fresh) _nextSeq = rxNext;
    _rxNext = rxNext;
    _execNext = execNext;
    _credits = credits;
    _unacked.removeWhere((p) => _before(p.seq, rxNext));
    // Same session after a reconnect: what was not received goes again.
    for (final p in _unacked) {
      p.resent = true;
      _send(p);
    }
    _settle();
    _pump();
  }

  /// A new session: nothing sent before counts.
  void reset() {
    _rtoTimer?.cancel();
    _unacked.clear();
    _queued.clear();
    _failAll();
    _srttUs = null;
    _backoff = 0;
  }

  /// The link dropped: packets wait until [start].
  void down() {
    _up = false;
    _rtoTimer?.cancel();
  }

  void dispose() {
    down();
    _failAll();
  }

  void _failAll() {
    for (final r in _ranges) {
      if (!r.done.isCompleted) r.done.complete(false);
    }
    _ranges.clear();
    _failed.clear();
  }

  /// Sends [codes] (host code, each at most maxPacket - 2 bytes) as packets
  /// in order. Completes with true once the arm ran all of them without an
  /// error, false on an error or when the session is reset.
  Future<bool> run(List<Uint8List> codes) {
    if (codes.isEmpty) return Future.value(true);
    final first = _nextSeq;
    for (final code in codes) {
      final data = Uint8List(code.length + 2)
        ..[0] = _nextSeq & 0xff
        ..[1] = (_nextSeq >> 8) & 0xff
        ..setRange(2, code.length + 2, code);
      _queued.add(_Packet(_nextSeq, data));
      _nextSeq = (_nextSeq + 1) & 0xffff;
    }
    final last = (_nextSeq - 1) & 0xffff;
    final done = Completer<bool>();
    _ranges.add(_Range(first, last, done));
    _pump();
    return done.future;
  }

  final List<_Range> _ranges = [];

  bool get idle => _unacked.isEmpty && _queued.isEmpty;

  /// Runs wait for the arm (sent but not yet executed).
  bool get waiting => _ranges.isNotEmpty;

  /// Last time an ACK arrived.
  DateTime lastHeard = DateTime.now();

  static bool _before(int a, int b) => ((a - b) & 0xffff) >= 0x8000;

  void _send(_Packet p) {
    p.sentAt = DateTime.now();
    _write(p.data).catchError((Object e) {
      log?.call('CMD write failed: $e');
    });
  }

  void _pump() {
    if (!_up || _pumping) return;
    _pumping = true;
    try {
      while (_queued.isNotEmpty) {
        final p = _queued.first;
        // Within the credits: seq < rx_next + credits.
        if (((p.seq - _rxNext) & 0xffff) >= _credits) break;
        _queued.removeAt(0);
        _unacked.add(p);
        _send(p);
      }
    } finally {
      _pumping = false;
    }
    _armRto();
  }

  Duration get _rto {
    final srtt = _srttUs;
    final estimate = srtt == null ? 1000000 : srtt + 4 * _rttvarUs;
    final us = min(max(estimate, 100000) << _backoff, 3000000);
    return Duration(microseconds: us);
  }

  void _armRto() {
    _rtoTimer?.cancel();
    if (_unacked.isEmpty || !_up) return;
    _rtoTimer = Timer(_rto, () {
      if (_unacked.isEmpty || !_up) return;
      final p = _unacked.first;
      p.resent = true;
      _backoff = min(_backoff + 1, 3);
      log?.call('CMD ${p.seq} resent (timeout)');
      _send(p);
      _armRto();
    });
  }

  /// `ACK` event (VM.md §6.3).
  void onAck(int rxNext, int execNext, int credits, int sack) {
    lastHeard = DateTime.now();
    final progressed = rxNext != _rxNext;
    final now = DateTime.now();
    while (_unacked.isNotEmpty && _before(_unacked.first.seq, rxNext)) {
      final p = _unacked.removeAt(0);
      if (!p.resent && p.sentAt != null) {
        _sample(now.difference(p.sentAt!).inMicroseconds);
      }
    }
    _rxNext = rxNext;
    _execNext = execNext;
    _credits = credits;
    if (progressed) _backoff = 0;
    // Holes before the highest packet the arm holds: resend once per RTT.
    if (sack != 0 && _unacked.isNotEmpty) {
      final highest = 31 - _clz32(sack);
      final rtt = Duration(microseconds: _srttUs ?? 100000);
      for (final p in _unacked) {
        final i = ((p.seq - rxNext) & 0xffff) - 1;
        final hole = i < 0 || (i <= highest && sack & (1 << i) == 0);
        if (!hole) continue;
        if (p.sentAt != null && now.difference(p.sentAt!) < rtt) continue;
        p.resent = true;
        _send(p);
      }
    }
    _settle();
    _pump();
  }

  static int _clz32(int x) {
    var n = 0;
    for (var bit = 31; bit >= 0 && x & (1 << bit) == 0; bit--) {
      n++;
    }
    return n;
  }

  void _sample(int us) {
    final srtt = _srttUs;
    if (srtt == null) {
      _srttUs = us;
      _rttvarUs = us ~/ 2;
    } else {
      _rttvarUs = (3 * _rttvarUs + (srtt - us).abs()) ~/ 4;
      _srttUs = (7 * srtt + us) ~/ 8;
    }
  }

  /// `ERROR` event: the packet [seq] ended with an error.
  void onError(int seq) {
    _failed.add(seq);
    _settle();
  }

  /// Completes the runs whose packets have all been executed.
  void _settle() {
    _ranges.removeWhere((r) {
      if (r.done.isCompleted) return true;
      var bad = false;
      for (
        var s = r.first;
        s != ((r.last + 1) & 0xffff);
        s = (s + 1) & 0xffff
      ) {
        if (_failed.contains(s)) bad = true;
      }
      if (bad || _before(r.last, _execNext)) {
        for (
          var s = r.first;
          s != ((r.last + 1) & 0xffff);
          s = (s + 1) & 0xffff
        ) {
          _failed.remove(s);
        }
        r.done.complete(!bad);
        return true;
      }
      return false;
    });
  }
}

class _Packet {
  _Packet(this.seq, this.data);

  final int seq;
  final Uint8List data;
  DateTime? sentAt;
  bool resent = false;
}

class _Range {
  _Range(this.first, this.last, this.done);

  final int first;
  final int last;
  final Completer<bool> done;
}
