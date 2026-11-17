/// The glasses' program and the app must agree on who draws: whatever the
/// order of notifications, taps, head movements, settings and recordings,
/// once things settle the program may show the dashboard again.
///
/// The program shows the dashboard on head up only if all of these hold
/// (sk_program.dart): the app shows nothing (`busy` = 0), the dashboard is
/// on (`flags`) and it has lines (`count` > 0). This test plays random
/// sequences of everything the app reacts to against simulated arms and
/// checks these words after every step. A new feature that draws on the
/// glasses or changes the program's words belongs in [_Scenario.actions].
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:even_g1_ha/bridge.dart';
import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/navigation/navigation.dart';
import 'package:even_g1_ha/navigation/nav_wiggle.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_asm.dart';
import 'package:even_g1_ha/scouter/sk_clock.dart';
import 'package:even_g1_ha/scouter/sk_icons.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nav_wiggle_check.dart';
import 'fake_arms.dart';
import 'fake_arms.dart' as fake show input;

/// One run: a bridge on a ScouterKit connection to simulated arms.
class _Scenario {
  _Scenario(this.async, this.settings, this.seed) : rnd = Random(seed) {
    arms = FakeArms();
    g1 = ScouterConnection.fake(
      (side, channel, data) {
        if (channel == 0) _watchFills(side, data);
        return arms.write(side, channel, data);
      },
      font: font,
      mtu: 247,
    );
    arms.connection = g1;
    arms.props[SkProp.inCase] = 0;
    arms.props[SkProp.worn] = 1;
    // Half the runs on a busy link: the arm answers "microphone on" late.
    if (seed.isOdd) arms.micOnDelay = const Duration(milliseconds: 300);
    bridge = Bridge(settings, g1: g1);
    bridge.display.screen.addListener(() => _screenChanges++);
    // The arms' clocks and the video follow the fake time.
    SkClock.fakeNow = () => 1000000 + async.elapsed.inMicroseconds;
  }

  final FakeAsync async;
  final Settings settings;
  final font = loadTestFont();
  final int seed;
  final Random rnd;
  late final FakeArms arms;
  late final ScouterConnection g1;
  late final Bridge bridge;

  /// What happened so far, for the failure message.
  final steps = <String>[];

  bool _mic = false;

  /// The navigation's cards (texts shown with its arrow), the screen's
  /// changes, and whether the arrow must show after the last action
  /// (null: no navigation step shown by it).
  final _navCards = <String>{};
  int _screenChanges = 0;
  bool? _arrowWanted;

  /// The wiggles the bridge handed to the glasses (their words), and the
  /// one of the step just shown right at the turn.
  final _arrows = <String>{};
  String? _arrowShown;

  /// The wiggle's words for [update] right at the turn.
  String _arrowFor(NavUpdate update) => NavWiggle.of(
    update.turn,
    bridge.navigation.icon,
    x: ScouterConnection.textLeft,
    y: ScouterConnection.textTop,
  ).data().join(',');

  /// Per arm, the navigation's bar (FILLs of its size) in the frame since
  /// the frame was last cleared: (x, y, w, h, level).
  final _bars = {
    for (final s in G1Side.values) s: <(int, int, int, int, int)>[],
  };

  /// The bar the step just shown must have: its filled width, null for
  /// none (no distance); not set when no step was shown.
  ({int? fill})? _barWanted;

