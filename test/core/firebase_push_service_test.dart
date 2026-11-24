import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/push/firebase_push_service.dart';

void main() {
  test('appointmentIdOf reads the appointment id from a payload', () {
    expect(
      FirebasePushService.appointmentIdOf({
        'type': 'reminder',
        'appointmentId': 'a1',
      }),
      'a1',
    );
  });

  test('appointmentIdOf ignores payloads without an appointment id', () {
    expect(FirebasePushService.appointmentIdOf(null), isNull);
    expect(FirebasePushService.appointmentIdOf({'type': 'recall'}), isNull);
    expect(FirebasePushService.appointmentIdOf({'appointmentId': ''}), isNull);
    expect(FirebasePushService.appointmentIdOf({'appointmentId': 7}), isNull);
  });
}
