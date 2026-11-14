import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/network/paged_notifier.dart';
import '../data/reviews_repository.dart';
import '../domain/review.dart';

class DoctorReviewsNotifier extends PagedNotifier<DoctorReview> {
  DoctorReviewsNotifier(this.doctorKey);

  final String doctorKey;

  @override
  void watchInputs() => ref.watch(localeProvider);

  @override
  ApiResult<Paged<DoctorReview>> fetchPage(int page) =>
      ref.read(reviewsRepositoryProvider).forDoctor(doctorKey, page: page);
}

final doctorReviewsProvider = AsyncNotifierProvider.autoDispose
    .family<DoctorReviewsNotifier, PagedState<DoctorReview>, String>(
      DoctorReviewsNotifier.new,
    );
