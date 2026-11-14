import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../../../core/storage/token_store.dart';
import '../domain/app_user.dart';

/// `{accessToken, refreshToken, …}` from `/auth/refresh` and `/auth/otp/verify`.
AuthTokens tokensFromJson(Map<String, dynamic> json) => AuthTokens(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
);

class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;

  static final _anonymous = Options(extra: {skipAuthKey: true});

  ApiResult<void> requestOtp(String phone) => guardApi(() async {
    await _dio.post<void>(
      '/auth/otp/request',
      data: {'phone': phone},
      options: _anonymous,
    );
  });

  /// Verifies the code, stores the token pair and returns the user.
  ApiResult<VerifiedLogin> verifyOtp(String phone, String code) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/otp/verify',
          data: {'phone': phone, 'code': code},
          options: _anonymous,
        );
        final json = response.data!;
        await _tokens.save(tokensFromJson(json));
        return VerifiedLogin(
          user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
          isNewUser: json['isNewUser'] as bool? ?? false,
        );
      });

  ApiResult<AppUser> me() => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/me');
    return AppUser.fromJson(response.data!);
  });

  /// Revokes the refresh-token family. Local tokens are dropped even if the
  /// server cannot be reached, so logout always works.
  Future<void> logout() async {
    try {
      final tokens = await _tokens.read();
      await _dio.post<void>(
        '/auth/logout',
        data: {'refreshToken': tokens?.refreshToken},
      );
    } on DioException {
      // Nothing to do: the server expires the family on its own.
    } finally {
      await _tokens.clear();
    }
  }

  Future<bool> hasTokens() async => await _tokens.read() != null;

  Future<void> clearTokens() => _tokens.clear();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      AuthRepository(ref.watch(dioProvider), ref.watch(tokenStoreProvider)),
);
