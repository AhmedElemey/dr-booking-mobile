import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/l10n/failure_messages.dart';
import 'package:moonlight/core/l10n/generated/app_localizations.dart';
import 'package:moonlight/core/network/failure.dart';

DioException _error({int? status, Object? data}) {
  final request = RequestOptions(path: '/x');
  return DioException(
    requestOptions: request,
    response: status == null
        ? null
        : Response(requestOptions: request, statusCode: status, data: data),
  );
}

void main() {
  group('Failure.fromDio', () {
    test('reads the code, detail and field errors of a problem+json body', () {
      final failure = Failure.fromDio(
        _error(
          status: 400,
          data: {
            'code': 'VALIDATION_FAILED',
            'detail': 'Bad input',
            'errors': {
              'startsAt': ['too early'],
            },
          },
        ),
      );

      expect(failure.code, 'VALIDATION_FAILED');
      expect(failure.statusCode, 400);
      expect(failure.detail, 'Bad input');
      expect(failure.fieldErrors['startsAt'], ['too early']);
    });

    test('falls back to the status when there is no code', () {
      expect(Failure.fromDio(_error(status: 401)).code, 'UNAUTHORIZED');
      expect(Failure.fromDio(_error(status: 429)).code, 'RATE_LIMITED');
      expect(Failure.fromDio(_error(status: 502)).code, 'INTERNAL_ERROR');
    });

    test('no response means a network failure', () {
      expect(Failure.fromDio(_error()).code, Failure.network);
    });
  });

  group('localized messages', () {
    final codes = [
      Failure.network,
      'OTP_INVALID',
      'OTP_EXPIRED',
      'FORBIDDEN',
      'SLOT_TAKEN',
      'SLOT_UNAVAILABLE',
      'CANCEL_WINDOW_PASSED',
      'INVALID_TRANSITION',
      'BOOKING_LIMIT',
      'RATE_LIMITED',
      'INTERNAL_ERROR',
    ];

    for (final lang in ['ar', 'en']) {
      test('every API code has its own $lang text', () async {
        final l10n = await AppLocalizations.delegate.load(Locale(lang));
        final messages = {
          for (final code in codes)
            code: l10n.failureMessage(Failure(code: code)),
        };

        expect(messages.values.toSet(), hasLength(codes.length));
        expect(messages.values, everyElement(isNotEmpty));
      });
    }

    test(
      'unknown codes show the server detail, else a generic message',
      () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        expect(
          l10n.failureMessage(const Failure(code: 'NEW_CODE', detail: 'Hello')),
          'Hello',
        );
        expect(
          l10n.failureMessage(const Failure(code: 'NEW_CODE')),
          l10n.errUnknown,
        );
      },
    );
  });

  test('guardApi folds Dio and parsing errors into Left', () async {
    final dioFailure = await guardApi<int>(
      () async => throw _error(status: 409, data: {'code': 'SLOT_TAKEN'}),
    );
    final parseFailure = await guardApi<int>(
      () async => throw const FormatException('bad'),
    );
    final ok = await guardApi(() async => 7);

    expect(dioFailure.getLeft().toNullable()?.code, 'SLOT_TAKEN');
    expect(parseFailure.getLeft().toNullable()?.code, Failure.unknown);
    expect(ok.toNullable(), 7);
  });
}
