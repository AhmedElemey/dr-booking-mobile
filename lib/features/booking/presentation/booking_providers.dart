import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appointments/domain/appointment.dart';
import '../domain/booking_draft.dart';

class BookingDraftController extends Notifier<BookingDraft?> {
  @override
  BookingDraft? build() => null;

  void set(BookingDraft draft) => state = draft;
  void clear() => state = null;
}

final bookingDraftProvider =
    NotifierProvider<BookingDraftController, BookingDraft?>(
      BookingDraftController.new,
    );

class LastBookingController extends Notifier<Appointment?> {
  @override
  Appointment? build() => null;

  void set(Appointment appointment) => state = appointment;
}

/// The appointment just booked, shown on the success screen (local state).
final lastBookingProvider =
    NotifierProvider<LastBookingController, Appointment?>(
      LastBookingController.new,
    );
