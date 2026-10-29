import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/data/auth_repository.dart' show tokensFromJson;
import '../config/env.dart';
import '../config/env_provider.dart';
import '../l10n/locale_controller.dart';
import '../mock/mock_api_adapter.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => ref.watch(envProvider).useMockApi
      ? InMemoryTokenStore()
      : SecureTokenStore(),
);

/// The one authenticated HTTP client every repository uses.
final dioProvider = Provider<Dio>((ref) {
  final env = ref.watch(envProvider);
  // One mock backend shared by both clients, so refreshed tokens stay valid.
  final mock = env.useMockApi ? MockApiAdapter() : null;
  final dio = _newDio(env, mock);

  // Refreshing goes through a bare client so it never re-enters the interceptor.
  final refreshDio = _newDio(env, mock);
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokenStore: ref.watch(tokenStoreProvider),
      languageCode: () => ref.read(localeProvider).languageCode,
      onSessionExpired: () =>
          ref.read(authControllerProvider.notifier).sessionExpired(),
      refresh: (refreshToken) async {
        final response = await refreshDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
        return tokensFromJson(response.data!);
      },
    ),
  );
  ref.onDispose(() {
    dio.close();
    refreshDio.close();
  });
  return dio;
});

Dio _newDio(Env env, MockApiAdapter? mock) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '${env.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  if (mock != null) dio.httpClientAdapter = mock;
  return dio;
}
