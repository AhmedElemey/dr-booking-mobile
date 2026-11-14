import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/l10n/failure_messages.dart';
import 'package:moonlight/core/l10n/generated/app_localizations_ar.dart';
import 'package:moonlight/core/l10n/generated/app_localizations_en.dart';
import 'package:moonlight/core/network/failure.dart';
import 'package:moonlight/core/router/app_router.dart';

import '../support/fixed_features.dart';
import '../support/pump_app.dart';

Future<void> _openFirstAppointment(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.event_note_outlined));
  await tester.pumpAndSettle();
  await signInViaUi(tester);
  await tester.tap(find.text('Dr. Karim Adel'));
  await tester.pumpAndSettle();
}

void main() {
  group('mobileApp off', () {
    testWidgets('shows the not-available page instead of the app', (
      tester,
    ) async {
      await pumpMoonlight(
        tester,
        overrides: [featuresOverride((f) => f.copyWith(mobileApp: false))],
      );

      expect(find.text("The app isn't available right now"), findsOneWidget);
      expect(find.byKey(const Key('callClinicUnavailable')), findsOneWidget);
      expect(find.textContaining('moonlight.example'), findsOneWidget);
      expect(find.byKey(const Key('searchField')), findsNothing);
    });

    testWidgets('skips the language picker too', (tester) async {
      await pumpMoonlight(
        tester,
        language: null,
        overrides: [featuresOverride((f) => f.copyWith(mobileApp: false))],
      );
      expect(find.byKey(const Key('chooseEnglish')), findsNothing);
      expect(find.byKey(const Key('callClinicUnavailable')), findsOneWidget);
    });
  });

  group('guestBrowsing', () {
    testWidgets('on: guests land on search', (tester) async {
      await pumpMoonlight(tester);
      expect(find.byKey(const Key('searchField')), findsOneWidget);
    });

    testWidgets('off: sign-in comes before search, then search opens', (
      tester,
    ) async {
      await pumpMoonlight(
        tester,
        overrides: [featuresOverride((f) => f.copyWith(guestBrowsing: false))],
      );

      expect(find.byKey(const Key('phoneField')), findsOneWidget);
      expect(find.byKey(const Key('searchField')), findsNothing);

      await signInViaUi(tester);
      expect(find.byKey(const Key('searchField')), findsOneWidget);
    });

    test('requiresAuth covers every page except login when off', () {
      expect(requiresAuth('/doctors', guestBrowsing: false), isTrue);
      expect(requiresAuth('/doctors/x/slots', guestBrowsing: false), isTrue);
      expect(requiresAuth('/', guestBrowsing: false), isTrue);
      expect(requiresAuth('/login', guestBrowsing: false), isFalse);
      expect(requiresAuth('/login/otp', guestBrowsing: false), isFalse);
      expect(requiresAuth('/doctors'), isFalse);
      expect(requiresAuth('/appointments'), isTrue);
    });
  });

  group('patientSelfService', () {
    testWidgets('on: cancel and reschedule are offered', (tester) async {
      await pumpMoonlight(tester);
      await _openFirstAppointment(tester);

      expect(find.byKey(const Key('reschedule')), findsOneWidget);
      expect(find.byKey(const Key('cancelAppointment')), findsOneWidget);
      expect(find.byKey(const Key('callToChange')), findsNothing);
    });

    testWidgets('off: hides them and asks to call the clinic', (tester) async {
      await pumpMoonlight(
        tester,
        overrides: [
          featuresOverride((f) => f.copyWith(patientSelfService: false)),
        ],
      );
      await _openFirstAppointment(tester);

      expect(find.byKey(const Key('reschedule')), findsNothing);
      expect(find.byKey(const Key('cancelAppointment')), findsNothing);
      expect(find.byKey(const Key('callToChange')), findsOneWidget);
      expect(find.byKey(const Key('callToChangeButton')), findsOneWidget);
      expect(
        find.text(
          'To change or cancel this appointment, please call the clinic.',
        ),
        findsOneWidget,
      );
    });
  });

  group('englishLanguage off', () {
    testWidgets('no picker on first launch, no switch, Arabic everywhere', (
      tester,
    ) async {
      await pumpMoonlight(
        tester,
        language: null,
        overrides: [
          featuresOverride((f) => f.copyWith(englishLanguage: false)),
        ],
      );

      expect(find.byKey(const Key('chooseEnglish')), findsNothing);
      expect(find.byKey(const Key('switchLanguage')), findsNothing);
      expect(find.text('ابحث عن طبيب أسنان واحجز في دقائق'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );
    });

    testWidgets('a saved English choice is overridden, settings hide it', (
      tester,
    ) async {
      await pumpMoonlight(
        tester,
        language: 'en',
        overrides: [
          featuresOverride((f) => f.copyWith(englishLanguage: false)),
        ],
      );
      expect(find.text('ابحث عن طبيب أسنان واحجز في دقائق'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('languageSelector')), findsNothing);
    });

    testWidgets('on: the switch and the setting are there', (tester) async {
      await pumpMoonlight(tester);
      expect(find.byKey(const Key('switchLanguage')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('languageSelector')), findsOneWidget);
    });
  });

  group('multiBranch', () {
    testWidgets('on: the city filter shows', (tester) async {
      await pumpMoonlight(tester);
      expect(find.byKey(const Key('cityField')), findsOneWidget);
    });

    testWidgets('off: the city filter is hidden', (tester) async {
      await pumpMoonlight(
        tester,
        overrides: [featuresOverride((f) => f.copyWith(multiBranch: false))],
      );
      expect(find.byKey(const Key('searchField')), findsOneWidget);
      expect(find.byKey(const Key('cityField')), findsNothing);
    });
  });

  group('FEATURE_DISABLED message', () {
    const selfService = Failure(
      code: 'FEATURE_DISABLED',
      statusCode: 403,
      feature: 'patientSelfService',
    );
    const other = Failure(
      code: 'FEATURE_DISABLED',
      statusCode: 403,
      feature: 'website',
    );

    test('is localized, and names the clinic call for self-service', () {
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(en.failureMessage(selfService), contains('call the clinic'));
      expect(
        en.failureMessage(other),
        "This isn't available right now. Please call the clinic.",
      );
      expect(ar.failureMessage(selfService), contains('اتصل بالعيادة'));
      expect(ar.failureMessage(other), contains('اتصل بالعيادة'));
    });
  });
}
