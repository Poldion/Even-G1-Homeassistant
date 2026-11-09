import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'g1_connection.dart';
import 'protocol.dart';

/// Shows (multi page) texts on the glasses with automatic and manual paging.
class G1Display {
  G1Display(this.g1);

  final G1Connection g1;

  /// Time each screen is shown before automatically flipping to the next one.
  Duration pageInterval = const Duration(seconds: 6);

  List<String> _screens = const [];
  int _page = 0;
  bool _manual = false;
  bool _active = false;
  int _generation = 0;
  Duration? _closeAfter;
  Timer? _pageTimer;
  Timer? _closeTimer;

  bool get active => _active;

  /// The pages of the current text (tests).
  @visibleForTesting
  List<String> get debugScreens => _screens;

  /// Screen currently shown by the app on the glasses (null = nothing / the
  /// glasses' own content). Used for the preview in the app.
  final ValueNotifier<String?> screen = ValueNotifier(null);

  /// Page position for the preview, e.g. "2/3" (empty for single pages).
  String get pageLabel =>
      _screens.length > 1 ? '${_page + 1}/${_screens.length}' : '';

  /// Shows a text. [closeAfter] switches the display off after the last
  /// page was shown for that long (null or zero: stay until dismissed).
  Future<bool> showText(
    String text, {
    Duration? closeAfter,
    String? icon,
    G1TextStyle style = G1TextStyle.plain,
    String? pageTitle,
    String? label,
  }) async {
    _reset();
    _label = label;
    _active = true;
    _icon = icon;
    _style = style;
    _closeAfter = (closeAfter == null || closeAfter == Duration.zero)
        ? null
        : closeAfter;
    final generation = _generation;
    var screens = await g1.layoutPages(text, icon: icon);
    if (generation != _generation) return false;
    if (pageTitle != null) screens = _withTitle(screens, pageTitle);
    _screens = screens;

    final ok = await _showPage(generation);
    if (generation != _generation) return ok;

    if (_screens.length > 1) {
      _pageTimer = Timer.periodic(pageInterval, (timer) async {
        if (_manual || _page >= _screens.length - 1) {
          timer.cancel();
          return;
        }
        _page++;
        await _showPage(generation);
        if (_page >= _screens.length - 1) {
          timer.cancel();
          _scheduleClose();
        }
      });
    } else {
      _scheduleClose();
    }
    return ok;
  }

  /// Short status line during Assist (e.g. "Ich höre zu …"), in a frame.
  Future<bool> showAiStatus(String text) => showText(
    text,
    style: labDesign ? G1TextStyle.labBadge : G1TextStyle.badge,
  );

  /// The lab design set for the Assist status (set by Home Assistant).
  bool labDesign = false;

  /// Assist answer with automatic paging; in the lab design set a terminal
  /// window titled [assistant].
  Future<bool> showAiAnswer(
    String text, {
    Duration? closeAfter,
    String? assistant,
  }) => showText(
    text,
    closeAfter: closeAfter,
    style: labDesign ? G1TextStyle.labTerminal : G1TextStyle.plain,
    pageTitle: labDesign ? (assistant ?? 'Home Assistant') : null,
  );

  /// [pages] again with [title] as the first line of each (one line less
  /// per page), "title  2/3" with several pages.
  List<String> _withTitle(List<String> pages, String title) {
    final lines = [for (final p in pages) ...p.split('\n')];
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    final per = max(1, g1.displayLines - 1);
    final n = max(1, (lines.length + per - 1) ~/ per);
    return [
      for (var i = 0; i < n; i++)
        [
          n > 1 ? '$title  ${i + 1}/$n' : title,
          ...lines.skip(i * per).take(per),
        ].join('\n'),
    ];
  }

  /// App icon of the notification on the display.
  String? _icon;
  G1TextStyle _style = G1TextStyle.plain;
  String? _label;

  /// Error message that closes itself after a few seconds.
  Future<bool> showAiError(String text) =>
      showText(text, closeAfter: const Duration(seconds: 5));

  /// Switches the display off.
  Future<bool> clear() async {
    _reset();
    return showIdle();
  }

  /// Empties the display (the panels switch off).
  Future<bool> showIdle() async {
    screen.value = null;
    return g1.blankScreen();
  }

  /// The glasses left the text view on their own (double tap).
  void onDismissed() => _reset();

  /// Single tap on a touch bar: left = previous page, right = next page.
  Future<void> onTap(G1Side side) async {
    if (!_active || _screens.length < 2) return;
    _manual = true;
    _pageTimer?.cancel();
    final next = side == G1Side.left ? _page - 1 : _page + 1;
    final page = next.clamp(0, _screens.length - 1);
    if (page == _page) return;
    _page = page;
    await _showPage(_generation);
    _scheduleClose();
  }

  Future<bool> _showPage(int generation) async {
    if (generation != _generation || !g1.connected) return false;
    screen.value = _screens[_page];
    return g1.sendText(
      _screens[_page],
      icon: _icon,
      style: _style,
      label: _label,
    );
  }

  void _scheduleClose() {
    final after = _closeAfter;
    if (after == null) return;
    _closeTimer?.cancel();
    final generation = _generation;
    _closeTimer = Timer(after, () async {
      if (generation != _generation) return;
      _reset();
      await showIdle();
    });
  }

  void _reset() {
    _generation++;
    _pageTimer?.cancel();
    _closeTimer?.cancel();
    _pageTimer = null;
    _closeTimer = null;
    _page = 0;
    _manual = false;
    _active = false;
    _closeAfter = null;
    _style = G1TextStyle.plain;
    screen.value = null;
  }
}
