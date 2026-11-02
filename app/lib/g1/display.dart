import 'dart:async';

import 'package:flutter/foundation.dart';

import 'g1_connection.dart';
import 'protocol.dart';
import 'text_layout.dart';

/// Shows (multi page) texts on the glasses with automatic and manual paging.
///
/// Everything (Home Assistant texts, Assist status and answers) is sent in
/// the plain text mode of the glasses; the app does the paging itself.
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

  /// Screen currently shown by the app on the glasses (null = nothing / the
  /// glasses' own content). Used for the preview in the app.
  final ValueNotifier<String?> screen = ValueNotifier(null);

  /// Page position for the preview, e.g. "2/3" (empty for single pages).
  String get pageLabel =>
      _screens.length > 1 ? '${_page + 1}/${_screens.length}' : '';

  /// Shows a text. [closeAfter] returns to the dashboard after the last page
  /// was shown for that long (null or zero: stay until dismissed).
  Future<bool> showText(
    String text, {
    Duration? closeAfter,
    bool evenAi = false,
  }) async {
    _reset();
    _active = true;
    _evenAi = evenAi;
    _closeAfter = (closeAfter == null || closeAfter == Duration.zero)
        ? null
        : closeAfter;
    _screens = G1TextLayout.screens(G1TextLayout.lines(text));
    final generation = _generation;

    final ok = await _showPage(generation);
    if (generation != _generation) return ok;
    if (!evenAi && verifyBothArms) {
      unawaited(_verifyBothArms(generation, _page));
    }

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
      if (evenAi) {
        // Like the official app: 0x30 first, 0x40 after a moment.
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (generation == _generation) _showPage(generation, last: true);
        });
      }
      _scheduleClose();
    }
    return ok;
  }

  /// Short status line during Assist (e.g. "Ich höre zu …").
  Future<bool> showAiStatus(String text) =>
      showText(text, evenAi: evenAiAnswers);

  /// Assist answer with automatic paging.
  Future<bool> showAiAnswer(String text, {Duration? closeAfter}) =>
      showText(text, closeAfter: closeAfter, evenAi: evenAiAnswers);

  /// Experimental: show Assist status and answers with the Even AI statuses
  /// of the official app (0x31 displaying, 0x41 last page) instead of the
  /// plain text mode. The firmware drives its Even AI screen on both arms
  /// itself in that mode.
  bool evenAiAnswers = false;
  bool _evenAi = false;

  /// Error message that closes itself after a few seconds.
  Future<bool> showAiError(String text) =>
      showText(text, closeAfter: const Duration(seconds: 5));

  /// Returns to the dashboard.
  Future<bool> clear() async {
    _reset();
    return showIdle();
  }

  /// Shown when nothing else is on the display (e.g. the recording dot),
  /// sent as is without layout so leading spaces are kept.
  String? idleText;

  /// Shows [idleText] or empties the display.
  Future<bool> showIdle() {
    final idle = idleText;
    screen.value = null;
    return idle == null ? g1.blankScreen() : g1.sendText(idle);
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

  Future<bool> _showPage(int generation, {bool last = false}) async {
    if (generation != _generation || !g1.connected) return false;
    screen.value = _screens[_page];
    if (!_evenAi) return g1.sendText(_screens[_page]);
    final isLast =
        last || (_screens.length > 1 && _page == _screens.length - 1);
    final status = _manual
        ? G1ScreenStatus.aiManual
        : isLast
        ? G1ScreenStatus.aiComplete
        : G1ScreenStatus.aiDisplaying;
    return g1.sendText(
      _screens[_page],
      status: status | G1ScreenStatus.newContent,
      page: _page + 1,
      pages: _screens.length,
    );
  }

  /// Check after showing a text that both arms display it and send it again
  /// to an arm that does not (e.g. the left arm while the glasses handle the
  /// head up movement).
  bool verifyBothArms = true;
  static const verifyDelay = Duration(milliseconds: 400);

  /// Screen id (0x39) of the text surface used by 0x4E (even-g1-companion).
  static const _textScreen = 0x10;

  Future<void> _verifyBothArms(int generation, int page) async {
    await Future<void>.delayed(verifyDelay);
    for (final side in G1Side.values) {
      if (generation != _generation || page != _page || !g1.connected) return;
      final id = await g1.readScreenState(side);
      if (id == null || id == _textScreen) continue;
      if (generation != _generation || page != _page) return;
      g1.note(
        'Anzeige ${side == G1Side.left ? 'links' : 'rechts'} fehlte '
        '(${screenName(id)}) – erneut gesendet',
      );
      await g1.sendText(
        _screens[_page],
        left: side == G1Side.left,
        right: side == G1Side.right,
      );
    }
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
    _evenAi = false;
    screen.value = null;
  }
}