  /// The FILLs of a CMD packet, decoded with the operand words it writes
  /// into the scratch words before them.
  void _watchFills(G1Side side, Uint8List data) {
    final code = Uint8List.sublistView(data, 2);
    final arena = arms.arenas[side]!;
    final scratch = Uint8List.fromList(
      arena.sublist(SkArena.params, SkArena.params + 256),
    );
    int word(int index) {
      final at = index * 4;
      final b = at >= SkArena.params && at + 4 <= SkArena.params + 256
          ? scratch
          : arena;
      final o = b == scratch ? at - SkArena.params : at;
      return ByteData.sublistView(b).getInt32(o, Endian.little);
    }

    var i = 0;
    while (i < code.length) {
      final op = code[i];
      if (op == SkOp.write) {
        final addr = code[i + 1] | code[i + 2] << 8 | code[i + 3] << 16;
        final n = code[i + 4];
        for (var j = 0; j < n; j++) {
          final a = addr + j - SkArena.params;
          if (a >= 0 && a < 256) scratch[a] = code[i + 5 + j];
        }
        i += 5 + n;
        continue;
      }
      if (op == SkOp.writeRle) {
        i += 7 + code[i + 6];
        continue;
      }
      if (op == SkOp.call) {
        i += 4;
        continue;
      }
      if (op == SkOp.end) {
        i += 1;
        continue;
      }
      final k = switch (op) {
        SkOp.sleepUntil || SkOp.raise => 1,
        SkOp.add => 3,
        SkOp.sysRead || SkOp.sysWrite => 2,
        SkOp.fill || SkOp.line => 7,
        SkOp.blit => 12,
        SkOp.glyphs => 9,
        SkOp.draw => 8,
        SkOp.video => 10,
        SkOp.assetLoad => 4,
        _ => throw StateError('op 0x${op.toRadixString(16)}'),
      };
      final at = i + 1 + (k + 1) ~/ 2;
      List<int> operands() => [
        for (var j = 0; j < k; j++)
          word(code[at + 2 * j] | code[at + 2 * j + 1] << 8),
      ];
      if (op == SkOp.fill) {
        final [dst, _, x, y, w, h, level] = operands();
        if (dst == SkArena.frame) {
          if (x <= 0 && y <= 0 && w >= SkPanel.width && h >= SkPanel.height) {
            _bars[side]!.clear();
          } else if (x == ScouterConnection.iconTextLeft &&
              h == ScouterConnection.barHeight) {
            _bars[side]!.add((x, y, w, h, level));
          }
        }
      }
      i = at + 2 * k;
    }
  }

  /// A navigation step (null: it ends) the way the phone sends it.
  void navigate(NavUpdate? update) {
    final changes = _screenChanges;
    run(() => bridge.onNavigation(update));
    final card = bridge.navigation.cardText;
    if (update != null && card.isNotEmpty) _navCards.add(card);
    final arrow =
        update != null && settings.forwardNavigation && bridge.navigation.atTurn
        ? _arrowFor(update)
        : null;
    if (arrow != null) _arrows.add(arrow);
    if (update != null &&
        _screenChanges > changes &&
        bridge.display.screen.value == card) {
      _arrowWanted = arrow != null;
      _arrowShown = arrow;
      final m = update.meters;
      _barWanted = (
        fill: m == null
            ? null
            : bridge.navigation.atTurn
            ? 0
            : (360 * min(m, 500) / 500).round(),
      );
    }
  }

  /// One step of a drive towards a turn: the same instruction ever nearer
  /// (500, 200, 50 m and right at the turn), then the next turn.
  int _drive = 0;
  int _mapsIcon = 0;
  int _driveTurn = 0;
  static const _driveMeters = [700, 480, 190, 45, 20, 8];
  static const _driveSteps = [
    'Rechts abbiegen auf Hauptstraße',
    'Turn left onto Elm St',
    'Make a U-turn',
    'Im Kreisverkehr die 2. Ausfahrt',
    'Sharp right',
    'Leicht links halten',
    'Continue on B27',
    'Ziel erreicht',
  ];

  int word(G1Side side, SkW w) =>
      ByteData.sublistView(arms.arenas[side]!)
          .getUint32(w.address, Endian.little);

  void run(Future<void> Function() f) {
    f();
    async.flushMicrotasks();
  }

  void wait(Duration d) {
    async.elapse(d);
    async.flushMicrotasks();
  }

  void input(G1Side side, int trigger, int value) =>
      g1.receive(side, fake.input(arms.epoch, trigger, value));

  void head(bool up) {
    for (final side in G1Side.values) {
      g1.receive(
        side,
        event(SkEvt.notify, arms.epoch, [
          0,
          0,
          0,
          ...u32(SkResident.notifyHead),
          ...u32(up ? 1 : 0),
        ]),
      );
    }
  }

