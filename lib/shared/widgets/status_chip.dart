import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../features/appointments/domain/appointment.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      AppointmentStatus.pending => (l10n.statusPending, Colors.amber),
      AppointmentStatus.confirmed => (l10n.statusConfirmed, Colors.green),
      AppointmentStatus.checkedIn => (l10n.statusCheckedIn, Colors.teal),
      AppointmentStatus.inProgress => (l10n.statusInProgress, Colors.blue),
      AppointmentStatus.cancelled => (l10n.statusCancelled, Colors.red),
      AppointmentStatus.completed => (l10n.statusCompleted, Colors.blueGrey),
      AppointmentStatus.noShow => (l10n.statusNoShow, Colors.orange),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: HSLColor.fromColor(color).withLightness(0.28).toColor(),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
