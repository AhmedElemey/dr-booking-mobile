// Applies clinic.config.json to the app.
//
//   dart run tool/apply_brand.dart            write the changes
//   dart run tool/apply_brand.dart --check    fail if anything would change
//
// It validates the config against clinic.config.schema.json, then
//  - generates lib/core/config/brand.g.dart (names, tagline, colours, support
//    phone, default feature switches),
//  - rewrites the Android applicationId / namespace / app label (and moves
//    MainActivity.kt into the matching package), the iOS bundle identifier and
//    display name, and the web manifest and page title.
//
// Running it twice changes nothing the second time. Plain Dart with no package
// dependencies, so it runs before `flutter pub get`.
import 'dart:convert';
import 'dart:io';

const featureKeys = [
  'mobileApp',
  'website',
  'guestBrowsing',
  'patientSelfService',
  'pushReminders',
  'smsNotifications',
  'englishLanguage',
  'multiBranch',
];

Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final check = args.contains('--check');
  final errors = <String>[];
  final changed = <String>[];
  try {
    changed.addAll(applyBrand(root, check: check, errors: errors));
  } on FormatException catch (e) {
    errors.add(e.message);
  }
  if (errors.isNotEmpty) {
    stderr.writeln('clinic.config.json is invalid:');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }
  if (check && changed.isNotEmpty) {
    stderr.writeln('Out of date, run `dart run tool/apply_brand.dart`:');
    for (final f in changed) {
      stderr.writeln('  - $f');
    }
    exit(1);
  }
  for (final f in changed) {
    stdout.writeln('updated $f');
  }
  if (changed.isEmpty) stdout.writeln('already up to date');
}

/// Validates the config under [root] and applies it. Returns the paths (relative
/// to [root]) that were, or with [check] would be, changed. Validation problems
/// are added to [errors] and nothing is written.
List<String> applyBrand(
  String root, {
  bool check = false,
  required List<String> errors,
}) {
  final configFile = File('$root/clinic.config.json');
  final schemaFile = File('$root/clinic.config.schema.json');
  if (!configFile.existsSync()) {
    errors.add('clinic.config.json not found in $root');
    return const [];
  }
  final Object? config;
  try {
    config = jsonDecode(configFile.readAsStringSync());
  } on FormatException catch (e) {
    errors.add('not valid JSON: ${e.message}');
    return const [];
  }
  final schema = jsonDecode(schemaFile.readAsStringSync());
  errors.addAll(validateAgainstSchema(config, schema as Map<String, dynamic>));
  if (errors.isNotEmpty) return const [];

  final c = config as Map<String, dynamic>;
  final logo = File('$root/${c['logo']}');
  if (!logo.existsSync()) {
    errors.add('logo: file "${c['logo']}" does not exist');
    return const [];
  }

  final writer = _Writer(root, check: check);
  final name = c['name'] as Map<String, dynamic>;
  final mobile = c['mobile'] as Map<String, dynamic>;
  final androidId = mobile['androidApplicationId'] as String;
  final iosId = mobile['iosBundleId'] as String;
  final nameEn = name['en'] as String;

  writer.write('lib/core/config/brand.g.dart', generateBrandDart(c));
  _android(writer, root, androidId, nameEn);
  _ios(writer, iosId, nameEn);
  _web(writer, nameEn);
  return writer.changed;
}

// --- validation ----------------------------------------------------------

/// Checks [value] against the subset of JSON Schema 2020-12 the config schema
/// uses: type, required, properties, additionalProperties, pattern, minLength,
/// maxLength, enum, const and local `$ref`s. Returns human-readable problems.
List<String> validateAgainstSchema(Object? value, Map<String, dynamic> schema) {
  final errors = <String>[];
  void walk(Object? v, Map<String, dynamic> s, String path) {
    final ref = s[r'$ref'];
    if (ref is String) {
      final target = _resolve(schema, ref);
      walk(v, target, path);
      return;
    }
    final label = path.isEmpty ? 'config' : path;
    final type = s['type'];
    if (type != null && !_isType(v, type as String)) {
      errors.add('$label: expected $type');
      return;
    }
    if (s.containsKey('const') && v != s['const']) {
      errors.add('$label: must be ${s['const']}');
    }
    final allowed = s['enum'];
    if (allowed is List && !allowed.contains(v)) {
      errors.add('$label: must be one of ${allowed.join(', ')}');
    }
    if (v is String) {
      final min = s['minLength'] as int?;
      final max = s['maxLength'] as int?;
      if (min != null && v.runes.length < min) {
        errors.add('$label: shorter than $min characters');
      }
      if (max != null && v.runes.length > max) {
        errors.add('$label: longer than $max characters');
      }
      final pattern = s['pattern'] as String?;
      if (pattern != null && !RegExp(pattern).hasMatch(v)) {
        errors.add('$label: "$v" does not match $pattern');
      }
    }
    if (v is Map) {
      final props = (s['properties'] as Map<String, dynamic>?) ?? const {};
      for (final key in (s['required'] as List?) ?? const []) {
        if (!v.containsKey(key)) errors.add('$label: missing "$key"');
      }
      for (final entry in v.entries) {
        final key = entry.key as String;
        final child = props[key];
        final childPath = path.isEmpty ? key : '$path.$key';
        if (child != null) {
          walk(entry.value, child as Map<String, dynamic>, childPath);
        } else if (s['additionalProperties'] == false) {
          errors.add('$label: unknown property "$key"');
        }
      }
    }
  }

  walk(value, schema, '');
  return errors;
}

