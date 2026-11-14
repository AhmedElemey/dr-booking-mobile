import 'core/config/env.dart';
import 'main.dart';

/// Demo mode: every API call is answered by in-app fixtures (see
/// core/mock/mock_api_adapter.dart). Log in with any phone and code 123456.
Future<void> main() => bootstrap(Env.demo);
