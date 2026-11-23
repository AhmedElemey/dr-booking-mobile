import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/config/env.dart';

void main() {
  test(
    'production uses the configured HTTPS origin, without a trailing slash',
    () {
      final env = Env.production('https://api.example.invalid:8443/');
      expect(env.apiBaseUrl, 'https://api.example.invalid:8443');
      expect(env.flavor, AppFlavor.prod);
      expect(env.useMockApi, isFalse);
    },
  );

  for (final invalid in [
    '',
    'http://localhost:5267',
    'https://',
    'https://user:password@api.example.invalid',
    'https://api.example.invalid/api/v1',
    'https://api.example.invalid?token=x',
    'https://api.example.invalid#fragment',
  ]) {
    test('production rejects an invalid origin: $invalid', () {
      expect(() => Env.production(invalid), throwsArgumentError);
    });
  }

  test('production entry point reads API_BASE_URL from the build', () {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isEmpty) {
      expect(() => Env.prod, throwsArgumentError);
    } else {
      expect(Env.prod.apiBaseUrl, Uri.parse(configured).origin);
      expect(Env.prod.useMockApi, isFalse);
    }
  });
}
