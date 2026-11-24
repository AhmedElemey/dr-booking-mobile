import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/push/firebase_push_service.dart';
import 'package:moonlight/core/push/push_service.dart';

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

  test('foregroundPushOf keeps the text and the appointment id', () {
    final push = FirebasePushService.foregroundPushOf(
      title: 'Reminder',
      body: 'Tomorrow at 10:30',
      data: {'appointmentId': 'a1'},
    );
    expect(push.text, 'Reminder: Tomorrow at 10:30');
    expect(push.appointmentId, 'a1');
  });

  test('a push with no text has nothing to show', () {
    expect(const ForegroundPush().text, isNull);
    expect(const ForegroundPush(title: ' ', body: '').text, isNull);
    expect(const ForegroundPush(body: 'Only body').text, 'Only body');
  });
}
