import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/brand_l10n.dart';
import 'core/config/env.dart';
import 'core/config/env_provider.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/clinic_config/presentation/features_controller.dart';

class MoonlightApp extends ConsumerStatefulWidget {
  const MoonlightApp({super.key});

  @override
  ConsumerState<MoonlightApp> createState() => _MoonlightAppState();
}

class _MoonlightAppState extends ConsumerState<MoonlightApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The clinic may have switched features while the app was in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(featuresProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = ref.watch(envProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).brandName,
      debugShowCheckedModeBanner: env.flavor == AppFlavor.dev,
      theme: buildTheme(),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
