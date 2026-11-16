/// The navigation's big arrow above the text: the model (TurnArrow), the
/// words the arm program reads, the host code the app sends, Navigation's
/// mark right at the turn and the bridge's part. The program itself runs
/// only in ScouterKit's C interpreter; here its arithmetic is repeated on
/// the words in the arena (turn_arrow_check.dart).
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:even_g1_ha/bridge.dart';
import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/navigation/navigation.dart';
import 'package:even_g1_ha/navigation/turn_arrow.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_asm.dart';
import 'package:even_g1_ha/scouter/sk_icons.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_arms.dart';
import 'fake_glasses.dart';
import 'turn_arrow_check.dart';

/// Distances as Google Maps gives them, with none (null).
const _meters = <int?>[null, 0, 10, 25, 30, 31, 45, 90, 200, 330, 500, 5000];

/// Every arrow the app can send: approaching at every distance, and at
/// every kind of turn.
Iterable<(String, TurnArrow)> _all() sync* {
  for (final m in [..._meters, 100000]) {
    yield ('approach $m m', TurnArrow.approach(m));
  }
  for (final turn in NavTurn.values) {
    yield ('at $turn', TurnArrow.at(turn));
  }
}

/// The arrow's words written into an empty arena, for [arrowProblems].
Uint8List _arena(TurnArrow a) {
  final arena = Uint8List(SkArena.size);
  final data = a.data();
  arena.setRange(
    SkResident.arrowData,
    SkResident.arrowData + data.length,
    data,
  );
  return arena;
}

/// The rows of a panel image that are lit.
Set<int> _litRows(Uint8List panel) => {
  for (var i = 0; i < panel.length; i++)
    if (panel[i] != 0) i ~/ SkPanel.stride,
};

/// The tip of the arrow (the shape's highest point, pointing up).
(int, int) _tipOf(List<TurnSegment> shape) {
  var tip = (0, 1 << 30);
  for (final s in shape) {
    for (final (x, y) in [(s.x0, s.y0), (s.x1, s.y1)]) {
      if (y < tip.$2) tip = (x, y);
    }
  }
  return tip;
}

/// Where the arrow points in [frame]: degrees counter-clockwise from up
/// (left 90, right −90, down ±180), seen on the panel.
double _heading(TurnArrow a, TurnFrame frame) {
  final (tx, ty) = _tipOf(a.segments);
  final (px, py) = a.transform(tx, ty, frame);
  final vx = px - (a.cx + frame.dx), vy = py - (a.cy + frame.dy);
  return atan2(-vx, -vy) * 180 / pi;
}

/// The arrow's scale in [frame] (1: full size).
double _scale(TurnFrame f) => sqrt(f.c * f.c + f.s * f.s) / 4096;

double _width(TurnFrame f) => (f.box.$3 - f.box.$1).toDouble();

