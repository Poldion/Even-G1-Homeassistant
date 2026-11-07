import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:even_g1_ha/bridge.dart';
import 'package:even_g1_ha/g1/g1_connection.dart';
import 'package:even_g1_ha/g1/protocol.dart';
import 'package:even_g1_ha/l10n/l10n.dart';
import 'package:even_g1_ha/main.dart';
import 'package:even_g1_ha/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Renders the main screens. With SCREENSHOT_DIR set, real fonts are loaded
// and PNGs are written there for a visual check.
final _shotDir = Platform.environment['SCREENSHOT_DIR'];

Future<void> _loadFonts() async {
  final fonts = Platform.environment['FLUTTER_FONTS'];
  if (fonts == null) return;
  Future<ByteData> read(String f) async =>
      ByteData.sublistView(File('$fonts/$f').readAsBytesSync());
  await (FontLoader('Roboto')..addFont(read('Roboto-Regular.ttf'))).load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('MaterialIcons-Regular.otf'))).load();
}

final _boundary = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  if (_shotDir == null) return;
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ImageByteFormat.png);
    File('$_shotDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('overview and settings tabs build', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      'left_id': 'L',
      'right_id': 'R',
      'glasses_name': 'G1 #45',
      'show_preview': true,
      // The screens in German (the texts below); English is the default.
      'language': 'de',
    });
    final settings = await Settings.load();
    L10n.apply(settings.language);
    // Simulated, connected glasses that report battery and case status.
    final g1 = G1Connection.fake((side, data) async {});
    for (final (side, data) in [
      (G1Side.left, [0xF5, 0x0A, 84]),
      (G1Side.right, [0xF5, 0x0A, 81]),
      (G1Side.right, [0xF5, 0x0F, 62]),
      (G1Side.right, [0xF5, 0x0E, 1]),
      (G1Side.right, [0xF5, 0x06]),
    ]) {
      g1.receive(side, Uint8List.fromList(data));
    }
    final bridge = Bridge(settings, g1: g1);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: EvenG1App(bridge: bridge),
      ),
    );
    await tester.pump();
    // Without Home Assistant the app opens on the settings tab.
    await tester.tap(find.text('Übersicht'));
    await tester.pumpAndSettle();
    expect(find.text('84 %'), findsOneWidget);
    expect(find.text('62 %'), findsOneWidget);
    expect(find.text('Getragen'), findsOneWidget);
    unawaited(bridge.display.showText('Wohnzimmer 21,5 °C\nHaustür zu'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Übersicht'), findsOneWidget);
    expect(find.text('Ruhemodus'), findsOneWidget);
    expect(find.text('Vorschau der Brillenanzeige'), findsOneWidget);
    await _shot(tester, 'overview');

    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();
    expect(find.text('Anzeige & Aktivierung'), findsOneWidget);
    await tester.tap(find.text('Anzeige & Aktivierung'));
    await tester.pumpAndSettle();
    expect(find.text('Aktivierungswinkel'), findsOneWidget);
    await _shot(tester, 'settings');
    bridge.display.onDismissed();
    await tester.pump(const Duration(seconds: 1));
  });
}
