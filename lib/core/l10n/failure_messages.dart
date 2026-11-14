import '../network/failure.dart';
import 'generated/app_localizations.dart';

extension FailureMessage on AppLocalizations {
  /// The user-facing text for an API failure, keyed by its stable `code`.
  /// Unknown codes fall back to the server's localized `detail`.
  String failureMessage(Object error) {
    if (error is! Failure) return errUnknown;
    return switch (error.code) {
      Failure.network => errNetwork,
      'VALIDATION_FAILED' => errValidation,
      'OTP_INVALID' => errOtpInvalid,
      'OTP_EXPIRED' => errOtpExpired,
      'UNAUTHORIZED' => errUnauthorized,
      'FORBIDDEN' => errForbidden,
      'NOT_FOUND' => errNotFound,
      'SLOT_TAKEN' => errSlotTaken,
      'SLOT_UNAVAILABLE' => errSlotUnavailable,
      'CANCEL_WINDOW_PASSED' => errCancelWindow,
      'INVALID_TRANSITION' => errInvalidTransition,
      'BOOKING_LIMIT' => errBookingLimit,
      'PHONE_IN_USE' => errPhoneInUse,
      'RATE_LIMITED' => errRateLimited,
      'INTERNAL_ERROR' => errServer,
      _ when (error.detail ?? '').isNotEmpty => error.detail!,
      _ => errUnknown,
    };
  }
}
