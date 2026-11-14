import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../clinic_config/presentation/features_controller.dart';
import '../../doctor/domain/doctor_slots.dart';
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
    final open = {
      for (final day in slots?.days ?? const <SlotDay>[])
        if (day.slots.isNotEmpty) day.date,
    };
    final closed = {for (final c in slots?.closedDates ?? const []) c.date};
    final format = DateFormat('yyyy-MM-dd');
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: l10n.pickWaitingDate,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 60)),
      selectableDayPredicate: (day) {
        final key = format.format(day);
        return !open.contains(key) && !closed.contains(key);
      },
    );
    if (picked == null) return;
    final result = await ref
        .read(waitingListRepositoryProvider)
        .join(doctorId: doctorId, date: format.format(picked));
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