  void config({String? gesture, int? duration, bool? lab}) => run(
    () => bridge.fakeHaCommand({
      'type': 'config',
      'name': 'Even G1',
      'dashboard_gesture': gesture ?? 'head_up',
      'display_duration': duration ?? 5,
      'design_set': lab == true ? 'lab' : 'standard',
    }),
  );

  G1Side get side => rnd.nextBool() ? G1Side.left : G1Side.right;

  /// Everything the app reacts to, by name.
  late final Map<String, void Function()> actions = {
    'notification': () => run(
      () => bridge.fakeHaCommand({
        'type': 'show_text',
        'mode': 'notification',
        'title': 'Paket',
        'message': 'Zugestellt',
      }),
    ),
    'text': () => run(
      () => bridge.fakeHaCommand({
        'type': 'show_text',
        'title': 'Hinweis',
        'message': 'Fenster offen',
        // 0: stays until dismissed.
        'duration': rnd.nextBool() ? 0 : 3,
      }),
    ),
    'long text': () => run(
      () => bridge.fakeHaCommand({
        'type': 'show_text',
        'message': List.generate(30, (i) => 'Zeile ${i + 1}').join('\n'),
        'duration': 2,
      }),
    ),
    'clear': () => run(() => bridge.fakeHaCommand({'type': 'clear'})),
    'dashboard text': () => run(
      () => bridge.fakeHaCommand({
        'type': 'dashboard',
        'text': 'Wohnzimmer ${rnd.nextInt(30)} °C\n$clockToken',
      }),
    ),
    'config': () => config(
      gesture: const [
        'head_up',
        'head_up',
        'single_tap_right',
        'none',
      ][rnd.nextInt(4)],
      duration: const [0, 3, 10][rnd.nextInt(3)],
      lab: rnd.nextBool(),
    ),
    'tap': () => input(side, SkTrigger.touch, SkGesture.tap),
    'double tap': () => input(side, SkTrigger.touch, SkGesture.doubleTap),
    'triple tap': () => input(side, SkTrigger.touch, SkGesture.tripleTap),
    'long press': () {
      final s = side;
      input(s, SkTrigger.touch, SkGesture.longStart);
      wait(Duration(milliseconds: rnd.nextInt(1500)));
      input(s, SkTrigger.touch, SkGesture.longEnd);
    },
    'head up': () => head(true),
    'head down': () => head(false),
    'microphone': () {
      _mic = !_mic;
      run(() => g1.setMic(_mic));
    },
    // A recording's keep-alive switches it on just as it is stopped.
    'microphone race': () {
      g1.setMic(true);
      g1.setMic(false);
      _mic = false;
      async.flushMicrotasks();
    },
    'video': () => run(
      () => bridge.playVideo(
        width: 64,
        height: 32,
        fps: 15,
        frames: 6,
        read: (start, count) async => Uint8List(8 * 32 * count),
      ),
    ),
    'silent mode': () => run(() => bridge.setSilentMode(rnd.nextBool())),
    'head gestures': () => run(() => bridge.setHeadGestures(rnd.nextBool())),
    'gyro check': () => run(() => bridge.setHeadUpGyroCheck(rnd.nextBool())),
    'head-up angle': () => run(() => g1.setHeadUpAngle(10 + rnd.nextInt(30))),
    'server online': () =>
        run(() => g1.setHomeAssistantOnline(rnd.nextInt(3) != 0)),
    'dashboard label': () =>
        run(() => g1.setDashboardLabel(rnd.nextBool() ? 'REC' : null)),
    'navigation': () => navigate(
      rnd.nextInt(3) == 0
          ? null
          : NavUpdate(
              title: '${50 + rnd.nextInt(500)} m',
              text: rnd.nextBool() ? 'Rechts abbiegen' : 'Links abbiegen',
              subText: '14:32',
            ),
    ),
    // Every kind of turn, in English and German, with and without a
    // distance.
    'navigation turns': () {
      const steps = [
        ('Turn right onto Main St', 'Rechts abbiegen auf Hauptstraße'),
        ('Turn left onto Elm St', 'Links abbiegen auf Ulmenweg'),
        ('Keep left at the fork', 'Leicht links halten'),
        ('Take exit 12', 'Ausfahrt 12 nehmen'),
        ('Sharp right', 'Scharf rechts abbiegen'),
        ('Sharp left', 'Scharf links abbiegen'),
        ('Make a U-turn', 'Wenden'),
        (
          'At the roundabout, take the 2nd exit',
          'Im Kreisverkehr die 2. Ausfahrt',
        ),
        ('Continue on B27', 'Weiter auf B27'),
        ('You have arrived at your destination', 'Ziel erreicht'),
      ];
      final (en, de) = steps[rnd.nextInt(steps.length)];
      final distance = [
        '',
        '${rnd.nextInt(40)} m',
        '${40 + rnd.nextInt(800)} m',
        '1,${rnd.nextInt(10)} km',
        '0.${1 + rnd.nextInt(9)} mi',
      ][rnd.nextInt(5)];
      navigate(
        NavUpdate(
          title: distance,
          text: rnd.nextBool() ? en : de,
          subText: rnd.nextBool() ? '12 min · 14:32' : '',
        ),
      );
    },
    // A drive: the step comes closer, its arrow with it, until it swings
    // into the turn.
    'navigation drive': () {
      if (_drive == _driveMeters.length) {
        _drive = 0;
        _driveTurn = rnd.nextInt(_driveSteps.length);
      }
      navigate(
        NavUpdate(
          title: '${_driveMeters[_drive++]} m',
          text: _driveSteps[_driveTurn],
          subText: '14:32',
        ),
      );
    },
    // Google Maps' own turn icon (50 × 50, 4 bpp) on a drive to the turn,
    // with the bar emptying and right at the turn the icon's push.
    'navigation maps icon': () {
      final icon = Uint8List(SkIcons.bytes);
      for (var i = 0; i < icon.length; i++) {
        icon[i] = (i * 7 + _mapsIcon * 31) & 0xff;
      }
      final m = const [900, 480, 300, 190, 120, 45, 30, 20, 3][rnd.nextInt(9)];
      if (rnd.nextInt(4) == 0) _mapsIcon++;
      navigate(
        NavUpdate(
          title: '$m m',
          text: rnd.nextBool() ? 'Turn left onto Elm St' : 'Links abbiegen',
          subText: '14:32',
          icon: icon,
        ),
      );
    },
    'brightness': () => run(() async {
      await g1.setBrightnessCurve(rnd.nextBool());
      await g1.setAutoBrightnessOffset(rnd.nextInt(9) - 4);
      await g1.setBrightness(rnd.nextInt(101), auto: rnd.nextBool());
    }),
    'wear detection': () => run(() => bridge.setWearDetection(rnd.nextBool())),
    'minute check': () => run(g1.fakeCheckPrograms),
    'short wait': () => wait(Duration(milliseconds: rnd.nextInt(800))),
    'long wait': () => wait(const Duration(seconds: 12)),
  };

