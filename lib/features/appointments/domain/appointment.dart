import '../../../shared/domain/clinic.dart';

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
      doctor: AppointmentDoctor(
        id: doctor['id'] as String,
        name: doctor['name'] as String,
        slug: doctor['slug'] as String?,
        photoUrl: doctor['photoUrl'] as String?,
      ),
      clinic: Clinic.fromJson(json['clinic'] as Map<String, dynamic>),
      service: service is Map<String, dynamic>
          ? ServiceItem.fromJson(service)
          : null,
      patientNote: json['patientNote'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
      cancelReason: json['cancelReason'] as String?,
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
