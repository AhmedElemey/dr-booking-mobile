import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:moonlight/core/format/clinic_time.dart';
import 'package:moonlight/core/links/url_opener.dart';
import 'package:moonlight/core/network/failure.dart';
import 'package:moonlight/core/network/feature_disabled_interceptor.dart';
import 'package:moonlight/features/appointments/domain/appointment.dart';
import 'package:moonlight/features/booking/domain/booking_issue.dart';
import 'package:moonlight/features/doctor/domain/doctor_slots.dart';
import 'package:moonlight/features/payments/domain/payment.dart';
import 'package:moonlight/features/records/data/records_repository.dart';
import 'package:moonlight/features/records/domain/patient_records.dart';
import 'package:moonlight/features/waiting_list/domain/waiting_entry.dart';
import 'package:moonlight/shared/widgets/input_formatters.dart';

import '../support/fake_adapter.dart';
import '../support/fixtures.dart';

Appointment _appointment(
  String payment, {
  num total = 300,
  bool future = true,
}) => Appointment.fromJson({
  ...appointmentJson(),
  'startsAt': future
      ? DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String()
      : '2020-01-01T10:00:00Z',
  'endsAt': future
      ? DateTime.now()
            .toUtc()
            .add(const Duration(days: 2, minutes: 30))
            .toIso8601String()
      : '2020-01-01T10:30:00Z',
  'paymentStatus': payment,
  'totalEgp': total,
});

