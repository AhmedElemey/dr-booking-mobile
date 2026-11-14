import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/config/clinic_features.dart';

import '../../tool/apply_brand.dart';

/// The files apply_brand touches, copied into a scratch project.
final _currentConfig = jsonDecode(
  File('clinic.config.json').readAsStringSync(),
) as Map<String, dynamic>;
final _currentAndroidId =
    (_currentConfig['mobile'] as Map<String, dynamic>)['androidApplicationId']
        as String;
final _currentIosId =
    (_currentConfig['mobile'] as Map<String, dynamic>)['iosBundleId'] as String;
final _currentPackagePath = _currentAndroidId.replaceAll('.', '/');

final _tracked = [
  'clinic.config.json',
  'clinic.config.schema.json',
  'branding/logo.svg',
  'android/app/build.gradle.kts',
  'android/app/src/main/AndroidManifest.xml',
  'android/app/src/main/kotlin/$_currentPackagePath/MainActivity.kt',
  'ios/Runner.xcodeproj/project.pbxproj',
  'ios/Runner/Info.plist',
  'web/manifest.json',
  'web/index.html',
];

Directory _scratchProject() {
  final dir = Directory.systemTemp.createTempSync('apply_brand_');
  addTearDown(() => dir.deleteSync(recursive: true));
  for (final path in _tracked) {
    final target = File('${dir.path}/$path')
      ..parent.createSync(recursive: true);
    File(path).copySync(target.path);
  }
  return dir;
}

Map<String, String> _snapshot(Directory dir) => {
  for (final f in dir.listSync(recursive: true).whereType<File>())
    f.path.substring(dir.path.length + 1): f.readAsStringSync(),
};

void _editConfig(Directory dir, void Function(Map<String, dynamic>) edit) {
  final file = File('${dir.path}/clinic.config.json');
  final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  edit(config);
  file.writeAsStringSync(jsonEncode(config));
}

