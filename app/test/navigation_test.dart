import 'package:even_g1_ha/bridge.dart';
import 'package:even_g1_ha/navigation/navigation.dart';
import 'package:even_g1_ha/scouter/sk_icons.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_glasses.dart';

NavUpdate step(String title, String text, [String sub = '']) =>
    NavUpdate(title: title, text: text, subText: sub);

void main() {
  test('distance and instruction from the notification', () {
    final u = step(
      '200 m',
      'Rechts abbiegen auf Hauptstraße',
      '12 min · 14:32',
    );
    expect(u.distance, '200 m');
    expect(u.meters, 200);
    expect(u.instruction, 'Rechts abbiegen auf Hauptstraße');
    expect(u.turn, NavTurn.right);
    expect(step('1,2 km', 'Weiter auf B27').meters, 1200);
    expect(step('In 500 ft', 'Turn left onto Main St').meters, 152);
    expect(
      step('In 500 ft', 'Turn left onto Main St').instruction,
      'Turn left onto Main St',
    );
    expect(step('Turn left · 0.3 mi', '').meters, 483);
    expect(step('Turn left · 0.3 mi', '').instruction, 'Turn left');
    expect(step('Head north', 'toward Elm St').meters, isNull);
  });

  test('turns in English and German', () {
    expect(NavTurn.of('Turn right onto Main St'), NavTurn.right);
    expect(NavTurn.of('Links abbiegen'), NavTurn.left);
    expect(NavTurn.of('Leicht rechts halten'), NavTurn.slightRight);
    expect(NavTurn.of('Keep left at the fork'), NavTurn.slightLeft);
    expect(NavTurn.of('Scharf links abbiegen'), NavTurn.sharpLeft);
    expect(NavTurn.of('Make a U-turn'), NavTurn.uTurn);
    expect(NavTurn.of('Im Kreisverkehr die 2. Ausfahrt'), NavTurn.roundabout);
    expect(NavTurn.of('Take exit 12'), NavTurn.slightRight);
    expect(NavTurn.of('Ziel erreicht'), NavTurn.destination);
    expect(NavTurn.of('Weiter auf B27'), NavTurn.straight);
  });

  test('every turn has an arrow', () {
    for (final t in NavTurn.values) {
      final icon = NavArrow.icon(t);
      expect(icon.length, SkIcons.bytes);
      expect(icon.where((b) => b != 0).length, greaterThan(40), reason: '$t');
      expect(t.emoji, isNotEmpty);
    }
  });

  test('shown at a new step and at 500, 200 and 50 m', () {
    final nav = Navigation();
    final shown = [
      for (final m in [800, 600, 480, 300, 190, 120, 45, 30])
        nav.update(step('$m m', 'Turn right onto Main St')),
    ];
    expect(shown, [true, false, true, false, true, false, true, false]);
    // The next step, already near 200 m: that mark counts as shown.
    expect(nav.update(step('230 m', 'Turn left onto Elm St')), isTrue);
    expect(nav.update(step('180 m', 'Turn left onto Elm St')), isFalse);
    expect(nav.update(step('40 m', 'Turn left onto Elm St')), isTrue);
    expect(nav.dashboardText.split('\n').first, '⬅️ 40 m');
    expect(nav.cardText, '40 m\nTurn left onto Elm St');
  });

  test('the bridge shows steps and the dashboard follows', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final g1 = FakeGlasses();
    final bridge = Bridge(settings, g1: g1);
    await bridge.onNavigation(
      step('300 m', 'Rechts abbiegen auf Hauptstraße', '14:32'),
    );
    expect(g1.texts.last, '300 m\nRechts abbiegen auf Hauptstraße\n14:32');
    expect(g1.icons.last, SkIcons.navigation);
    expect(g1.navigationIcon, hasLength(SkIcons.bytes));
    expect(g1.dashboard?.onHeadUp, isTrue);
    expect(g1.dashboard?.text, startsWith('➡️ 300 m'));
    final count = g1.texts.length;
    await bridge.onNavigation(
      step('280 m', 'Rechts abbiegen auf Hauptstraße', '14:32'),
    );
    expect(g1.texts.length, count);
    expect(g1.dashboard?.text, startsWith('➡️ 280 m'));
    await bridge.onNavigation(null);
    expect(bridge.navigation.active, isFalse);
    expect(g1.navigationIcon, isNull);
    expect(g1.dashboard?.text, isNot(contains('280 m')));
    await bridge.display.clear();
  });
}
