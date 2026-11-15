import '../../appointments/domain/appointment.dart';
import '../../family/domain/family_member.dart';

enum WaitingStatus {
  waiting,
  notified,
  booked,
  cancelled,
  expired;

  static WaitingStatus parse(String? value) => switch (value) {
    'Notified' => notified,
    'Booked' => booked,
    'Cancelled' => cancelled,
    'Expired' => expired,
    _ => waiting,
  };
}

class WaitingEntry {
  const WaitingEntry({
    required this.id,
    required this.doctor,
    required this.date,
    required this.status,
    this.notifiedAt,
    this.familyMember,
  });

  final String id;
  final AppointmentDoctor doctor;

  /// Clinic-local calendar date, `yyyy-MM-dd`.
  final String date;
  final WaitingStatus status;
  final DateTime? notifiedAt;

  /// Who the patient is waiting for; null when it is the account owner.
  final FamilyMemberRef? familyMember;

  /// Whether the patient can still leave the list.
  bool get isActive =>
      status == WaitingStatus.waiting || status == WaitingStatus.notified;

  factory WaitingEntry.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'] as Map<String, dynamic>;
    final notified = json['notifiedAt'] as String?;
    final member = json['familyMember'];
    return WaitingEntry(
      id: json['id'] as String,
      doctor: AppointmentDoctor.fromJson(doctor),
      date: (json['date'] as String).substring(0, 10),
      status: WaitingStatus.parse(json['status'] as String?),
      notifiedAt: notified == null ? null : DateTime.parse(notified),
      familyMember: member is Map<String, dynamic>
          ? FamilyMemberRef.fromJson(member)
          : null,
    );
  }
}
