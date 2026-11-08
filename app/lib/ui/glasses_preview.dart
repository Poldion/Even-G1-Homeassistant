import 'package:flutter/material.dart';

import '../g1/display.dart';
import '../l10n/l10n.dart';

/// Shows what the app currently displays on the glasses: green text on a
/// dark lens, in the proportions of the display (640×480).
class GlassesPreview extends StatelessWidget {
  const GlassesPreview({super.key, required this.display});

  final G1Display display;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: display.screen,
      builder: (context, text, _) {
        return AspectRatio(
          aspectRatio: 640 / 480,
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
                  alignment: Alignment.topLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: Text(
                      text?.trimRight() ?? tr.uiPreviewEmpty,
                      style: TextStyle(
                        color: text == null
                            ? const Color(0xFF3F6B3F)
                            : const Color(0xFF6CFF6C),
                        fontSize: 15,
                        height: 1.25,
                        fontFamily: 'monospace',
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
