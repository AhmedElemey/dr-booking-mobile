import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:moonlight/core/links/url_opener.dart';
import 'package:moonlight/core/network/dio_provider.dart';
import 'package:moonlight/core/network/failure.dart';
import 'package:moonlight/core/router/app_router.dart';
import 'package:moonlight/features/appointments/data/appointments_repository.dart';
import 'package:moonlight/features/appointments/domain/appointment.dart';
import 'package:moonlight/features/insurance/domain/insurance.dart';
import 'package:moonlight/features/records/data/records_repository.dart';
import 'package:moonlight/features/waiting_list/data/waiting_list_repository.dart';
import 'package:dio/dio.dart';

import '../support/pump_app.dart';

Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.event_note_outlined));
  await tester.pumpAndSettle();
  await signInViaUi(tester);
}

/// A repository whose booking is always refused with [fieldErrors].
class _RefusingAppointments extends AppointmentsRepository {
  _RefusingAppointments(this.fieldErrors) : super(Dio());

  final Map<String, List<String>> fieldErrors;
  final bodies = <Map<String, Object?>>[];

  @override
  ApiResult<Appointment> book({
    required String slotId,
    String? serviceId,
    String? note,
    String? familyMemberId,
    AppointmentMode? mode,
    InsuranceChoice? insurance,
    String? couponCode,
  }) async {
    bodies.add({
      'familyMemberId': familyMemberId,
      'mode': mode,
      'insurance': insurance,
    });
    return Left(
      Failure(
        code: 'VALIDATION_FAILED',
        statusCode: 422,
        fieldErrors: fieldErrors,
      ),
    );
  }
}

Future<void> _toConfirm(
  WidgetTester tester, {
  String doctor = 'Dr. Mona Hassan',
}) async {
  containerOf(tester).read(routerProvider).go('/doctors');
  await tester.pumpAndSettle();
  await tester.tap(find.text(doctor));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('bookAppointment')));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ChoiceChip).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('continueToConfirm')));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Writing the downloaded file is real I/O, which only completes outside the
