import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/network/paged_notifier.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment.dart';

class AppointmentListNotifier extends PagedNotifier<Appointment> {
  AppointmentListNotifier(this.scope);

  final AppointmentScope scope;

  @override
  void watchInputs() => ref.watch(localeProvider);

  @override
  ApiResult<Paged<Appointment>> fetchPage(int page) =>
      ref.read(appointmentsRepositoryProvider).list(scope, page: page);
}

final appointmentListProvider = AsyncNotifierProvider.autoDispose
    .family<AppointmentListNotifier, PagedState<Appointment>, AppointmentScope>(
      AppointmentListNotifier.new,
    );

final appointmentProvider = FutureProvider.autoDispose
    .family<Appointment, String>((ref, id) {
      ref.watch(localeProvider);
      return ref.watch(appointmentsRepositoryProvider).get(id).unwrap();
    });

/// Drop cached lists/details after a booking, cancel or reschedule.
void invalidateAppointments(WidgetRef ref, {String? id}) {
  ref.invalidate(appointmentListProvider);
  if (id != null) ref.invalidate(appointmentProvider(id));
}
