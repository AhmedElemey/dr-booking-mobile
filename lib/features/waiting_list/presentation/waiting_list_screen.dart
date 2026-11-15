import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/enum_labels.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/doctor_avatar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/pill.dart';
import '../data/waiting_list_repository.dart';
import '../domain/waiting_entry.dart';
import 'waiting_list_providers.dart';

/// "My waiting list": the days the patient is waiting for, with a way to leave
/// and, once a slot opens up, a "Book now" shortcut.
class WaitingListScreen extends ConsumerWidget {
  const WaitingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(waitingListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.waitingListTitle)),
      body: entries.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(waitingListProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyView(
                icon: Icons.notifications_none_outlined,
                message: l10n.waitingListEmpty,
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(waitingListProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _EntryCard(entry: items[index]),
                ),
              ),
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry});

  final WaitingEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final notified = entry.status == WaitingStatus.notified;
    final color = switch (entry.status) {
      WaitingStatus.notified => Colors.green,
      WaitingStatus.waiting => Colors.orange,
      WaitingStatus.booked => Colors.blue,
      _ => Colors.blueGrey,
    };
    return Card(
      key: Key('waiting-${entry.id}'),
      color: notified ? Colors.green.withValues(alpha: 0.06) : null,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DoctorAvatar(
                  name: entry.doctor.name,
                  photoUrl: entry.doctor.photoUrl,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.doctor.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (entry.familyMember != null)
                        Text(
                          '${l10n.bookingFor}: ${entry.familyMember!.fullName} '
                          '(${l10n.relationName(entry.familyMember!.relation)})',
                          key: Key('waitingFor-${entry.id}'),
                          style: theme.textTheme.bodySmall,
                        ),
                      Text(
                        ClinicTime.date(
                          ClinicTime.parseDate(entry.date),
                          locale,
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Pill(
                  key: Key('waitingStatus-${entry.id}'),
                  label: l10n.waitingStatusName(entry.status),
                  color: color,
                ),
              ],
            ),
            if (notified) ...[
              const SizedBox(height: 10),
              Text(l10n.waitingNotifiedBody),
              const SizedBox(height: 10),
              FilledButton(
                key: Key('bookNow-${entry.id}'),
                onPressed: () =>
                    context.push('/doctors/${entry.doctor.key}/slots'),
                child: Text(l10n.bookNow),
              ),
            ],
            if (entry.isActive)
              TextButton(
                key: Key('leave-${entry.id}'),
                onPressed: () => _leave(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(l10n.leaveWaitingList),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(waitingListRepositoryProvider)
        .leave(entry.id);
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(failure))),
      ),
      (_) {
        ref.invalidate(waitingListProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.waitingLeft)));
      },
    );
  }
}
