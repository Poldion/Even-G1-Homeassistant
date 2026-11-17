/// The navigation's card: the turn's icon beside the distance, the bar of
/// the way left under the text, and right at the turn the icon's push into
/// the turn, played by the resident program (label `arrow`). The program
/// runs here in a small VM (sk_vm.dart) on the packets the app sends.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:even_g1_ha/bridge.dart';
import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/navigation/nav_wiggle.dart';
import 'package:even_g1_ha/navigation/navigation.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_icons.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_arms.dart';
import 'fake_glasses.dart';
import 'nav_wiggle_check.dart';
import 'sk_vm.dart';

/// Every kind of turn with an icon of its own and one from Google Maps.
Iterable<(String, NavTurn, Uint8List)> _wiggles() sync* {
  final maps = Uint8List(SkIcons.bytes);
  for (var i = 0; i < maps.length; i++) {
    maps[i] = (i * 37 + 11) & 0xff;
  }
  for (final turn in NavTurn.values) {
    yield ('$turn', turn, NavArrow.icon(turn));
    yield ('$turn (Maps\' icon)', turn, maps);
  }
}

NavWiggle _at(NavTurn turn, Uint8List icon) => NavWiggle.of(
  turn,
  icon,
  x: ScouterConnection.textLeft,
  y: ScouterConnection.textTop,
);

Uint8List _arena(NavWiggle w) {
  final arena = Uint8List(SkArena.size);
  final data = w.data();
  arena.setRange(
    SkResident.arrowData,
    SkResident.arrowData + data.length,
    data,
  );
  return arena;
}

