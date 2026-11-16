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

import 'dart:math';
import 'dart:typed_data';

import 'package:even_g1_ha/bridge.dart';
import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:even_g1_ha/scouter/sk_asm.dart';
import 'package:even_g1_ha/scouter/sk_clock.dart';
import 'package:even_g1_ha/scouter/sk_program.dart';
import 'package:even_g1_ha/scouter/sk_protocol.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final wanted =
          bridge.haConfig.dashboardOnHeadUp && bridge.silentMode != true;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Settings settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await Settings.load();
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
