enum RecordKind {
  note,
  diagnosis,
  prescription,
  attachment;

  static RecordKind parse(String? value) => switch (value) {
    'Diagnosis' => diagnosis,
    'Prescription' => prescription,
    'Attachment' => attachment,
    _ => note,
  };
}

class MedicalInfo {
  const MedicalInfo({
    this.bloodType,
    this.allergies,
    this.chronicConditions,
    this.medications,
  });

  final String? bloodType;
  final String? allergies;
  final String? chronicConditions;
  final String? medications;

  bool get isEmpty =>
      [bloodType, allergies, chronicConditions, medications].every(_blank);

  static bool _blank(String? s) => (s ?? '').trim().isEmpty;

  static MedicalInfo? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return MedicalInfo(
      bloodType: json['bloodType'] as String?,
      allergies: json['allergies'] as String?,
      chronicConditions: json['chronicConditions'] as String?,
      medications: json['medications'] as String?,
    );
  }
}

class RecordEntry {
  const RecordEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.hasAttachment = false,
    this.doctorName,
  });

  final String id;
  final RecordKind kind;
  final String title;
  final String? body;

  /// Whether a file is attached. It is downloaded with the signed-in session
  /// from `GET /me/records/{id}/attachment`, never from a public link.
  final bool hasAttachment;

  /// The doctor who wrote the entry, when the clinic shows it.
  final String? doctorName;
  final DateTime createdAt;

  factory RecordEntry.fromJson(Map<String, dynamic> json) => RecordEntry(
    id: json['id'] as String,
    kind: RecordKind.parse(json['kind'] as String?),
    title: json['title'] as String,
    body: json['body'] as String?,
    hasAttachment:
        json['hasAttachment'] == true ||
        ((json['attachmentUrl'] as String?) ?? '').isNotEmpty,
    doctorName: json['doctorName'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// `GET /me/records`: the patient's own medical info and the entries the clinic
/// chose to show them.
class PatientRecords {
  const PatientRecords({this.medicalInfo, this.entries = const []});

  final MedicalInfo? medicalInfo;
  final List<RecordEntry> entries;

  factory PatientRecords.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'] ?? json['records'];
    return PatientRecords(
      medicalInfo: MedicalInfo.fromJson(json['medicalInfo']),
      entries: [
        if (raw is List)
          for (final e in raw) RecordEntry.fromJson(e as Map<String, dynamic>),
      ],
    );
  }
}