  void setUp() {
    run(g1.fakeSetup);
    wait(const Duration(seconds: 1));
    config();
    run(
      () => bridge.fakeHaCommand({
        'type': 'dashboard',
        'text': 'Home Assistant\n$clockToken',
      }),
    );
    wait(const Duration(seconds: 1));
    check('setup');
  }

  /// The rules once things settled.
  void check(String after) {
    String why(String rule) =>
        'seed $seed, after ${steps.length} steps (${steps.reversed.take(12).toList().reversed.join(' → ')}): $rule';
    expect(g1.connected, isTrue, reason: why('connected'));
    final shown = bridge.display.active || bridge.display.screen.value != null;
    for (final side in G1Side.values) {
      final busy = word(side, SkResident.busy);
      if (shown) {
        // The program keeps away from the app's text.
        expect(busy, 1, reason: why('${side.code}: text shown, busy'));
      } else if (!bridge.assistRunning) {
        // Nothing shown: the program may draw.
        expect(busy, 0, reason: why('${side.code}: nothing shown, busy'));
      }
      // The arrow only with a navigation step the app shows.
      if (word(side, SkResident.arrowOn) != 0) {
        expect(shown, isTrue, reason: why('${side.code}: arrow without text'));
        expect(busy, 1, reason: why('${side.code}: arrow, busy'));
        final screen = bridge.display.screen.value;
        expect(
          _navCards.contains(screen),
          isTrue,
          reason: why('${side.code}: arrow under "$screen"'),
        );
        // Beside the text and on the panel, in every frame.
        expect(
          wiggleProblems(arms.arenas[side]!),
          isEmpty,
          reason: why('${side.code}: the wiggle\'s words'),
        );
        // The words of an arrow the bridge handed over, never another's.
        final words = arms.arenas[side]!.sublist(
          SkResident.arrowData,
          SkResident.arrowData + NavWiggle.dataMax,
        );
        expect(
          _arrows.contains(words.join(',')),
          isTrue,
          reason: why('${side.code}: arrow of no step'),
        );
        // From its first frame, the icon's box at its place (the program
        // clears the box before each frame: no trail of the icon).
        final x = armWord(arms.arenas[side]!, SkResident.arrowData + 4);
        final y = armWord(arms.arenas[side]!, SkResident.arrowData + 8);
        expect(
          [
            word(side, SkResident.arrowFrame),
            word(side, SkResident.arrowAt),
            for (var k = 0; k < 4; k++)
              armWord(arms.arenas[side]!, SkResident.arrowBox.address + 4 * k),
          ],
          [0, 0, x, y, x + SkIcons.size - 1, y + SkIcons.size - 1],
          reason: why('${side.code}: the wiggle not from its first frame'),
        );
      }
      // The bar of the way left: under the step just shown, as far as the
      // turn is; never under another text.
      final screen = bridge.display.screen.value;
      final bar = _barWanted;
      if (bar != null && screen == bridge.navigation.cardText) {
        final bars = _bars[side]!;
        final fill = bar.fill;
        if (fill == null) {
          expect(
            bars,
            isEmpty,
            reason: why('${side.code}: a bar, no distance'),
          );
        } else {
          expect(
            [for (final b in bars) (b.$1, b.$3, b.$4, b.$5)],
            [
              (
                ScouterConnection.iconTextLeft,
                ScouterConnection.barWidth,
                ScouterConnection.barHeight,
                ScouterConnection.barTrack,
              ),
              if (fill > 0)
                (
                  ScouterConnection.iconTextLeft,
                  fill,
                  ScouterConnection.barHeight,
                  ScouterConnection.barLevel,
                ),
            ],
            reason: why(
              '${side.code}: the bar at ${bridge.navigation.current?.meters} m'
              '${bridge.navigation.atTurn ? ' (at the turn)' : ''}',
            ),
          );
          expect(
            bars.first.$2,
            greaterThan(ScouterConnection.textTop + font.lineSpacing),
            reason: why('${side.code}: the bar on the text'),
          );
        }
      } else if (shown && screen != null && !_navCards.contains(screen)) {
        expect(
          _bars[side],
          isEmpty,
          reason: why('${side.code}: a bar under "$screen"'),
        );
      }
      // A step just shown: the wiggle right at the turn, none before.
      final wantArrow = _arrowWanted;
      if (wantArrow != null &&
          bridge.display.screen.value == bridge.navigation.cardText) {
        expect(
          word(side, SkResident.arrowOn),
          wantArrow ? 1 : 0,
          reason: why('${side.code}: arrow ${wantArrow ? 'on' : 'off'}'),
        );
        // The step's own arrow: coming closer, or right at the turn the
        // swing into its direction.
        final shownArrow = _arrowShown;
        if (wantArrow && shownArrow != null) {
          final a = arms.arenas[side]!;
          final words = a
              .sublist(
                SkResident.arrowData,
                SkResident.arrowData + shownArrow.split(',').length,
              )
              .join(',');
          expect(
            words == shownArrow,
            isTrue,
            reason: why(
              '${side.code}: not the arrow of the step just shown '
              '(${bridge.navigation.atTurn ? 'at the turn' : 'before it'}'
              ', ${bridge.navigation.current?.meters} m)',
            ),
          );
        }
      }
      final wanted =
          (bridge.haConfig.dashboardOnHeadUp || bridge.navigation.active) &&
          bridge.silentMode != true;
      final flags = word(side, SkResident.flags);
      expect(
        flags & SkResident.flagDashboard != 0,
        wanted,
        reason: why('${side.code}: dashboard on head up'),
      );
      expect(
        word(side, SkResident.count),
        greaterThan(0),
        reason: why('${side.code}: dashboard lines'),
      );
    }
    expect(
      word(G1Side.right, SkResident.micOn),
      _mic ? 1 : 0,
      reason: why('microphone stand'),
    );
    _arrowWanted = null;
    _barWanted = null;
    _arrowShown = null;
  }

