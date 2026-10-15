import 'dart:async';

import 'g1_connection.dart';
import 'protocol.dart';
import 'text_layout.dart';

enum _Mode { text, ai }

/// Shows (multi page) texts on the glasses with automatic and manual paging.
class G1Display {
  G1Display(this.g1);

  final G1Connection g1;

  /// Time each screen is shown before automatically flipping to the next one.
  Duration pageInterval = const Duration(seconds: 6);

  List<String> _screens = const [];
  int _page = 0;
  _Mode _mode = _Mode.text;
  bool _manual = false;
  bool _active = false;
  int _generation = 0;
  Duration? _closeAfter;
  Timer? _pageTimer;
  Timer? _closeTimer;

  bool get active => _active;

  /// Shows a full screen text. [closeAfter] returns to the dashboard after the
  /// last page was shown for that long (null or zero: stay until dismissed).
  Future<bool> showText(String text, {Duration? closeAfter}) {
    return _start(text, _Mode.text, closeAfter);
  }

  /// Shows an Even AI style status line (e.g. "Ich höre zu…").
  Future<bool> showAiStatus(String text) async {
    _reset();
    _active = true;
    _mode = _Mode.ai;
    _screens = G1TextLayout.screens(G1TextLayout.lines(text));
    final generation = _generation;
    return _send(generation, _screens.first, G1ScreenStatus.aiDisplaying, 1, 1);
  }

  /// Shows an assistant answer with automatic paging.
  Future<bool> showAiAnswer(String text, {Duration? closeAfter}) {
    return _start(text, _Mode.ai, closeAfter);
  }

  /// Shows an error in the Even AI view.
  Future<bool> showAiError(String text) async {
    _reset();
    _active = true;
    _mode = _Mode.ai;
    _screens = G1TextLayout.screens(G1TextLayout.lines(text));
    final ok = await _send(
      _generation,
      _screens.first,
      G1ScreenStatus.aiNetworkError,
      1,
      1,
    );
    _scheduleClose(const Duration(seconds: 5));
    return ok;
  }

  /// Returns to the dashboard.
  Future<bool> clear() async {
    _reset();
    return g1.exitToDashboard();
  }

  /// The glasses left the text view on their own (double tap).
  void onDismissed() => _reset();

  /// Single tap on a touch bar: left = previous page, right = next page.
  Future<void> onTap(G1Side side) async {
    if (!_active) return;
    _manual = true;
    _pageTimer?.cancel();
    final next = side == G1Side.left ? _page - 1 : _page + 1;
    _page = next.clamp(0, _screens.length - 1);
    await _showPage(_generation);
    if (_closeAfter != null) _scheduleClose(_closeAfter!);
  }

  Future<bool> _start(String text, _Mode mode, Duration? closeAfter) async {
    _reset();
    _active = true;
    _mode = mode;
    _closeAfter = (closeAfter == null || closeAfter == Duration.zero)
        ? null
        : closeAfter;
    _screens = G1TextLayout.screens(G1TextLayout.lines(text));
    final generation = _generation;

    final ok = await _showPage(generation);
    if (!ok || generation != _generation) return ok;

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
          if (_closeAfter != null) _scheduleClose(_closeAfter!);
        }
      });
    } else {
      if (mode == _Mode.ai) {
        // The glasses need a 0x30 screen before they accept 0x40.
        await Future<void>.delayed(const Duration(seconds: 3));
        if (generation == _generation && !_manual) {
          await _send(
            generation,
            _screens.first,
            G1ScreenStatus.aiComplete,
            1,
            1,
          );
        }
      }
      if (_closeAfter != null) _scheduleClose(_closeAfter!);
    }
    return ok;
  }

  Future<bool> _showPage(int generation) {
    final last = _page >= _screens.length - 1;
    final int status;
    if (_mode == _Mode.text) {
      status = G1ScreenStatus.textShow;
    } else if (_manual) {
      status = G1ScreenStatus.aiManual;
    } else if (last && _screens.length > 1) {
      status = G1ScreenStatus.aiComplete;
    } else {
      status = G1ScreenStatus.aiDisplaying;
    }
    return _send(
      generation,
      _screens[_page],
      status,
      _page + 1,
      _screens.length,
    );
  }

  Future<bool> _send(
    int generation,
    String text,
    int status,
    int page,
    int pages,
  ) async {
    if (generation != _generation || !g1.connected) return false;
    return g1.sendText(
      text,
      newScreen: status | G1ScreenStatus.newContent,
      currentPage: page,
      maxPage: pages,
    );
  }

  void _scheduleClose(Duration after) {
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
