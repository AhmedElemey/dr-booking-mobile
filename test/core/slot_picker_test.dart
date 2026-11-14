import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:moonlight/core/l10n/generated/app_localizations.dart';
import 'package:moonlight/features/doctor/domain/doctor_slots.dart';
import 'package:moonlight/shared/widgets/slot_picker.dart';

Slot _slot(String id, String utc, String local) => Slot(
  id: id,
  startsAt: DateTime.parse(utc),
  endsAt: DateTime.parse(utc).add(const Duration(minutes: 30)),
  local: local,
);

void main() {
  final slots = DoctorSlots(
    doctorId: 'doc-1',
    timezone: 'Africa/Cairo',
    days: [
      SlotDay(
        date: '2026-11-02',
        slots: [
          _slot('a', '2026-11-02T07:00:00Z', '09:00'),
          _slot('b', '2026-11-02T07:30:00Z', '09:30'),
        ],
      ),
      SlotDay(
        date: '2026-11-03',
        slots: [_slot('c', '2026-11-03T14:00:00Z', '16:00')],
      ),
      const SlotDay(date: '2026-11-04', slots: []),
    ],
  );

  Future<void> pump(
    WidgetTester tester,
    String lang,
    ValueChanged<Slot> onTap, [
    Slot? selected,
  ]) {
    return tester.pumpWidget(
      MaterialApp(
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SlotPicker(slots: slots, selected: selected, onSelected: onTap),
        ),
      ),
    );
  }

  String clock(String lang, int h, int m) =>
      DateFormat.jm(lang).format(DateTime(2000, 1, 1, h, m));

  testWidgets('shows the API clinic-local times, whatever the device zone', (
    tester,
  ) async {
    await pump(tester, 'en', (_) {});
    await tester.pumpAndSettle();

    // 07:00Z is shown as the slot's `local` 09:00, never converted.
    expect(find.text(clock('en', 9, 0)), findsOneWidget);
    expect(find.text(clock('en', 9, 30)), findsOneWidget);
    expect(find.text(clock('en', 7, 0)), findsNothing);
  });

  testWidgets('groups slots by day and hides days without slots', (
    tester,
  ) async {
    Slot? tapped;
    await pump(tester, 'en', (s) => tapped = s);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('day-2026-11-02')), findsOneWidget);
    expect(find.byKey(const Key('day-2026-11-03')), findsOneWidget);
    expect(find.byKey(const Key('day-2026-11-04')), findsNothing);
    expect(find.byKey(const Key('slot-c')), findsNothing);

    await tester.tap(find.byKey(const Key('day-2026-11-03')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('slot-a')), findsNothing);
    await tester.tap(find.byKey(const Key('slot-c')));

    expect(tapped?.id, 'c');
  });

  testWidgets('renders in Arabic with right-to-left day strip', (tester) async {
    await pump(tester, 'ar', (_) {});
    await tester.pumpAndSettle();

    expect(find.text(clock('ar', 9, 0)), findsOneWidget);
    final first = tester.getCenter(find.byKey(const Key('day-2026-11-02')));
    final second = tester.getCenter(find.byKey(const Key('day-2026-11-03')));
    expect(first.dx, greaterThan(second.dx)); // earlier day starts on the right
  });
}
