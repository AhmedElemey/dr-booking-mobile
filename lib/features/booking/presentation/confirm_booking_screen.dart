import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/network/failure.dart';
import '../../../shared/domain/clinic.dart';
import '../../appointments/data/appointments_repository.dart';
import '../../appointments/presentation/appointments_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../doctor/presentation/doctor_providers.dart';
import 'booking_providers.dart';

/// Booking step 2: summary, optional visit type and note. Guests can reach this
/// screen; they are asked to sign in only when they confirm.
class ConfirmBookingScreen extends ConsumerStatefulWidget {
  const ConfirmBookingScreen({super.key});

  @override
  ConsumerState<ConfirmBookingScreen> createState() =>
      _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends ConsumerState<ConfirmBookingScreen> {
  final _note = TextEditingController();
  ServiceItem? _service;
  bool _booking = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final draft = ref.read(bookingDraftProvider);
    if (draft == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _booking = true;
      _error = null;
    });
    final result = await ref
        .read(appointmentsRepositoryProvider)
        .book(slotId: draft.slot.id, serviceId: _service?.id, note: _note.text);
    if (!mounted) return;
    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      setState(() {
        _booking = false;
        _error = l10n.failureMessage(failure);
      });
      if (failure.code == 'SLOT_TAKEN' || failure.code == 'SLOT_UNAVAILABLE') {
        // The list is stale: reload it and send the patient back to choose again.
        ref.invalidate(doctorSlotsProvider(draft.doctor.slug));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failureMessage(failure))));
        context.go('/doctors/${draft.doctor.slug}/slots');
      }
      return;
    }
    final appointment = result.toNullable()!;
    ref.read(lastBookingProvider.notifier).set(appointment);
    invalidateAppointments(ref);
    ref.invalidate(doctorSlotsProvider(draft.doctor.slug));
    context.go('/booking/success');
    ref.read(bookingDraftProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final draft = ref.watch(bookingDraftProvider);
    if (draft == null) return const Scaffold();
    final isGuest = ref.watch(authControllerProvider).value == null;
    final when = ClinicTime.dateAndTime(
      ClinicTime.parseTime(
        draft.slot.local,
        onDate: ClinicTime.parseDate(draft.slotDate),
      ),
      locale,
    );
    final doctor = draft.doctor;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.confirmTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(label: l10n.doctorLabel, value: doctor.name),
                  if (doctor.clinic != null)
                    _SummaryRow(
                      label: l10n.clinicLabel,
                      value: [
                        doctor.clinic!.name,
                        ?doctor.clinic!.address,
                      ].join('\n'),
                    ),
                  _SummaryRow(
                    label: l10n.whenLabel,
                    value: when,
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ),
          if (doctor.services.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l10n.visitType, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final service in doctor.services)
                  ChoiceChip(
                    key: Key('service-${service.id}'),
                    label: Text(service.name),
                    selected: _service?.id == service.id,
                    onSelected: (selected) =>
                        setState(() => _service = selected ? service : null),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            key: const Key('noteField'),
            controller: _note,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(labelText: l10n.noteLabel),
          ),
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(l10n.payAtClinic),
              subtitle: Text(l10n.payAtClinicDetail),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('bookingError'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGuest)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: Text(
                    l10n.signInToBookHint,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton(
                key: const Key('confirmBooking'),
                onPressed: _booking
                    ? null
                    : isGuest
                    ? () => context.push(
                        Uri(
                          path: '/login',
                          queryParameters: {'from': '/booking/confirm'},
                        ).toString(),
                      )
                    : _confirm,
                child: _booking
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isGuest ? l10n.signInToBook : l10n.confirmBooking),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: emphasize
                ? theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  )
                : theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
