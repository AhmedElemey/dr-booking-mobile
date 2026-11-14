import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/brand.g.dart';
import '../../../core/config/brand_l10n.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import 'features_controller.dart';

/// Shown instead of the whole app when the clinic has turned the mobile app off.
class AppUnavailableScreen extends ConsumerWidget {
  const AppUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.phonelink_off_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.appUnavailableTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.appUnavailableBody(l10n.brandName, Brand.websiteDomain),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                key: const Key('callClinicUnavailable'),
                onPressed: () =>
                    launchUrl(Uri(scheme: 'tel', path: Brand.supportPhone)),
                icon: const Icon(Icons.call_outlined),
                label: Text(l10n.callClinic),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('retryFeatures'),
                onPressed: () => ref.read(featuresProvider.notifier).refresh(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Call the clinic to change this appointment", for when online changes are off.
class CallToChangeNotice extends StatelessWidget {
  const CallToChangeNotice({super.key, required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: const Key('callToChange'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.callToChangeAppointment),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('callToChangeButton'),
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              icon: const Icon(Icons.call_outlined),
              label: Text(l10n.callClinic),
            ),
          ],
        ),
      ),
    );
  }
}
