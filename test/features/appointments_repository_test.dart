import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/appointments/data/appointments_repository.dart';
import 'package:moonlight/features/appointments/domain/appointment.dart';
import 'package:moonlight/features/booking/presentation/calendar_link.dart';

import '../support/fake_adapter.dart';
import '../support/fixtures.dart';

void main() {
  group('AppointmentsRepository', () {
    test('book posts the slot, service and trimmed note', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse(appointmentJson(), status: 201),
      );
      final repo = AppointmentsRepository(testDio(adapter));

      final appointment = (await repo.book(
        slotId: 'slot-1',
        serviceId: 'svc-1',
        note: '  first visit ',
      )).toNullable()!;

      final request = adapter.requests.single;
      expect(request.path, '/appointments');
      expect(request.data, {
        'slotId': 'slot-1',
        'serviceId': 'svc-1',
        'patientNote': 'first visit',
      });
      expect(appointment.status, AppointmentStatus.confirmed);
      expect(appointment.doctor.key, 'mona-hassan');
    });

    test('book omits an empty note and service', () async {
      final adapter = FakeAdapter((_) => jsonResponse(appointmentJson()));
      final repo = AppointmentsRepository(testDio(adapter));

      await repo.book(slotId: 'slot-1', note: '   ');

      expect(adapter.requests.single.data, {'slotId': 'slot-1'});
    });

    test('a taken slot is a SLOT_TAKEN failure', () async {
      final adapter = FakeAdapter((_) => problem('SLOT_TAKEN', 409));
      final repo = AppointmentsRepository(testDio(adapter));

      final result = await repo.book(slotId: 'slot-1');

      expect(result.getLeft().toNullable()?.code, 'SLOT_TAKEN');
      expect(result.getLeft().toNullable()?.statusCode, 409);
    });

    test('list passes the scope and parses the page envelope', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'items': [appointmentJson(), appointmentJson(id: 'apt-2')],
          'page': 1,
          'pageSize': 20,
          'totalCount': 2,
        }),
      );
      final repo = AppointmentsRepository(testDio(adapter));

      final page = (await repo.list(AppointmentScope.past)).toNullable()!;

      expect(adapter.requests.single.queryParameters['scope'], 'past');
      expect(page.items.map((a) => a.id), ['apt-1', 'apt-2']);
      expect(page.hasMore, isFalse);
    });

    test('cancel sends the reason and reads the appointment back', () async {
      final adapter = FakeAdapter(
        (o) => o.method == 'POST'
            ? jsonResponse(null, status: 204)
            : jsonResponse(appointmentJson(status: 'Cancelled')),
      );
      final repo = AppointmentsRepository(testDio(adapter));

      final appointment = (await repo.cancel(
        'apt-1',
        reason: 'Busy',
      )).toNullable()!;

      expect(adapter.requests.first.path, '/appointments/apt-1/cancel');
      expect(adapter.requests.first.data, {'reason': 'Busy'});
      expect(appointment.status, AppointmentStatus.cancelled);
    });

    test('cancel inside the window maps to CANCEL_WINDOW_PASSED', () async {
      final adapter = FakeAdapter((_) => problem('CANCEL_WINDOW_PASSED', 409));
      final repo = AppointmentsRepository(testDio(adapter));

      final result = await repo.cancel('apt-1');

      expect(result.getLeft().toNullable()?.code, 'CANCEL_WINDOW_PASSED');
    });

    test('reschedule posts the new slot', () async {
      final adapter = FakeAdapter((_) => jsonResponse(appointmentJson()));
      final repo = AppointmentsRepository(testDio(adapter));

      await repo.reschedule('apt-1', slotId: 'slot-9');

      expect(adapter.requests.single.path, '/appointments/apt-1/reschedule');
      expect(adapter.requests.single.data, {'slotId': 'slot-9'});
    });
  });

  group('Appointment', () {
    test('keeps the clinic wall-clock time, whatever the device zone', () {
      final appointment = Appointment.fromJson(appointmentJson());

      // 07:00Z is 09:00 in Cairo; screens read the local fields as-is.
      expect(appointment.startsAt, DateTime.utc(2026, 11, 2, 7));
      expect(appointment.startsAtLocal, DateTime(2026, 11, 2, 9));
      expect(appointment.endsAtLocal, DateTime(2026, 11, 2, 9, 30));
      expect(appointment.timezone, 'Africa/Cairo');
    });

    test('parseLocalDateTime ignores any offset suffix', () {
      expect(
        parseLocalDateTime('2026-11-02T09:00:00+02:00'),
        DateTime(2026, 11, 2, 9),
      );
      expect(
        parseLocalDateTime('2026-11-02T09:00:00Z'),
        DateTime(2026, 11, 2, 9),
      );
    });

    test('only a future confirmed appointment can be changed', () {
      final future = appointmentJson()
        ..['startsAt'] = DateTime.now()
            .toUtc()
            .add(const Duration(days: 2))
            .toIso8601String();
      expect(Appointment.fromJson(future).canChange, isTrue);
      expect(
        Appointment.fromJson({...future, 'status': 'Cancelled'}).canChange,
        isFalse,
      );
      expect(
        Appointment.fromJson({
          ...appointmentJson(),
          'startsAt': '2020-01-01T07:00:00Z',
        }).canChange,
        isFalse,
      );
    });
  });

  test('calendar link carries the UTC times and the clinic location', () {
    final uri = calendarUri(
      Appointment.fromJson(appointmentJson()),
      title: 'Dr booking',
    );

    expect(uri.host, 'calendar.google.com');
    expect(uri.queryParameters['dates'], '20261102T070000Z/20261102T073000Z');
    expect(uri.queryParameters['location'], 'Nile Smile, 12 Road 9, Maadi');
  });
}
