import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/appointments/data/appointments_repository.dart';
import 'package:moonlight/features/appointments/domain/appointment.dart';
import 'package:moonlight/features/family/data/family_repository.dart';
import 'package:moonlight/features/family/domain/family_member.dart';
import 'package:moonlight/features/insurance/domain/insurance.dart';
import 'package:moonlight/features/payments/data/payments_repository.dart';
import 'package:moonlight/features/profile/data/profile_repository.dart';
import 'package:moonlight/features/promotions/data/promotions_repository.dart';
import 'package:moonlight/features/reviews/data/reviews_repository.dart';
import 'package:moonlight/features/search/data/search_repository.dart';
import 'package:moonlight/features/search/domain/doctor_query.dart';
import 'package:moonlight/features/video/data/video_repository.dart';
import 'package:moonlight/features/waiting_list/data/waiting_list_repository.dart';

import '../support/fake_adapter.dart';
import '../support/fixtures.dart';

void main() {
  test('booking sends the phase 2 fields only when set', () async {
    final adapter = FakeAdapter((_) => jsonResponse(appointmentJson()));
    final repo = AppointmentsRepository(testDio(adapter));

    await repo.book(slotId: 's1');
    expect(adapter.requests.last.data, {'slotId': 's1'});

    await repo.book(
      slotId: 's1',
      familyMemberId: 'fam-1',
      mode: AppointmentMode.video,
      insurance: const InsuranceChoice(providerId: 'ins-1', memberNumber: 'B1'),
      couponCode: 'SMILE20',
    );
    expect(adapter.requests.last.data, {
      'slotId': 's1',
      'familyMemberId': 'fam-1',
      'mode': 'Video',
      'insurance': {'providerId': 'ins-1', 'memberNumber': 'B1'},
      'couponCode': 'SMILE20',
    });
  });

  test('coupon validation posts code, doctor and service', () async {
    final adapter = FakeAdapter(
      (_) => jsonResponse({'valid': false, 'reason': 'Expired'}),
    );
    final result = await PromotionsRepository(testDio(adapter))
        .validate('OLD', doctorId: 'd1', serviceId: 's1');
    expect(adapter.requests.single.path, '/coupons/validate');
    expect(adapter.requests.single.data, {
      'code': 'OLD',
      'doctorId': 'd1',
      'serviceId': 's1',
    });
    expect(result.toNullable()!.valid, isFalse);
  });

  test(
    'offers, insurers and the doctor filter use the contract paths',
    () async {
      final adapter = FakeAdapter((o) {
        if (o.path == '/promotions') {
          return jsonResponse([
            {
              'code': 'A1',
              'title': 'T',
              'discountType': 'Percent',
              'value': 10,
              'validTo': '2026-12-01T00:00:00Z',
            },
          ]);
        }
        if (o.path == '/insurance-providers') {
          return jsonResponse([
            {'id': 'i', 'name': 'AXA'},
          ]);
        }
        return jsonResponse({
          'items': <Object>[],
          'page': 1,
          'pageSize': 20,
          'totalCount': 0,
        });
      });
      final dio = testDio(adapter);
      final offers = (await PromotionsRepository(dio).offers()).toNullable()!;
      expect(offers.single.validTo, '2026-12-01');
      await SearchRepository(dio)
          .doctors(const DoctorQuery(insuranceProviderId: 'i'));
      expect(adapter.requests.last.queryParameters['insuranceProviderId'], 'i');
    },
  );

  test('family CRUD, waiting list, pay, review and video requests', () async {
    final adapter = FakeAdapter((o) {
      return switch ((o.method, o.path)) {
        ('GET', '/me/family') => jsonResponse([
          {'id': 'f1', 'fullName': 'A', 'relation': 'Child'},
        ]),
        ('POST', '/me/family') || ('PUT', '/me/family/f1') => jsonResponse({
          'id': 'f1',
          'fullName': 'A',
          'relation': 'Child',
        }),
        ('POST', '/waiting-list') => jsonResponse({
          'id': 'w1',
          'doctor': {'id': 'd', 'name': 'D'},
          'date': '2026-11-20',
          'status': 'Waiting',
        }, status: 201),
        ('POST', '/appointments/a1/pay') => jsonResponse({
          'paymentId': 'p1',
          'checkoutUrl': 'https://pay/x',
        }),
        ('GET', '/payments/p1') => jsonResponse({
          'id': 'p1',
          'appointmentId': 'a1',
          'amountEgp': 240,
          'status': 'Pending',
        }),
        ('GET', '/appointments/a1/video') => jsonResponse({
          'joinUrl': 'https://meet/x',
          'opensAt': '2026-11-02T06:45:00Z',
          'closesAt': '2026-11-02T08:00:00Z',
        }),
        ('PUT', '/me') => jsonResponse({
          ...userJson(),
          'marketingOptIn': false,
        }),
        _ => problem('ALREADY_REVIEWED', 409),
      };
    });
    final dio = testDio(adapter);

    final family = FamilyRepository(dio);
    expect((await family.list()).toNullable()!.single.fullName, 'A');
    await family.add(fullName: ' A ', relation: FamilyRelation.child);
    expect(adapter.requests.last.data['fullName'], 'A');
    expect(adapter.requests.last.data['relation'], 'Child');
    await family.update('f1', fullName: 'A', relation: FamilyRelation.sibling);
    expect(adapter.requests.last.data['relation'], 'Sibling');

    await WaitingListRepository(dio).join(doctorId: 'd', date: '2026-11-20');
    expect(adapter.requests.last.data, {'doctorId': 'd', 'date': '2026-11-20'});

    final payments = PaymentsRepository(dio);
    final checkout = (await payments.pay(
      'a1',
      returnUrl: 'com.drbooking.app://payment-return',
    )).toNullable()!;
    expect(checkout.checkoutUrl, 'https://pay/x');
    expect(adapter.requests.last.data, {
      'returnUrl': 'com.drbooking.app://payment-return',
    });
    expect((await payments.get('p1')).toNullable()!.amountEgp, 240);

    final room = (await VideoRepository(dio).room('a1')).toNullable()!;
    expect(room.joinUrl, 'https://meet/x');

    final user = (await ProfileRepository(dio).updateMe(marketingOptIn: false))
        .toNullable()!;
    expect(adapter.requests.last.data, {'marketingOptIn': false});
    expect(user.marketingOptIn, isFalse);

    final review = await ReviewsRepository(dio)
        .submit('a1', rating: 5, comment: ' nice ');
    expect(adapter.requests.last.data, {'rating': 5, 'comment': 'nice'});
    expect(review.swap().toNullable()!.code, 'ALREADY_REVIEWED');
  });
}
