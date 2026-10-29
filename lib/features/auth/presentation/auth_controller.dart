import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_registrar.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// The signed-in patient, or null for a guest. Loading while the stored session
/// is being restored at launch.
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final repo = ref.read(authRepositoryProvider);
    if (!await repo.hasTokens()) return null;
    final user = (await repo.me()).toNullable();
    if (user != null && user.isPatient) {
      _registerPush();
      return user;
    }
    return null;
  }

  /// Called after a successful OTP verification. Returns false when the account
  /// is a doctor/staff one: the patient app signs it straight back out.
  Future<bool> signIn(AppUser user) async {
    if (!user.isPatient) {
      await ref.read(authRepositoryProvider).clearTokens();
      return false;
    }
    state = AsyncData(user);
    _registerPush();
    return true;
  }

  /// Name changed in profile completion or settings.
  void userUpdated(AppUser user) => state = AsyncData(user);

  Future<void> logout() async {
    await ref.read(pushRegistrarProvider).onLogout();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  /// The refresh token was rejected: back to guest, tokens already cleared.
  void sessionExpired() {
    if (state.isLoading) return;
    state = const AsyncData(null);
  }

  void _registerPush() {
    // Fire and forget: push problems must never block the UI.
    ref.read(pushRegistrarProvider).onLogin().ignore();
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
