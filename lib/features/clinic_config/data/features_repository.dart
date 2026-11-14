import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/brand.g.dart';
import '../../../core/config/clinic_features.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../../../core/storage/local_settings.dart';

/// Reads the clinic's feature switches from `GET /features`, and remembers the
/// last good answer so the app behaves the same offline.
class FeaturesRepository {
  FeaturesRepository(
    this._dio,
    this._settings, {
    this.defaults = Brand.defaultFeatures,
  });

  final Dio _dio;
  final LocalSettings _settings;

  /// What applies when nothing has been fetched or cached yet.
  final ClinicFeatures defaults;

  /// The cached switches, or [defaults] when there are none (or they are
  /// unreadable).
  ClinicFeatures cached() {
    final raw = _settings.featuresJson;
    if (raw == null) return defaults;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return ClinicFeatures.fromJson(json, defaults: defaults);
      }
    } on FormatException {
      // Fall through to the defaults.
    }
    return defaults;
  }

  /// Fetches the current switches and caches them. On failure nothing is
  /// cached and the caller keeps what it has.
  Future<ClinicFeatures> fetch() async {
    final result = await guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>('/features');
      final body = response.data;
      final features = body?['features'];
      if (features is! Map<String, dynamic>) {
        throw const Failure(code: Failure.unknown);
      }
      return ClinicFeatures.fromJson(features, defaults: defaults);
    });
    return result.fold((failure) => throw failure, (features) async {
      await _settings.setFeaturesJson(jsonEncode(features.toJson()));
      return features;
    });
  }
}

final featuresRepositoryProvider = Provider<FeaturesRepository>(
  (ref) => FeaturesRepository(
    ref.watch(dioProvider),
    ref.watch(localSettingsProvider),
  ),
);
