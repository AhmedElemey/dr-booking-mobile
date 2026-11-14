import '../../../shared/domain/clinic.dart';
import '../../family/domain/family_member.dart';
import '../../insurance/domain/insurance.dart';
import '../../payments/domain/payment.dart';
import '../../reviews/domain/review.dart';
import '../../video/domain/video_room.dart';

/// How the visit takes place (`mode`).
enum AppointmentMode {
  inPerson,
  video;

  static AppointmentMode parse(String? value) =>
      value == 'Video' ? video : inPerson;

  String get wire => this == video ? 'Video' : 'InPerson';
}

enum AppointmentStatus {
  confirmed,
  cancelled,
  completed,
  noShow;

  static AppointmentStatus parse(String? value) => switch (value) {
    'Cancelled' => cancelled,
    'Completed' => completed,
    'NoShow' => noShow,
    _ => confirmed,
  };
}

class AppointmentDoctor {
  const AppointmentDoctor({
    required this.id,
    required this.name,
    this.slug,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String? slug;
  final String? photoUrl;

  /// What the doctor endpoints accept as `{idOrSlug}`.
  String get key => slug ?? id;

  factory AppointmentDoctor.fromJson(Map<String, dynamic> json) =>
      AppointmentDoctor(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String?,
        photoUrl: json['photoUrl'] as String?,
      );
}

class Appointment {
  const Appointment({
    required this.id,
    required this.status,
    required this.slotId,
    required this.startsAt,
    required this.endsAt,
    required this.startsAtLocal,
    required this.timezone,
    required this.doctor,
    required this.clinic,
    this.service,
    this.patientNote,
    this.cancelledBy,
    this.cancelReason,
    this.familyMember,
    this.mode = AppointmentMode.inPerson,
    this.priceEgp,
    this.discountEgp = 0,
    this.totalEgp,
    this.paymentStatus = AppointmentPaymentStatus.unpaid,
    this.insurance,
    this.canReview = false,
    this.review,
  });

  final String id;
  final AppointmentStatus status;
  final String slotId;

  /// The instant, in UTC (for comparisons and calendar export).
  final DateTime startsAt;
  final DateTime endsAt;

  /// Clinic wall-clock start as a zone-less [DateTime]: read its fields, never
  /// convert it. This is what screens format, so the device timezone is moot.
  final DateTime startsAtLocal;
  final String timezone;
  final AppointmentDoctor doctor;
  final Clinic clinic;
  final ServiceItem? service;
  final String? patientNote;
  final String? cancelledBy;
  final String? cancelReason;

  /// Who the visit is for, when it was booked for a family member.
  final FamilyMemberRef? familyMember;
  final AppointmentMode mode;

  /// Price before and after discounts (only meaningful with online payments or
  /// promotions on).
  final num? priceEgp;
  final num discountEgp;
  final num? totalEgp;
  final AppointmentPaymentStatus paymentStatus;
  final AppointmentInsurance? insurance;
  final bool canReview;
  final AppointmentReview? review;

  bool get isVideo => mode == AppointmentMode.video;

  /// Whether "Pay online" applies: a future confirmed visit with something to pay.
  bool get canPayOnline =>
      isUpcoming &&
      paymentStatus == AppointmentPaymentStatus.unpaid &&
      (totalEgp ?? 0) > 0;

  /// When the video room opens and closes (start - 15 min, end + 30 min).
  DateTime get videoOpensAt => startsAt.subtract(videoOpensBefore);
  DateTime get videoClosesAt => endsAt.add(videoClosesAfter);

  bool isVideoOpen(DateTime now) =>
      isVideo &&
      status == AppointmentStatus.confirmed &&
      !now.isBefore(videoOpensAt) &&
      !now.isAfter(videoClosesAt);

  Duration get duration => endsAt.difference(startsAt);
  DateTime get endsAtLocal => startsAtLocal.add(duration);

  bool get isUpcoming =>
      status == AppointmentStatus.confirmed &&
      startsAt.isAfter(DateTime.now().toUtc());

  /// Whether the UI offers cancel / reschedule (the server enforces the window).
  bool get canChange => isUpcoming;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'] as Map<String, dynamic>;
    final service = json['service'];
    return Appointment(
      id: json['id'] as String,
      status: AppointmentStatus.parse(json['status'] as String?),
      slotId: json['slotId'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String).toUtc(),
      endsAt: DateTime.parse(json['endsAt'] as String).toUtc(),
      startsAtLocal: parseLocalDateTime(json['startsAtLocal'] as String),
      timezone: (json['timezone'] as String?) ?? 'Africa/Cairo',
      doctor: AppointmentDoctor.fromJson(doctor),
      clinic: Clinic.fromJson(json['clinic'] as Map<String, dynamic>),
      service: service is Map<String, dynamic>
          ? ServiceItem.fromJson(service)
          : null,
      patientNote: json['patientNote'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
      cancelReason: json['cancelReason'] as String?,
      familyMember: json['familyMember'] is Map<String, dynamic>
          ? FamilyMemberRef.fromJson(
              json['familyMember'] as Map<String, dynamic>,
            )
          : null,
      mode: AppointmentMode.parse(json['mode'] as String?),
      priceEgp: json['priceEgp'] as num?,
      discountEgp: (json['discountEgp'] as num?) ?? 0,
      totalEgp: json['totalEgp'] as num?,
      paymentStatus: AppointmentPaymentStatus.parse(
        json['paymentStatus'] as String?,
      ),
      insurance: json['insurance'] is Map<String, dynamic>
          ? AppointmentInsurance.fromJson(
              json['insurance'] as Map<String, dynamic>,
            )
          : null,
      canReview: json['canReview'] == true,
      review: AppointmentReview.fromJson(json['review']),
    );
  }
}

/// Reads the date and time fields of `2026-11-02T09:00:00` (optionally with a
/// `+02:00` / `Z` suffix) as written, without any zone conversion.
DateTime parseLocalDateTime(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})')
      .firstMatch(value);
  if (match == null) throw FormatException('Bad local date-time', value);
  final n = [for (var i = 1; i <= 5; i++) int.parse(match.group(i)!)];
  return DateTime(n[0], n[1], n[2], n[3], n[4]);
}
