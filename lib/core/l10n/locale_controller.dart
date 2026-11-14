import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's current language. Arabic first; layout direction follows the locale.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('ar');

  void toggle() => state = state.languageCode == 'ar'
      ? const Locale('en')
      : const Locale('ar');
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
