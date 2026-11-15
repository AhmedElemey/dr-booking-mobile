import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/config/brand_l10n.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/enum_labels.dart';
import '../../appointments/presentation/appointment_extras.dart';
import '../../clinic_config/presentation/features_controller.dart';
import 'booking_providers.dart';
import 'calendar_link.dart';

/// Shown right after `POST /appointments` succeeds; reads local state only.
class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final appointment = ref.watch(lastBookingProvider);
    final features = ref.watch(featuresProvider);
    if (appointment == null) return const Scaffold();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.check_circle,
              size: 88,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.bookingConfirmedTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.bookingConfirmedSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctor.name,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _Line(
                      icon: Icons.event,
                      text: ClinicTime.date(appointment.startsAtLocal, locale),
                    ),
                    _Line(
                      icon: Icons.schedule,
                      text: ClinicTime.time(appointment.startsAtLocal, locale),
                    ),
                    _Line(
                      icon: Icons.local_hospital_outlined,
                      text: appointment.clinic.name,
                    ),
                    if ((appointment.clinic.address ?? '').isNotEmpty)
                      _Line(
                        icon: Icons.place_outlined,
                        text: appointment.clinic.address!,
                      ),
                    if (features.familyAccounts &&
                        appointment.familyMember != null)
                      _Line(
                        icon: Icons.family_restroom_outlined,
                        text: l10n.forPersonLabel(appointment.familyMember!),
                      ),
                    if (features.videoConsultation && appointment.isVideo)
                      _Line(
                        icon: Icons.videocam_outlined,
                        text: l10n.videoVisit,
                      ),
                    if (!features.onlinePayments && !features.promotions)
                      _Line(
                        icon: Icons.payments_outlined,
                        text: l10n.payAtClinic,
                      ),
                  ],
                ),
              ),
            ),
            if (features.onlinePayments || features.promotions) ...[
              const SizedBox(height: 12),
              PriceCard(appointment: appointment),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('addToCalendar'),
              onPressed: () => launchUrl(
                calendarUri(appointment, title: l10n.brandName),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(l10n.addToCalendar),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('viewAppointments'),
              onPressed: () => context.go('/appointments'),
              child: Text(l10n.viewMyAppointments),
            ),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(l10n.backToHome),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
