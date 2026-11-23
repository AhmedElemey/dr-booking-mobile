import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/format/arabic_digits.dart';
import 'core/config/env_provider.dart';
import 'core/storage/local_settings.dart';

/// Shared startup for every entry point.
Future<void> bootstrap(Env env) async {
  WidgetsFlutterBinding.ensureInitialized();
  useArabicIndicDigits();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        envProvider.overrideWithValue(env),
        localSettingsProvider.overrideWithValue(LocalSettings(prefs)),
      ],
      child: const MoonlightApp(),
    ),
  );
}

Future<void> main() => bootstrap(Env.dev);