void main() {
  test('the repo config is valid and its generated files are current', () {
    final errors = <String>[];
    final stale = applyBrand('.', check: true, errors: errors);
    expect(errors, isEmpty);
    expect(stale, isEmpty, reason: 'run `dart run tool/apply_brand.dart`');
  });

  test('every phase 2 feature key is in the config, schema and defaults', () {
    final schema = jsonDecode(
      File('clinic.config.schema.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final features =
        ((schema['properties'] as Map)['features'] as Map)
            as Map<String, dynamic>;
    final config = _currentConfig['features'] as Map<String, dynamic>;
    for (final key in ClinicFeatures.phase2Keys) {
      expect(features['required'], contains(key));
      expect((features['properties'] as Map).containsKey(key), isTrue);
      expect(config[key], isFalse, reason: '$key is off in the template');
    }
    expect(ClinicFeatures.phase2Keys, hasLength(13));
    expect(featureKeys, containsAll(ClinicFeatures.phase2Keys));
  });

  test('applying today\'s config to a copy changes nothing', () {
    final dir = _scratchProject();
    final before = _snapshot(dir);
    final errors = <String>[];
    // brand.g.dart is the only file that does not exist in the scratch copy.
    final changed = applyBrand(dir.path, errors: errors);
    expect(errors, isEmpty);
    expect(changed, ['lib/core/config/brand.g.dart']);
    final after = _snapshot(dir);
    after.remove('lib/core/config/brand.g.dart');
    expect(after, before);
  });

  test('a rebrand rewrites every platform file, and is idempotent', () {
    final dir = _scratchProject();
    _editConfig(dir, (c) {
      c['slug'] = 'smile-care';
      c['name'] = {'ar': 'سمايل كير', 'en': 'Smile Care'};
      c['tagline'] = {'ar': 'ابتسامتك', 'en': "Your smile's home"};
      c['colors'] = {'primary': '#112233', 'accent': '#aabbcc'};
      c['supportPhone'] = '+201111111111';
      c['mobile'] = {
        'androidApplicationId': 'com.smilecare.patient',
        'iosBundleId': 'com.smilecare.Patient',
      };
      (c['features'] as Map<String, dynamic>)
        ..['guestBrowsing'] = false
        ..['onlinePayments'] = true;
    });

    final errors = <String>[];
    final first = applyBrand(dir.path, errors: errors);
    expect(errors, isEmpty);
    expect(first, isNotEmpty);

    final snapshot = _snapshot(dir);
    final gradle = snapshot['android/app/build.gradle.kts']!;
    expect(gradle, contains('namespace = "com.smilecare.patient"'));
    expect(gradle, contains('applicationId = "com.smilecare.patient"'));
    expect(
      gradle,
      contains('manifestPlaceholders["appName"] = "Smile Care Dev"'),
    );
    expect(gradle, contains('manifestPlaceholders["appName"] = "Smile Care"'));
    expect(
      gradle,
      contains('com.smilecare.patient.dev / com.smilecare.patient.'),
    );

    expect(
      snapshot.containsKey(
        'android/app/src/main/kotlin/com/smilecare/patient/MainActivity.kt',
      ),
      isTrue,
    );
    expect(
      snapshot.keys.where((k) => k.contains('kotlin/$_currentPackagePath/')),
      isEmpty,
      reason: 'the old package directory is gone',
    );
    expect(
      snapshot['android/app/src/main/kotlin/com/smilecare/patient/MainActivity.kt'],
      contains('package com.smilecare.patient'),
    );

    final pbx = snapshot['ios/Runner.xcodeproj/project.pbxproj']!;
    expect(pbx, contains('PRODUCT_BUNDLE_IDENTIFIER = com.smilecare.Patient;'));
    expect(
      pbx,
      contains(
        'PRODUCT_BUNDLE_IDENTIFIER = com.smilecare.Patient.RunnerTests;',
      ),
    );
    expect(pbx, isNot(contains(_currentIosId)));
    expect(
      snapshot['ios/Runner/Info.plist'],
      contains('<key>CFBundleDisplayName</key>\n\t<string>Smile Care</string>'),
    );

    // The payment checkout returns to `<androidApplicationId>://payment-return`.
    expect(
      snapshot['android/app/src/main/AndroidManifest.xml'],
      contains(
        '<data android:scheme="com.smilecare.patient" '
        'android:host="payment-return"/>',
      ),
    );
    expect(
      snapshot['android/app/src/main/AndroidManifest.xml'],
      isNot(contains('android:scheme="$_currentAndroidId"')),
    );
    expect(
      snapshot['ios/Runner/Info.plist'],
      contains('<string>com.smilecare.patient</string>'),
    );

    final manifest = jsonDecode(snapshot['web/manifest.json']!) as Map;
    expect(manifest['name'], 'Smile Care');
    expect(manifest['short_name'], 'Smile Care');
    expect(snapshot['web/index.html'], contains('<title>Smile Care</title>'));

    final brand = snapshot['lib/core/config/brand.g.dart']!;
    expect(brand, contains("static const nameEn = 'Smile Care';"));
    expect(brand, contains("static const taglineEn = 'Your smile\\'s home';"));
    expect(brand, contains('Color(0xFF112233)'));
    expect(brand, contains('Color(0xFFAABBCC)'));
    expect(brand, contains("'+201111111111'"));
    expect(brand, contains('guestBrowsing: false,'));
    expect(brand, contains('onlinePayments: true,'));
    expect(brand, contains('waitingList: false,'));
    expect(
      brand,
      contains("static const paymentReturnUrl = 'com.smilecare.patient://"),
    );

    // Second run: no changes at all.
    final second = applyBrand(dir.path, errors: errors);
    expect(second, isEmpty);
    expect(_snapshot(dir), snapshot);
    // And --check agrees.
    expect(applyBrand(dir.path, check: true, errors: errors), isEmpty);
    expect(errors, isEmpty);
  });

  group('validation', () {
    List<String> problemsAfter(void Function(Map<String, dynamic>) edit) {
      final dir = _scratchProject();
      _editConfig(dir, edit);
      final errors = <String>[];
      final changed = applyBrand(dir.path, errors: errors);
      expect(changed, isEmpty, reason: 'nothing is written when invalid');
      return errors;
    }

    test('rejects a bad slug, colour and phone', () {
      final errors = problemsAfter((c) {
        c['slug'] = 'Not A Slug';
        (c['colors'] as Map)['primary'] = 'blue';
        c['supportPhone'] = 'call me';
      });
      expect(errors, hasLength(3));
      expect(errors.join('\n'), contains('slug'));
      expect(errors.join('\n'), contains('colors.primary'));
      expect(errors.join('\n'), contains('supportPhone'));
    });

    test('rejects missing, unknown and mistyped fields', () {
      final errors = problemsAfter((c) {
        c.remove('tagline');
        c['extra'] = 1;
        (c['features'] as Map)['multiBranch'] = 'yes';
      });
      final text = errors.join('\n');
      expect(text, contains('missing "tagline"'));
      expect(text, contains('unknown property "extra"'));
      expect(text, contains('features.multiBranch: expected boolean'));
    });

    test('rejects a slug over 40 characters and a missing logo file', () {
      expect(
        problemsAfter((c) => c['slug'] = 'a' * 41).single,
        contains('longer than 40'),
      );
      expect(
        problemsAfter((c) => c['logo'] = 'branding/missing.svg').single,
        contains('does not exist'),
      );
    });
  });
}
