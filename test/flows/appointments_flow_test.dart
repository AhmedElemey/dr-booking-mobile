import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/push/push_service.dart';

import '../support/fake_push.dart';
import '../support/pump_app.dart';

Future<void> _signInAndOpenAppointments(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.event_note_outlined));
  await tester.pumpAndSettle();
  await signInViaUi(tester);
}

void main() {
  testWidgets('lists upcoming and past appointments in tabs', (tester) async {
    await pumpMoonlight(tester);
    await _signInAndOpenAppointments(tester);

    expect(find.text('Dr. Mona Hassan'), findsOneWidget);
    expect(find.text('Dr. Karim Adel'), findsOneWidget);
    expect(find.text('Dr. Salma Farouk'), findsNothing);

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Salma Farouk'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('cancelling an appointment asks first and then updates it', (
    tester,
  ) async {
    await pumpMoonlight(tester);
    await _signInAndOpenAppointments(tester);

    await tester.tap(find.text('Dr. Karim Adel'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.byKey(const Key('callClinic')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancelAppointment')));
    await tester.pumpAndSettle();
    // Keeping it changes nothing.
    await tester.tap(find.byKey(const Key('keepAppointment')));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancelAppointment')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cancelReason')), 'Travelling');
    await tester.tap(find.byKey(const Key('confirmCancel')));
    await pumpUi(tester);
    await tester.pumpAndSettle();

    expect(find.text('Appointment cancelled.'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancelled by you'), findsOneWidget);
    expect(find.text('Reason: Travelling'), findsOneWidget);
    expect(find.byKey(const Key('cancelAppointment')), findsNothing);
    expect(find.byKey(const Key('reschedule')), findsNothing);
  });

  testWidgets('rescheduling picks another slot of the same doctor', (
    tester,
  ) async {
    await pumpMoonlight(tester);
    await _signInAndOpenAppointments(tester);
    await tester.tap(find.text('Dr. Mona Hassan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reschedule')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a new time'), findsOneWidget);
    final button = find.byKey(const Key('confirmReschedule'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await pumpUi(tester);
    await tester.pumpAndSettle();

    expect(find.text('Appointment moved.'), findsOneWidget);
    expect(find.text('Appointment'), findsOneWidget); // back on the details
    expect(find.byKey(const Key('reschedule')), findsOneWidget);
  });

  testWidgets('tapping a push notification opens its appointment', (
    tester,
  ) async {
    final push = FakePushService();
    addTearDown(push.tapController.close);
    await pumpMoonlight(
      tester,
      overrides: [pushServiceProvider.overrideWithValue(push)],
    );
    await _signInAndOpenAppointments(tester);

    push.tapController.add('apt-2');
    await pumpUi(tester);
    await tester.pumpAndSettle();

    expect(find.text('Dr. Karim Adel'), findsOneWidget);
    expect(find.byKey(const Key('getDirections')), findsOneWidget);
  });

  testWidgets('a push that arrives while the app is open shows a banner', (
    tester,
  ) async {
    final push = FakePushService();
    addTearDown(push.foregroundController.close);
    await pumpMoonlight(
      tester,
      overrides: [pushServiceProvider.overrideWithValue(push)],
    );
    await _signInAndOpenAppointments(tester);

    push.foregroundController.add(
      const ForegroundPush(
        title: 'Reminder',
        body: 'Tomorrow at 10:30',
        appointmentId: 'apt-2',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Reminder: Tomorrow at 10:30'), findsOneWidget);

    await tester.tap(find.text('View'));
    await pumpUi(tester);
    await tester.pumpAndSettle();

    expect(find.text('Dr. Karim Adel'), findsOneWidget);
    expect(find.byKey(const Key('getDirections')), findsOneWidget);
  });
}
