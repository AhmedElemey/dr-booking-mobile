import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env.dart';

/// Overridden in bootstrap() with the entry point's [Env].
final envProvider = Provider<Env>(
  (ref) => throw UnimplementedError('envProvider must be overridden'),
);
