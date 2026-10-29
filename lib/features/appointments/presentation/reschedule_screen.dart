import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/slots_pane.dart';
import '../../doctor/domain/doctor_slots.dart';
import '../../doctor/presentation/doctor_providers.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment.dart';
import 'appointments_providers.dart';

/// Reschedule: the slot picker again, for the same doctor's other open slots.
class RescheduleScreen extends ConsumerStatefulWidget {
  const RescheduleScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends ConsumerState<RescheduleScreen> {
  Slot? _selected;
  String? _selectedDate;
  bool _saving = false;

  Future<void> _submit(Appointment appointment) async {
    final slot = _selected;
    if (slot == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    final result = await ref
        .read(appointmentsRepositoryProvider)
        .reschedule(appointment.id, slotId: slot.id);
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (failure) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.failureMessage(failure))),
        );
        // Whatever went wrong, the shown slots may be stale.
        ref.invalidate(doctorSlotsProvider(appointment.doctor.key));
        setState(() => _selected = null);
      },
      (_) {
        invalidateAppointments(ref, id: appointment.id);
        ref.invalidate(doctorSlotsProvider(appointment.doctor.key));
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.appointmentRescheduled)),
        );
        router.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final appointment = ref.watch(appointmentProvider(widget.id));
    final slot = _selected;
    final date = _selectedDate;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rescheduleTitle)),
      body: appointment.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(appointmentProvider(widget.id)),
        ),
        data: (appointment) => SlotsPane(
          doctorKey: appointment.doctor.key,
          selected: slot,
          onSelected: (slot, slots) => setState(() {
            _selected = slot;
            _selectedDate = slots.days
                .firstWhere((d) => d.slots.any((s) => s.id == slot.id))
                .date;
          }),
        ),
      ),
      bottomNavigationBar: appointment.hasValue
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: FilledButton(
                  key: const Key('confirmReschedule'),
                  onPressed: slot == null || _saving
                      ? null
                      : () => _submit(appointment.requireValue),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          slot == null || date == null
                              ? l10n.rescheduleConfirm
                              : '${l10n.rescheduleConfirm} · '
                                    '${ClinicTime.dateAndTime(ClinicTime.parseTime(slot.local, onDate: ClinicTime.parseDate(date)), locale)}',
                        ),
                ),
              ),
            )
          : null,
    );
  }
}
