import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/brand_l10n.dart';
import 'core/config/env.dart';
import 'core/config/env_provider.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/clinic_config/presentation/features_controller.dart';
import 'features/payments/presentation/payment_flow.dart';

class MoonlightApp extends ConsumerStatefulWidget {
  const MoonlightApp({super.key});

  @override
  ConsumerState<MoonlightApp> createState() => _MoonlightAppState();
}

class _MoonlightAppState extends ConsumerState<MoonlightApp>
    with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<ForegroundPush>? _foregroundPush;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foregroundPush = ref
        .read(pushServiceProvider)
        .foregroundMessages
        .listen(_showForegroundPush);
  }

  @override
  void dispose() {
    _foregroundPush?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A push that arrives while the app is open is not shown by the system, so
  /// show it as a banner that opens its appointment.
  void _showForegroundPush(ForegroundPush push) {
    final text = push.text;
    final messenger = _messengerKey.currentState;
    if (text == null || messenger == null) return;
    final appointmentId = push.appointmentId;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: appointmentId == null
              ? null
              : SnackBarAction(
                  label: _viewLabel(),
                  onPressed: () => ref
                      .read(routerProvider)
                      .go('/appointments/$appointmentId'),
                ),
        ),
      );
  }

  /// The scaffold messenger sits above the app's localizations, so the label
  /// is looked up from the chosen locale directly.
  String _viewLabel() {
    final chosen = ref.read(localeProvider);
    final locale = AppLocalizations.supportedLocales.firstWhere(
      (supported) => supported.languageCode == chosen.languageCode,
      orElse: () => AppLocalizations.supportedLocales.first,
    );
    return lookupAppLocalizations(locale).pushViewAction;
  }

  /// The clinic may have switched features while the app was in the background,
  /// and a payment started in the browser may have settled (the checkout's
  /// return link does not always reach the app, so it is read back here).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(featuresProvider.notifier).refresh();
      ref.read(paymentFlowProvider.notifier).refreshPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = ref.watch(envProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: _messengerKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).brandName,
      debugShowCheckedModeBanner: env.flavor == AppFlavor.dev,
      theme: buildTheme(),
      builder: (context, child) {
        if (!env.useMockApi || !const bool.fromEnvironment('DESIGN_PREVIEW')) {
          return child ?? const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        return Column(
          children: [
            Material(
              color: scheme.tertiaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    'DESIGN PREVIEW | Synthetic fixtures only | No real bookings or payments',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
