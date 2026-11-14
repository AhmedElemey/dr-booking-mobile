import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_app.dart';

void main() {
  TextDirection directionOf(WidgetTester tester) =>
      Directionality.of(tester.element(find.byType(Scaffold).first));

  testWidgets('first launch asks for a language, then opens home', (
    tester,
  ) async {
    await pumpMoonlight(tester, language: null);

    expect(find.text('Choose your language'), findsNothing); // default is ar
    expect(find.text('اختر لغتك'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chooseEnglish')));
    await tester.pumpAndSettle();

    expect(directionOf(tester), TextDirection.ltr);
    expect(find.text('Find a dentist and book in minutes'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'en');
  });

  testWidgets('a saved language skips the picker; Arabic is right to left', (
    tester,
  ) async {
    await pumpMoonlight(tester, language: 'ar');

    expect(directionOf(tester), TextDirection.rtl);
    expect(find.text('ابحث عن طبيب أسنان واحجز في دقائق'), findsOneWidget);
    expect(find.text('اختر لغتك'), findsNothing);
  });

  testWidgets('the language toggle flips text and layout direction', (
    tester,
  ) async {
    await pumpMoonlight(tester, language: 'ar');

    await tester.tap(find.byKey(const Key('switchLanguage')));
    await tester.pumpAndSettle();

    expect(directionOf(tester), TextDirection.ltr);
    expect(find.text('Find a dentist and book in minutes'), findsOneWidget);
    // Server-provided catalog text reloads in the new language too.
    expect(find.text('General Dentistry'), findsOneWidget);

    await tester.tap(find.byKey(const Key('switchLanguage')));
    await tester.pumpAndSettle();

    expect(directionOf(tester), TextDirection.rtl);
    expect(find.text('طب الأسنان العام'), findsOneWidget);
  });

  testWidgets('settings language selector persists the choice', (tester) async {
    await pumpMoonlight(tester, language: 'ar');

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(directionOf(tester), TextDirection.ltr);
    expect(
      AppLocalizations.of(tester.element(find.byType(Scaffold).first))
          .settingsTitle,
      'Settings',
    );
    expect((await SharedPreferences.getInstance()).getString('language'), 'en');
  });
}