/// fake-async clock: alternate between advancing it and yielding to the loop
/// until the download spinner clears. A hard cap keeps a broken download from
/// hanging pumpAndSettle on the spinner; it fails clearly instead.
Future<void> _settleWithIo(WidgetTester tester) async {
  await tester.pump(); // Let the tap's setState build the busy spinner.
  final sw = Stopwatch()..start();
  while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
      sw.elapsed < const Duration(seconds: 10)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
    fail('Attachment download did not finish within 10 seconds.');
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a started checkout offers "Continue payment"', (tester) async {
    await pumpMoonlight(tester, phase2: true);
    await _signIn(tester);
    containerOf(tester).read(routerProvider).go('/appointments/apt-1');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('payOnline')));
    expect(find.text('Pay online'), findsOneWidget);
    expect(find.text('Continue payment'), findsNothing);

    // Start the demo checkout and leave it without paying.
    await tester.tap(find.byKey(const Key('payOnline')));
    await pumpUi(tester);
    expect(find.byKey(const Key('demoPay')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await pumpUi(tester);
    await tester.pumpAndSettle();

    containerOf(tester).read(routerProvider).go('/appointments');
    await tester.pumpAndSettle();
    containerOf(tester).read(routerProvider).go('/appointments/apt-1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('payOnline')));
    expect(find.text('Continue payment'), findsOneWidget);
    expect(find.byKey(const Key('payOnline')), findsOneWidget);
  });

  testWidgets('the payment return link closes the checkout browser', (
    tester,
  ) async {
    var closed = 0;
    await pumpMoonlight(
      tester,
      phase2: true,
      overrides: [
        inAppBrowserCloserProvider.overrideWithValue(() async => closed++),
      ],
    );
    await _signIn(tester);
    final router = containerOf(tester).read(routerProvider);
    // The custom-scheme URI the OS hands the app, run through the redirect.
    router.go('com.moonlight.app://payment-return?paymentId=nope&status=paid');
    await tester.pumpAndSettle();
    expect(find.text('Payment'), findsWidgets);
    expect(closed, 1);
    expect(router.routeInformationProvider.value.uri.path, '/payment-return');
  });

  testWidgets('a record attachment is downloaded with the session and opened', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('rec_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final opened = <File>[];
    await pumpMoonlight(
      tester,
      phase2: true,
      overrides: [
        recordsRepositoryProvider.overrideWith(
          (ref) => RecordsRepository(
            ref.watch(dioProvider),
            tempDir: () async => dir,
          ),
        ),
        fileOpenerProvider.overrideWithValue((file) async {
          opened.add(file);
          return true;
        }),
      ],
    );
    await _signIn(tester);
    containerOf(tester).read(routerProvider).go('/records');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recordDoctor-rec-1')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-rec-3')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open-rec-3')));
    await _settleWithIo(tester);
    expect(opened, hasLength(1));
    expect(opened.single.path.endsWith('/panorama.pdf'), isTrue);
    expect(opened.single.readAsStringSync(), startsWith('%PDF'));
    expect(
      find.text("Couldn't open the file. Check your connection and try again."),
      findsNothing,
    );
  });

  testWidgets('an attachment that cannot be opened says so', (tester) async {
    final dir = Directory.systemTemp.createTempSync('rec_');
    addTearDown(() => dir.deleteSync(recursive: true));
    await pumpMoonlight(
      tester,
      phase2: true,
      overrides: [
        recordsRepositoryProvider.overrideWith(
          (ref) => RecordsRepository(
            ref.watch(dioProvider),
            tempDir: () async => dir,
          ),
        ),
        fileOpenerProvider.overrideWithValue((file) async => false),
      ],
    );
    await _signIn(tester);
    containerOf(tester).read(routerProvider).go('/records');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-rec-3')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open-rec-3')));
    await _settleWithIo(tester);
    expect(find.textContaining("Couldn't open the file"), findsOneWidget);
  });

  testWidgets('the waiting list shows who an entry is for', (tester) async {
    await pumpMoonlight(tester, phase2: true);
    await _signIn(tester);
    final container = containerOf(tester);
    container.read(routerProvider).go('/waiting-list');
    await tester.pumpAndSettle();
    expect(find.textContaining('Booking for:'), findsNothing);

    final pending = container
        .read(waitingListRepositoryProvider)
        .join(
          doctorId: 'doc-1',
          date: _ymd(DateTime.now().add(const Duration(days: 9))),
          familyMemberId: 'fam-1',
        );
    await tester.pump(const Duration(seconds: 1));
    final entry = (await pending).toNullable()!;
    expect(entry.familyMember?.id, 'fam-1');

    container.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/waiting-list');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('waitingFor-${entry.id}')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(Key('waitingFor-${entry.id}'))).data,
      contains('يوسف نور'),
    );
  });

  testWidgets('joining the waiting list asks who it is for', (tester) async {
    await pumpMoonlight(tester, phase2: true);
    await _signIn(tester);
    final container = containerOf(tester);
    const slug = 'mona-hassan';
    container.read(routerProvider).go('/doctors/$slug/slots');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('joinWaitingList')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('joinWaitingList')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bookingFor')), findsOneWidget);
    await tester.tap(find.byKey(const Key('for-fam-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('waitingMemberContinue')));
    await tester.pumpAndSettle();
    // The date picker follows; cancel it: nothing is joined.
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final pending = container.read(waitingListRepositoryProvider).mine();
    await tester.pump(const Duration(seconds: 1));
    final list = (await pending).toNullable()!;
    expect(list.where((e) => e.familyMember != null), isEmpty);
  });

  group('booking refused by the API', () {
    Future<_RefusingAppointments> start(
      WidgetTester tester,
      Map<String, List<String>> errors,
    ) async {
      final repo = _RefusingAppointments(errors);
      await pumpMoonlight(
        tester,
        phase2: true,
        overrides: [appointmentsRepositoryProvider.overrideWithValue(repo)],
      );
      await _signIn(tester);
      await _toConfirm(tester);
      return repo;
    }

    testWidgets('video no longer offered: back to in person, control hidden', (
      tester,
    ) async {
      final repo = await start(tester, {
        'mode': ['This doctor does not offer video consultations.'],
      });
      await _scrollTo(tester, const Key('visitMode'));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('visitMode')),
          matching: find.byIcon(Icons.videocam_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, const Key('confirmBooking'));
      await tester.tap(find.byKey(const Key('confirmBooking')));
      await tester.pumpAndSettle();

      expect(repo.bodies.single['mode'], AppointmentMode.video);
      expect(
        find.textContaining(
          'no longer offers video visits',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('visitMode')), findsNothing);
    });

    testWidgets('insurer refused: the member number rule keeps its text', (
      tester,
    ) async {
      final repo = await start(tester, {
        'insurance.providerId': ['not accepted'],
      });
      await _scrollTo(tester, const Key('useInsurance'));
      await tester.tap(find.byKey(const Key('useInsurance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('insurerField')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenuItem<InsuranceProvider>).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('memberNumberField')), 'M-1');
      await _scrollTo(tester, const Key('confirmBooking'));
      await tester.tap(find.byKey(const Key('confirmBooking')));
      await tester.pumpAndSettle();

      expect(repo.bodies.single['insurance'], isNotNull);
      await _scrollTo(tester, const Key('bookingError'));
      expect(
        find.textContaining(
          'does not accept that insurance provider',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('family member refused: back to "me"', (tester) async {
      final repo = await start(tester, {
        'familyMemberId': ['not found'],
      });
      await _scrollTo(tester, const Key('for-fam-1'));
      await tester.tap(find.byKey(const Key('for-fam-1')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, const Key('confirmBooking'));
      await tester.tap(find.byKey(const Key('confirmBooking')));
      await tester.pumpAndSettle();
      expect(repo.bodies.single['familyMemberId'], 'fam-1');
      expect(
        find.textContaining('no longer available', skipOffstage: false),
        findsOneWidget,
      );
      await _scrollTo(tester, const Key('for-me'));
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('for-me'))).selected,
        isTrue,
      );
    });
  });

  testWidgets('text inputs carry the backend length limits', (tester) async {
    await pumpMoonlight(tester, phase2: true);
    await _signIn(tester);
    await _toConfirm(tester);
    await _scrollTo(tester, const Key('useInsurance'));
    await tester.tap(find.byKey(const Key('useInsurance')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('memberNumberField')))
          .maxLength,
      100,
    );
    await _scrollTo(tester, const Key('addMemberChip'));
    await tester.tap(find.byKey(const Key('addMemberChip')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('familyNameField')))
          .maxLength,
      200,
    );
  });
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
