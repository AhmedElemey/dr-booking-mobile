import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/locale_controller.dart';

/// First launch: pick Arabic or English (a local setting).
class LanguageSelectScreen extends ConsumerWidget {
  const LanguageSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Future<void> choose(String code) async {
      await ref.read(localeProvider.notifier).setLanguage(code);
      if (context.mounted) context.go('/');
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.nightlight_round,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.chooseLanguageTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.chooseLanguageSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 40),
              FilledButton(
                key: const Key('chooseArabic'),
                onPressed: () => choose('ar'),
                child: const Text('العربية'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('chooseEnglish'),
                onPressed: () => choose('en'),
                child: const Text('English'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
