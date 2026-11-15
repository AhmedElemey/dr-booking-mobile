import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../../doctor/data/doctor_repository.dart';
import '../../doctor/domain/doctor_slots.dart';
import '../../family/domain/family_member.dart';
import '../../family/presentation/booking_for_picker.dart';
import '../../family/presentation/family_providers.dart';
import '../data/waiting_list_repository.dart';
import 'waiting_list_providers.dart';

/// "Join the waiting list": the patient picks a day without open times and is
/// told when one opens up. Hidden when the feature is off.
class JoinWaitingListButton extends ConsumerWidget {
  const JoinWaitingListButton({
    super.key,
    required this.doctorId,
    required this.slots,
    required this.loginReturnTo,
  });

  final String doctorId;

  /// The slots the picker shows: days with open times cannot be waited for.
  final DoctorSlots? slots;

  /// Where to come back to after signing in (guests).
  final String loginReturnTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(featuresProvider.select((f) => f.waitingList));
    if (!enabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.waitingListHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const Key('joinWaitingList'),
            onPressed: () => _join(context, ref),
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(l10n.joinWaitingList),
          ),
        ],
      ),
    );
  }

  static const _cancelled = Object();

  /// Who the patient is waiting for: null = me. Skipped (me) when the clinic
  /// has no family accounts or the patient has no members; [_cancelled] when
  /// the dialog is dismissed.
  Future<Object?> _pickMember(BuildContext context, WidgetRef ref) async {
    if (!ref.read(featuresProvider).familyAccounts) return null;
    try {
      final members = await ref.read(familyMembersProvider.future);
      if (members.isEmpty || !context.mounted) return null;
    } catch (_) {
      return null;
    }
    if (!context.mounted) return _cancelled;
    FamilyMember? chosen;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          content: BookingForPicker(
            selected: chosen,
            onSelected: (m) => setState(() => chosen = m),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: const Key('waitingMemberContinue'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    );
    return confirmed == true ? chosen : _cancelled;
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (ref.read(authControllerProvider).value == null) {
      router.push(
        Uri(
          path: '/login',
          queryParameters: {'from': loginReturnTo},
        ).toString(),
      );
      return;
    }
    final member = await _pickMember(context, ref);
    if (member == _cancelled || !context.mounted) return;
    final open = {
      for (final day in slots?.days ?? const <SlotDay>[])
        if (day.slots.isNotEmpty) day.date,
    };
    final closed = {for (final c in slots?.closedDates ?? const []) c.date};
    // "Today" is the clinic's (the API refuses clinic-local past dates), and
    // only the window the picker loaded can be checked against open/closed days.
    final today =
        slots?.clinicToday(DateTime.now().toUtc()) ??
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final picked = await showDatePicker(
      context: context,
      helpText: l10n.pickWaitingDate,
      firstDate: today,
      lastDate: today.add(
        const Duration(days: DoctorRepository.slotWindowDays - 1),
      ),
      selectableDayPredicate: (day) {
        final key = ClinicTime.apiDate(day);
        return !open.contains(key) && !closed.contains(key);
      },
    );
    if (picked == null) return;
    final result = await ref
        .read(waitingListRepositoryProvider)
        .join(
          doctorId: doctorId,
          date: ClinicTime.apiDate(picked),
          familyMemberId: (member as FamilyMember?)?.id,
        );
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(failure))),
      ),
      (_) {
        ref.invalidate(waitingListProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.waitingJoined),
            action: SnackBarAction(
              label: l10n.waitingListTitle,
              onPressed: () => router.push('/waiting-list'),
            ),
          ),
        );
      },
    );
  }
}
