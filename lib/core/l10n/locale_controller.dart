import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_settings.dart';

/// The app's current language. Arabic first; layout direction follows the locale.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() =>
      Locale(ref.read(localSettingsProvider).languageCode ?? 'ar');

  /// Switches language and remembers the choice across launches.
  Future<void> setLanguage(String code) async {
    state = Locale(code);
    await ref.read(localSettingsProvider).setLanguageCode(code);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