/// [b] − [a] in degrees, within (−180, 180].
double _turned(double a, double b) {
  var d = (b - a) % 360;
  if (d > 180) d -= 360;
  return d;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model', () {
    test('every arrow stays above the text and on the panel, in every '
        'frame', () {
      for (final (name, a) in _all()) {
        expect(a.frames, isNotEmpty, reason: name);
        expect(a.frames.length, lessThanOrEqualTo(TurnArrow.maxFrames));
        expect(a.segments.length, lessThanOrEqualTo(TurnArrow.maxSegments));
        expect(
          arrowProblems(_arena(a), textTop: ScouterConnection.textTop),
          isEmpty,
          reason: name,
        );
        for (final f in a.frames) {
          expect(f.box.$2, greaterThanOrEqualTo(TurnArrow.top), reason: name);
          expect(f.box.$4, lessThanOrEqualTo(TurnArrow.bottom), reason: name);
        }
      }
      // The text below starts after the arrow's rows.
      expect(TurnArrow.bottom, lessThan(ScouterConnection.textTop));
    });

    test('what it draws: nothing on the text\'s rows, no trail of earlier '
        'frames', () {
      for (final (name, a) in _all()) {
        final panel = Uint8List(SkPanel.stride * SkPanel.height);
        for (var k = 0; k < a.frames.length; k++) {
          a.drawInto(panel, k);
          final rows = _litRows(panel);
          expect(rows, isNotEmpty, reason: '$name, frame $k');
          expect(rows.reduce(min), greaterThanOrEqualTo(TurnArrow.top));
          expect(
            rows.reduce(max),
            lessThan(ScouterConnection.textTop),
            reason: '$name, frame $k: over the text',
          );
          // Each frame clears what the one before drew: the panel holds
          // only this frame.
          final alone = Uint8List(SkPanel.stride * SkPanel.height);
          a.drawInto(alone, k);
          expect(
            panel,
            alone,
            reason: '$name, frame $k: pixels of an earlier frame left',
          );
        }
      }
    });

    test('it comes closer: from smaller and higher to its size, larger the '
        'nearer the turn', () {
      for (final m in _meters) {
        final a = TurnArrow.approach(m);
        final first = a.frames.first, last = a.frames.last;
        expect(a.frames.length, greaterThan(3), reason: '$m m: no animation');
        expect(_scale(first), lessThan(_scale(last) * 0.8), reason: '$m m');
        expect(_width(first), lessThan(_width(last)), reason: '$m m');
        // Higher: its middle above where it ends.
        expect(
          first.box.$2 + first.box.$4,
          lessThan(last.box.$2 + last.box.$4),
          reason: '$m m: not from higher up',
        );
        // Never smaller or higher again on the way, never turned.
        for (var k = 1; k < a.frames.length; k++) {
          final f = a.frames[k], b = a.frames[k - 1];
          expect(_scale(f), greaterThanOrEqualTo(_scale(b) - 0.001));
          expect(f.dy, greaterThanOrEqualTo(b.dy), reason: '$m m frame $k');
          expect(f.s, 0, reason: '$m m frame $k: turned');
        }
        expect(last.dx, 0);
        expect(last.dy, 0);
        expect(_scale(last), closeTo(TurnArrow.sizeFor(m), 0.002));
      }
      // Larger the nearer, at the marks the glasses show it.
      double size(int? m) => _width(TurnArrow.approach(m).frames.last);
      expect(size(5000), lessThanOrEqualTo(size(500)));
      expect(size(500), lessThan(size(200)));
      expect(size(200), lessThan(size(50)));
      expect(size(50), lessThanOrEqualTo(size(30)));
      expect(size(30), size(0));
      // Unknown distance: in between.
      expect(size(null), greaterThan(size(500)));
      expect(size(null), lessThan(size(30)));
    });

    test('at the turn it swings into the direction to take and stays so', () {
      const want = {
        NavTurn.slightLeft: 45.0,
        NavTurn.left: 90.0,
        NavTurn.sharpLeft: 135.0,
        NavTurn.slightRight: -45.0,
        NavTurn.right: -90.0,
        NavTurn.sharpRight: -135.0,
        NavTurn.uTurn: 180.0,
        NavTurn.straight: 0.0,
        NavTurn.roundabout: 0.0,
        NavTurn.destination: 0.0,
      };
      expect(want.keys, containsAll(NavTurn.values));
      for (final turn in NavTurn.values) {
        final a = TurnArrow.at(turn);
        // It starts upright at full size, where the approach ended.
        final first = a.frames.first;
        expect(
          (first.c, first.s, first.dx, first.dy),
          (4096, 0, 0, 0),
          reason: '$turn: first frame',
        );
        final last = a.frames.last;
        expect(
          _turned(want[turn]!, _heading(a, last)).abs(),
          lessThan(3),
          reason: '$turn: points ${_heading(a, last)}°, not ${want[turn]}°',
        );
        // Moved a little that way (left turns left, right turns right).
        final w = want[turn]!;
        if (w > 0 && w < 180) {
          expect(last.dx, lessThan(-10), reason: '$turn: not moved left');
        } else if (w < 0) {
          expect(last.dx, greaterThan(10), reason: '$turn: not moved right');
        }
        // A swing, no jump: at most 40° from frame to frame.
        var turnedSum = 0.0;
        for (var k = 1; k < a.frames.length; k++) {
          final d = _turned(
            _heading(a, a.frames[k - 1]),
            _heading(a, a.frames[k]),
          );
          expect(d.abs(), lessThanOrEqualTo(40), reason: '$turn frame $k');
          // One way only.
          if (w > 0 || turn == NavTurn.roundabout || turn == NavTurn.uTurn) {
            expect(d, greaterThanOrEqualTo(-0.5), reason: '$turn frame $k');
          } else if (w < 0) {
            expect(d, lessThanOrEqualTo(0.5), reason: '$turn frame $k');
          }
          turnedSum += d;
        }
        switch (turn) {
          case NavTurn.roundabout:
            // Once round, counter-clockwise.
            expect(turnedSum, closeTo(360, 3), reason: '$turn');
          case NavTurn.uTurn:
            // By the left (driving on the right).
            expect(turnedSum, closeTo(180, 3), reason: '$turn');
            expect(
              a.frames.any((f) => (_heading(a, f) - 90).abs() < 30),
              isTrue,
              reason: '$turn: not through the left',
            );
          case NavTurn.straight || NavTurn.destination:
            expect(turnedSum, 0, reason: '$turn');
            // Something moves: a push forward, a beat.
            expect(
              a.frames.map((f) => (f.c, f.dy)).toSet().length,
              greaterThan(2),
              reason: '$turn: no animation',
            );
          default:
            expect(turnedSum, closeTo(w, 3), reason: '$turn');
        }
      }
      // Every kind of turn its own animation.
      expect(
        NavTurn.values
            .map((t) => TurnArrow.at(t).frames.map((f) => f.box).join())
            .toSet(),
        hasLength(NavTurn.values.length),
      );
    });

    test('the words fit their area, the program before them', () {
      for (final (name, a) in _all()) {
        final data = a.data();
        expect(
          data.length,
          TurnArrow.segmentsAt + 20 * a.segments.length,
          reason: name,
        );
        expect(data.length, lessThanOrEqualTo(TurnArrow.dataMax));
        final arena = _arena(a);
        int d(int offset) => armWord(arena, SkResident.arrowData + offset);
        expect(
          [d(0), d(4), d(8), d(12)],
          [a.segments.length, a.cx, a.cy, a.frames.length],
          reason: name,
        );
        for (var k = 0; k < a.frames.length; k++) {
          final f = a.frames[k];
          expect(
            [for (var i = 0; i < 8; i++) d(32 + 32 * k + 4 * i)],
            [f.c, f.s, f.dx, f.dy, f.box.$1, f.box.$2, f.box.$3, f.box.$4],
            reason: '$name frame $k',
          );
        }
      }
      expect(
        SkResident.arrowData + TurnArrow.dataMax,
        lessThanOrEqualTo(SkResident.arrowDataEnd),
      );
      for (final (gestures, mic) in [
        (false, false),
        (false, true),
        (true, false),
        (true, true),
      ]) {
        for (final peer in [
          SkResident.peerNone,
          SkResident.peerLeader,
          SkResident.peerFollower,
        ]) {
          final p = SkResident.build(
            gestures: gestures,
            peer: peer,
            micArm: mic,
          );
          expect(
            SkResident.code + p.code.length,
            lessThanOrEqualTo(SkResident.arrowData),
          );
        }
      }
    });
  });

  group('host code', () {
    late FakeArms arms;
    late ScouterConnection g1;
    final font = loadTestFont();

    /// Per arm, at the moment each timed draw (SLEEP_UNTIL) arrived: the
    /// arrow's word; and the triggers raised.
    late Map<G1Side, List<int>> arrowAtTimedDraw;
    late Map<G1Side, List<int>> raised;

    /// The arrow's word after each packet that draws, while set.
    Map<G1Side, List<int>>? trace;

    setUp(() {
      arms = FakeArms();
      arrowAtTimedDraw = {for (final s in G1Side.values) s: <int>[]};
      raised = {for (final s in G1Side.values) s: <int>[]};
      trace = null;
      g1 = ScouterConnection.fake((side, channel, data) {
        final ops = arms.ops[side]!;
        final before = ops.length;
        final arrow = armWord(arms.arenas[side]!, SkResident.arrowOn.address);
        final done = arms.write(side, channel, data);
        if (channel == 0) {
          final added = ops.sublist(before);
          const drawing = [
            SkOp.fill,
            SkOp.blit,
            SkOp.glyphs,
            SkOp.draw,
            SkOp.line,
            SkOp.video,
            SkOp.call,
            SkOp.sysWrite,
          ];
          if (added.any(drawing.contains)) {
            trace?[side]!.add(
              armWord(arms.arenas[side]!, SkResident.arrowOn.address),
            );
          }
          if (added.contains(SkOp.sleepUntil)) {
            arrowAtTimedDraw[side]!.add(arrow);
          }
          if (added.isNotEmpty && added.last == SkOp.raise) {
            raised[side]!.add(armWord(arms.arenas[side]!, SkArena.params));
          }
        }
        return done;
      }, font: font);
      arms.connection = g1;
    });

    tearDown(() => g1.dispose());

    int word(G1Side side, SkW w) => armWord(arms.arenas[side]!, w.address);

    /// The arrow's words in the arm's arena.
    Uint8List arrowWords(G1Side side, int length) => arms.arenas[side]!.sublist(
      SkResident.arrowData,
      SkResident.arrowData + length,
    );

    const card = '200 m\nRechts abbiegen auf Hauptstraße\n14:32';

    Future<bool> showStep({
      NavTurn turn = NavTurn.right,
      int? meters = 200,
      bool atTurn = false,
      bool arrow = true,
      String text = card,
    }) {
      g1.setNavigationIcon(NavArrow.icon(turn));
      g1.setNavigationArrow(
        arrow ? (turn: turn, meters: meters, atTurn: atTurn) : null,
      );
      return g1.sendText(text, icon: SkIcons.navigation);
    }

    /// The icon's rows beside the text in the arm's frame.
    bool iconDrawn(G1Side side, NavTurn turn) {
      final icon = NavArrow.icon(turn);
      final frame = arms.arenas[side]!;
      for (var r = 0; r < SkIcons.size; r++) {
        final at =
            SkArena.frame +
            (ScouterConnection.textTop + r) * SkPanel.stride +
            ScouterConnection.textLeft ~/ 2;
        final row = icon.sublist(r * SkIcons.stride, (r + 1) * SkIcons.stride);
        if (frame.sublist(at, at + SkIcons.stride).join() != row.join()) {
          return false;
        }
      }
      return true;
    }

    /// Nothing lit in the arm's frame above the text: the program draws
    /// the arrow there, the app leaves the rows empty.
    bool rowsAboveTextEmpty(G1Side side) {
      final a = arms.arenas[side]!;
      return a
          .sublist(
            SkArena.frame,
            SkArena.frame + ScouterConnection.textTop * SkPanel.stride,
          )
          .every((b) => b == 0);
    }

    test('a step: the arrow coming closer above its text, both arms', () async {
      g1.fakeReady(epoch: arms.epoch);
      expect(await showStep(), isTrue);
      final want = TurnArrow.approach(200);
      final data = want.data();
      for (final side in G1Side.values) {
        expect(word(side, SkResident.busy), 1);
        expect(word(side, SkResident.arrowOn), 1, reason: '$side');
        // From its first frame, the box at the pivot.
        expect(word(side, SkResident.arrowFrame), 0);
        expect(word(side, SkResident.arrowAt), 0);
        expect(
          [
            for (var k = 0; k < 4; k++)
              armWord(arms.arenas[side]!, SkResident.arrowBox.address + 4 * k),
          ],
          [want.cx, want.cy, want.cx, want.cy],
        );
        expect(arrowWords(side, data.length), data, reason: '$side');
        expect(
          arrowProblems(arms.arenas[side]!, textTop: ScouterConnection.textTop),
          isEmpty,
        );
        // The program is told to play it; the small icon is not drawn, the
        // arrow's rows are free.
        expect(raised[side], [SkTrigger.user1]);
        expect(iconDrawn(side, NavTurn.right), isFalse);
        expect(rowsAboveTextEmpty(side), isTrue, reason: '$side');
      }
    });

    test('right at the turn: the swing into its direction', () async {
      g1.fakeReady(epoch: arms.epoch);
      for (final turn in NavTurn.values) {
        expect(
          await showStep(turn: turn, meters: 20, atTurn: true),
          isTrue,
          reason: '$turn',
        );
        final data = TurnArrow.at(turn).data();
        for (final side in G1Side.values) {
          expect(word(side, SkResident.arrowOn), 1, reason: '$turn $side');
          expect(word(side, SkResident.arrowFrame), 0, reason: '$turn');
          expect(
            arrowWords(side, data.length),
            data,
            reason: '$turn $side: not the swing',
          );
        }
      }
      // Not at the turn: the approach again, even at 20 m.
      expect(await showStep(turn: NavTurn.left, meters: 20), isTrue);
      final data = TurnArrow.approach(20).data();
      for (final side in G1Side.values) {
        expect(arrowWords(side, data.length), data);
      }
    });

    test('a new step starts the animation from its first frame', () async {
      g1.fakeReady(epoch: arms.epoch);
      await showStep(meters: 480);
      // The program played some frames meanwhile.
      for (final side in G1Side.values) {
        final d = ByteData.sublistView(arms.arenas[side]!);
        d.setUint32(SkResident.arrowFrame.address, 6, Endian.little);
        d.setUint32(SkResident.arrowAt.address, 123456789, Endian.little);
        for (var k = 0; k < 4; k++) {
          d.setUint32(SkResident.arrowBox.address + 4 * k, 77, Endian.little);
        }
      }
      await showStep(turn: NavTurn.left, meters: 20, atTurn: true);
      final a = TurnArrow.at(NavTurn.left);
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowFrame), 0, reason: '$side');
        expect(word(side, SkResident.arrowAt), 0, reason: '$side');
        expect(
          [
            for (var k = 0; k < 4; k++)
              armWord(arms.arenas[side]!, SkResident.arrowBox.address + 4 * k),
          ],
          [a.cx, a.cy, a.cx, a.cy],
        );
      }
    });

    test('both languages and every turn: the arrow on both arms', () async {
      g1.fakeReady(epoch: arms.epoch);
      for (final (text, turn) in [
        ('300 m\nTurn left onto Main St\n14:32', NavTurn.left),
        ('Ziel erreicht', NavTurn.destination),
        ('1,2 km\nIm Kreisverkehr die 2. Ausfahrt', NavTurn.roundabout),
        ('20 m\nMake a U-turn', NavTurn.uTurn),
        ('Weiter auf B27', NavTurn.straight),
        ('10 m\nScharf rechts abbiegen', NavTurn.sharpRight),
        ('0.1 mi\nKeep left at the fork', NavTurn.slightLeft),
      ]) {
        final u = NavUpdate(title: text, text: '');
        expect(u.turn, turn, reason: text);
        final at = (u.meters ?? 1000) < Navigation.atTurnMeters;
        await showStep(turn: u.turn, meters: u.meters, atTurn: at, text: text);
        final want = at ? TurnArrow.at(turn) : TurnArrow.approach(u.meters);
        for (final side in G1Side.values) {
          expect(word(side, SkResident.arrowOn), 1, reason: '$text $side');
          expect(
            arrowWords(side, want.data().length),
            want.data(),
            reason: text,
          );
          expect(rowsAboveTextEmpty(side), isTrue, reason: text);
        }
      }
    });

    test('the arrow is not there before its words are', () async {
      g1.fakeReady(epoch: arms.epoch);
      final codes = ScouterConnection.textCode(
        font,
        card,
        maxCode: 242,
        arArrow: (turn: NavTurn.uTurn, meters: 20, atTurn: true),
      );
      expect(codes.length, greaterThan(2));
      for (final side in G1Side.values) {
        final arena = arms.arenas[side]!;
        // A step with the arrow before (its words and the arrow on).
        for (final c in ScouterConnection.textCode(
          font,
          card,
          maxCode: 242,
          arArrow: (turn: NavTurn.right, meters: 40, atTurn: false),
        )) {
          execute(c, arena, []);
        }
        expect(word(side, SkResident.arrowOn), 1);
        final seen = <int>[];
        for (final c in codes) {
          execute(c, arena, []);
          seen.add(word(side, SkResident.arrowOn));
        }
        // Off from the first packet until the last one switched it on.
        expect(seen, [...List.filled(codes.length - 1, 0), 1]);
      }
    });

    test(
      'both eyes: the arrow goes on with the timed draw, not before',
      () async {
        g1.fakeReady(epoch: arms.epoch);
        await g1.fakeSyncClocks();
        await showStep(meters: 20, atTurn: true);
        for (final side in G1Side.values) {
          final ops = arms.ops[side]!;
          expect(
            ops.lastIndexOf(SkOp.draw),
            lessThan(ops.lastIndexOf(SkOp.raise)),
          );
          expect(arrowAtTimedDraw[side], [0], reason: '$side');
          expect(word(side, SkResident.arrowOn), 1, reason: '$side at the end');
          expect(raised[side], [SkTrigger.user1]);
        }
      },
    );

    test('both eyes, no answer from the arms: no arrow without its text', () {
      // The arms run the packets but never acknowledge them: the timed draw
      // never goes out, and with it not the arrow.
      return Future(() async {
        g1.fakeReady(epoch: arms.epoch);
        await g1.fakeSyncClocks();
        arms.acks = false;
        final shown = showStep(meters: 20, atTurn: true);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        for (final side in G1Side.values) {
          expect(arrowAtTimedDraw[side], isEmpty, reason: '$side');
          expect(word(side, SkResident.arrowOn), 0, reason: '$side');
          expect(raised[side], isEmpty, reason: '$side');
        }
        arms.acks = true;
        unawaited(shown);
      });
    });

    test('arrow off: the small icon beside the text, as before', () async {
      g1.fakeReady(epoch: arms.epoch);
      await showStep(arrow: false);
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowOn), 0);
        expect(iconDrawn(side, NavTurn.right), isTrue, reason: '$side');
        expect(raised[side], isEmpty);
      }
      // On, then off again.
      await showStep(turn: NavTurn.left, meters: 20, atTurn: true);
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowOn), 1);
        expect(iconDrawn(side, NavTurn.left), isFalse);
      }
      await showStep(turn: NavTurn.left, arrow: false);
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowOn), 0);
        expect(iconDrawn(side, NavTurn.left), isTrue);
      }
    });

    test('only the navigation\'s text has it', () async {
      g1.fakeReady(epoch: arms.epoch);
      g1.setNavigationArrow((turn: NavTurn.right, meters: 20, atTurn: true));
      await g1.sendText('Hinweis\nFenster offen');
      await g1.sendText('Telegram: Anna\nHallo!', icon: 'Telegram_app');
      await g1.sendText('Wohnzimmer 21 °C', serverOnline: true);
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowOn), 0);
        expect(raised[side], isEmpty);
      }
    });

    test('glasses not connected: nothing written', () async {
      expect(await showStep(), isFalse);
      for (final side in G1Side.values) {
        expect(arms.ops[side], isEmpty);
        expect(word(side, SkResident.arrowOn), 0);
      }
    });

    for (final (name, end)
        in <(String, Future<void> Function(ScouterConnection))>[
          ('a blank screen', (g) => g.blankScreen()),
          ('another text', (g) => g.sendText('Hinweis\nFenster offen')),
          (
            'a notification with its icon',
            (g) {
              return g.sendText('Telegram: Anna\nHallo!', icon: 'Telegram_app');
            },
          ),
          (
            'the dashboard the app shows',
            (g) {
              return g.sendText('Wohnzimmer 21 °C', serverOnline: true);
            },
          ),
          ('the silent-mode animation', (g) => g.playSilentModeAnimation(true)),
          (
            'the lab silent-mode animation',
            (g) {
              return g.playSilentModeAnimation(false, lab: true);
            },
          ),
          (
            'a video',
            (g) {
              return g.playVideo(
                width: 64,
                height: 32,
                fps: 15,
                frames: 3,
                read: (start, count) async => Uint8List(8 * 32 * count),
              );
            },
          ),
        ]) {
      for (final atTurn in [false, true]) {
        test(
          'the arrow stops with $name${atTurn ? ' (at the turn)' : ''}',
          () async {
            g1.fakeReady(epoch: arms.epoch);
            await g1.fakeSyncClocks();
            await showStep(meters: atTurn ? 20 : 200, atTurn: atTurn);
            for (final side in G1Side.values) {
              expect(word(side, SkResident.arrowOn), 1);
            }
            trace = {for (final s in G1Side.values) s: <int>[]};
            await end(g1);
            for (final side in G1Side.values) {
              expect(trace![side], isNotEmpty, reason: '$side: nothing sent');
              expect(
                trace![side]!.every((v) => v == 0) &&
                    word(side, SkResident.arrowOn) == 0,
                isTrue,
                reason:
                    '$side: the arrow on after packets of $name: '
                    '${trace![side]}',
              );
            }
          },
        );
      }
    }

    test('an arm in the case gets no arrow', () async {
      g1.fakeReady(epoch: arms.epoch);
      g1.receive(G1Side.left, input(arms.epoch, SkTrigger.caseState, 0xff01));
      await showStep(meters: 20, atTurn: true);
      expect(arms.ops[G1Side.left], isEmpty);
      expect(word(G1Side.left, SkResident.arrowOn), 0);
      expect(word(G1Side.right, SkResident.arrowOn), 1);
      g1.receive(G1Side.left, input(arms.epoch, SkTrigger.caseState, 0xff00));
      await showStep(turn: NavTurn.left);
      expect(word(G1Side.left, SkResident.arrowOn), 1);
      expect(word(G1Side.right, SkResident.arrowOn), 1);
    });
  });

  group('navigation', () {
    NavUpdate step(String title, String text) =>
        NavUpdate(title: title, text: text, subText: '14:32');

    test('right at the turn: one more step shown, marked at the turn', () {
      final nav = Navigation();
      final seen = [
        for (final m in [800, 480, 190, 45, 30, 24, 10, 3])
          (nav.update(step('$m m', 'Turn right onto Main St')), nav.atTurn),
      ];
      expect(seen, [
        (true, false),
        (true, false),
        (true, false),
        (true, false),
        (false, false),
        (true, true),
        (false, true),
        (false, true),
      ]);
      // The next step: not at its turn yet.
      expect(nav.update(step('400 m', 'Turn left onto Elm St')), isTrue);
      expect(nav.atTurn, isFalse);
      // A step that begins right at its turn.
      expect(nav.update(step('15 m', 'Links abbiegen')), isTrue);
      expect(nav.atTurn, isTrue);
      expect(nav.update(step('5 m', 'Links abbiegen')), isFalse);
      // A step without a distance is never at the turn.
      expect(nav.update(step('', 'Weiter auf B27')), isTrue);
      expect(nav.atTurn, isFalse);
      nav.update(step('20 m', 'Rechts abbiegen'));
      expect(nav.atTurn, isTrue);
      nav.end();
      expect(nav.atTurn, isFalse);
    });

    test('updates that skip marks: right at the turn is still the turn', () {
      // The phone's updates come seconds apart: from 480 m straight to the
      // turn, or from 190 m.
      for (final from in [480, 190, 45]) {
        final nav = Navigation();
        expect(nav.update(step('$from m', 'Rechts abbiegen')), isTrue);
        expect(nav.atTurn, isFalse);
        expect(
          nav.update(step('20 m', 'Rechts abbiegen')),
          isTrue,
          reason: 'from $from m: 20 m not shown',
        );
        expect(
          nav.atTurn,
          isTrue,
          reason: 'from $from m: at 20 m the step is not at the turn',
        );
        // And the marks passed are not shown again on the next updates.
        expect(
          nav.update(step('15 m', 'Rechts abbiegen')),
          isFalse,
          reason: 'from $from m: shown again at 15 m',
        );
      }
    });
  });

  group('bridge', () {
    late Settings settings;
    late FakeGlasses g1;
    late Bridge bridge;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = await Settings.load();
      g1 = FakeGlasses();
      bridge = Bridge(settings, g1: g1);
    });

    tearDown(() => bridge.display.clear());

    NavUpdate step(String title, String text) =>
        NavUpdate(title: title, text: text, subText: '14:32');

    test('on by default: turn, distance and "at the turn" go with each '
        'step', () async {
      expect(settings.navigationArrow, isTrue);
      await bridge.onNavigation(
        step('300 m', 'Rechts abbiegen auf Hauptstraße'),
      );
      expect(g1.navigationArrow, (
        turn: NavTurn.right,
        meters: 300,
        atTurn: false,
      ));
      expect(g1.icons.last, SkIcons.navigation);
      expect(g1.navigationIcon, hasLength(SkIcons.bytes));
      for (final m in [190, 45]) {
        await bridge.onNavigation(
          step('$m m', 'Rechts abbiegen auf Hauptstraße'),
        );
        expect(g1.navigationArrow?.atTurn, isFalse, reason: '$m m');
      }
      final shown = g1.texts.length;
      await bridge.onNavigation(
        step('20 m', 'Rechts abbiegen auf Hauptstraße'),
      );
      expect(g1.texts.length, shown + 1, reason: 'not shown at the turn');
      expect(g1.texts.last, startsWith('20 m'));
      expect(g1.navigationArrow, (
        turn: NavTurn.right,
        meters: 20,
        atTurn: true,
      ));
      await bridge.onNavigation(step('In 0.3 mi', 'Turn left onto Main St'));
      expect(g1.navigationArrow, (
        turn: NavTurn.left,
        meters: 483,
        atTurn: false,
      ));
      await bridge.onNavigation(step('Head north', 'toward Elm St'));
      expect(g1.navigationArrow, (
        turn: NavTurn.straight,
        meters: null,
        atTurn: false,
      ));
    });

    test('from far away straight to the turn: the swing, shown once', () async {
      // Updates seconds apart (a fast car, a slow phone): 300 m, then the
      // turn.
      await bridge.onNavigation(step('300 m', 'Rechts abbiegen'));
      final shown = g1.texts.length;
      await bridge.onNavigation(step('20 m', 'Rechts abbiegen'));
      expect(g1.texts.length, shown + 1);
      expect(g1.navigationArrow, (
        turn: NavTurn.right,
        meters: 20,
        atTurn: true,
      ), reason: 'shown at 20 m with the arrow coming closer, not the swing');
      // Not shown again for the marks it skipped.
      await bridge.onNavigation(step('15 m', 'Rechts abbiegen'));
      await bridge.onNavigation(step('10 m', 'Rechts abbiegen'));
      expect(g1.texts.length, shown + 1, reason: 'shown again: ${g1.texts}');
    });

    test('switched off and on again', () async {
      settings.navigationArrow = false;
      expect((await Settings.load()).navigationArrow, isFalse);
      await bridge.onNavigation(step('300 m', 'Rechts abbiegen'));
      expect(g1.arrowCalls, isNotEmpty);
      expect(g1.navigationArrow, isNull);
      expect(g1.icons.last, SkIcons.navigation);
      expect(g1.navigationIcon, hasLength(SkIcons.bytes));
      settings.navigationArrow = true;
      expect((await Settings.load()).navigationArrow, isTrue);
      await bridge.onNavigation(step('20 m', 'Links abbiegen'));
      expect(g1.navigationArrow, (
        turn: NavTurn.left,
        meters: 20,
        atTurn: true,
      ));
      settings.navigationArrow = false;
      await bridge.onNavigation(step('10 m', 'Links abbiegen'));
      expect(g1.navigationArrow, isNull);
    });

    test('the setting is kept under navigation_arrow, on by default', () async {
      SharedPreferences.setMockInitialValues({'navigation_arrow': false});
      expect((await Settings.load()).navigationArrow, isFalse);
      SharedPreferences.setMockInitialValues({});
      final s = await Settings.load();
      expect(s.navigationArrow, isTrue);
      s.navigationArrow = false;
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('navigation_arrow'), isFalse);
    });

    test('the navigation ends: no arrow', () async {
      await bridge.onNavigation(step('20 m', 'Rechts abbiegen'));
      expect(g1.navigationArrow?.atTurn, isTrue);
      await bridge.onNavigation(null);
      expect(g1.navigationArrow, isNull);
      expect(g1.navigationIcon, isNull);
      // A new navigation: not at the turn from the last one.
      await bridge.onNavigation(step('300 m', 'Rechts abbiegen'));
      expect(g1.navigationArrow?.atTurn, isFalse);
      // Navigation not forwarded: none either.
      settings.forwardNavigation = false;
      await bridge.onNavigation(step('20 m', 'Rechts abbiegen'));
      expect(g1.navigationArrow, isNull);
    });
  });
}
