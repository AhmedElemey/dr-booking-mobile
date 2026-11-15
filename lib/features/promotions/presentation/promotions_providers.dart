import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/failure.dart';
import '../data/promotions_repository.dart';
import '../domain/promotion.dart';

/// Public offers for the home screen; localized, so reloads on language change.
final promotionsProvider = FutureProvider.autoDispose<List<Promotion>>((ref) {
  ref.watch(localeProvider);
  return ref.watch(promotionsRepositoryProvider).offers().unwrap();
});

/// A code the patient picked from an offer; the confirm screen starts with it.
class SelectedCouponController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String code) => state = code;
  void clear() => state = null;
}

final selectedCouponProvider =
    NotifierProvider<SelectedCouponController, String?>(
      SelectedCouponController.new,
    );
