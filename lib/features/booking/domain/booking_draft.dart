import '../../doctor/domain/doctor.dart';
import '../../doctor/domain/doctor_slots.dart';

/// What the patient has picked so far, kept across the login detour so a guest
/// who signs in lands back on the same confirm screen.
class BookingDraft {
  const BookingDraft({
    required this.doctor,
    required this.slot,
    required this.timezone,
    required this.slotDate,
  });

  final Doctor doctor;
  final Slot slot;
  final String timezone;

  /// Clinic-local `yyyy-MM-dd` of the slot.
  final String slotDate;
}
