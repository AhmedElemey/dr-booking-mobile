import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/doctor/data/doctor_repository.dart';
import 'package:moonlight/features/search/data/search_repository.dart';
import 'package:moonlight/features/search/domain/doctor_query.dart';

import '../support/fake_adapter.dart';

const _doctor = {
  'id': 'doc-1',
  'slug': 'mona-hassan',
  'name': 'Dr. Mona Hassan',
  'photoUrl': null,
  'yearsExperience': 12,
  'consultationFeeEgp': 300,
  'specialty': {'id': 'sp-1', 'name': 'General Dentistry'},
  'clinic': {'id': 'c-1', 'name': 'Nile Smile', 'city': 'Cairo'},
};

void main() {
  group('SearchRepository', () {
    test('lists specialties and cities (strings or objects)', () async {
      final adapter = FakeAdapter(
        (o) => o.path == '/specialties'
            ? jsonResponse([
                {'id': 'sp-1', 'name': 'General Dentistry'},
              ])
            : jsonResponse([
                'Cairo',
                {'name': 'Giza'},
              ]),
      );
      final repo = SearchRepository(testDio(adapter));

      expect(
        (await repo.specialties()).toNullable()!.single.name,
        'General Dentistry',
      );
      expect((await repo.cities()).toNullable(), ['Cairo', 'Giza']);
    });

    test('doctors sends only the filters that are set, plus paging', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'items': [_doctor],
          'page': 2,
          'pageSize': 20,
          'totalCount': 41,
        }),
      );
      final repo = SearchRepository(testDio(adapter));

      final page = (await repo.doctors(
        const DoctorQuery(specialtyId: 'sp-1', text: '  mona '),
        page: 2,
      )).toNullable()!;

      expect(adapter.requests.single.queryParameters, {
        'specialtyId': 'sp-1',
        'q': 'mona',
        'page': 2,
        'pageSize': 20,
      });
      expect(page.hasMore, isTrue);
      final doctor = page.items.single;
      expect(doctor.slug, 'mona-hassan');
      expect(doctor.specialty?.name, 'General Dentistry');
      expect(doctor.clinic?.city, 'Cairo');
      expect(doctor.services, isEmpty);
    });

    test('the last page has no more', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'items': [_doctor],
          'page': 3,
          'pageSize': 20,
          'totalCount': 41,
        }),
      );
      final repo = SearchRepository(testDio(adapter));

      final page = (await repo.doctors(
        const DoctorQuery(),
        page: 3,
      )).toNullable()!;

      expect(page.hasMore, isFalse);
    });
  });

  group('DoctorRepository', () {
    test('profile includes bio, clinic and services', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          ..._doctor,
          'bio': 'Friendly dentist',
          'services': [
            {
              'id': 's1',
              'name': 'Cleaning',
              'durationMinutes': 45,
              'priceEgp': 400.5,
            },
          ],
        }),
      );
      final repo = DoctorRepository(testDio(adapter));

      final doctor = (await repo.doctor('mona-hassan')).toNullable()!;

      expect(adapter.requests.single.path, '/doctors/mona-hassan');
      expect(doctor.bio, 'Friendly dentist');
      expect(doctor.services.single.durationMinutes, 45);
      expect(doctor.services.single.priceEgp, 400.5);
    });

    test('slots asks for clinic-local dates and groups by day', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'doctorId': 'doc-1',
          'timezone': 'Africa/Cairo',
          'days': [
            {
              'date': '2026-11-02',
              'slots': [
                {
                  'id': 's1',
                  'startsAt': '2026-11-02T07:00:00Z',
                  'endsAt': '2026-11-02T07:30:00Z',
                  'local': '09:00',
                },
              ],
            },
          ],
        }),
      );
      final repo = DoctorRepository(testDio(adapter));

      final slots = (await repo.slots(
        'mona-hassan',
        from: DateTime(2026, 11, 2),
      )).toNullable()!;

      expect(adapter.requests.single.queryParameters, {
        'from': '2026-11-02',
        'to': '2026-11-15', // 14 days inclusive: the API maximum
      });
      expect(slots.timezone, 'Africa/Cairo');
      expect(slots.days.single.slots.single.local, '09:00');
      expect(slots.days.single.slots.single.startsAt.isUtc, isTrue);
      expect(slots.isEmpty, isFalse);
    });

    test('an unpublished doctor is a NOT_FOUND failure', () async {
      final adapter = FakeAdapter((_) => problem('NOT_FOUND', 404));
      final repo = DoctorRepository(testDio(adapter));

      final result = await repo.doctor('hidden');

      expect(result.getLeft().toNullable()?.code, 'NOT_FOUND');
    });
  });
}
