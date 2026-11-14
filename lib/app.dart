import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/config/env_provider.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';

class MoonlightApp extends ConsumerWidget {
  const MoonlightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(envProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: env.flavor == AppFlavor.dev,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5)),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
