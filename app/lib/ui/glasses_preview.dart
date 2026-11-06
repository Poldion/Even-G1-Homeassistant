import 'package:flutter/material.dart';

import '../g1/display.dart';

/// Shows what the app currently displays on the glasses: green text on a
/// dark lens, roughly in the proportions of the display (Even's text view
/// 640×200 px of which ~488 px hold text; ScouterKit the whole 640×480).
class GlassesPreview extends StatelessWidget {
  const GlassesPreview({super.key, required this.display});

  final G1Display display;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: display.screen,
      builder: (context, text, _) {
        final fullPanel = !display.g1.evenFirmware;
        return AspectRatio(
          aspectRatio: fullPanel ? 640 / 480 : 640 / 200,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF050805),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E2A1E)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Stack(
              children: [
                Align(
                  alignment: fullPanel
                      ? Alignment.topLeft
                      : Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: fullPanel
                        ? Alignment.topLeft
                        : Alignment.centerLeft,
                    child: Text(
                      text?.trimRight() ??
                          'Keine Anzeige der App\n(die Brille zeigt ggf. '
                              'ihre eigene Oberfläche)',
                      style: TextStyle(
                        color: text == null
                            ? const Color(0xFF3F6B3F)
                            : const Color(0xFF6CFF6C),
                        fontSize: 15,
                        height: 1.25,
                        fontFamily: fullPanel ? 'monospace' : null,
                      ),
                    ),
                  ),
                ),
                if (text != null && display.pageLabel.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      display.pageLabel,
                      style: const TextStyle(
                        color: Color(0xFF3F6B3F),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
