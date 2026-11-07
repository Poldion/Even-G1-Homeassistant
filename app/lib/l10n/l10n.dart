import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// The app's texts in the chosen language, also outside of widgets (texts
/// on the glasses, log lines, notifications).
///
/// English is the main language; German if chosen or, with "system", if the
/// phone is set to German.
class L10n {
  static const supported = [Locale('en'), Locale('de')];

  /// The language setting: "system", "en" or "de".
  static String _setting = 'system';
  static AppLocalizations _current = lookupAppLocalizations(const Locale('en'));

  /// The locale in use; widgets rebuild when it changes.
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  static String get setting => _setting;

  /// Applies the language setting ("system", "en" or "de").
  static void apply(String? setting, {Locale? system}) {
    _setting = setting == 'en' || setting == 'de' ? setting! : 'system';
    final phone = system ?? PlatformDispatcher.instance.locale;
    final code = _setting == 'system'
        ? (phone.languageCode == 'de' ? 'de' : 'en')
        : _setting;
    _current = lookupAppLocalizations(Locale(code));
    locale.value = Locale(code);
  }

  /// The phone's own language, if the app supports it ("en" otherwise).
  static String get systemCode =>
      PlatformDispatcher.instance.locale.languageCode == 'de' ? 'de' : 'en';
}

/// The texts in the current language.
AppLocalizations get tr => L10n._current;
