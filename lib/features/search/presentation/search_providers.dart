import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/network/paged_notifier.dart';
import '../../doctor/domain/doctor.dart';
import '../data/search_repository.dart';
import '../domain/doctor_query.dart';
import '../domain/specialty.dart';

// Catalog names are localized by the server, so these reload on language change.
final specialtiesProvider = FutureProvider.autoDispose<List<Specialty>>((ref) {
  ref.watch(localeProvider);
  return ref.watch(searchRepositoryProvider).specialties().unwrap();
});

final citiesProvider = FutureProvider.autoDispose<List<String>>((ref) {
  ref.watch(localeProvider);
  return ref.watch(searchRepositoryProvider).cities().unwrap();
});

class DoctorListNotifier extends PagedNotifier<Doctor> {
  DoctorListNotifier(this.query);

  final DoctorQuery query;

  @override
  void watchInputs() => ref.watch(localeProvider);

  @override
  ApiResult<Paged<Doctor>> fetchPage(int page) =>
      ref.read(searchRepositoryProvider).doctors(query, page: page);
}

final doctorListProvider = AsyncNotifierProvider.autoDispose
    .family<DoctorListNotifier, PagedState<Doctor>, DoctorQuery>(
      DoctorListNotifier.new,
    );
