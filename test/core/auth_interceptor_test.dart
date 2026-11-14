import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/network/auth_interceptor.dart';
import 'package:moonlight/core/storage/token_store.dart';

import '../support/fake_adapter.dart';

void main() {
  late InMemoryTokenStore store;
  late FakeAdapter adapter;
  late Dio dio;
  late int refreshCalls;
  late int expiredCalls;
  Future<AuthTokens> Function(String) refresh = (_) async =>
      throw StateError('');

  /// An API that only accepts `Bearer fresh-access`.
  void setUp0({Future<AuthTokens> Function(String)? onRefresh}) {
    store = InMemoryTokenStore(
      const AuthTokens(accessToken: 'stale-access', refreshToken: 'refresh-1'),
    );
    refreshCalls = 0;
    expiredCalls = 0;
    refresh =
        onRefresh ??
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const AuthTokens(
            accessToken: 'fresh-access',
            refreshToken: 'refresh-2',
          );
        };
    adapter = FakeAdapter((options) async {
      // '/slow' answers late, after other requests have already refreshed.
      if (options.path == '/slow') {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      final ok = options.headers['Authorization'] == 'Bearer fresh-access';
      return ok
          ? jsonResponse({'path': options.path})
          : problem('UNAUTHORIZED', 401);
    });
    dio = testDio(adapter);
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        tokenStore: store,
        languageCode: () => 'ar',
        onSessionExpired: () => expiredCalls++,
        refresh: (token) {
          refreshCalls++;
          return refresh(token);
        },
      ),
    );
  }

  test('sends the bearer token and the app language', () async {
    setUp0();
    await store.save(
      const AuthTokens(accessToken: 'fresh-access', refreshToken: 'r'),
    );

    await dio.get<dynamic>('/me');

    final sent = adapter.requests.single.headers;
    expect(sent['Authorization'], 'Bearer fresh-access');
    expect(sent['Accept-Language'], 'ar');
    expect(refreshCalls, 0);
  });

  test('expired access token: refreshes, retries and succeeds', () async {
    setUp0();

    final response = await dio.get<Map<String, dynamic>>('/appointments');

    expect(response.data, {'path': '/appointments'});
    expect(refreshCalls, 1);
    final tokens = await store.read();
    expect(tokens?.accessToken, 'fresh-access');
    expect(tokens?.refreshToken, 'refresh-2');
    // First attempt with the stale token, then the replay with the new one.
    expect(adapter.requests.map((r) => r.headers['Authorization']), [
      'Bearer stale-access',
      'Bearer fresh-access',
    ]);
    expect(expiredCalls, 0);
  });

  test('concurrent 401s trigger a single refresh', () async {
    setUp0();

    final responses = await Future.wait([
      dio.get<dynamic>('/appointments'),
      dio.get<dynamic>('/me'),
      dio.get<dynamic>('/appointments/apt-1'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(refreshCalls, 1);
  });

  test(
    'a late 401 for an already-replaced token retries without refreshing again',
    () async {
      setUp0();
      // Slow first request: by the time it fails, another one has refreshed.
      final first = dio.get<dynamic>('/a');
      await dio.get<dynamic>('/b');
      await first;

      expect(refreshCalls, 1);
    },
  );

  test('rejected refresh token: error surfaces, session cleared', () async {
    setUp0(
      onRefresh: (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          statusCode: 401,
        ),
      ),
    );

    await expectLater(
      dio.get<dynamic>('/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );

    expect(await store.read(), isNull);
    expect(expiredCalls, 1);
  });

  test('network failure while refreshing keeps the tokens', () async {
    setUp0(
      onRefresh: (_) async => throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        reason: 'offline',
      ),
    );

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));

    expect((await store.read())?.refreshToken, 'refresh-1');
    expect(expiredCalls, 0);
  });

  test('requests marked skipAuth carry no token and never refresh', () async {
    setUp0();

    await expectLater(
      dio.post<dynamic>(
        '/auth/otp/verify',
        options: Options(extra: {skipAuthKey: true}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requests.single.headers['Authorization'], isNull);
    expect(refreshCalls, 0);
  });

  test('does not loop when the replayed request is still rejected', () async {
    setUp0(
      onRefresh: (_) async =>
          const AuthTokens(accessToken: 'still-bad', refreshToken: 'r3'),
    );

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));

    expect(refreshCalls, 1);
    expect(adapter.requests, hasLength(2));
  });
}