void main() {
  group('safeWebUri', () {
    test('accepts https and, only when allowed, http', () {
      expect(safeWebUri('https://meet.jit.si/room-1')?.host, 'meet.jit.si');
      expect(
        safeWebUri('http://10.0.2.2:5267/pay/1', allowHttp: true),
        isNotNull,
      );
      expect(
        safeWebUri('http://10.0.2.2:5267/pay/1', allowHttp: false),
        isNull,
      );
      expect(safeWebUri('HTTPS://Example.com/x'), isNotNull);
    });

    test('rejects other schemes, relative and malformed values', () {
      for (final bad in [
        'tel:+20100000000',
        'sms:+20100000000',
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'com.evil.app://payment-return',
        '/uploads/x.pdf',
        'https://',
        'http://[bad',
        '',
        '   ',
      ]) {
        expect(safeWebUri(bad, allowHttp: true), isNull, reason: bad);
      }
      expect(safeWebUri(null), isNull);
    });

    test(
      'the platform opener refuses an unsafe link without calling out',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final open = container.read(urlOpenerProvider);
        expect(await open(Uri.parse('tel:123')), isFalse);
        expect(await open(Uri.parse('intent://x#Intent;end')), isFalse);
      },
    );

    test('closing the in-app browser never throws', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(inAppBrowserCloserProvider)();
    });
  });

  group('payment retry', () {
    test('an unpaid or pending upcoming visit can be paid', () {
      expect(_appointment('Unpaid').canPayOnline, isTrue);
      expect(_appointment('Unpaid').isPaymentPending, isFalse);
      final pending = _appointment('Pending');
      expect(pending.canPayOnline, isTrue);
      expect(pending.isPaymentPending, isTrue);
    });

    test('paid, refunded, past and free visits cannot', () {
      expect(_appointment('Paid').canPayOnline, isFalse);
      expect(_appointment('Refunded').canPayOnline, isFalse);
      expect(_appointment('Pending', future: false).canPayOnline, isFalse);
      expect(_appointment('Pending', total: 0).canPayOnline, isFalse);
      expect(
        AppointmentPaymentStatus.parse('Pending'),
        AppointmentPaymentStatus.pending,
      );
    });
  });

  group('booking validation issues', () {
    Failure refused(String key) => Failure(
      code: 'VALIDATION_FAILED',
      statusCode: 422,
      fieldErrors: {
        key: ['x'],
      },
    );

    test('known field keys map to an issue', () {
      expect(BookingIssue.from(refused('mode')), BookingIssue.mode);
      expect(
        BookingIssue.from(refused('insurance.providerId')),
        BookingIssue.insuranceProvider,
      );
      expect(
        BookingIssue.from(refused('insurance.memberNumber')),
        BookingIssue.insuranceMemberNumber,
      );
      expect(
        BookingIssue.from(refused('familyMemberId')),
        BookingIssue.familyMember,
      );
    });

    test('anything else keeps the generic message', () {
      expect(BookingIssue.from(refused('note')), isNull);
      expect(BookingIssue.from(const Failure(code: 'SLOT_TAKEN')), isNull);
      expect(
        BookingIssue.from(
          const Failure(
            code: 'NOT_FOUND',
            fieldErrors: {
              'mode': ['x'],
            },
          ),
        ),
        isNull,
      );
    });

    test('field errors are read from the problem body', () async {
      final dio = testDio(
        FakeAdapter(
          (_) => jsonResponse({
            'status': 422,
            'code': 'VALIDATION_FAILED',
            'errors': {
              'insurance.providerId': [
                'The doctor does not accept this insurance provider.',
              ],
            },
          }, status: 422),
        ),
      );
      final result = await guardApi(() => dio.get<void>('/x'));
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      expect(BookingIssue.from(failure!), BookingIssue.insuranceProvider);
    });
  });

  group('FEATURE_DISABLED', () {
    test('triggers a switch refresh, once per failed call', () async {
      var refreshes = 0;
      final adapter = FakeAdapter(
        (o) => o.path.endsWith('/features')
            ? problem('FEATURE_DISABLED', 403)
            : problem('FEATURE_DISABLED', 403),
      );
      final dio = testDio(adapter)
        ..interceptors.add(FeatureDisabledInterceptor(() => refreshes++));
      await guardApi(() => dio.post<void>('/waiting-list'));
      expect(refreshes, 1);
      await guardApi(() => dio.get<void>('/features'));
      expect(refreshes, 1, reason: 'the features call itself never loops');
    });

    test('other errors do not', () async {
      var refreshes = 0;
      final dio = testDio(FakeAdapter((_) => problem('FORBIDDEN', 403)))
        ..interceptors.add(FeatureDisabledInterceptor(() => refreshes++));
      await guardApi(() => dio.get<void>('/me'));
      expect(refreshes, 0);
    });
  });

  group('dates for the API', () {
    test('apiDate is ASCII whatever the default locale', () {
      final saved = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = saved);
      Intl.defaultLocale = 'ar_EG';
      expect(ClinicTime.apiDate(DateTime(2026, 3, 7)), '2026-03-07');
      expect(ClinicTime.apiDate(DateTime(987, 1, 2)), '0987-01-02');
    });

    test('clinicToday comes from a slot, not the device zone', () {
      // Cairo is UTC+2 here: 23:30 UTC on the 14th is already the 15th there.
      final slots = DoctorSlots(
        doctorId: 'd',
        timezone: 'Africa/Cairo',
        days: [
          SlotDay(
            date: '2026-11-16',
            slots: [
              Slot(
                id: 's',
                startsAt: DateTime.utc(2026, 11, 16, 7),
                endsAt: DateTime.utc(2026, 11, 16, 7, 30),
                local: '09:00',
              ),
            ],
          ),
        ],
      );
      expect(
        slots.clinicToday(DateTime.utc(2026, 11, 14, 23, 30)),
        DateTime(2026, 11, 15),
      );
      expect(
        slots.clinicToday(DateTime.utc(2026, 11, 14, 21, 59)),
        DateTime(2026, 11, 14),
      );
      expect(
        const DoctorSlots(
          doctorId: 'd',
          timezone: 'x',
          days: [],
        ).clinicToday(DateTime.now()),
        isNull,
      );
    });
  });

  group('waiting entries and records', () {
    test('the waiting entry carries who it is for', () {
      final base = {
        'id': 'w1',
        'doctor': {'id': 'd1', 'name': 'Dr. A'},
        'date': '2026-11-20',
        'status': 'Waiting',
      };
      final mine = WaitingEntry.fromJson({...base, 'familyMember': null});
      expect(mine.familyMember, isNull);
      expect(WaitingEntry.fromJson(base).familyMember, isNull);
      final child = WaitingEntry.fromJson({
        ...base,
        'familyMember': {
          'id': 'f1',
          'fullName': 'Omar Ahmed',
          'relation': 'Child',
        },
      });
      expect(child.familyMember!.fullName, 'Omar Ahmed');
      expect(child.familyMember!.id, 'f1');
    });

    test('records: attachment flag and doctor name', () {
      final base = {
        'id': 'r',
        'kind': 'Note',
        'title': 't',
        'createdAt': '2026-10-01T10:00:00Z',
      };
      expect(RecordEntry.fromJson(base).hasAttachment, isFalse);
      expect(
        RecordEntry.fromJson({...base, 'attachmentUrl': ''}).hasAttachment,
        isFalse,
      );
      expect(
        RecordEntry.fromJson({...base, 'hasAttachment': true}).hasAttachment,
        isTrue,
      );
      final withUrl = RecordEntry.fromJson({
        ...base,
        'attachmentUrl': 'https://x/uploads/a.pdf',
        'doctorName': 'Dr. Amr Hassan',
      });
      expect(withUrl.hasAttachment, isTrue);
      expect(withUrl.doctorName, 'Dr. Amr Hassan');
    });
  });

  group('attachment download', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('attach_'));
    tearDown(() => temp.deleteSync(recursive: true));

    ResponseBody bytes(
      List<int> data,
      Map<String, String> headers, {
      int status = 200,
    }) => ResponseBody.fromBytes(
      data,
      status,
      headers: {
        for (final e in headers.entries) e.key: [e.value],
      },
    );

    test(
      'uses the authorized endpoint and writes a file named by the server',
      () async {
        final adapter = FakeAdapter(
          (_) => bytes(utf8.encode('%PDF-1.4'), {
            'content-type': 'application/pdf',
            'content-disposition': 'attachment; filename="../x-ray 1.pdf"',
          }),
        );
        final repo = RecordsRepository(
          testDio(adapter),
          tempDir: () async => temp,
        );
        final file = (await repo.downloadAttachment('rec-3')).toNullable()!;
        expect(adapter.requests.single.method, 'GET');
        expect(adapter.requests.single.path, '/me/records/rec-3/attachment');
        expect(adapter.requests.single.responseType, ResponseType.bytes);
        expect(file.path.startsWith(temp.path), isTrue);
        expect(file.path.endsWith('/x-ray_1.pdf'), isTrue);
        expect(file.readAsStringSync(), '%PDF-1.4');
      },
    );

    test('falls back to the content type for the extension', () async {
      final repo = RecordsRepository(
        testDio(
          FakeAdapter((_) => bytes([1, 2, 3], {'content-type': 'image/png'})),
        ),
        tempDir: () async => temp,
      );
      final file = (await repo.downloadAttachment('r1')).toNullable()!;
      expect(file.path.endsWith('/attachment.png'), isTrue);
    });

    test('a refused download is a Failure, not a file', () async {
      final repo = RecordsRepository(
        testDio(FakeAdapter((_) => problem('NOT_FOUND', 404))),
        tempDir: () async => temp,
      );
      final result = await repo.downloadAttachment('missing');
      expect(result.fold((f) => f.code, (_) => 'file'), 'NOT_FOUND');
      expect(Directory('${temp.path}/attachments').existsSync(), isFalse);
    });

    test('file names are sanitised', () {
      expect(
        attachmentFileName(
          contentDisposition: 'attachment; filename*=UTF-8\'\'a%20b.pdf',
        ),
        'a_b.pdf',
      );
      expect(
        attachmentFileName(contentType: 'application/octet-stream'),
        'attachment',
      );
      expect(
        attachmentFileName(contentDisposition: 'attachment; filename=".."'),
        'attachment',
      );
    });
  });

  test('leading spaces are dropped from names and member numbers', () {
    final formatted = noLeadingSpace.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '  Omar',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    expect(formatted.text, 'Omar');
  });
}
