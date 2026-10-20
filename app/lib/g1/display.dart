import 'dart:async';

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

  /// Shows a text. [closeAfter] returns to the dashboard after the last page
  /// was shown for that long (null or zero: stay until dismissed).
  Future<bool> showText(String text, {Duration? closeAfter}) async {
    _reset();
    _active = true;
    _closeAfter = (closeAfter == null || closeAfter == Duration.zero)
        ? null
        : closeAfter;
    _screens = G1TextLayout.screens(G1TextLayout.lines(text));
    final generation = _generation;

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

  /// Short status line during Assist (e.g. "Ich höre zu …").
  Future<bool> showAiStatus(String text) => showText(text);

  /// Assist answer with automatic paging.
  Future<bool> showAiAnswer(String text, {Duration? closeAfter}) =>
      showText(text, closeAfter: closeAfter);

  /// Error message that closes itself after a few seconds.
  Future<bool> showAiError(String text) =>
      showText(text, closeAfter: const Duration(seconds: 5));

  /// Returns to the dashboard.
  Future<bool> clear() async {
    _reset();
    return g1.exitToDashboard();
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
    return g1.sendText(_screens[_page]);
  }

  void _scheduleClose() {
    final after = _closeAfter;
    if (after == null) return;
    _closeTimer?.cancel();
    final generation = _generation;
    _closeTimer = Timer(after, () async {
      if (generation != _generation) return;
      _reset();
      await g1.exitToDashboard();
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
  }
}
