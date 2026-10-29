import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/storage/token_store.dart';
import 'package:moonlight/features/auth/data/auth_repository.dart';
import 'package:moonlight/features/auth/domain/phone_number.dart';

import '../support/fake_adapter.dart';
import '../support/fixtures.dart';

void main() {
  group('AuthRepository', () {
    test('requestOtp posts the phone without a token', () async {
      final adapter = FakeAdapter((_) => jsonResponse(null, status: 204));
      final repo = AuthRepository(testDio(adapter), InMemoryTokenStore());

      final result = await repo.requestOtp('+201012345678');

      expect(result.isRight(), isTrue);
      final request = adapter.requests.single;
      expect(request.path, '/auth/otp/request');
      expect(request.data, {'phone': '+201012345678'});
    });

    test('verifyOtp stores the tokens and returns the user', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'accessToken': 'a1',
          'refreshToken': 'r1',
          'expiresIn': 900,
          'isNewUser': true,
          'user': userJson(fullName: null),
        }),
      );
      final store = InMemoryTokenStore();
      final repo = AuthRepository(testDio(adapter), store);

      final login = (await repo.verifyOtp(
        '+201012345678',
        '123456',
      )).toNullable()!;

      expect(login.isNewUser, isTrue);
      expect(login.user.hasName, isFalse);
      expect(login.user.isPatient, isTrue);
      expect((await store.read())?.accessToken, 'a1');
      expect(adapter.requests.single.data, {
        'phone': '+201012345678',
        'code': '123456',
      });
    });

    test('a wrong code is an OTP_INVALID failure and stores nothing', () async {
      final adapter = FakeAdapter((_) => problem('OTP_INVALID', 400));
      final store = InMemoryTokenStore();
      final repo = AuthRepository(testDio(adapter), store);

      final result = await repo.verifyOtp('+201012345678', '000000');

      expect(result.getLeft().toNullable()?.code, 'OTP_INVALID');
      expect(await store.read(), isNull);
    });

    test(
      'logout clears local tokens even when the server is unreachable',
      () async {
        final adapter = FakeAdapter((_) => problem('INTERNAL_ERROR', 500));
        final store = InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        );
        final repo = AuthRepository(testDio(adapter), store);

        await repo.logout();

        expect(await store.read(), isNull);
        expect(adapter.requests.single.path, '/auth/logout');
        // The API revokes the token family named in the body.
        expect(adapter.requests.single.data, {'refreshToken': 'r'});
      },
    );
  });

  group('PhoneNumber.normalize', () {
    test('accepts the usual ways of writing an Egyptian mobile number', () {
      for (final input in [
        '01012345678',
        '1012345678',
        '+201012345678',
        '+20 101 234 5678',
        '00201012345678',
        '201012345678',
        '٠١٠١٢٣٤٥٦٧٨',
        '0101-234-5678',
      ]) {
        expect(PhoneNumber.normalize(input), '+201012345678', reason: input);
      }
    });

    test('rejects numbers that are not Egyptian mobiles', () {
      for (final input in [
        '',
        '0101234567',
        '01312345678',
        '+14155550123',
        'abc',
      ]) {
        expect(PhoneNumber.normalize(input), isNull, reason: input);
      }
    });
  });
}
