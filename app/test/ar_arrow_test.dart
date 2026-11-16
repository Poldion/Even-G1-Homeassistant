/// The navigation's AR arrow: the model (stage 1), the words the arm
/// program reads (stage 2), the host code the app sends and the bridge's
/// part. The program itself runs only in ScouterKit's C interpreter; here
/// its arithmetic is repeated on the words in the arena (ar_arrow_check).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:even_g1_ha/bridge.dart';
import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/navigation/ar_arrow.dart';
import 'package:even_g1_ha/navigation/navigation.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_asm.dart';
import 'package:even_g1_ha/scouter/sk_icons.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ar_arrow_check.dart';
import 'fake_arms.dart';
import 'fake_glasses.dart';

/// Distances as Google Maps gives them, with none (null).
const _meters = <int?>[null, 0, 10, 30, 31, 45, 90, 200, 330, 500, 5000];

/// The arrow's words written into an empty arena, for [arrowProblems].
Uint8List _arena(ArArrow a) {
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
Set<int> _litRows(Uint8List frame) => {
  for (var i = 0; i < frame.length; i++)
    if (frame[i] != 0) i ~/ SkPanel.stride,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model', () {
    test('every turn at every distance stays on the panel and below the '
        'text, whatever the head does', () {
      // Text of one to five lines above it.
      for (final lines in [1, 2, 3, 4, 5]) {
        final textEnd = ScouterConnection.textTop + 28 * lines;
        final top = textEnd + ScouterConnection.arrowGap;
        for (final turn in NavTurn.values) {
          for (final m in _meters) {
            final a = ArArrow.build(turn, m, top: top);
            expect(a, isNotNull, reason: '$turn at $m m, top $top');
            expect(a!.top, top);
            expect(
              arrowProblems(_arena(a), textBottom: top),
              isEmpty,
              reason: '$turn at $m m, top $top',
            );
          }
        }
      }
    });

    test('at any top it is either within its rows or not there', () {
      for (var top = 0; top < SkPanel.height; top += 7) {
        for (final turn in NavTurn.values) {
          final a = ArArrow.build(turn, 200, top: top);
          if (a == null) continue;
          expect(
            arrowProblems(_arena(a), textBottom: top),
            isEmpty,
            reason: '$turn, top $top',
          );
        }
      }
      // No room below a long text: no arrow (the icon instead).
      for (final turn in NavTurn.values) {
        expect(ArArrow.build(turn, 200, top: 400), isNull, reason: '$turn');
        expect(ArArrow.build(turn, 200, top: 477), isNull, reason: '$turn');
      }
    });

    test('what it draws: nothing above its top, nothing off the panel', () {
      for (final turn in NavTurn.values) {
        final a = ArArrow.build(turn, 120, top: 238)!;
        for (final (pitch, roll) in [
          (-10, 0),
          (-90, 0),
          (90, 0),
          (-10, 10),
          (-10, -10),
          (-40, 30),
          (35, -45),
        ]) {
          final frame = Uint8List(SkPanel.stride * SkPanel.height);
          a.drawInto(frame, pitch: pitch, roll: roll);
          final rows = _litRows(frame);
          expect(rows, isNotEmpty, reason: '$turn ($pitch, $roll)');
          expect(
            rows.reduce((a, b) => a < b ? a : b),
            greaterThanOrEqualTo(238),
            reason: '$turn ($pitch, $roll): over the text',
          );
          expect(rows.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(477));
        }
      }
    });

    test('it follows the head: down when looking up, turned against the '
        'roll', () {
      final a = ArArrow.build(NavTurn.straight, 200, top: 238)!;
      final r = ArArrow.rollMax;
      // Looking up (positive pitch): the street goes down in the view.
      expect(a.shiftFor(0, 0), greaterThan(a.shiftFor(-10, 0)));
      expect(a.shiftFor(-20, 0), lessThan(a.shiftFor(-10, 0)));
      expect(a.shiftFor(ArArrow.pitchRest, 0), 0);
      // Head tilted right (right ear down, positive roll): the world turns
      // counter-clockwise, so a point right of the pivot goes up.
      final (_, yRight) = a.transform(100, 0, r, 0);
      final (_, yLeft) = a.transform(-100, 0, r, 0);
      expect(yRight, lessThan(a.cy));
      expect(yLeft, greaterThan(a.cy));
      // Beyond ±rollMax the program keeps the last angle.
      expect(ArArrow.rollFor(45), r);
      expect(ArArrow.rollFor(-90), -r);
    });

    test('nearer turn: closer or larger, never further and smaller', () {
      const far = [5000, 500, 330, 200, 100, 45, 30, 0];
      for (final turn in NavTurn.values) {
        (int, int) look(int m) {
          final a = ArArrow.build(turn, m, top: 238)!;
          final b = a.boxes[ArArrow.rollMax];
          return (b.$2, b.$3 - b.$1); // highest row, width
        }

        for (var i = 0; i + 1 < far.length; i++) {
          final (top0, w0) = look(far[i]);
          final (top1, w1) = look(far[i + 1]);
          expect(
            top1 < top0 && w1 < w0,
            isFalse,
            reason:
                '$turn: ${far[i + 1]} m (top $top1, width $w1) further and '
                'smaller than ${far[i]} m (top $top0, width $w0)',
          );
        }
        final (topFar, wFar) = look(500);
        final (topNear, wNear) = look(0);
        expect(
          topNear > topFar || wNear > wFar,
          isTrue,
          reason: '$turn: at 0 m neither closer nor larger than at 500 m',
        );
      }
      expect(ArArrow.turnDepth(30), lessThan(ArArrow.turnDepth(200)));
      expect(ArArrow.turnDepth(200), lessThanOrEqualTo(ArArrow.turnDepth(500)));
    });

    test('every kind of turn has its own arrow, pointing its way', () {
      int reach(ArArrow a, bool right) {
        var v = 0;
        for (final s in a.segments) {
          for (final x in [s.x0 + a.cx, s.x1 + a.cx]) {
            final d = right ? x - SkPanel.width ~/ 2 : SkPanel.width ~/ 2 - x;
            if (d > v) v = d;
          }
        }
        return v;
      }

      final shapes = <String>{};
      for (final turn in NavTurn.values) {
        final a = ArArrow.build(turn, 120, top: 238)!;
        shapes.add(a.segments.join());
        final r = reach(a, true), l = reach(a, false);
        switch (turn) {
          case NavTurn.right || NavTurn.slightRight || NavTurn.sharpRight:
            expect(r, greaterThan(l + 40), reason: '$turn');
          case NavTurn.left || NavTurn.slightLeft || NavTurn.sharpLeft:
            expect(l, greaterThan(r + 40), reason: '$turn');
          case NavTurn.uTurn:
            // Turns back on the left (driving on the right).
            expect(l, greaterThan(r + 40), reason: '$turn');
          case NavTurn.straight || NavTurn.roundabout || NavTurn.destination:
            expect((r - l).abs(), lessThanOrEqualTo(2), reason: '$turn');
        }
      }
      expect(shapes, hasLength(NavTurn.values.length));
    });

    test('the program draws what the model draws', () {
      for (final turn in NavTurn.values) {
        for (final m in [null, 40, 500]) {
          final a = ArArrow.build(turn, m, top: 238)!;
          final arena = _arena(a);
          for (final roll in [-90, -10, -7, -1, 0, 3, 10, 25, SkProp.unknown]) {
            for (final pitch in [-60, -25, -10, 0, 12, 40, SkProp.unknown]) {
              final r = ArArrow.rollFor(roll == SkProp.unknown ? 0 : roll);
              final shift = a.shiftFor(
                pitch == SkProp.unknown ? ArArrow.pitchRest : pitch,
                r,
              );
              expect(programPoints(arena, pitch, roll), [
                for (final s in a.segments) ...[
                  a.transform(s.x0, s.y0, r, shift),
                  a.transform(s.x1, s.y1, r, shift),
                ],
              ], reason: '$turn at $m m, pitch $pitch, roll $roll');
            }
          }
        }
      }
    });

    test('the words fit their area, the program before them', () {
      for (final turn in NavTurn.values) {
        for (final m in _meters) {
          final a = ArArrow.build(turn, m, top: 210)!;
          final data = a.data();
          expect(data.length, ArArrow.segmentsAt + 20 * a.segments.length);
          expect(data.length, lessThanOrEqualTo(ArArrow.dataMax));
        }
      }
      expect(
        SkResident.arrowData + ArArrow.dataMax,
        lessThanOrEqualTo(SkResident.arrowDataEnd),
      );
      for (final (gestures, mic) in [
        (false, false),
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

    test('the arrow\'s state words are its own', () {
      // Every program word at state + n (sk_program.dart): none shared, all
      // within the state area; the box and the rectangle are 4 words each.
      final source = File('lib/scouter/sk_program.dart').readAsStringSync();
      final at = RegExp(r'static final (\w+) = SkW\.at\(state(?: \+ (\d+))?\)');
      final used = <int, String>{};
      for (final m in at.allMatches(source)) {
        final name = m.group(1)!;
        final offset = int.parse(m.group(2) ?? '0');
        final words = name == 'arrowBox' || name == '_arrowRect' ? 4 : 1;
        for (var k = 0; k < words; k++) {
          final o = offset + 4 * k;
          expect(used[o], isNull, reason: '$name and ${used[o]} at state + $o');
          used[o] = name;
        }
      }
      expect(used.values, containsAll(['arrowOn', 'arrowBox', '_arrowRect']));
      expect(
        used.keys.reduce((a, b) => a > b ? a : b) + 4,
        lessThanOrEqualTo(SkResident.lines - SkResident.state),
      );
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
          // A packet that draws (frame or panel): the arrow's word after it.
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

    const card = '200 m\nRechts abbiegen auf Hauptstraße\n14:32';

    Future<void> showStep({
      NavTurn turn = NavTurn.right,
      int? meters = 200,
      bool ar = true,
      String text = card,
    }) async {
      g1.setNavigationIcon(NavArrow.icon(turn));
      g1.setNavigationArrow(ar ? (turn: turn, meters: meters) : null);
      expect(await g1.sendText(text, icon: SkIcons.navigation), isTrue);
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

    test('a navigation step: the arrow below its text on both arms', () async {
      g1.fakeReady(epoch: arms.epoch);
      await showStep();
      final lines = card.split('\n').length;
      final textEnd = ScouterConnection.textTop + lines * font.lineSpacing;
      final want = ArArrow.build(
        NavTurn.right,
        200,
        top: textEnd + ScouterConnection.arrowGap,
      )!.data();
      for (final side in G1Side.values) {
        final arena = arms.arenas[side]!;
        expect(word(side, SkResident.busy), 1);
        expect(word(side, SkResident.arrowOn), 1, reason: '$side');
        // Drawn anew: nothing drawn yet, the box at the pivot.
        expect(word(side, SkResident.arrowShift), SkResident.arrowNone);
        expect(word(side, SkResident.arrowAt), 0);
        final cx = armWord(arena, SkResident.arrowData + 4);
        final cy = armWord(arena, SkResident.arrowData + 8);
        expect(
          [
            for (var k = 0; k < 4; k++)
              armWord(arena, SkResident.arrowBox.address + 4 * k),
          ],
          [cx, cy, cx, cy],
        );
        expect(
          arena.sublist(
            SkResident.arrowData,
            SkResident.arrowData + want.length,
          ),
          want,
        );
        // Below the text's glyphs, whatever the head does.
        final lastBaseline =
            ScouterConnection.textTop +
            (lines - 1) * font.lineSpacing +
            font.ascent;
        expect(
          arrowProblems(arena, textBottom: lastBaseline + font.descent + 1),
          isEmpty,
        );
        // The program is told to draw it; the small icon is not drawn.
        expect(raised[side], [SkTrigger.user1]);
        expect(iconDrawn(side, NavTurn.right), isFalse);
      }
    });

    test('both languages and every turn: the arrow on both arms', () async {
      g1.fakeReady(epoch: arms.epoch);
      for (final (text, turn) in [
        ('300 m\nTurn left onto Main St\n14:32', NavTurn.left),
        ('Ziel erreicht', NavTurn.destination),
        ('1,2 km\nIm Kreisverkehr die 2. Ausfahrt', NavTurn.roundabout),
        ('Make a U-turn', NavTurn.uTurn),
        ('Weiter auf B27', NavTurn.straight),
      ]) {
        final u = NavUpdate(title: text, text: '');
        expect(u.turn, turn);
        await showStep(turn: u.turn, meters: u.meters, text: text);
        for (final side in G1Side.values) {
          expect(word(side, SkResident.arrowOn), 1, reason: '$text $side');
          final lines = text.split('\n').length;
          expect(
            arrowProblems(
              arms.arenas[side]!,
              textBottom: ScouterConnection.textTop + lines * font.lineSpacing,
            ),
            isEmpty,
            reason: text,
          );
        }
      }
    });

    test('the arrow is not there before its words are', () async {
      g1.fakeReady(epoch: arms.epoch);
      // Record the arrow's word after every packet of the step.
      final seen = {for (final s in G1Side.values) s: <int>[]};
      final codes = ScouterConnection.textCode(
        font,
        card,
        maxCode: 242,
        arArrow: (turn: NavTurn.uTurn, meters: 120),
      );
      expect(codes.length, greaterThan(2));
      for (final side in G1Side.values) {
        final arena = arms.arenas[side]!;
        // A step with the arrow before (its words and the arrow on).
        for (final c in ScouterConnection.textCode(
          font,
          card,
          maxCode: 242,
          arArrow: (turn: NavTurn.right, meters: 40),
        )) {
          execute(c, arena, []);
        }
        expect(word(side, SkResident.arrowOn), 1);
        for (final c in codes) {
          execute(c, arena, []);
          seen[side]!.add(word(side, SkResident.arrowOn));
        }
        // Off from the first packet until the last one switched it on.
        expect(seen[side], [...List.filled(codes.length - 1, 0), 1]);
      }
    });

    test('both eyes: the arrow does not show before the text', () async {
      g1.fakeReady(epoch: arms.epoch);
      await g1.fakeSyncClocks();
      await showStep();
      for (final side in G1Side.values) {
        // The text waits for the moment both eyes draw it; the arrow goes
        // on (USER1) only after that DRAW.
        final ops = arms.ops[side]!;
        expect(
          ops.lastIndexOf(SkOp.draw),
          lessThan(ops.lastIndexOf(SkOp.raise)),
        );
        expect(arrowAtTimedDraw[side], hasLength(1));
        // Until that moment the program must not draw the arrow: with the
        // arrow on (and USER1 raised) it draws at once, on the old screen
        // and on one eye before the other.
        expect(
          arrowAtTimedDraw[side],
          [0],
          reason:
              '$side: the arrow is on (USER1 ${raised[side]}) before the '
              'text\'s timed draw arrived',
        );
        expect(word(side, SkResident.arrowOn), 1, reason: '$side at the end');
      }
    });

    test('AR arrow off: the small icon beside the text, as before', () async {
      g1.fakeReady(epoch: arms.epoch);
      await showStep(ar: false);
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowOn), 0);
        expect(iconDrawn(side, NavTurn.right), isTrue, reason: '$side');
        expect(raised[side], isEmpty);
      }
      // On, then off again.
      await showStep(turn: NavTurn.left);
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowOn), 1);
      }
      await showStep(turn: NavTurn.left, ar: false);
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowOn), 0);
        expect(iconDrawn(side, NavTurn.left), isTrue);
      }
    });

    test('no room below the text: the icon instead', () async {
      g1.fakeReady(epoch: arms.epoch);
      final long = List.generate(9, (i) => 'Zeile ${i + 1}').join('\n');
      await showStep(text: long);
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowOn), 0, reason: '$side');
        expect(iconDrawn(side, NavTurn.right), isTrue, reason: '$side');
      }
    });

    test('only the navigation\'s text has it', () async {
      g1.fakeReady(epoch: arms.epoch);
      g1.setNavigationArrow((turn: NavTurn.right, meters: 200));
      await g1.sendText('Hinweis\nFenster offen');
      await g1.sendText('Telegram: Anna\nHallo!', icon: 'Telegram_app');
      for (final side in G1Side.values) {
        expect(word(side, SkResident.arrowOn), 0);
        expect(raised[side], isEmpty);
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
      test('the arrow stops with $name', () async {
        g1.fakeReady(epoch: arms.epoch);
        await g1.fakeSyncClocks();
        await showStep();
        for (final side in G1Side.values) {
          expect(word(side, SkResident.arrowOn), 1);
        }
        // From the first packet that draws what follows on, the arrow is
        // off (the program would draw it over the new content), and stays
        // off.
        trace = {for (final s in G1Side.values) s: <int>[]};
        await end(g1);
        for (final side in G1Side.values) {
          expect(trace![side], isNotEmpty, reason: '$side: nothing sent');
          expect(
            trace![side]!.every((v) => v == 0) &&
                word(side, SkResident.arrowOn) == 0,
            isTrue,
            reason:
                '$side: the arrow on after packets of $name: ${trace![side]}',
          );
        }
      });
    }

    test('an arm in the case gets no arrow', () async {
      g1.fakeReady(epoch: arms.epoch);
      g1.receive(G1Side.left, input(arms.epoch, SkTrigger.caseState, 0xff01));
      await showStep();
      expect(arms.ops[G1Side.left], isEmpty);
      expect(word(G1Side.left, SkResident.arrowOn), 0);
      expect(word(G1Side.right, SkResident.arrowOn), 1);
      // Back out of the case: the next step reaches both.
      g1.receive(G1Side.left, input(arms.epoch, SkTrigger.caseState, 0xff00));
      await showStep(turn: NavTurn.left);
      expect(word(G1Side.left, SkResident.arrowOn), 1);
      expect(word(G1Side.right, SkResident.arrowOn), 1);
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

    test('on by default: the turn and its distance go with the step', () async {
      expect(settings.navigationArArrow, isTrue);
      await bridge.onNavigation(
        step('300 m', 'Rechts abbiegen auf Hauptstraße'),
      );
      expect(g1.navigationArrow, (turn: NavTurn.right, meters: 300));
      expect(g1.icons.last, SkIcons.navigation);
      // The icon stays set as the fallback.
      expect(g1.navigationIcon, hasLength(SkIcons.bytes));
      await bridge.onNavigation(step('In 0.3 mi', 'Turn left onto Main St'));
      expect(g1.navigationArrow, (turn: NavTurn.left, meters: 483));
      await bridge.onNavigation(step('Head north', 'toward Elm St'));
      expect(g1.navigationArrow, (turn: NavTurn.straight, meters: null));
    });

    test('switched off and on again', () async {
      settings.navigationArArrow = false;
      expect((await Settings.load()).navigationArArrow, isFalse);
      await bridge.onNavigation(step('300 m', 'Rechts abbiegen'));
      expect(g1.arrowCalls, isNotEmpty);
      expect(g1.navigationArrow, isNull);
      expect(g1.navigationIcon, hasLength(SkIcons.bytes));
      settings.navigationArArrow = true;
      await bridge.onNavigation(step('40 m', 'Links abbiegen'));
      expect(g1.navigationArrow, (turn: NavTurn.left, meters: 40));
    });

    test('the navigation ends: no arrow', () async {
      await bridge.onNavigation(step('300 m', 'Rechts abbiegen'));
      expect(g1.navigationArrow, isNotNull);
      await bridge.onNavigation(null);
      expect(g1.navigationArrow, isNull);
      expect(g1.navigationIcon, isNull);
      // Navigation not forwarded: none either.
      await bridge.onNavigation(step('300 m', 'Rechts abbiegen'));
      settings.forwardNavigation = false;
      await bridge.onNavigation(step('200 m', 'Rechts abbiegen'));
      expect(g1.navigationArrow, isNull);
    });
  });
}
