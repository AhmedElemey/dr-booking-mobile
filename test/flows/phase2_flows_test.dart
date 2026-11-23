import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/router/app_router.dart';

import '../support/pump_app.dart';

/// Home, doctors list, first doctor, first slot, then the confirm screen.
Future<void> _toConfirm(WidgetTester tester) async {
  containerOf(tester).read(routerProvider).go('/doctors');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dr. Mona Hassan'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('bookAppointment')));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ChoiceChip).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('continueToConfirm')));
  await tester.pumpAndSettle();
}

/// The confirm screen is a long lazy list: scroll until [key] is built.
Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _signInFromAppointments(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.event_note_outlined));
  await tester.pumpAndSettle();
  await signInViaUi(tester);
}

void main() {
  testWidgets('features off: nothing of phase 2 shows', (tester) async {
    await pumpMoonlight(tester);
    expect(find.byKey(const Key('offersStrip')), findsNothing);

    await _toConfirm(tester);
    expect(find.byKey(const Key('couponField')), findsNothing);
    expect(find.byKey(const Key('bookingFor')), findsNothing);
    expect(find.byKey(const Key('visitMode')), findsNothing);
    expect(find.byKey(const Key('useInsurance')), findsNothing);

    containerOf(tester).read(routerProvider).go('/appointments');
    await tester.pumpAndSettle();
    await signInViaUi(tester);
    containerOf(tester).read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('openFamily')), findsNothing);
    expect(find.byKey(const Key('openWaitingList')), findsNothing);
    expect(find.byKey(const Key('openRecords')), findsNothing);
    expect(find.byKey(const Key('whatsappOptIn')), findsNothing);
  });

  testWidgets('features on: offers strip and confirm extras show', (
    tester,
  ) async {
    await pumpMoonlight(tester, phase2: true);
    expect(find.byKey(const Key('offersStrip')), findsOneWidget);
    await _toConfirm(tester);
    await _scrollTo(tester, const Key('couponField'));
    expect(find.byKey(const Key('couponField')), findsOneWidget);
  });

  testWidgets('coupon: valid code applies, expired code explains why', (
    tester,
  ) async {
    await pumpMoonlight(tester, phase2: true);
    await _signInFromAppointments(tester);
    await _toConfirm(tester);

    await _scrollTo(tester, const Key('couponField'));
    await tester.enterText(find.byKey(const Key('couponField')), 'SMILE20');
    await tester.ensureVisible(find.byKey(const Key('applyCoupon')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('applyCoupon')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('SMILE20 applied'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('couponField')), 'EID2025');
    await tester.ensureVisible(find.byKey(const Key('applyCoupon')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('applyCoupon')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('This code has expired.'), findsOneWidget);
  });

  testWidgets(
    'confirm: family rows align and insurance clears the fixed action',
    (tester) async {
      await pumpMoonlight(tester, phase2: true);
      await _signInFromAppointments(tester);
      await _toConfirm(tester);
      await _scrollTo(tester, const Key('for-me'));
      final me = tester.getRect(find.byKey(const Key('for-me')));
      final member = tester.getRect(find.byKey(const Key('for-fam-1')));
      expect(member.left, closeTo(me.left, 0.1));
      expect(member.width, closeTo(me.width, 0.1));
      expect(member.top, greaterThan(me.bottom));
      await _scrollTo(tester, const Key('useInsurance'));
      final insurance = tester.getRect(find.byKey(const Key('useInsurance')));
      final confirm = tester.getRect(find.byKey(const Key('confirmBooking')));
      expect(insurance.bottom, lessThan(confirm.top));
      await tester.tap(find.byKey(const Key('useInsurance')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('insurerField')), findsOneWidget);
    },
  );

  testWidgets('family picker: book for a family member', (tester) async {
    await pumpMoonlight(tester, phase2: true);
    await _signInFromAppointments(tester);
    await _toConfirm(tester);

    expect(find.byKey(const Key('bookingFor')), findsOneWidget);
    await _scrollTo(tester, const Key('for-fam-1'));
    await tester.tap(find.byKey(const Key('for-fam-1')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('confirmBooking'));
    await tester.tap(find.byKey(const Key('confirmBooking')));
    await tester.pumpAndSettle();
    expect(find.text('You are booked!'), findsOneWidget);
    expect(find.textContaining('For '), findsWidgets);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('rate visit: once only', (tester) async {
    await pumpMoonlight(tester, phase2: true);
    await _signInFromAppointments(tester);
    containerOf(tester).read(routerProvider).go('/appointments/apt-3');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rateCard')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('rateVisit')));
    await tester.tap(find.byKey(const Key('rateVisit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('reviewComment')), 'Great');
    await tester.ensureVisible(find.byKey(const Key('submitReview')));
    await tester.tap(find.byKey(const Key('submitReview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rateCard')), findsNothing);
    expect(find.byKey(const Key('yourReview')), findsOneWidget);
  });

  testWidgets('settings: marketing opt-in can be switched on', (tester) async {
    await pumpMoonlight(tester, phase2: true);
    await _signInFromAppointments(tester);
    containerOf(tester).read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('openFamily')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('marketingOptIn')));
    final before = tester.widget<SwitchListTile>(
      find.byKey(const Key('marketingOptIn')),
    );
    await tester.tap(find.byKey(const Key('marketingOptIn')));
    await tester.pumpAndSettle();
    final after = tester.widget<SwitchListTile>(
      find.byKey(const Key('marketingOptIn')),
    );
    expect(after.value, !before.value);
  });
}
