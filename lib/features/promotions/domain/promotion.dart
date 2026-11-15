enum DiscountType {
  percent,
  fixed;

  static DiscountType parse(String? value) =>
      value == 'Fixed' ? fixed : percent;
}

/// A public offer (`GET /promotions`).
class Promotion {
  const Promotion({
    required this.code,
    required this.title,
    required this.discountType,
    required this.value,
    this.description,
    this.validTo,
    this.doctorId,
    this.serviceId,
  });

  final String code;
  final String title;
  final String? description;
  final DiscountType discountType;
  final num value;

  /// Last day the code works, `yyyy-MM-dd`.
  final String? validTo;
  final String? doctorId;
  final String? serviceId;

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
    code: json['code'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    discountType: DiscountType.parse(json['discountType'] as String?),
    value: json['value'] as num,
    validTo: (json['validTo'] as String?)?.substring(0, 10),
    doctorId: json['doctorId'] as String?,
    serviceId: json['serviceId'] as String?,
  );
}

/// The reasons `POST /coupons/validate` gives for refusing a code.
enum CouponReason {
  notFound,
  expired,
  notStarted,
  exhausted,
  perPatientLimit,
  notApplicable,
  noPrice,
  unknown;

  static CouponReason parse(String? value) => switch (value) {
    'NotFound' => notFound,
    'Expired' => expired,
    'NotStarted' => notStarted,
    'Exhausted' => exhausted,
    'PerPatientLimit' => perPatientLimit,
    'NotApplicable' => notApplicable,
    'NoPrice' => noPrice,
    _ => unknown,
  };
}

/// `{valid, discountEgp, totalEgp, reason?}`
class CouponValidation {
  const CouponValidation({
    required this.code,
    required this.valid,
    this.discountEgp = 0,
    this.totalEgp,
    this.reason,
  });

  final String code;
  final bool valid;
  final num discountEgp;
  final num? totalEgp;
  final CouponReason? reason;

  factory CouponValidation.fromJson(String code, Map<String, dynamic> json) {
    final valid = json['valid'] == true;
    return CouponValidation(
      code: code,
      valid: valid,
      discountEgp: (json['discountEgp'] as num?) ?? 0,
      totalEgp: json['totalEgp'] as num?,
      reason: valid ? null : CouponReason.parse(json['reason'] as String?),
    );
  }
}
