import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../features/doctor/domain/doctor_slots.dart';
import '../../features/doctor/presentation/doctor_providers.dart';
import 'error_view.dart';
import 'slot_picker.dart';

/// Loads a doctor's open slots and shows the picker (shared by booking and
/// reschedule). [onLoaded] receives the response so the host screen can read the
/// timezone and day of the chosen slot.
class SlotsPane extends ConsumerWidget {
  const SlotsPane({
    super.key,
    required this.doctorKey,
    required this.selected,
    required this.onSelected,
    this.emptyAction,
    this.footer,
  });

  final String doctorKey;
  final Slot? selected;
  final void Function(Slot slot, DoctorSlots slots) onSelected;

  /// Shown under the "no times" message (for example "Join the waiting list").
  final Widget? emptyAction;

  /// Shown under the slot picker.
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final slotsAsync = ref.watch(doctorSlotsProvider(doctorKey));
    return slotsAsync.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(doctorSlotsProvider(doctorKey)),
      ),
      data: (slots) {
        if (slots.isEmpty && slots.closedDates.isEmpty) {
          return EmptyView(
            message: l10n.noAvailability,
            icon: Icons.event_busy_outlined,
            action: emptyAction,
          );
        }
        return Column(
          children: [
            Expanded(
              child: SlotPicker(
                slots: slots,
                selected: selected,
                onSelected: (slot) => onSelected(slot, slots),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.clinicTimeNote(slots.timezone),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            ?footer,
          ],
        );
      },
    );
  }
}
