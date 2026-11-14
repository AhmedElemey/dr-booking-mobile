import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_store.dart';

/// Marks a request that must not carry a token or trigger a refresh
/// (`/auth/otp/*`, `/auth/refresh`).
const skipAuthKey = 'skipAuth';
const _retriedKey = 'retriedAfterRefresh';

/// Exchanges a refresh token for a new pair. Throws [DioException] on failure.
typedef RefreshCall = Future<AuthTokens> Function(String refreshToken);

/// Adds the bearer token and handles an expired access token transparently:
/// on `401` it refreshes once (single-flight, however many requests failed at
/// the same time) and replays the request with the new token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.tokenStore,
    required this.refresh,
    required this.onSessionExpired,
    required this.languageCode,
  });

  final Dio dio;
  final TokenStore tokenStore;
  final RefreshCall refresh;

  /// Called when the refresh token is rejected: the user has to log in again.
  final void Function() onSessionExpired;
  final String Function() languageCode;

  Future<AuthTokens?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept-Language'] = languageCode();
    if (options.extra[skipAuthKey] != true) {
      final tokens = await tokenStore.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isExpiredToken =
        err.response?.statusCode == 401 &&
        request.extra[skipAuthKey] != true &&
        request.extra[_retriedKey] != true &&
        request.headers['Authorization'] != null;
    if (!isExpiredToken) return handler.next(err);

    final usedHeader = request.headers['Authorization'] as String;
    final tokens = await _refreshTokens(usedHeader);
    if (tokens == null) return handler.next(err);

    try {
      final retry = request.copyWith(
        headers: {
          ...request.headers,
          'Authorization': 'Bearer ${tokens.accessToken}',
        },
        extra: {...request.extra, _retriedKey: true},
      );
      handler.resolve(await dio.fetch<dynamic>(retry));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<AuthTokens?> _refreshTokens(String failedAuthorization) async {
    // Another request may already have refreshed while this one was in flight.
    final current = await tokenStore.read();
    if (current != null &&
        'Bearer ${current.accessToken}' != failedAuthorization) {
      return current;
    }
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<AuthTokens?> _doRefresh() async {
    final current = await tokenStore.read();
    if (current == null) return null;
    try {
      final fresh = await refresh(current.refreshToken);
      await tokenStore.save(fresh);
      return fresh;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // Rejected (expired, revoked, reuse detected): the session is over.
      // A network error keeps the tokens so the next call can retry.
      if (status != null && status >= 400 && status < 500) {
        await tokenStore.clear();
        onSessionExpired();
      }
      return null;
    }
  }
}
