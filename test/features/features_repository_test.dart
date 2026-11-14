import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/config/brand.g.dart';
import 'package:moonlight/core/network/dio_provider.dart';
import 'package:moonlight/core/network/failure.dart';
import 'package:moonlight/core/storage/local_settings.dart';
import 'package:moonlight/features/clinic_config/data/features_repository.dart';
import 'package:moonlight/features/clinic_config/presentation/features_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_adapter.dart';

Map<String, Object?> _body(Map<String, bool> features) => {
  'features': features,
  'source': 'console',
  'updatedAt': '2026-11-14T17:00:00Z',
};

Future<LocalSettings> _settings([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return LocalSettings(await SharedPreferences.getInstance());
}

void main() {
  const defaults = Brand.defaultFeatures;

  group('FeaturesRepository', () {
    test('without a cache it serves the brand defaults', () async {
      final repo = FeaturesRepository(
        testDio(FakeAdapter((_) => jsonResponse(null, status: 500))),
        await _settings(),
      );
      expect(repo.cached(), defaults);
    });

    test('fetch parses the response and caches it', () async {
      final settings = await _settings();
      final adapter = FakeAdapter(
        (_) => jsonResponse(
          _body({...defaults.toJson(), 'patientSelfService': false}),
        ),
      );
      final repo = FeaturesRepository(testDio(adapter), settings);

      final fetched = await repo.fetch();

      expect(adapter.requests.single.path, '/features');
      expect(fetched.patientSelfService, isFalse);
      expect(fetched.guestBrowsing, isTrue);
      // A new repository (next app launch) reads the cached value.
      expect(FeaturesRepository(testDio(adapter), settings).cached(), fetched);
    });

    test(
      'missing keys fall back to defaults and unknown keys are ignored',
      () async {
        final adapter = FakeAdapter(
          (_) => jsonResponse({
            'features': {'multiBranch': false, 'somethingNew': true},
          }),
        );
        final fetched = await FeaturesRepository(
          testDio(adapter),
          await _settings(),
        ).fetch();

        expect(fetched, defaults.copyWith(multiBranch: false));
      },
    );

    test('a failed fetch throws and leaves the cache alone', () async {
      final settings = await _settings({
        'features_json': jsonEncode(
          defaults.copyWith(englishLanguage: false).toJson(),
        ),
      });
      final repo = FeaturesRepository(
        testDio(FakeAdapter((_) => jsonResponse(null, status: 503))),
        settings,
      );

      await expectLater(repo.fetch(), throwsA(isA<Failure>()));
      expect(repo.cached().englishLanguage, isFalse);
    });

    test('an unreadable cache falls back to the defaults', () async {
      final repo = FeaturesRepository(
        testDio(FakeAdapter((_) => jsonResponse(null))),
        await _settings({'features_json': '{not json'}),
      );
      expect(repo.cached(), defaults);
    });
  });

  group('featuresProvider', () {
    ProviderContainer containerFor(FakeAdapter adapter, LocalSettings s) {
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(testDio(adapter)),
          localSettingsProvider.overrideWithValue(s),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('starts from the cache, then refreshes from the API', () async {
      final settings = await _settings({
        'features_json': jsonEncode(
          defaults.copyWith(guestBrowsing: false).toJson(),
        ),
      });
      final container = containerFor(
        FakeAdapter(
          (_) =>
              jsonResponse(_body({...defaults.toJson(), 'mobileApp': false})),
        ),
        settings,
      );

      expect(container.read(featuresProvider).guestBrowsing, isFalse);
      for (
        var i = 0;
        i < 50 && container.read(featuresProvider).mobileApp;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final now = container.read(featuresProvider);
      expect(now.mobileApp, isFalse);
      expect(now.guestBrowsing, isTrue);
    });

    test('keeps the last value when the API is down', () async {
      final settings = await _settings({
        'features_json': jsonEncode(
          defaults.copyWith(patientSelfService: false).toJson(),
        ),
      });
      final container = containerFor(
        FakeAdapter((_) => jsonResponse(null, status: 500)),
        settings,
      );

      container.read(featuresProvider);
      await container.read(featuresProvider.notifier).refresh();

      expect(container.read(featuresProvider).patientSelfService, isFalse);
    });

    test('refresh (app resume) picks up a new switch', () async {
      var selfService = true;
      final container = containerFor(
        FakeAdapter(
          (_) => jsonResponse(
            _body({...defaults.toJson(), 'patientSelfService': selfService}),
          ),
        ),
        await _settings(),
      );
      container.read(featuresProvider);
      await container.read(featuresProvider.notifier).refresh();
      expect(container.read(featuresProvider).patientSelfService, isTrue);

      selfService = false;
      await container.read(featuresProvider.notifier).refresh();
      expect(container.read(featuresProvider).patientSelfService, isFalse);
    });
  });

  test('FEATURE_DISABLED problems keep the feature name', () {
    final request = RequestOptions(path: '/appointments/x/cancel');
    final failure = Failure.fromDio(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 403,
          data: {'code': 'FEATURE_DISABLED', 'feature': 'patientSelfService'},
        ),
      ),
    );
    expect(failure.code, 'FEATURE_DISABLED');
    expect(failure.feature, 'patientSelfService');
  });
}
