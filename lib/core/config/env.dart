enum AppFlavor { dev, prod }

/// Per-flavor settings, chosen by the entry point (main_dev.dart / main_prod.dart).
class Env {
  const Env({required this.flavor, required this.apiBaseUrl});

  final AppFlavor flavor;
  final String apiBaseUrl;

  static const dev = Env(
    flavor: AppFlavor.dev,
    // Android emulator alias for the host machine's localhost.
    apiBaseUrl: 'http://10.0.2.2:5267',
  );

  // Set to the production API origin before the first prod release (M6).
  static const prod = Env(flavor: AppFlavor.prod, apiBaseUrl: '');
}
