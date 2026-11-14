import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/appointment_card.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../data/appointments_repository.dart';
import 'appointments_providers.dart';

/// "My appointments": upcoming and past tabs.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appointmentsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.upcomingTab),
              Tab(text: l10n.pastTab),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AppointmentList(scope: AppointmentScope.upcoming),
            _AppointmentList(scope: AppointmentScope.past),
          ],
        ),
      ),
    );
  }
}

class _AppointmentList extends ConsumerWidget {
  const _AppointmentList({required this.scope});

  final AppointmentScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = appointmentListProvider(scope);
    return PagedListView(
      value: ref.watch(provider),
      onLoadMore: ref.read(provider.notifier).loadMore,
      onRefresh: () => ref.refresh(provider.future),
      empty: EmptyView(
        icon: Icons.event_available_outlined,
        message: scope == AppointmentScope.upcoming
            ? l10n.noUpcoming
            : l10n.noPast,
        action: scope == AppointmentScope.upcoming
            ? FilledButton.tonal(
                onPressed: () => context.go('/'),
                child: Text(l10n.navSearch),
              )
            : null,
      ),
      itemBuilder: (context, appointment) => AppointmentCard(
        appointment: appointment,
        onTap: () => context.push('/appointments/${appointment.id}'),
      ),
    );
  }
}
