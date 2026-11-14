import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/config/brand.g.dart';
import 'package:moonlight/core/mock/mock_api_adapter.dart';
import 'package:moonlight/features/auth/data/auth_repository.dart';
import 'package:moonlight/features/auth/domain/app_user.dart';
import 'package:moonlight/features/auth/presentation/auth_controller.dart';

import '../support/pump_app.dart';

Future<void> _goToLogin(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.event_note_outlined));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'appointments need login; a guest is redirected to the phone screen',
    (tester) async {
      await pumpMoonlight(tester);

      await _goToLogin(tester);

      expect(find.byKey(const Key('phoneField')), findsOneWidget);
      expect(find.text('Welcome to ${Brand.nameEn}'), findsOneWidget);
    },
  );

  testWidgets('login returns to the page the guest wanted', (tester) async {
    await pumpMoonlight(tester);
    await _goToLogin(tester);

    await signInViaUi(tester);

    expect(find.text('My appointments'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Dr. Mona Hassan'), findsOneWidget);
  });

  testWidgets('rejects a number that is not an Egyptian mobile', (
    tester,
  ) async {
    await pumpMoonlight(tester);
    await _goToLogin(tester);

    await tester.enterText(find.byKey(const Key('phoneField')), '12345');
    await tester.tap(find.byKey(const Key('sendCode')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid Egyptian mobile number.'), findsOneWidget);
    expect(find.byKey(const Key('otpField')), findsNothing);
  });

  testWidgets('a wrong code shows the localized error and allows a retry', (
    tester,
  ) async {
    await pumpMoonlight(tester);
    await _goToLogin(tester);
    await tester.enterText(find.byKey(const Key('phoneField')), '01012345678');
    await tester.tap(find.byKey(const Key('sendCode')));
    await pumpUi(tester);

    await tester.enterText(find.byKey(const Key('otpField')), '000000');
    await pumpUi(tester);
    expect(find.text('That code is incorrect.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('otpField')), '123456');
    await pumpUi(tester);
    await tester.pumpAndSettle();
    expect(find.text('My appointments'), findsOneWidget);
  });

  testWidgets('the resend button appears after the countdown', (tester) async {
    await pumpMoonlight(tester);
    await _goToLogin(tester);
    await tester.enterText(find.byKey(const Key('phoneField')), '01012345678');
    await tester.tap(find.byKey(const Key('sendCode')));
    await pumpUi(tester);

    expect(find.text('Resend code in 60s'), findsOneWidget);
    expect(find.byKey(const Key('resendCode')), findsNothing);

    await tester.pump(const Duration(seconds: 61));

    expect(find.byKey(const Key('resendCode')), findsOneWidget);
  });

  testWidgets('a new user completes their profile before continuing', (
    tester,
  ) async {
    await pumpMoonlight(tester);
    await _goToLogin(tester);

    await signInViaUi(tester, phone: MockApiAdapter.newUserPhone);

    expect(find.text('One last thing'), findsOneWidget);
    await tester.tap(find.byKey(const Key('saveName')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your name.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('nameField')), 'Laila Hossam');
    await tester.tap(find.byKey(const Key('saveName')));
    await tester.pumpAndSettle();

    // Lands on the page they originally asked for.
    expect(find.text('My appointments'), findsOneWidget);
  });

  testWidgets('logout returns to guest browsing', (tester) async {
    await pumpMoonlight(tester);
    await _goToLogin(tester);
    await signInViaUi(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Nour Samir'), findsNothing); // Arabic fixture name below
    expect(find.text('نور سمير'), findsOneWidget);
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmLogout')));
    await pumpUi(tester, steps: 40); // the mock API answers after a short delay
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settingsSignIn')), findsOneWidget);
    expect(find.byKey(const Key('logout')), findsNothing);
    await _goToLogin(tester);
    expect(find.byKey(const Key('phoneField')), findsOneWidget);
  });

  testWidgets('a doctor or staff account is turned away', (tester) async {
    await pumpMoonlight(tester);
    final container = containerOf(tester);
    final repo = container.read(authRepositoryProvider);
    // The mock API answers after a real delay, so run outside fake time.
    final accepted = await tester.runAsync(() async {
      await repo.verifyOtp('+201012345678', '123456');
      return container
          .read(authControllerProvider.notifier)
          .signIn(
            const AppUser(
              id: 'u1',
              phone: '+201099999999',
              role: 'Doctor',
              preferredLanguage: 'ar',
              fullName: 'Dr. X',
            ),
          );
    });

    expect(accepted, isFalse);
    expect(await tester.runAsync(repo.hasTokens), isFalse);
    expect(container.read(authControllerProvider).value, isNull);
  });
}
