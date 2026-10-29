enum AppFlavor { dev, prod }

/// Per-flavor settings, chosen by the entry point (main_dev.dart / main_prod.dart /
/// main_mock.dart).
class Env {
  const Env({
    required this.flavor,
    required this.apiBaseUrl,
    this.useMockApi = false,
  });

  final AppFlavor flavor;
  final String apiBaseUrl;

  /// Serve every API call from in-app fixtures instead of the network (demo mode).
  final bool useMockApi;

  static const dev = Env(
    flavor: AppFlavor.dev,
    // Android emulator alias for the host machine's localhost; override with
    // --dart-define=API_BASE_URL=http://localhost:5267 for web or iOS.
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5267',
    ),
  );

  // Set to the production API origin before the first prod release (M6).
  static const prod = Env(flavor: AppFlavor.prod, apiBaseUrl: '');

  /// Demo mode: fixtures only, no backend needed (lib/main_mock.dart).
  static const mock = Env(
    flavor: AppFlavor.dev,
    apiBaseUrl: 'https://mock.moonlight.local',
    useMockApi: true,
  );
}
