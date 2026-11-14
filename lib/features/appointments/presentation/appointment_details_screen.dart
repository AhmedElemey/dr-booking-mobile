import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/config/brand.g.dart';
import '../../../shared/domain/clinic.dart';
import '../../../shared/widgets/doctor_avatar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../clinic_config/presentation/feature_unavailable_screen.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment.dart';
import 'appointments_providers.dart';

class AppointmentDetailsScreen extends ConsumerStatefulWidget {
  const AppointmentDetailsScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<AppointmentDetailsScreen> createState() =>
      _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState
    extends ConsumerState<AppointmentDetailsScreen> {
  bool _cancelling = false;

  Future<void> _cancel(Appointment appointment) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _CancelDialog(),
    );
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    final result = await ref
        .read(appointmentsRepositoryProvider)
        .cancel(appointment.id, reason: reason);
    if (!mounted) return;
    setState(() => _cancelling = false);
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(failure))),
      ),
      (_) {
        invalidateAppointments(ref, id: appointment.id);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.appointmentCancelled)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appointment = ref.watch(appointmentProvider(widget.id));
    final selfService = ref.watch(
      featuresProvider.select((f) => f.patientSelfService),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appointmentDetailsTitle)),
      body: appointment.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(appointmentProvider(widget.id)),
        ),
        data: (appointment) => _Body(
          appointment: appointment,
          cancelling: _cancelling,
          selfService: selfService,
          onCancel: () => _cancel(appointment),
          onReschedule: () =>
              context.push('/appointments/${appointment.id}/reschedule'),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.appointment,
    required this.cancelling,
    required this.selfService,
    required this.onCancel,
    required this.onReschedule,
  });

  final Appointment appointment;
  final bool cancelling;
  final bool selfService;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final clinic = appointment.clinic;

    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Row(
          children: [
            DoctorAvatar(
              name: appointment.doctor.name,
              photoUrl: appointment.doctor.photoUrl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                appointment.doctor.name,
                style: theme.textTheme.titleLarge,
              ),
            ),
            StatusChip(status: appointment.status),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(
                  icon: Icons.event,
                  text: ClinicTime.date(appointment.startsAtLocal, locale),
                ),
                _InfoLine(
                  icon: Icons.schedule,
                  text:
                      '${ClinicTime.time(appointment.startsAtLocal, locale)} - '
                      '${ClinicTime.time(appointment.endsAtLocal, locale)}',
                ),
                if (appointment.service != null)
                  _InfoLine(
                    icon: Icons.medical_services_outlined,
                    text: appointment.service!.name,
                  ),
                _InfoLine(
                  icon: Icons.payments_outlined,
                  text: l10n.payAtClinic,
                ),
                if ((appointment.patientNote ?? '').isNotEmpty)
                  _InfoLine(
                    icon: Icons.notes,
                    text: '${l10n.yourNote}: ${appointment.patientNote}',
                  ),
                if (appointment.status == AppointmentStatus.cancelled) ...[
                  const Divider(height: 24),
                  _InfoLine(
                    icon: Icons.cancel_outlined,
                    text: appointment.cancelledBy == 'Clinic'
                        ? l10n.cancelledByClinic
                        : l10n.cancelledByPatient,
                  ),
                  if ((appointment.cancelReason ?? '').isNotEmpty)
                    _InfoLine(
                      icon: Icons.info_outline,
                      text: '${l10n.reasonLabel}: ${appointment.cancelReason}',
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clinic.name, style: theme.textTheme.titleMedium),
                if ((clinic.address ?? '').isNotEmpty)
                  _InfoLine(icon: Icons.place_outlined, text: clinic.address!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if ((clinic.phone ?? '').isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('callClinic'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: () =>
                              launchUrl(Uri(scheme: 'tel', path: clinic.phone)),
                          icon: const Icon(Icons.call_outlined),
                          label: Text(l10n.callClinic),
                        ),
                      ),
                    if ((clinic.phone ?? '').isNotEmpty)
                      const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('getDirections'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () => launchUrl(
                          directionsUri(clinic),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.directions_outlined),
                        label: Text(l10n.getDirections),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (appointment.canChange && !selfService) ...[
          const SizedBox(height: 20),
          CallToChangeNotice(
            phone: (clinic.phone ?? '').isNotEmpty
                ? clinic.phone!
                : Brand.supportPhone,
          ),
        ],
        if (appointment.canChange && selfService) ...[
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('reschedule'),
            onPressed: cancelling ? null : onReschedule,
            child: Text(l10n.rescheduleAppointment),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('cancelAppointment'),
            onPressed: cancelling ? null : onCancel,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: const Size.fromHeight(48),
            ),
            child: cancelling
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.cancelAppointment),
          ),
        ],
      ],
    );
  }
}

/// Opens maps at the clinic's coordinates, or searches its address.
Uri directionsUri(Clinic clinic) {
  final lat = clinic.latitude;
  final lng = clinic.longitude;
  final query = lat != null && lng != null
      ? '$lat,$lng'
      : [clinic.name, ?clinic.address].join(', ');
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

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

/// Asks for an optional reason. Pops the reason (possibly empty) on confirm and
/// null when the patient keeps the appointment.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.cancelConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cancelConfirmBody),
          const SizedBox(height: 12),
          TextField(
            key: const Key('cancelReason'),
            controller: _reason,
            maxLines: 2,
            decoration: InputDecoration(hintText: l10n.cancelReasonHint),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('keepAppointment'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.keepAppointment),
        ),
        TextButton(
          key: const Key('confirmCancel'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: Text(l10n.cancelAppointment),
        ),
      ],
    );
  }
}
