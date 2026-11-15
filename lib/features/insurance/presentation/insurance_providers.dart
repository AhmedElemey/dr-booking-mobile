import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/failure.dart';
import '../data/insurance_repository.dart';
import '../domain/insurance.dart';

/// Active insurance providers (names are localized by the server).
final insuranceProvidersProvider =
    FutureProvider.autoDispose<List<InsuranceProvider>>((ref) {
      ref.watch(localeProvider);
      return ref.watch(insuranceRepositoryProvider).providers().unwrap();
    });
