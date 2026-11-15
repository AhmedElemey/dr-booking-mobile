import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/config/brand.g.dart';
import 'package:moonlight/core/l10n/failure_messages.dart';
import 'package:moonlight/core/l10n/generated/app_localizations_ar.dart';
import 'package:moonlight/core/l10n/generated/app_localizations_en.dart';
import 'package:moonlight/core/network/failure.dart';
import 'package:moonlight/features/appointments/domain/appointment.dart';
import 'package:moonlight/features/auth/domain/app_user.dart';
import 'package:moonlight/features/doctor/domain/doctor.dart';
import 'package:moonlight/features/doctor/domain/doctor_slots.dart';
import 'package:moonlight/features/family/domain/family_member.dart';
import 'package:moonlight/features/insurance/domain/insurance.dart';
import 'package:moonlight/features/payments/domain/payment.dart';
import 'package:moonlight/features/payments/presentation/payment_flow.dart';
import 'package:moonlight/features/promotions/domain/promotion.dart';
import 'package:moonlight/features/records/domain/patient_records.dart';
import 'package:moonlight/features/waiting_list/domain/waiting_entry.dart';

import '../support/fixtures.dart';

void main() {
  group('Appointment', () {
    test('phase 2 fields default sensibly when absent', () {
      final a = Appointment.fromJson(appointmentJson());
      expect(a.familyMember, isNull);
      expect(a.mode, AppointmentMode.inPerson);
      expect(a.paymentStatus, AppointmentPaymentStatus.unpaid);
      expect(a.canReview, isFalse);
      expect(a.insurance, isNull);
      expect(a.discountEgp, 0);
    });

    test('parses family member, price, insurance, mode and review', () {
      final a = Appointment.fromJson({
        ...appointmentJson(status: 'Completed'),
        'familyMember': {
          'id': 'fam-1',
          'fullName': 'Youssef',
          'relation': 'Child',
        },
        'mode': 'Video',
        'priceEgp': 300,
        'discountEgp': 60,
        'totalEgp': 240,
        'paymentStatus': 'Paid',
        'insurance': {
          'provider': {'id': 'ins-1', 'name': 'Bupa Egypt'},
          'memberNumber': 'B-1',
          'status': 'Approved',
          'note': 'ok',
        },
        'canReview': false,
        'review': {'rating': 5, 'comment': 'Great'},
      });
      expect(a.familyMember!.relation, FamilyRelation.child);
      expect(a.isVideo, isTrue);
      expect(a.totalEgp, 240);
      expect(a.paymentStatus, AppointmentPaymentStatus.paid);
      expect(a.insurance!.status, InsuranceStatus.approved);
      expect(a.insurance!.provider.name, 'Bupa Egypt');
      expect(a.review!.rating, 5);
    });

    test('the video window runs from 15 minutes before to 30 after', () {
      final a = Appointment.fromJson({
        ...appointmentJson(),
        'mode': 'Video',
      }); // 07:00-07:30Z
      expect(a.isVideoOpen(DateTime.utc(2026, 11, 2, 6, 44)), isFalse);
      expect(a.isVideoOpen(DateTime.utc(2026, 11, 2, 6, 45)), isTrue);
      expect(a.isVideoOpen(DateTime.utc(2026, 11, 2, 7, 59)), isTrue);
      expect(a.isVideoOpen(DateTime.utc(2026, 11, 2, 8, 1)), isFalse);
    });
  });

  test('Doctor reads rating, video and accepted insurers', () {
    final d = Doctor.fromJson({
      'id': 'd1',
      'name': 'Dr. A',
      'offersVideo': true,
      'rating': {'average': 4.8, 'count': 126},
      'insuranceProviders': [
        {'id': 'ins-1', 'name': 'AXA'},
      ],
    });
    expect(d.offersVideo, isTrue);
    expect(d.rating!.count, 126);
    expect(d.insuranceProviders.single.name, 'AXA');
    expect(
      Doctor.fromJson({'id': 'd', 'name': 'x', 'rating': null}).rating,
      isNull,
    );
  });

  test('DoctorSlots reads closedDates', () {
    final s = DoctorSlots.fromJson({
      'doctorId': 'd1',
      'timezone': 'Africa/Cairo',
      'days': <Object>[],
      'closedDates': [
        {'date': '2026-11-19', 'name': 'Public holiday'},
      ],
    });
    expect(s.closedOn('2026-11-19')!.name, 'Public holiday');
    expect(s.closedOn('2026-11-20'), isNull);
    expect(s.isEmpty, isTrue);
  });

  test('coupon validation parses a refusal with its reason', () {
    final ok = CouponValidation.fromJson('A', {
      'valid': true,
      'discountEgp': 60,
      'totalEgp': 240,
    });
    expect(ok.valid, isTrue);
    expect(ok.totalEgp, 240);
    final no = CouponValidation.fromJson('A', {
      'valid': false,
      'reason': 'PerPatientLimit',
    });
    expect(no.reason, CouponReason.perPatientLimit);
    expect(CouponReason.parse('Weird'), CouponReason.unknown);
  });

  test('waiting entries, payments, records and family parse', () {
    final w = WaitingEntry.fromJson({
      'id': 'w1',
      'doctor': {'id': 'd1', 'name': 'Dr. A'},
      'date': '2026-11-20',
      'status': 'Notified',
      'notifiedAt': '2026-11-14T10:00:00Z',
    });
    expect(w.status, WaitingStatus.notified);
    expect(w.isActive, isTrue);
    expect(w.doctor.key, 'd1');

    final p = Payment.fromJson({
      'id': 'p1',
      'appointmentId': 'a1',
      'amountEgp': 240,
      'status': 'Paid',
    });
    expect(p.status.isFinal, isTrue);
    expect(PaymentStatus.parse('Pending').isFinal, isFalse);

    final r = PatientRecords.fromJson({
      'medicalInfo': {'bloodType': 'A+', 'allergies': null},
      'entries': [
        {
          'id': 'r1',
          'kind': 'Attachment',
          'title': 'X-ray',
          'attachmentUrl': 'https://x/y.pdf',
          'createdAt': '2026-10-01T10:00:00Z',
        },
      ],
    });
    expect(r.medicalInfo!.bloodType, 'A+');
    expect(r.entries.single.kind, RecordKind.attachment);

    final f = FamilyMember.fromJson({
      'id': 'f1',
      'fullName': 'Layla',
      'relation': 'Child',
      'dateOfBirth': '2019-09-03T00:00:00',
      'gender': 'Female',
    });
    expect(f.dateOfBirth, '2019-09-03');
    expect(f.gender, FamilyGender.female);
  });

  test('the user carries the opt-ins, on by default', () {
    expect(AppUser.fromJson(userJson()).marketingOptIn, isTrue);
    final u = AppUser.fromJson({
      ...userJson(),
      'whatsAppOptIn': false,
      'marketingOptIn': false,
    });
    expect(u.whatsAppOptIn, isFalse);
    expect(u.marketingOptIn, isFalse);
  });

  test('every phase 2 switch defaults off', () {
    final json = Brand.defaultFeatures.toJson();
    for (final key in [
      'videoConsultation',
      'waitingList',
      'familyAccounts',
      'whatsappReminders',
      'onlinePayments',
      'insurance',
      'holidayCalendar',
      'workingHoursTemplates',
      'patientRecords',
      'reviews',
      'promotions',
      'recallCampaigns',
      'reports',
    ]) {
      expect(json[key], isFalse, reason: key);
    }
  });

  group('payment-return link', () {
    test('custom scheme maps to the in-app route', () {
      expect(
        paymentReturnLocation(
          Uri.parse(
            'com.moonlight.app://payment-return?paymentId=p1&status=paid',
          ),
        ),
        '/payment-return?paymentId=p1&status=paid',
      );
      expect(paymentReturnLocation(Uri.parse('/doctors')), isNull);
      expect(Brand.paymentReturnUrl, 'com.moonlight.app://payment-return');
    });
  });

  group('error codes', () {
    final en = AppLocalizationsEn();
    final ar = AppLocalizationsAr();
    test('every new code has a friendly message in both languages', () {
      for (final code in [
        'CLINIC_CLOSED',
        'ALREADY_REVIEWED',
        'NOT_REVIEWABLE',
        'PAYMENT_NOT_ALLOWED',
        'VIDEO_NOT_OPEN',
        'ALREADY_WAITING',
        'PROVIDER_ERROR',
      ]) {
        final f = Failure(code: code, statusCode: 409);
        expect(en.failureMessage(f), isNot(en.errUnknown), reason: code);
        expect(ar.failureMessage(f), isNot(ar.errUnknown), reason: code);
      }
    });

    test('COUPON_INVALID is explained by its reason', () {
      expect(
        en.failureMessage(
          const Failure(code: 'COUPON_INVALID', reason: 'Expired'),
        ),
        'This code has expired.',
      );
      expect(
        ar.failureMessage(
          const Failure(code: 'COUPON_INVALID', reason: 'Exhausted'),
        ),
        ar.couponExhausted,
      );
    });

    test('Failure.fromJson keeps the reason', () {
      final f = const Failure(code: 'COUPON_INVALID', reason: 'NotFound');
      expect(f.reason, 'NotFound');
    });
  });
}
