import 'package:flutter/material.dart';

import '../../core/format/clinic_time.dart';
import '../../features/appointments/domain/appointment.dart';
import 'doctor_avatar.dart';
import 'status_chip.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(14),
          child: Row(
            children: [
              DoctorAvatar(
                name: appointment.doctor.name,
                photoUrl: appointment.doctor.photoUrl,
                radius: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctor.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
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
                    const SizedBox(height: 2),
                    Text(
                      appointment.clinic.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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
