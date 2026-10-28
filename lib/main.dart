import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/env_provider.dart';

/// Shared startup for every flavor entry point.
void bootstrap(Env env) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(overrides: [envProvider.overrideWithValue(env)], child: const MoonlightApp()),
  );
}

void main() => bootstrap(Env.dev);