  void play(int count) {
    final names = actions.keys.toList();
    for (var i = 0; i < count; i++) {
      final name = names[rnd.nextInt(names.length)];
      steps.add(name);
      actions[name]!();
      // Settled: the arms answered, a switched-off microphone got its
      // second "off".
      wait(const Duration(milliseconds: 1500));
      check(name);
    }
    // In the end everything closes by itself or with a double tap.
    wait(const Duration(seconds: 30));
    if (bridge.display.active) {
      steps.add('double tap');
      input(G1Side.right, SkTrigger.touch, SkGesture.doubleTap);
      wait(const Duration(seconds: 2));
    }
    check('end');
    expect(
      bridge.display.active,
      isFalse,
      reason: 'seed $seed: the display closes',
    );
  }

  void dispose() {
    SkClock.fakeNow = null;
    bridge.dispose();
    async.flushMicrotasks();
  }
}

/// What the connection to the glasses can do, and where this test covers
/// it: an action in [_Scenario.actions], or why it needs none. A new
/// method makes the guard below fail until it is listed here.
const _coverage = <String, String>{
  'blankScreen': 'action: clear',
  'connect': 'exempt: the scenario starts connected (fakeSetup)',
  'disconnect': 'exempt: the scenario stays connected',
  'dispose': 'exempt: end of the scenario',
  'emitAudio': 'exempt: audio to the app, nothing on the glasses',
  'emitEvent': 'action: tap',
  'layoutPages': 'exempt: computes pages, writes nothing',
  'note': 'exempt: logging',
  'notifyListeners': 'exempt: app state only',
  'playSilentModeAnimation': 'action: silent mode',
  'playVideo': 'action: video',
  'readBrightnessLevel': 'exempt: reads only',
  'readWearDetection': 'exempt: reads only',
  'receive': 'action: tap',
  'refreshBattery': 'exempt: reads only',
  'sendText': 'action: text',
  'setAutoBrightnessOffset': 'action: brightness',
  'setBrightness': 'action: brightness',
  'setBrightnessCurve': 'action: brightness',
  'setBrightnessLevel': 'action: brightness',
  'setDashboard': 'action: dashboard text',
  'setDashboardLabel': 'action: dashboard label',
  'setFastConnection': 'exempt: Bluetooth priority only',
  'setHeadGestures': 'action: head gestures',
  'setHeadUpAngle': 'action: head-up angle',
  'setHeadUpGyroCheck': 'action: gyro check',
  'setHomeAssistantOnline': 'action: server online',
  'setMic': 'action: microphone',
  'setNavigationIcon': 'action: navigation',
  'setNavigationArrow': 'action: navigation turns',
  'setSilentMode': 'action: silent mode',
  'setWearDetection': 'action: wear detection',
  'two': 'exempt: helper',
  'labelBase': 'exempt: layout helper, writes nothing',
  'loadFont': 'exempt: loads an asset',
  'loadSmallFont': 'exempt: loads an asset',
  'scan': 'exempt: finds glasses, writes nothing',
  'wrap': 'exempt: layout helper, writes nothing',
  'navigationBar': 'exempt: layout helper (the bar\'s place), writes nothing',
  'dashboardLabelAt': 'exempt: layout helper, writes nothing',
  'dashboardStatusAt': 'exempt: layout helper, writes nothing',
};

