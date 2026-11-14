import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../data/profile_repository.dart';

/// Changes the app language, and tells the server when someone is signed in so
/// notifications arrive in the same language.
Future<void> changeLanguage(WidgetRef ref, String code) async {
  if (ref.read(localeProvider).languageCode == code) return;
  await ref.read(localeProvider.notifier).setLanguage(code);
  if (ref.read(authControllerProvider).value != null) {
    // Best effort: the local choice already applies.
    await ref.read(profileRepositoryProvider).updateMe(preferredLanguage: code);
  }
}

/// App-bar shortcut that flips between Arabic and English.
class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featuresProvider.select((f) => f.englishLanguage))) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    return TextButton(
      key: const Key('switchLanguage'),
      onPressed: () => changeLanguage(ref, isArabic ? 'en' : 'ar'),
      child: Text(l10n.switchLanguage),
    );
  }
}
