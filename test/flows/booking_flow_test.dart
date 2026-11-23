import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/appointments/data/appointments_repository.dart';
import 'package:moonlight/features/booking/presentation/booking_providers.dart';

import '../support/pump_app.dart';

Future<void> _openFirstSlotOfDoctor(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('specialty-sp-general')));
  await tester.pumpAndSettle();
  expect(find.text('Dr. Mona Hassan'), findsOneWidget);
  expect(find.text('Dr. Karim Adel'), findsNothing); // filtered by specialty

  await tester.tap(find.text('Dr. Mona Hassan'));
  await tester.pumpAndSettle();
  expect(find.text('Check-up'), findsOneWidget); // services on the profile
  await tester.tap(find.byKey(const Key('bookAppointment')));
  await tester.pumpAndSettle();

  await tester.tap(find.byType(ChoiceChip).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('continueToConfirm')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guest browses up to confirm, signs in there, and books', (
    tester,
  ) async {
    await pumpMoonlight(tester);
    await _openFirstSlotOfDoctor(tester);

    // A guest gets all the way to the confirm step...
    expect(find.text('Confirm booking'), findsOneWidget);
    expect(find.text('Pay at the clinic'), findsOneWidget);
    expect(find.text('Dr. Mona Hassan'), findsOneWidget);
    // ...and is asked to sign in only when confirming.
    await tester.tap(find.byKey(const Key('confirmBooking')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phoneField')), findsOneWidget);

    await signInViaUi(tester);

    // Back on the same confirm screen, now able to book.
    expect(find.byKey(const Key('confirmBooking')), findsOneWidget);
    expect(find.text('Sign in to confirm'), findsNothing);
    expect(find.byKey(const Key('confirmBack')), findsOneWidget);
    await tester.tap(find.byKey(const Key('service-svc-cleaning')));
    await tester.enterText(
      find.byKey(const Key('noteField')),
      'Sensitive tooth',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirmBooking')));
    await tester.pumpAndSettle();

    expect(find.text('You are booked!'), findsOneWidget);
    expect(find.text('Dr. Mona Hassan'), findsOneWidget);
    expect(find.byKey(const Key('addToCalendar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('viewAppointments')));
    await tester.pumpAndSettle();
    // Seeded two upcoming + the new one.
    expect(find.text('Dr. Mona Hassan'), findsNWidgets(2));
    expect(find.text('Dr. Karim Adel'), findsOneWidget);
  });

  testWidgets(
    'a slot taken in the meantime sends the patient back to pick another',
    (tester) async {
      await pumpMoonlight(tester);
      await tester.tap(find.byKey(const Key('allDoctors')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dr. Karim Adel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bookAppointment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('continueToConfirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmBooking')));
      await tester.pumpAndSettle();
      await signInViaUi(tester);

      // Somebody else books the same slot first.
      final container = containerOf(tester);
      final slotId = container.read(bookingDraftProvider)!.slot.id;
      await tester.runAsync(
        () =>
            container.read(appointmentsRepositoryProvider).book(slotId: slotId),
      );

      await tester.tap(find.byKey(const Key('confirmBooking')));
      await tester.pumpAndSettle();

      expect(
        find.text('Someone just booked this time. Please pick another one.'),
        findsWidgets,
      );
      expect(find.text('Pick a time'), findsOneWidget);
      expect(find.byKey(Key('slot-$slotId')), findsNothing);
    },
  );
}
