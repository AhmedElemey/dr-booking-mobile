import '../../../core/network/failure.dart';

/// Which booking field the API refused with a 422/400 `VALIDATION_FAILED`.
/// The field messages in `errors` are English only, so the app maps the keys to
/// its own texts and resets the control.
enum BookingIssue {
  mode,
  insuranceProvider,
  insuranceMemberNumber,
  familyMember;

  static BookingIssue? from(Failure failure) {
    if (failure.code != 'VALIDATION_FAILED') return null;
    final keys = failure.fieldErrors.keys.map((k) => k.toLowerCase()).toSet();
    if (keys.contains('mode')) return mode;
    if (keys.contains('insurance.providerid')) return insuranceProvider;
    if (keys.contains('insurance.membernumber')) return insuranceMemberNumber;
    if (keys.contains('familymemberid')) return familyMember;
    return null;
  }
}
