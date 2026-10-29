import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/slots_pane.dart';
import '../../doctor/domain/doctor_slots.dart';
import '../../doctor/presentation/doctor_providers.dart';
import '../domain/booking_draft.dart';
import 'booking_providers.dart';

/// Booking step 1: choose one of the doctor's open slots.
class PickSlotScreen extends ConsumerStatefulWidget {
  const PickSlotScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<PickSlotScreen> createState() => _PickSlotScreenState();
}

class _PickSlotScreenState extends ConsumerState<PickSlotScreen> {
  Slot? _selected;
  DoctorSlots? _slots;

  void _continue() {
    final slot = _selected;
    final slots = _slots;
    final doctor = ref.read(doctorProvider(widget.slug)).value;
    if (slot == null || slots == null || doctor == null) return;
    final day = slots.days.firstWhere(
      (d) => d.slots.any((s) => s.id == slot.id),
    );
    ref
        .read(bookingDraftProvider.notifier)
        .set(
          BookingDraft(
            doctor: doctor,
            slot: slot,
            timezone: slots.timezone,
            slotDate: day.date,
          ),
        );
    context.push('/booking/confirm');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final slot = _selected;
    final day = slot == null
        ? null
        : _slots?.days
              .firstWhere((d) => d.slots.any((s) => s.id == slot.id))
              .date;
    final summary = slot == null || day == null
        ? null
        : ClinicTime.dateAndTime(
            ClinicTime.parseTime(slot.local, onDate: ClinicTime.parseDate(day)),
            locale,
          );
    // Reloaded slots (for example after SLOT_TAKEN) may no longer include the
    // slot the patient had selected.
    ref.listen(doctorSlotsProvider(widget.slug), (_, next) {
      final fresh = next.value;
      final selected = _selected;
      if (fresh == null || selected == null) return;
      final stillOpen = fresh.days.any(
        (d) => d.slots.any((s) => s.id == selected.id),
      );
      if (!stillOpen) setState(() => _selected = null);
    });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickSlotTitle)),
      body: SlotsPane(
        doctorKey: widget.slug,
        selected: slot,
        onSelected: (slot, slots) => setState(() {
          _selected = slot;
          _slots = slots;
        }),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: FilledButton(
            key: const Key('continueToConfirm'),
            onPressed: slot == null ? null : _continue,
            child: Text(
              summary == null
                  ? l10n.continueAction
                  : '${l10n.continueAction} · $summary',
            ),
          ),
        ),
      ),
    );
  }
}
