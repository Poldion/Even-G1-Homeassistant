import 'package:even_g1_ha/scouter/scouter_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the logarithmic curve: the same step for every tenfold light', () {
    int at(double lux) => ScouterConnection.logLevel((lux * 100).round());
    expect(at(1), 4);
    expect(at(10), 13);
    expect(at(100), 22);
    expect(at(1000), 31);
    expect(at(10000), 40);
    // Darker than about a third of a lux: below 0 (clamped to 0 later).
    expect(at(0.1), lessThan(0));
    // Rising all the way.
    var last = -100;
    for (var light = 1; light < 10000000; light = light * 11 ~/ 10 + 1) {
      final l = ScouterConnection.logLevel(light);
      expect(l, greaterThanOrEqualTo(last));
      last = l;
    }
  });

  test('the original table stays as it was', () {
    expect(ScouterConnection.stockLevel(30), 6);
    expect(ScouterConnection.stockLevel(100), 15);
    expect(ScouterConnection.stockLevel(1500), 41);
  });
}
