import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/config/env.dart';
import 'package:moonlight/core/config/env_provider.dart';
import 'package:moonlight/core/push/push_registrar.dart';
import 'package:moonlight/core/push/push_service.dart';
import 'package:moonlight/core/storage/local_settings.dart';
import 'package:moonlight/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_push.dart';

void main() {
  test(
    'registers the FCM token after login and removes it on logout',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = LocalSettings(await SharedPreferences.getInstance());
      final push = FakePushService();
      final container = ProviderContainer(
        overrides: [
          envProvider.overrideWithValue(Env.mock),
          localSettingsProvider.overrideWithValue(settings),
          pushServiceProvider.overrideWithValue(push),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(push.tokenController.close);
      await container
          .read(authRepositoryProvider)
          .verifyOtp('+201012345678', '123456');
      final registrar = container.read(pushRegistrarProvider);

      await registrar.onLogin();

      expect(push.initializeCalls, 1);
      expect(settings.deviceTokenId, 'device-token-1');

      await registrar.onLogout();
      expect(settings.deviceTokenId, isNull);
    },
  );

  test('without Firebase the no-op service registers nothing', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = LocalSettings(await SharedPreferences.getInstance());
    final container = ProviderContainer(
      overrides: [
        envProvider.overrideWithValue(Env.mock),
        localSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pushRegistrarProvider).onLogin();

    expect(settings.deviceTokenId, isNull);
    expect(await const NoopPushService().currentToken(), isNull);
  });
}
