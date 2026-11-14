import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:moonlight/core/config/brand.g.dart';
import 'package:moonlight/core/config/clinic_features.dart';
import 'package:moonlight/features/clinic_config/presentation/features_controller.dart';

/// Pins the feature switches for a widget test (no network refresh).
class FixedFeatures extends FeaturesController {
  FixedFeatures(this.value);

  final ClinicFeatures value;

  @override
  ClinicFeatures build() => value;

  @override
  Future<void> refresh() async {}
}

/// The brand defaults with [change] applied, as an override for `pumpMoonlight`.
Override featuresOverride(
  ClinicFeatures Function(ClinicFeatures defaults) change,
) => featuresProvider.overrideWith(
  () => FixedFeatures(change(Brand.defaultFeatures)),
);
