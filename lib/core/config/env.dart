enum AppFlavor { dev, prod }

/// Per-flavor settings, chosen by the entry point (main_dev.dart / main_prod.dart /
/// main_mock.dart).
class Env {
  const Env({
    required this.flavor,
    required this.apiBaseUrl,
    this.useMockApi = false,
    this.demoData = false,
    this.hostedTest = false,
  });

  final AppFlavor flavor;
  final String apiBaseUrl;

  /// Serve every API call from in-app fixtures instead of the network (demo mode).
  final bool useMockApi;

  /// Demo mode only: extra showcase data (a video visit open to join now).
  final bool demoData;

  /// True only on the hosted test deployment; shows the synthetic-data banner
  /// on the login screen. Off everywhere else, including real clinic builds.
  final bool hostedTest;

  static const dev = Env(
    flavor: AppFlavor.dev,
    // Android emulator alias for the host machine's localhost; override with
    // --dart-define=API_BASE_URL=http://localhost:5267 for web or iOS.
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5267',
    ),
  );

  /// A production build must point at the real HTTPS backend, never fixtures.
  static Env get prod =>
      production(const String.fromEnvironment('API_BASE_URL'));

  static Env production(String apiOrigin) {
    final uri = Uri.tryParse(apiOrigin);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError(
        'API_BASE_URL must be an HTTPS origin without credentials, path or query.',
      );
    }
    return Env(
      flavor: AppFlavor.prod,
      apiBaseUrl: uri.origin,
      hostedTest: const String.fromEnvironment('HOSTED_TEST') == '1',
    );
  }

  /// Demo mode: fixtures only, no backend needed (lib/main_mock.dart).
  static const mock = Env(
    flavor: AppFlavor.dev,
    apiBaseUrl: 'https://mock.moonlight.local',
    useMockApi: true,
  );

  /// The demo build (lib/main_mock.dart): the mock API plus showcase data.
  static const demo = Env(
    flavor: AppFlavor.dev,
    apiBaseUrl: 'https://mock.moonlight.local',
    useMockApi: true,
    demoData: true,
  );
}
