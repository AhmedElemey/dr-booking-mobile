import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/clinic_config/presentation/features_controller.dart';
import '../storage/local_settings.dart';

/// The app's current language. Arabic first; layout direction follows the locale.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    // Clinics without English get Arabic whatever was chosen before.
    final english = ref.watch(
      featuresProvider.select((f) => f.englishLanguage),
    );
    if (!english) return const Locale('ar');
    return Locale(ref.read(localSettingsProvider).languageCode ?? 'ar');
  }

  /// Switches language and remembers the choice across launches.
  Future<void> setLanguage(String code) async {
    if (!ref.read(featuresProvider).englishLanguage) code = 'ar';
    state = Locale(code);
    await ref.read(localSettingsProvider).setLanguageCode(code);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
