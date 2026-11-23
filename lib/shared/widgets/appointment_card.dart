import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/clinic_time.dart';
import '../../core/l10n/enum_labels.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../features/appointments/domain/appointment.dart';
import '../../features/clinic_config/presentation/features_controller.dart';
import '../../features/payments/domain/payment.dart';
import 'doctor_avatar.dart';
import 'pill.dart';
import 'status_chip.dart';

class AppointmentCard extends ConsumerWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final features = ref.watch(featuresProvider);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(18),
          child: Row(
            children: [
              DoctorAvatar(
                name: appointment.doctor.name,
                photoUrl: appointment.doctor.photoUrl,
                radius: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctor.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ClinicTime.date(appointment.startsAtLocal, locale),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      ClinicTime.time(appointment.startsAtLocal, locale),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      appointment.clinic.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (features.familyAccounts &&
                        appointment.familyMember != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        key: const Key('forPerson'),
                        children: [
                          Icon(
                            Icons.family_restroom_outlined,
                            size: 15,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.forPersonLabel(appointment.familyMember!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((features.videoConsultation && appointment.isVideo) ||
                        (features.onlinePayments &&
                            appointment.paymentStatus ==
                                AppointmentPaymentStatus.paid)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (features.videoConsultation && appointment.isVideo)
                            Pill(
                              key: const Key('videoBadge'),
                              label: l10n.videoBadge,
                              color: theme.colorScheme.primary,
                              icon: Icons.videocam_outlined,
                            ),
                          if (features.onlinePayments &&
                              appointment.paymentStatus ==
                                  AppointmentPaymentStatus.paid)
                            Pill(
                              label: l10n.payStatusPaid,
                              color: Colors.green,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              StatusChip(status: appointment.status),
            ],
          ),
        ),
      ),
    );
  }
}
