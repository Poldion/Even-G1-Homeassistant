import 'package:even_g1_ha/bridge.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_glasses.dart';

void main() {
  test('the log report has a header and every line, oldest first', () async {
    SharedPreferences.setMockInitialValues({});
    final bridge = Bridge(await Settings.load(), g1: FakeGlasses());
    bridge.logLines
      ..clear()
      ..addAll(List.generate(500, (i) => 'line $i'));
    final report = bridge.logReport(appVersion: '0.53.2').split('\n');
    expect(report.first, 'Even G1 HA 0.53.2');
    expect(report, contains('line 0'));
    expect(report.last, 'line 499');
    expect(report.indexOf('line 0'), lessThan(report.indexOf('line 1')));
  });
}