/// The bar's filled width at [meters], computed here on its own.
int _barFill(int meters) => (360 * min(meters, 500) / 500).round();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = loadTestFont();

  group('model', () {
    test('every wiggle: beside the text, on the panel, back at its place', () {
      for (final (name, turn, icon) in _wiggles()) {
        final w = _at(turn, icon);
        expect(w.offsets, isNotEmpty, reason: name);
        expect(
          w.offsets.length,
          lessThanOrEqualTo(NavWiggle.maxFrames),
          reason: name,
        );
        expect(wiggleProblems(_arena(w)), isEmpty, reason: name);
        for (var k = 0; k < w.offsets.length; k++) {
          final (x0, y0, x1, y1) = w.box(k);
          expect(x0 >= 0 && y0 >= 0, isTrue, reason: '$name frame $k');
          expect(y1, lessThan(SkPanel.height), reason: '$name frame $k');
          expect(
            x1,
            lessThan(ScouterConnection.iconTextLeft),
            reason: '$name frame $k: on the text column',
          );
        }
        expect(w.offsets.last, (0, 0), reason: '$name: not back at its place');
      }
    });

    test('it pushes a few times into the direction to take', () {
      // (dx, dy) on the panel, y down: where each turn goes.
      const want = {
        NavTurn.left: (-1, 0),
        NavTurn.right: (1, 0),
        NavTurn.slightLeft: (-1, -1),
        NavTurn.slightRight: (1, -1),
        NavTurn.sharpLeft: (-1, 1),
        NavTurn.sharpRight: (1, 1),
        NavTurn.straight: (0, -1),
      };
      for (final MapEntry(key: turn, value: (wx, wy)) in want.entries) {
        final w = _at(turn, NavArrow.icon(turn));
        var pushes = 0;
        var out = false;
        var far = 0.0;
        for (final (dx, dy) in w.offsets) {
          // Only along its direction, never against it.
          expect(dx.sign == wx || dx == 0, isTrue, reason: '$turn ($dx, $dy)');
          expect(dy.sign == wy || dy == 0, isTrue, reason: '$turn ($dx, $dy)');
          if (wx == 0) expect(dx, 0, reason: '$turn');
          if (wy == 0) expect(dy, 0, reason: '$turn');
          final r = sqrt(dx * dx + dy * dy);
          far = max(far, r);
          if (r >= NavWiggle.reach - 1 && !out) {
            pushes++;
            out = true;
          }
          if (r == 0) out = false;
        }
        expect(pushes, greaterThanOrEqualTo(2), reason: '$turn: a few');
        expect(pushes, NavWiggle.pushes, reason: '$turn: pushes');
        expect(far, closeTo(NavWiggle.reach, 1), reason: '$turn: how far');
      }
      // A U-turn: down, the way back.
      final u = _at(NavTurn.uTurn, NavArrow.icon(NavTurn.uTurn));
      expect(u.offsets.map((o) => o.$2).reduce(max), greaterThan(0));
      // The destination: ahead.
      final d = _at(NavTurn.destination, NavArrow.icon(NavTurn.destination));
      expect(d.offsets.every((o) => o.$1 == 0 && o.$2 <= 0), isTrue);
    });

    test('a roundabout goes once round and back to its place', () {
      final w = _at(NavTurn.roundabout, NavArrow.icon(NavTurn.roundabout));
      final xs = w.offsets.map((o) => o.$1), ys = w.offsets.map((o) => o.$2);
      // Left of, right of and above its place: round, not a push.
      expect(xs.reduce(min), lessThanOrEqualTo(-NavWiggle.reach ~/ 2));
      expect(xs.reduce(max), greaterThanOrEqualTo(NavWiggle.reach ~/ 2));
      expect(ys.reduce(min), lessThanOrEqualTo(-NavWiggle.reach));
      expect(ys.reduce(max), lessThanOrEqualTo(0));
      // Small steps all the way (no jump across the circle).
      var at = (0, 0);
      for (final o in w.offsets) {
        final d = sqrt(pow(o.$1 - at.$1, 2) + pow(o.$2 - at.$2, 2));
        expect(d, lessThanOrEqualTo(NavWiggle.reach / 2), reason: '$at → $o');
        at = o;
      }
      expect(w.offsets.last, (0, 0));
    });

    test('a roundabout goes round as the traffic goes', () {
      final w = _at(NavTurn.roundabout, NavArrow.icon(NavTurn.roundabout));
      final pts = [(0, 0), ...w.offsets];
      // Twice the signed area with y up: > 0 is counter-clockwise as the
      // wearer sees it.
      var area = 0;
      for (var k = 1; k < pts.length; k++) {
        final (ax, ay) = pts[k - 1];
        final (bx, by) = pts[k];
        area += ax * -by - bx * -ay;
      }
      // Right-hand traffic (Germany, the US): counter-clockwise, as
      // nav_wiggle.dart says ("counter-clockwise as the traffic goes").
      expect(
        area,
        greaterThan(0),
        reason:
            'the roundabout wiggle goes clockwise on the panel '
            '(first left, then up, then right): ${w.offsets}',
      );
    });

    test('the model draws what the glasses show (renders, docs)', () {
      for (final (name, turn, icon) in _wiggles()) {
        final w = _at(turn, icon);
        // The text's picture: the icon at its place, a line of text.
        final shown = Uint8List(SkPanel.stride * SkPanel.height);
        for (var r = 0; r < SkIcons.size; r++) {
          final at =
              (ScouterConnection.textTop + r) * SkPanel.stride +
              ScouterConnection.textLeft ~/ 2;
          shown.setRange(
            at,
            at + SkIcons.stride,
            icon.sublist(r * SkIcons.stride, (r + 1) * SkIcons.stride),
          );
        }
        shown.fillRange(
          (ScouterConnection.textTop + 10) * SkPanel.stride +
              ScouterConnection.iconTextLeft ~/ 2,
          (ScouterConnection.textTop + 10) * SkPanel.stride + 300,
          0xff,
        );
        final panel = Uint8List.fromList(shown);
        for (var k = 0; k < w.offsets.length; k++) {
          w.drawInto(panel, k);
          expect(
            _same(panel, _framePicture(shown, w, k)),
            isTrue,
            reason:
                '$name frame $k: NavWiggle.drawInto leaves a trail or '
                'draws elsewhere than the program',
          );
        }
      }
    });

    test('an icon of the wrong size is refused', () {
      expect(
        () => NavWiggle.of(NavTurn.left, Uint8List(100), x: 24, y: 140),
        throwsArgumentError,
      );
    });

    test('the words: frames, place and icon where the program reads them', () {
      for (final (name, turn, icon) in _wiggles()) {
        final w = _at(turn, icon);
        final data = w.data();
        expect(data.length, NavWiggle.dataMax, reason: name);
        final arena = _arena(w);
        int d(int offset) => armWord(arena, SkResident.arrowData + offset);
        expect(
          [d(0), d(4), d(8)],
          [
            w.offsets.length,
            ScouterConnection.textLeft,
            ScouterConnection.textTop,
          ],
          reason: name,
        );
        for (var k = 0; k < NavWiggle.maxFrames; k++) {
          final (dx, dy) = k < w.offsets.length ? w.offsets[k] : (0, 0);
          expect(
            [
              d(NavWiggle.offsetsAt + 8 * k),
              d(NavWiggle.offsetsAt + 8 * k + 4),
            ],
            [dx, dy],
            reason: '$name frame $k',
          );
        }
        expect(data.sublist(NavWiggle.iconAt), icon, reason: name);
      }
      expect(
        SkResident.arrowData + NavWiggle.dataMax,
        lessThanOrEqualTo(SkResident.arrowDataEnd),
      );
      for (final gestures in [false, true]) {
        for (final mic in [false, true]) {
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
      }
    });
  });

  group('the bar of the way left', () {
    const card = '200 m\nRechts abbiegen auf Hauptstraße\n14:32';

    /// The FILLs of a navigation card into the frame, run on the VM.
    SkVm run(
      String text, {
      int? meters,
      bool atTurn = false,
      bool arrow = true,
      Uint8List? icon,
    }) {
      final vm = SkVm(Uint8List(SkArena.size));
      for (final c in ScouterConnection.textCode(
        font,
        text,
        top: ScouterConnection.textTop,
        maxCode: 242,
        iconData: icon ?? NavArrow.icon(NavTurn.right),
        arArrow: arrow
            ? (turn: NavTurn.right, meters: meters, atTurn: atTurn)
            : null,
      )) {
        vm.runHost(c);
      }
      return vm;
    }

    /// The bar's rectangles (track and fill) among [fills].
    List<(int, int, int, int, int)> barFills(SkVm vm) => [
      for (final f in vm.fills)
        if (f.$5 == ScouterConnection.barTrack ||
            f.$5 == ScouterConnection.barLevel)
          f,
    ];

    /// The bottom row of the text's last line (its line spacing).
    int textBottom(String text) {
      final lines = text.split('\n').length;
      return ScouterConnection.textTop + lines * font.lineSpacing - 1;
    }

    test('full at 500 m or more, emptying to the turn, empty at it', () {
      for (final m in [5000, 501, 500, 499, 330, 250, 200, 90, 45, 26, 1, 0]) {
        final vm = run(card, meters: m);
        final bars = barFills(vm);
        final fill = _barFill(m);
        expect(bars.first.$5, ScouterConnection.barTrack, reason: '$m m');
        expect(bars.first.$3, 360, reason: '$m m: the track');
        final x = bars.first.$1, y = bars.first.$2;
        expect(x, ScouterConnection.iconTextLeft, reason: '$m m: under text');
        expect(y, greaterThan(textBottom(card)), reason: '$m m: on the text');
        expect(y + bars.first.$4, lessThanOrEqualTo(SkPanel.height));
        if (fill == 0) {
          expect(bars, hasLength(1), reason: '$m m: filled at 0');
        } else {
          expect(bars, hasLength(2), reason: '$m m');
          expect(bars[1], (x, y, fill, 6, ScouterConnection.barLevel));
        }
        // The pixels in the frame: lit to the fill, the track after it.
        int px(int dx) {
          final b = vm
              .arena[SkArena.frame + (y + 2) * SkPanel.stride + (x + dx) ~/ 2];
          return (x + dx).isEven ? b >> 4 : b & 15;
        }

        if (fill > 0) {
          expect(px(fill - 1), ScouterConnection.barLevel, reason: '$m m');
        }
        if (fill < 360) {
          expect(px(fill), ScouterConnection.barTrack, reason: '$m m');
        }
      }
      // Fuller farther away.
      expect(_barFill(500), greaterThan(_barFill(200)));
      expect(_barFill(200), greaterThan(_barFill(50)));
    });

    test('right at the turn the bar is empty, without a distance absent', () {
      final at = barFills(run(card, meters: 20, atTurn: true));
      expect(at, hasLength(1));
      expect(at.single.$5, ScouterConnection.barTrack);
      // No distance (a step without one): no bar at all.
      expect(barFills(run('Weiter auf B27\n14:32')), isEmpty);
      // Not the navigation's step (no arrow handed over): no bar.
      expect(barFills(run(card, arrow: false)), isEmpty);
    });

    test('below a longer text, in both languages', () {
      for (final text in [
        '300 m\nTurn left onto Main Street and keep going towards the '
            'motorway junction\n12 min · 14:32',
        '1,2 km\nIm Kreisverkehr die 2. Ausfahrt nehmen, auf die '
            'Bundesstraße B27 Richtung Stuttgart\n14:32',
      ]) {
        final meters = NavUpdate(
          title: text.split('\n').first,
          text: '',
        ).meters;
        final vm = run(text, meters: meters);
        final bars = barFills(vm);
        expect(bars, isNotEmpty, reason: text);
        final lines = ScouterConnection.wrap(
          font,
          text,
          SkPanel.width -
              ScouterConnection.textLeft -
              ScouterConnection.iconTextLeft,
        ).length;
        expect(
          bars.first.$2,
          greaterThanOrEqualTo(
            ScouterConnection.textTop + lines * font.lineSpacing,
          ),
          reason: '$text: the bar on the text ($lines lines)',
        );
        expect(bars.first.$1 + bars.first.$3, lessThanOrEqualTo(SkPanel.width));
      }
    });

    test('the icon beside the distance, the bar not on it', () {
      final icon = NavArrow.icon(NavTurn.left);
      final vm = run(card, meters: 200, icon: icon);
      for (var r = 0; r < SkIcons.size; r++) {
        final at =
            SkArena.frame +
            (ScouterConnection.textTop + r) * SkPanel.stride +
            ScouterConnection.textLeft ~/ 2;
        expect(
          vm.arena.sublist(at, at + SkIcons.stride),
          icon.sublist(r * SkIcons.stride, (r + 1) * SkIcons.stride),
          reason: 'icon row $r',
        );
      }
      final bar = barFills(vm).first;
      expect(
        bar.$1,
        greaterThanOrEqualTo(ScouterConnection.textLeft + SkIcons.size),
      );
    });
  });

  group('on the glasses', () {
    late FakeArms arms;
    late ScouterConnection g1;
    late Map<G1Side, SkVm> vms;

    /// Per arm: arrowOn when each timed draw (SLEEP_UNTIL) arrived.
    late Map<G1Side, List<int>> arrowAtTimedDraw;

    void install(G1Side side, {required bool gestures}) {
      final p = SkResident.build(
        gestures: gestures,
        micArm: side == G1Side.right,
      );
      final a = vms[side]!.arena;
      a.setRange(SkResident.code, SkResident.code + p.code.length, p.code);
      a.setRange(SkResident.pool, SkResident.pool + p.pool.length, p.pool);
      a.setRange(SkResident.table, SkResident.table + 64, p.table);
      if (gestures) vms[side]!.timer = vms[side]!.now;
    }

    setUp(() {
      arms = FakeArms();
      vms = {for (final s in G1Side.values) s: SkVm(Uint8List(SkArena.size))};
      arrowAtTimedDraw = {for (final s in G1Side.values) s: <int>[]};
      // The left arm without, the right with the gesture detector.
      install(G1Side.left, gestures: false);
      install(G1Side.right, gestures: true);
      g1 = ScouterConnection.fake((side, channel, data) {
        if (channel == 0) {
          final vm = vms[side]!;
          final on = vm.word(SkResident.arrowOn.index);
          final sleeps = vm.sleeps.length;
          vm.runHost(Uint8List.sublistView(data, 2));
          if (vm.sleeps.length > sleeps) arrowAtTimedDraw[side]!.add(on);
          vm.handlePending();
        }
        return arms.write(side, channel, data);
      }, font: font);
      arms.connection = g1;
    });

    tearDown(() => g1.dispose());

    /// The program's timer and handlers for [us] µs of device time.
    void play(int us) {
      for (final vm in vms.values) {
        final end = vm.now + us;
        while (vm.now < end) {
          vm.now += 1000;
          final t = vm.timer;
          if (t != null && (t - vm.now).toSigned(32) <= 0) {
            vm.timer = null;
            vm.trigger(SkTrigger.timer);
          }
        }
      }
    }

    Future<bool> showStep({
      NavTurn turn = NavTurn.right,
      int? meters = 20,
      bool atTurn = true,
      Uint8List? icon,
      String text = '20 m\nRechts abbiegen auf Hauptstraße\n14:32',
    }) {
      g1.setNavigationIcon(icon ?? NavArrow.icon(turn));
      g1.setNavigationArrow((turn: turn, meters: meters, atTurn: atTurn));
      return g1.sendText(text, icon: SkIcons.navigation);
    }

    List<SkVmDraw> programDraws(G1Side side) =>
        vms[side]!.draws.where((d) => d.program).toList();

    test('right at the turn both arms play every frame, then rest', () async {
      g1.fakeReady(epoch: arms.epoch);
      for (final (name, turn, icon) in _wiggles()) {
        for (final vm in vms.values) {
          vm.draws.clear();
        }
        expect(
          await showStep(turn: turn, icon: icon),
          isTrue,
          reason: name,
        );
        final w = _at(turn, icon);
        // The panel as the text left it, and the model drawn on it.
        final shown = {
          for (final s in G1Side.values)
            s: Uint8List.fromList(vms[s]!.hostPanel!),
        };
        final frames = {for (final s in G1Side.values) s: <Uint8List>[]};
        final seen = {for (final s in G1Side.values) s: 0};
        for (var t = 0; t < 3000; t += 5) {
          if (t > 0) play(5000);
          for (final side in G1Side.values) {
            final n = programDraws(side).length;
            while (seen[side]! < n) {
              final k = seen[side]!;
              seen[side] = k + 1;
              expect(
                k,
                lessThan(w.offsets.length),
                reason: '$name ${side.code}: more frames than the wiggle has',
              );
              frames[side]!.add(Uint8List.fromList(vms[side]!.panel));
              expect(
                _framePicture(shown[side]!, w, k),
                vms[side]!.panel,
                reason: '$name ${side.code} frame $k: not the icon moved',
              );
            }
          }
        }
        for (final side in G1Side.values) {
          final draws = programDraws(side);
          expect(
            draws,
            hasLength(w.offsets.length),
            reason: '$name ${side.code}: frames played',
          );
          for (var k = 0; k < draws.length; k++) {
            final d = draws[k];
            expect(
              d.x >= 0 &&
                  d.y >= 0 &&
                  d.x + d.w <= SkPanel.width &&
                  d.y + d.h <= SkPanel.height,
              isTrue,
              reason: '$name ${side.code} frame $k: off the panel $d',
            );
            expect(
              d.x + d.w,
              lessThanOrEqualTo(ScouterConnection.iconTextLeft),
              reason: '$name ${side.code} frame $k: on the text column $d',
            );
            if (k > 0) {
              expect(
                d.at - draws[k - 1].at,
                greaterThanOrEqualTo(SkResident.arrowPeriodUs),
                reason: '$name ${side.code} frame $k: too soon',
              );
              expect(
                d.at - draws[k - 1].at,
                lessThanOrEqualTo(SkResident.arrowPeriodUs + 25000),
                reason: '$name ${side.code} frame $k: too late',
              );
            }
          }
          // Back at its place: the panel as the text showed it.
          expect(
            vms[side]!.panel,
            shown[side],
            reason: '$name ${side.code}: the icon not back at its place',
          );
          // Not the same picture all along: it moved.
          if (w.offsets.any((o) => o != (0, 0))) {
            expect(
              frames[side]!.any((f) => !_same(f, shown[side]!)),
              isTrue,
              reason: '$name ${side.code}: never moved',
            );
          }
        }
      }
    });

    test('both eyes show the same frame at the same time', () async {
      // The left arm runs the program without, the right one with the
      // head-gesture detector (its timer ticks every 20 ms).
      g1.fakeReady(epoch: arms.epoch);
      await showStep(turn: NavTurn.left);
      play(3000000);
      final left = programDraws(G1Side.left);
      final right = programDraws(G1Side.right);
      expect(left.length, right.length);
      final apart = [
        for (var k = 0; k < left.length; k++)
          (right[k].at - left[k].at).abs() ~/ 1000,
      ];
      expect(
        apart.every((ms) => ms <= SkResident.arrowPeriodUs ~/ 2000),
        isTrue,
        reason:
            'ms between the eyes per frame (left ${left.length} frames '
            '${(left.last.at - left.first.at) ~/ 1000} ms, right '
            '${(right.last.at - right.first.at) ~/ 1000} ms): $apart',
      );
    });

    test('before the turn: the icon stays, no frame played', () async {
      g1.fakeReady(epoch: arms.epoch);
      for (final m in [5000, 480, 190, 45]) {
        await showStep(
          meters: m,
          atTurn: false,
          text: '$m m\nLinks abbiegen\n14:32',
        );
        play(1500000);
        for (final side in G1Side.values) {
          expect(vms[side]!.word(SkResident.arrowOn.index), 0, reason: '$m m');
          expect(programDraws(side), isEmpty, reason: '$m m ${side.code}');
        }
      }
    });

    test('a new step at the turn plays from its first frame', () async {
      g1.fakeReady(epoch: arms.epoch);
      await showStep(turn: NavTurn.left);
      play(170000); // a few frames
      for (final side in G1Side.values) {
        expect(programDraws(side).length, inInclusiveRange(2, 6));
        vms[side]!.draws.clear();
      }
      await showStep(turn: NavTurn.sharpRight);
      play(3000000);
      final w = _at(NavTurn.sharpRight, NavArrow.icon(NavTurn.sharpRight));
      for (final side in G1Side.values) {
        expect(
          programDraws(side),
          hasLength(w.offsets.length),
          reason: side.code,
        );
      }
    });

    test('both eyes: it starts with the timed draw, not before', () async {
      g1.fakeReady(epoch: arms.epoch);
      await g1.fakeSyncClocks();
      await showStep(turn: NavTurn.slightLeft);
      for (final side in G1Side.values) {
        final draws = vms[side]!.draws;
        final text = draws.indexWhere((d) => !d.program && d.w == 640);
        final first = draws.indexWhere((d) => d.program);
        expect(text, isNot(-1), reason: '${side.code}: no text');
        expect(first, greaterThan(text), reason: '${side.code}: before text');
        expect(arrowAtTimedDraw[side], [0], reason: side.code);
      }
    });

    test('both eyes, no answer: no wiggle without its text', () {
      return Future(() async {
        g1.fakeReady(epoch: arms.epoch);
        await g1.fakeSyncClocks();
        arms.acks = false;
        final shown = showStep(turn: NavTurn.uTurn);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        play(1000000);
        for (final side in G1Side.values) {
          expect(programDraws(side), isEmpty, reason: side.code);
          expect(vms[side]!.word(SkResident.arrowOn.index), 0);
        }
        arms.acks = true;
        unawaited(shown);
      });
    });

    for (final (name, end)
        in <(String, Future<void> Function(ScouterConnection))>[
          ('a blank screen', (g) => g.blankScreen()),
          ('another text', (g) => g.sendText('Hinweis\nFenster offen')),
          (
            'a notification with its icon',
            (g) => g.sendText('Telegram: Anna\nHallo!', icon: 'Telegram_app'),
          ),
          (
            'the next step before its turn',
            (g) {
              g.setNavigationArrow((
                turn: NavTurn.left,
                meters: 400,
                atTurn: false,
              ));
              return g.sendText('400 m\nLinks', icon: SkIcons.navigation);
            },
          ),
        ]) {
      test('it stops with $name', () async {
        g1.fakeReady(epoch: arms.epoch);
        await showStep(turn: NavTurn.roundabout);
        play(120000);
        for (final side in G1Side.values) {
          expect(programDraws(side), isNotEmpty, reason: side.code);
          vms[side]!.draws.clear();
        }
        await end(g1);
        play(2000000);
        for (final side in G1Side.values) {
          expect(
            programDraws(side),
            isEmpty,
            reason: '${side.code}: frames after $name',
          );
          expect(
            vms[side]!.word(SkResident.arrowOn.index),
            0,
            reason: '${side.code}: the wiggle still on after $name',
          );
        }
      });
    }

    for (final (name, end)
        in <(String, Future<void> Function(ScouterConnection))>[
          ('the silent-mode animation', (g) => g.playSilentModeAnimation(true)),
          (
            'the lab silent-mode animation',
            (g) => g.playSilentModeAnimation(false, lab: true),
          ),
          (
            'a video',
            (g) => g.playVideo(
              width: 64,
              height: 32,
              fps: 15,
              frames: 3,
              read: (start, count) async => Uint8List(8 * 32 * count),
            ),
          ),
        ]) {
      // These run code the small VM does not have: their packets switch
      // the wiggle off before anything draws.
      test('it stops with $name', () async {
        final fake = arms;
        final words = {for (final s in G1Side.values) s: <int>[]};
        g1.dispose();
        g1 = ScouterConnection.fake((side, channel, data) {
          final ops = fake.ops[side]!;
          final before = ops.length;
          final done = fake.write(side, channel, data);
          if (channel == 0) {
            const drawing = [
              SkOp.fill,
              SkOp.blit,
              SkOp.glyphs,
              SkOp.draw,
              SkOp.line,
              SkOp.video,
              SkOp.call,
            ];
            if (ops.sublist(before).any(drawing.contains)) {
              words[side]!.add(
                armWord(fake.arenas[side]!, SkResident.arrowOn.address),
              );
            }
          }
          return done;
        }, font: font);
        fake.connection = g1;
        g1.fakeReady(epoch: fake.epoch);
        await showStep(turn: NavTurn.left);
        for (final side in G1Side.values) {
          expect(armWord(fake.arenas[side]!, SkResident.arrowOn.address), 1);
          words[side]!.clear();
        }
        await end(g1);
        for (final side in G1Side.values) {
          expect(words[side], isNotEmpty, reason: '${side.code}: nothing');
          expect(
            words[side]!.every((v) => v == 0),
            isTrue,
            reason: '${side.code}: the wiggle on under $name: ${words[side]}',
          );
          expect(armWord(fake.arenas[side]!, SkResident.arrowOn.address), 0);
        }
      });
    }

    test('only the navigation\'s text has the bar and the wiggle', () async {
      g1.fakeReady(epoch: arms.epoch);
      g1.setNavigationIcon(NavArrow.icon(NavTurn.right));
      g1.setNavigationArrow((turn: NavTurn.right, meters: 20, atTurn: true));
      for (final send in [
        () => g1.sendText('Hinweis\nFenster offen'),
        () => g1.sendText('Telegram: Anna\nHallo!', icon: 'Telegram_app'),
        () => g1.sendText('Wohnzimmer 21 °C', serverOnline: true),
      ]) {
        for (final vm in vms.values) {
          vm.fills.clear();
        }
        await send();
        play(500000);
        for (final side in G1Side.values) {
          final vm = vms[side]!;
          expect(vm.word(SkResident.arrowOn.index), 0);
          expect(programDraws(side), isEmpty);
          expect(
            vm.fills.where(
              (f) => f.$3 == ScouterConnection.barWidth && f.$4 == 6,
            ),
            isEmpty,
            reason: '${side.code}: a bar',
          );
        }
      }
    });

    test('an arm in the case gets nothing, the other plays', () async {
      g1.fakeReady(epoch: arms.epoch);
      g1.receive(G1Side.left, input(arms.epoch, SkTrigger.caseState, 0xff01));
      await showStep(turn: NavTurn.right);
      play(2000000);
      expect(vms[G1Side.left]!.draws, isEmpty);
      expect(programDraws(G1Side.right), isNotEmpty);
      g1.receive(G1Side.left, input(arms.epoch, SkTrigger.caseState, 0xff00));
      await showStep(turn: NavTurn.left);
      play(2000000);
      expect(programDraws(G1Side.left), isNotEmpty);
    });

    test('glasses not connected: nothing written', () async {
      expect(await showStep(), isFalse);
      for (final side in G1Side.values) {
        expect(arms.ops[side], isEmpty);
        expect(vms[side]!.draws, isEmpty);
      }
    });

    test('no icon to push (an icon of the wrong size): no wiggle', () async {
      g1.fakeReady(epoch: arms.epoch);
      await showStep(icon: Uint8List(300));
      play(1000000);
      for (final side in G1Side.values) {
        expect(vms[side]!.word(SkResident.arrowOn.index), 0);
        expect(programDraws(side), isEmpty);
      }
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
      expect(nav.update(step('400 m', 'Turn left onto Elm St')), isTrue);
      expect(nav.atTurn, isFalse);
      expect(nav.update(step('15 m', 'Links abbiegen')), isTrue);
      expect(nav.atTurn, isTrue);
      expect(nav.update(step('', 'Weiter auf B27')), isTrue);
      expect(nav.atTurn, isFalse);
      nav.update(step('20 m', 'Rechts abbiegen'));
      expect(nav.atTurn, isTrue);
      nav.end();
      expect(nav.atTurn, isFalse);
    });

    test('updates that skip marks: right at the turn is still the turn', () {
      for (final from in [480, 190, 45]) {
        final nav = Navigation();
        expect(nav.update(step('$from m', 'Rechts abbiegen')), isTrue);
        expect(nav.update(step('20 m', 'Rechts abbiegen')), isTrue);
        expect(nav.atTurn, isTrue, reason: 'from $from m');
        expect(nav.update(step('15 m', 'Rechts abbiegen')), isFalse);
      }
    });
  });

  group('bridge', () {
    late Settings settings;
    late FakeGlasses g1;
    late Bridge bridge;

    Future<void> start([Map<String, Object> prefs = const {}]) async {
      SharedPreferences.setMockInitialValues(prefs);
      settings = await Settings.load();
      g1 = FakeGlasses();
      bridge = Bridge(settings, g1: g1);
    }

    tearDown(() => bridge.display.clear());

    NavUpdate step(String title, String text, {Uint8List? icon}) =>
        NavUpdate(title: title, text: text, subText: '14:32', icon: icon);

    test('turn, distance and "at the turn" go with each step', () async {
      await start();
      await bridge.onNavigation(step('300 m', 'Rechts abbiegen'));
      expect(g1.navigationArrow, (
        turn: NavTurn.right,
        meters: 300,
        atTurn: false,
      ));
      expect(g1.icons.last, SkIcons.navigation);
      expect(g1.navigationIcon, NavArrow.icon(NavTurn.right));
      await bridge.onNavigation(step('20 m', 'Rechts abbiegen'));
      expect(g1.navigationArrow, (
        turn: NavTurn.right,
        meters: 20,
        atTurn: true,
      ));
      await bridge.onNavigation(step('Head north', 'toward Elm St'));
      expect(g1.navigationArrow, (
        turn: NavTurn.straight,
        meters: null,
        atTurn: false,
      ));
      // Google Maps' own icon goes to the glasses as it is.
      final maps = Uint8List(SkIcons.bytes)..fillRange(0, 100, 0x5a);
      await bridge.onNavigation(step('20 m', 'Links abbiegen', icon: maps));
      expect(g1.navigationIcon, maps);
      expect(g1.navigationArrow?.atTurn, isTrue);
    });

    test('no setting any more: an old "off" does not switch it off', () async {
      for (final key in ['navigation_arrow', 'navigation_ar_arrow']) {
        await start({key: false});
        await bridge.onNavigation(step('20 m', 'Rechts abbiegen'));
        expect(g1.navigationArrow, isNotNull, reason: key);
        expect(g1.navigationArrow?.atTurn, isTrue, reason: key);
        bridge.display.clear();
      }
    });

    test('the navigation ends: no arrow; not forwarded: none', () async {
      await start();
      await bridge.onNavigation(step('20 m', 'Rechts abbiegen'));
      await bridge.onNavigation(null);
      expect(g1.navigationArrow, isNull);
      expect(g1.navigationIcon, isNull);
      await bridge.onNavigation(step('300 m', 'Rechts abbiegen'));
      expect(g1.navigationArrow?.atTurn, isFalse);
      settings.forwardNavigation = false;
      await bridge.onNavigation(step('20 m', 'Rechts abbiegen'));
      expect(g1.navigationArrow, isNull);
      // On again: a new navigation, not at the turn of the old one.
      settings.forwardNavigation = true;
      await bridge.onNavigation(step('300 m', 'Links abbiegen'));
      expect(g1.navigationArrow?.atTurn, isFalse);
    });
  });
}

/// What the wearer sees in frame [k] of [w], from the picture the text
/// showed ([shown]): the text column as it was, left of it nothing but the
/// icon at the frame's place (no trail where it was before).
Uint8List _framePicture(Uint8List shown, NavWiggle w, int k) {
  final out = Uint8List.fromList(shown);
  final (x0, y0, x1, y1) = w.box(k);
  for (var y = 0; y < SkPanel.height; y++) {
    for (var x = 0; x < ScouterConnection.iconTextLeft; x++) {
      var v = 0;
      if (x >= x0 && x <= x1 && y >= y0 && y <= y1) {
        final b = w.icon[(y - y0) * SkIcons.stride + ((x - x0) >> 1)];
        v = (x - x0).isEven ? b >> 4 : b & 15;
      }
      final i = y * SkPanel.stride + (x >> 1);
      out[i] = x.isEven ? (out[i] & 0x0f) | v << 4 : (out[i] & 0xf0) | v;
    }
  }
  return out;
}

bool _same(Uint8List a, Uint8List b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
