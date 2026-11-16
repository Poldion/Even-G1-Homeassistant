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
import 'package:even_g1_ha/navigation/turn_arrow.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_asm.dart';
import 'package:even_g1_ha/scouter/sk_clock.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'turn_arrow_check.dart';
import 'fake_arms.dart';
import 'fake_arms.dart' as fake show input;

/// One run: a bridge on a ScouterKit connection to simulated arms.
class _Scenario {
  _Scenario(this.async, this.settings, this.seed) : rnd = Random(seed) {
    arms = FakeArms();
    g1 = ScouterConnection.fake(arms.write, font: loadTestFont(), mtu: 247);
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

  /// The arrows the bridge handed to the glasses (their words), and the
  /// one of the step just shown: coming closer, or at the turn its swing.
  final _arrows = <String>{};
  String? _arrowShown;

  /// The arrow's words for [update] as the step is shown now.
  String _arrowFor(NavUpdate update) =>
      (bridge.navigation.atTurn
              ? TurnArrow.at(update.turn)
              : TurnArrow.approach(update.meters))
          .data()
          .join(',');

  /// A navigation step (null: it ends) the way the phone sends it.
  void navigate(NavUpdate? update) {
    final changes = _screenChanges;
    run(() => bridge.onNavigation(update));
    final card = bridge.navigation.cardText;
    if (update != null && card.isNotEmpty) _navCards.add(card);
    final arrow =
        update != null && settings.forwardNavigation && settings.navigationArrow
        ? _arrowFor(update)
        : null;
    if (arrow != null) _arrows.add(arrow);
    if (update != null &&
        _screenChanges > changes &&
        bridge.display.screen.value == card) {
      _arrowWanted = settings.navigationArrow;
      _arrowShown = arrow;
    }
  }

  /// One step of a drive towards a turn: the same instruction ever nearer
  /// (500, 200, 50 m and right at the turn), then the next turn.
  int _drive = 0;
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
    'arrow setting': () => settings.navigationArrow = !settings.navigationArrow,
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
        // Above that text and on the panel, in every frame.
        expect(
          arrowProblems(arms.arenas[side]!, textTop: ScouterConnection.textTop),
          isEmpty,
          reason: why('${side.code}: the arrow\'s words'),
        );
        // The words of an arrow the bridge handed over, never another's.
        final words = arms.arenas[side]!.sublist(
          SkResident.arrowData,
          SkResident.arrowData +
              TurnArrow.segmentsAt +
              20 * word(side, SkW.at(SkResident.arrowData)),
        );
        expect(
          _arrows.contains(words.join(',')),
          isTrue,
          reason: why('${side.code}: arrow of no step'),
        );
      }
      // A step just shown: its arrow with the setting on, its icon without.
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
              '(${bridge.navigation.atTurn ? 'at the turn' : 'coming closer'}'
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
};

/// The public methods of the connection's interface and of ScouterKit's.
Set<String> _connectionMethods() {
  final names = <String>{};
  final method = RegExp(
    r'^  (?:static )?(?:Future<[^ ]+>|Stream<[^ ]+>|void|bool|int|String|'
    r'[A-Z][A-Za-z<>?, ]*) ([a-z][A-Za-z0-9]*)\(',
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

  test('a navigation step shows its arrow until it closes', () {
    fakeAsync((async) {
      final s = _Scenario(async, settings, 0)..setUp();
      int arrow(G1Side side) => s.word(side, SkResident.arrowOn);
      final step = NavUpdate(
        title: '200 m',
        text: 'Turn right onto Main St',
        subText: '14:32',
      );
      s.navigate(step);
      s.wait(const Duration(seconds: 1));
      s.check('navigation');
      for (final side in G1Side.values) {
        expect(arrow(side), 1, reason: '${side.code}: the step\'s arrow');
      }
      // The step closes by itself: the arrow with it.
      s.wait(Bridge.navigationDuration);
      s.check('closed');
      expect(s.bridge.display.active, isFalse);
      for (final side in G1Side.values) {
        expect(arrow(side), 0, reason: '${side.code}: closed');
      }
      // Silent mode: no step on the glasses, no arrow.
      s.run(() => s.bridge.setSilentMode(true));
      s.wait(const Duration(seconds: 3));
      s.navigate(
        NavUpdate(title: '40 m', text: 'Links abbiegen', subText: '14:33'),
      );
      s.wait(const Duration(seconds: 1));
      s.check('silent navigation');
      for (final side in G1Side.values) {
        expect(arrow(side), 0, reason: '${side.code}: silent mode');
      }
      s.dispose();
    });
  });

  test('a drive: the arrow comes closer, then swings into the turn', () {
    fakeAsync((async) {
      final s = _Scenario(async, settings, 0)..setUp();
      Uint8List words(G1Side side, TurnArrow a) => s.arms.arenas[side]!.sublist(
        SkResident.arrowData,
        SkResident.arrowData + a.data().length,
      );
      for (final (m, atTurn) in [
        (700, false),
        (480, false),
        (190, false),
        (45, false),
        (20, true),
      ]) {
        s.steps.add('$m m');
        s.navigate(
          NavUpdate(
            title: '$m m',
            text: 'Links abbiegen auf Ulmenweg',
            subText: '14:32',
          ),
        );
        s.wait(const Duration(milliseconds: 500));
        s.check('$m m');
        expect(s.bridge.navigation.atTurn, atTurn, reason: '$m m');
        final want = atTurn
            ? TurnArrow.at(NavTurn.left)
            : TurnArrow.approach(m);
        for (final side in G1Side.values) {
          expect(
            s.word(side, SkResident.arrowOn),
            1,
            reason: '${side.code} $m m',
          );
          expect(words(side, want), want.data(), reason: '${side.code} $m m');
        }
      }
      // Past the turn: no step shown again, the swing stays.
      s.navigate(
        NavUpdate(
          title: '5 m',
          text: 'Links abbiegen auf Ulmenweg',
          subText: '14:32',
        ),
      );
      s.wait(const Duration(milliseconds: 500));
      final swing = TurnArrow.at(NavTurn.left);
      for (final side in G1Side.values) {
        expect(words(side, swing), swing.data(), reason: side.code);
      }
      // The arrow switched off: the next step with its icon.
      s.settings.navigationArrow = false;
      s.navigate(
        NavUpdate(title: '300 m', text: 'Rechts abbiegen', subText: '14:32'),
      );
      s.wait(const Duration(milliseconds: 500));
      s.check('arrow off');
      for (final side in G1Side.values) {
        expect(s.word(side, SkResident.arrowOn), 0, reason: side.code);
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
