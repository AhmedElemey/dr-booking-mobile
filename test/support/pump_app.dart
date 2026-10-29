import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/app.dart';
import 'package:moonlight/core/config/env.dart';
import 'package:moonlight/core/config/env_provider.dart';
import 'package:moonlight/core/storage/local_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the whole app against the in-app mock API, on a phone-sized screen.
/// [language] is the saved choice (null = first launch).
Future<void> pumpMoonlight(
  WidgetTester tester, {
  String? language = 'en',
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'language': ?language});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        envProvider.overrideWithValue(Env.mock),
        localSettingsProvider.overrideWithValue(LocalSettings(prefs)),
        ...overrides,
      ],
      child: const MoonlightApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Advances time in small steps. `pumpAndSettle` cannot be used while the OTP
/// screen's resend countdown is running, since it never stops scheduling frames.
Future<void> pumpUi(WidgetTester tester, {int steps = 12}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Logs in through the real screens (any phone, code 123456).
Future<void> signInViaUi(
  WidgetTester tester, {
  String phone = '01012345678',
}) async {
  await tester.enterText(find.byKey(const Key('phoneField')), phone);
  await tester.tap(find.byKey(const Key('sendCode')));
  await pumpUi(tester);
  await tester.enterText(find.byKey(const Key('otpField')), '123456');
  await pumpUi(tester);
  await tester.pumpAndSettle();
}

/// The container behind the running app, for reaching providers in tests.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MoonlightApp)));