Map<String, dynamic> _resolve(Map<String, dynamic> root, String ref) {
  if (!ref.startsWith('#/')) throw FormatException('Unsupported \$ref $ref');
  Object? node = root;
  for (final part in ref.substring(2).split('/')) {
    node = (node as Map<String, dynamic>)[part];
  }
  return node as Map<String, dynamic>;
}

bool _isType(Object? v, String type) => switch (type) {
  'object' => v is Map,
  'array' => v is List,
  'string' => v is String,
  'boolean' => v is bool,
  'integer' => v is int,
  'number' => v is num,
  'null' => v == null,
  _ => true,
};

// --- generated Dart ------------------------------------------------------

String _q(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}

String _color(String hex) => 'Color(0xFF${hex.substring(1).toUpperCase()})';

String generateBrandDart(Map<String, dynamic> c) {
  final name = c['name'] as Map<String, dynamic>;
  final tagline = c['tagline'] as Map<String, dynamic>;
  final colors = c['colors'] as Map<String, dynamic>;
  final website = c['website'] as Map<String, dynamic>;
  final features = c['features'] as Map<String, dynamic>;
  final b = StringBuffer()
    ..writeln('// GENERATED by tool/apply_brand.dart from clinic.config.json.')
    ..writeln('// Do not edit by hand; run `dart run tool/apply_brand.dart`.')
    ..writeln()
    ..writeln("import 'package:flutter/painting.dart' show Color;")
    ..writeln()
    ..writeln("import 'clinic_features.dart';")
    ..writeln()
    ..writeln('/// The clinic this build belongs to.')
    ..writeln('abstract final class Brand {')
    ..writeln('  static const slug = ${_q(c['slug'] as String)};')
    ..writeln('  static const nameAr = ${_q(name['ar'] as String)};')
    ..writeln('  static const nameEn = ${_q(name['en'] as String)};')
    ..writeln('  static const taglineAr = ${_q(tagline['ar'] as String)};')
    ..writeln('  static const taglineEn = ${_q(tagline['en'] as String)};')
    ..writeln(
      '  static const primary = ${_color(colors['primary'] as String)};',
    )
    ..writeln('  static const accent = ${_color(colors['accent'] as String)};')
    ..writeln(
      '  static const supportPhone = ${_q(c['supportPhone'] as String)};',
    )
    ..writeln(
      '  static const websiteDomain = ${_q(website['domain'] as String)};',
    )
    ..writeln()
    ..writeln(
      '  /// Used until the API answers, and whenever it cannot be reached.',
    )
    ..writeln('  static const defaultFeatures = ClinicFeatures(');
  for (final key in featureKeys) {
    b.writeln('    $key: ${features[key] as bool},');
  }
  b
    ..writeln('  );')
    ..writeln('}');
  return b.toString();
}

// --- platform files ------------------------------------------------------

class _Writer {
  _Writer(this.root, {required this.check});

  final String root;
  final bool check;
  final changed = <String>[];

