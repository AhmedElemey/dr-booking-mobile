import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/profile_repository.dart';
import '../storage/local_settings.dart';
import 'push_service.dart';

/// Keeps the backend's `DeviceToken` row in step with the login state:
/// register after login (and on token rotation), unregister before logout.
class PushRegistrar {
  PushRegistrar(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _refreshes;

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'Ios' : 'Android';

  Future<void> onLogin() async {
    final push = _ref.read(pushServiceProvider);
    await push.initialize();
    await _register(await push.currentToken());
    unawaited(_refreshes?.cancel());
    _refreshes = push.tokenRefreshes.listen(_register);
  }

  /// Must run while the access token is still valid (before logout).
  Future<void> onLogout() async {
    unawaited(_refreshes?.cancel());
    _refreshes = null;
    final settings = _ref.read(localSettingsProvider);
    final id = settings.deviceTokenId;
    if (id == null) return;
    await _ref.read(profileRepositoryProvider).unregisterDeviceToken(id);
    await settings.setDeviceTokenId(null);
  }

  Future<void> _register(String? token) async {
    if (token == null) return;
    final result = await _ref
        .read(profileRepositoryProvider)
        .registerDeviceToken(token, _platform);
    final id = result.toNullable();
    if (id != null) {
      await _ref.read(localSettingsProvider).setDeviceTokenId(id);
    }
  }

  void dispose() => _refreshes?.cancel();
}

final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  final registrar = PushRegistrar(ref);
  ref.onDispose(registrar.dispose);
  return registrar;
});
