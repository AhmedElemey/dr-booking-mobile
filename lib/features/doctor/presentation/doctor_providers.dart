import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/failure.dart';
import '../data/doctor_repository.dart';
import '../domain/doctor.dart';
import '../domain/doctor_slots.dart';

final doctorProvider = FutureProvider.autoDispose.family<Doctor, String>((
  ref,
  idOrSlug,
) {
  ref.watch(localeProvider);
  return ref.watch(doctorRepositoryProvider).doctor(idOrSlug).unwrap();
});

/// Open slots for the next two weeks; auto-disposed with the screen so a
/// revisit never shows slots somebody else has taken since.
final doctorSlotsProvider = FutureProvider.autoDispose
    .family<DoctorSlots, String>((ref, idOrSlug) {
      return ref
          .watch(doctorRepositoryProvider)
          .slots(idOrSlug, from: DateTime.now())
          .unwrap();
    });