  /// Writes [content] unless the file already has it.
  void write(String relative, String content) {
    final file = File('$root/$relative');
    final current = file.existsSync() ? file.readAsStringSync() : null;
    if (current == content) return;
    changed.add(relative);
    if (check) return;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String? read(String relative) {
    final file = File('$root/$relative');
    return file.existsSync() ? file.readAsStringSync() : null;
  }
}

void _android(_Writer w, String root, String id, String nameEn) {
  const gradle = 'android/app/build.gradle.kts';
  final text = w.read(gradle);
  if (text != null) {
    final out = text
        .replaceFirstMapped(
          RegExp(r'namespace = "[^"]*"'),
          (_) => 'namespace = "$id"',
        )
        .replaceFirstMapped(
          RegExp(r'applicationId = "[^"]*"'),
          (_) => 'applicationId = "$id"',
        )
        .replaceFirstMapped(
          RegExp(
            r'(create\("dev"\)[\s\S]*?manifestPlaceholders\["appName"\] = )"[^"]*"',
          ),
          (m) => '${m[1]}"$nameEn Dev"',
        )
        .replaceFirstMapped(
          RegExp(
            r'(create\("prod"\)[\s\S]*?manifestPlaceholders\["appName"\] = )"[^"]*"',
          ),
          (m) => '${m[1]}"$nameEn"',
        )
        .replaceFirstMapped(
          RegExp(r'// dev and prod installs coexist: \S+ / \S+\.'),
          (_) => '// dev and prod installs coexist: $id.dev / $id.',
        );
    w.write(gradle, out);
  }

  // The manifest names `.MainActivity` relative to the namespace, so the Kotlin
  // package (and its directory) must follow the id.
  final kotlinDir = Directory('$root/android/app/src/main/kotlin');
  if (!kotlinDir.existsSync()) return;
  final activity = kotlinDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('/MainActivity.kt'))
      .firstOrNull;
  if (activity == null) return;
  final target =
      'android/app/src/main/kotlin/${id.replaceAll('.', '/')}/MainActivity.kt';
  final source = activity.readAsStringSync();
  final rewritten = source.replaceFirstMapped(
    RegExp(r'^package .*$', multiLine: true),
    (_) => 'package $id',
  );
  final targetFile = File('$root/$target');
  if (activity.absolute.path == targetFile.absolute.path) {
    w.write(target, rewritten);
    return;
  }
  w.changed.add(target);
  if (w.check) return;
  targetFile.parent.createSync(recursive: true);
  targetFile.writeAsStringSync(rewritten);
  activity.deleteSync();
  // Prune package directories the move left empty.
  var dir = activity.parent;
  while (dir.path != kotlinDir.path &&
      dir.existsSync() &&
      dir.listSync().isEmpty) {
    dir.deleteSync();
    dir = dir.parent;
  }
}

void _ios(_Writer w, String id, String nameEn) {
  const pbx = 'ios/Runner.xcodeproj/project.pbxproj';
  final pbxText = w.read(pbx);
  if (pbxText != null) {
    w.write(
      pbx,
      pbxText.replaceAllMapped(
        RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);'),
        (m) => m[1]!.endsWith('.RunnerTests')
            ? 'PRODUCT_BUNDLE_IDENTIFIER = $id.RunnerTests;'
            : 'PRODUCT_BUNDLE_IDENTIFIER = $id;',
      ),
    );
  }
  const plist = 'ios/Runner/Info.plist';
  final plistText = w.read(plist);
  if (plistText != null) {
    w.write(
      plist,
      plistText.replaceFirstMapped(
        RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
        (m) => '${m[1]}${_xml(nameEn)}${m[2]}',
      ),
    );
  }
}

void _web(_Writer w, String nameEn) {
  const manifest = 'web/manifest.json';
  final text = w.read(manifest);
  if (text != null) {
    w.write(
      manifest,
      text
          .replaceFirstMapped(
            RegExp(r'("name":\s*)"[^"]*"'),
            (m) => '${m[1]}${jsonEncode(nameEn)}',
          )
          .replaceFirstMapped(
            RegExp(r'("short_name":\s*)"[^"]*"'),
            (m) => '${m[1]}${jsonEncode(nameEn)}',
          ),
    );
  }
  const index = 'web/index.html';
  final html = w.read(index);
  if (html != null) {
    w.write(
      index,
      html
          .replaceFirstMapped(
            RegExp(r'<title>[^<]*</title>'),
            (_) => '<title>${_xml(nameEn)}</title>',
          )
          .replaceFirstMapped(
            RegExp(
              r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(")',
            ),
            (m) => '${m[1]}${_xml(nameEn)}${m[2]}',
          )
          .replaceFirstMapped(
            RegExp(r'(<meta name="description" content=")[^"]*?:'),
            (m) => '${m[1]}${_xml(nameEn)}:',
          ),
    );
  }
}

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