/// The public methods of the connection's interface and of ScouterKit's.
Set<String> _connectionMethods() {
  final names = <String>{};
  final method = RegExp(
    r'^  (?:static )?(?:Future<[^ ]+>|Stream<[^ ]+>|void|bool|int|String|'
    // Records too: `(int, int)? name(`, `({int x, int y}) name(`.
    r'[A-Z][A-Za-z<>?, ]*|\([^()]*\)\??) ([a-z][A-Za-z0-9]*)\(',
    multiLine: true,
  );
  for (final path in [
    'lib/g1/g1_connection.dart',
    'lib/scouter/scouter_connection.dart',
  ]) {
    final lines = File(path).readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final m = method.firstMatch(lines[i]);
      if (m == null) continue;
      // Test helpers are marked @visibleForTesting.
      if (i > 0 && lines[i - 1].contains('@visibleForTesting')) continue;
      names.add(m.group(1)!);
    }
  }
  return names;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Settings settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await Settings.load();
  });

  test('every way to change the glasses is covered or exempt', () {
    final missing = _connectionMethods().difference(_coverage.keys.toSet());
    expect(
      missing,
      isEmpty,
      reason:
          'New methods on the glasses connection: add an action for each '
          'to _Scenario.actions and list it in _coverage (or list it as '
          'exempt with the reason).',
    );
    // Each listed action exists.
    final s = _Scenario(FakeAsync(), settings, 0);
    for (final e in _coverage.entries) {
      if (!e.value.startsWith('action: ')) {
        expect(e.value, startsWith('exempt: '), reason: e.key);
        continue;
      }
      final action = e.value.substring('action: '.length);
      expect(s.actions.keys, contains(action), reason: e.key);
    }
  });

  test('a double tap on a text leaves the dashboard free', () {
    fakeAsync((async) {
      final s = _Scenario(async, settings, 0)..setUp();
      s.config(duration: 0);
      s.actions['notification']!();
      s.wait(const Duration(seconds: 1));
      s.check('notification');
      s.input(G1Side.right, SkTrigger.touch, SkGesture.doubleTap);
      s.wait(const Duration(seconds: 1));
      s.check('double tap');
      expect(s.word(G1Side.right, SkResident.busy), 0);
      s.dispose();
    });
  });

  test('right at the turn the icon wiggles until the step closes', () {
    fakeAsync((async) {
      final s = _Scenario(async, settings, 0)..setUp();
      int arrow(G1Side side) => s.word(side, SkResident.arrowOn);
      void step(int m) => s.navigate(
        NavUpdate(
          title: '$m m',
          text: 'Turn right onto Main St',
          subText: '14:32',
        ),
      );
      // Before the turn: the icon and the bar, no wiggle.
      step(200);
      s.wait(const Duration(seconds: 1));
      s.check('200 m');
      for (final side in G1Side.values) {
        expect(arrow(side), 0, reason: '${side.code}: 200 m');
      }
      step(20);
      s.wait(const Duration(seconds: 1));
      s.check('20 m');
      final want = NavWiggle.of(
        NavTurn.right,
        s.bridge.navigation.icon,
        x: ScouterConnection.textLeft,
        y: ScouterConnection.textTop,
      ).data();
      for (final side in G1Side.values) {
        expect(arrow(side), 1, reason: '${side.code}: the wiggle');
        expect(
          s.arms.arenas[side]!.sublist(
            SkResident.arrowData,
            SkResident.arrowData + want.length,
          ),
          want,
          reason: side.code,
        );
      }
      // The step closes by itself: the wiggle with it.
      s.wait(Bridge.navigationDuration);
      s.check('closed');
      expect(s.bridge.display.active, isFalse);
      for (final side in G1Side.values) {
        expect(arrow(side), 0, reason: '${side.code}: closed');
      }
      // Silent mode: no step on the glasses, no wiggle.
      s.run(() => s.bridge.setSilentMode(true));
      s.wait(const Duration(seconds: 3));
      s.navigate(
        NavUpdate(title: '10 m', text: 'Links abbiegen', subText: '14:33'),
      );
      s.wait(const Duration(seconds: 1));
      s.check('silent navigation');
      for (final side in G1Side.values) {
        expect(arrow(side), 0, reason: '${side.code}: silent mode');
      }
      s.dispose();
    });
  });

  for (var seed = 1; seed <= 100; seed++) {
    test('random sequence $seed keeps program and app in agreement', () {
      fakeAsync((async) {
        final s = _Scenario(async, settings, seed)..setUp();
        s.play(80);
        s.dispose();
      });
    });
  }
}
