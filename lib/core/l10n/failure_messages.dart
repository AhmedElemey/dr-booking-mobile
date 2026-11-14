import '../../features/promotions/domain/promotion.dart';
import '../network/failure.dart';
import '../config/brand_l10n.dart';
import 'generated/app_localizations.dart';

extension FailureMessage on AppLocalizations {
  /// The user-facing text for an API failure, keyed by its stable `code`.
  /// Unknown codes fall back to the server's localized `detail`.
  String failureMessage(Object error) {
    if (error is! Failure) return errUnknown;
    return switch (error.code) {
      Failure.network => errNetwork(brandName),
      'VALIDATION_FAILED' => errValidation,
      'OTP_INVALID' => errOtpInvalid,
      'OTP_EXPIRED' => errOtpExpired,
      'UNAUTHORIZED' => errUnauthorized,
      'FORBIDDEN' => errForbidden(brandName),
      'FEATURE_DISABLED' =>
        error.feature == 'patientSelfService'
            ? errSelfServiceDisabled
            : errFeatureDisabled,
      'NOT_FOUND' => errNotFound,
      'SLOT_TAKEN' => errSlotTaken,
      'SLOT_UNAVAILABLE' => errSlotUnavailable,
      'CANCEL_WINDOW_PASSED' => errCancelWindow,
      'INVALID_TRANSITION' => errInvalidTransition,
      'BOOKING_LIMIT' => errBookingLimit,
      'PHONE_IN_USE' => errPhoneInUse,
      'RATE_LIMITED' => errRateLimited,
      'INTERNAL_ERROR' => errServer,
      'CLINIC_CLOSED' => errClinicClosed,
      'COUPON_INVALID' => couponReasonMessage(CouponReason.parse(error.reason)),
      'ALREADY_REVIEWED' => errAlreadyReviewed,
      'NOT_REVIEWABLE' => errNotReviewable,
      'PAYMENT_NOT_ALLOWED' => errPaymentNotAllowed,
      'VIDEO_NOT_OPEN' => errVideoNotOpen,
      'ALREADY_WAITING' => errAlreadyWaiting,
      'PROVIDER_ERROR' => errProvider,
      _ when (error.detail ?? '').isNotEmpty => error.detail!,
      _ => errUnknown,
    };
  }

  /// Why a coupon code was refused (`reason` of `POST /coupons/validate`).
  String couponReasonMessage(CouponReason? reason) => switch (reason) {
    CouponReason.notFound => couponNotFound,
    CouponReason.expired => couponExpired,
    CouponReason.notStarted => couponNotStarted,
    CouponReason.exhausted => couponExhausted,
    CouponReason.perPatientLimit => couponPerPatient,
    CouponReason.notApplicable => couponNotApplicable,
    CouponReason.noPrice => couponNoPrice,
    _ => couponInvalid,
  };
}
