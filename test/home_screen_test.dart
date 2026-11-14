import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/app.dart';
import 'package:moonlight/core/config/env.dart';
import 'package:moonlight/core/config/env_provider.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [envProvider.overrideWithValue(Env.dev)],
        child: const MoonlightApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextDirection directionOf(WidgetTester tester) =>
      Directionality.of(tester.element(find.byType(Scaffold)));

  testWidgets('starts in Arabic, right to left', (tester) async {
    await pumpApp(tester);

    expect(directionOf(tester), TextDirection.rtl);
    expect(find.text('ابحث عن طبيب أسنان واحجز في دقائق'), findsOneWidget);
  });

  testWidgets('language toggle switches to English, left to right', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('switchLanguage')));
    await tester.pumpAndSettle();

    expect(directionOf(tester), TextDirection.ltr);
    expect(find.text('Find a dentist and book in minutes'), findsOneWidget);
  });
}
