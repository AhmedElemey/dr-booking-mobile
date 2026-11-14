import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/clinic_features.dart';
import '../data/features_repository.dart';

/// The feature switches in force right now. Starts from the cached value (or
/// the brand defaults), refreshes from the API at startup and when the app
/// resumes, and keeps the last value if the API cannot be reached.
class FeaturesController extends Notifier<ClinicFeatures> {
  @override
  ClinicFeatures build() {
    final repository = ref.read(featuresRepositoryProvider);
    Future.microtask(refresh);
    return repository.cached();
  }

  Future<void> refresh() async {
    try {
      final fresh = await ref.read(featuresRepositoryProvider).fetch();
      if (ref.mounted) state = fresh;
    } catch (error) {
      // Offline or the API is down: keep the cached/default switches.
      debugPrint('features refresh failed: $error');
    }
  }
}

final featuresProvider = NotifierProvider<FeaturesController, ClinicFeatures>(
  FeaturesController.new,
);
