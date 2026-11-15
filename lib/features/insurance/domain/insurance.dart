class InsuranceProvider {
  const InsuranceProvider({required this.id, required this.name});

  final String id;
  final String name;

  factory InsuranceProvider.fromJson(Map<String, dynamic> json) =>
      InsuranceProvider(id: json['id'] as String, name: json['name'] as String);

  @override
  bool operator ==(Object other) =>
      other is InsuranceProvider && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

enum InsuranceStatus {
  pending,
  approved,
  rejected;

  static InsuranceStatus parse(String? value) => switch (value) {
    'Approved' => approved,
    'Rejected' => rejected,
    _ => pending,
  };
}

/// What the patient entered at booking, and the clinic's answer to it.
class AppointmentInsurance {
  const AppointmentInsurance({
    required this.provider,
    required this.memberNumber,
    required this.status,
    this.note,
  });

  final InsuranceProvider provider;
  final String memberNumber;
  final InsuranceStatus status;
  final String? note;

  factory AppointmentInsurance.fromJson(Map<String, dynamic> json) =>
      AppointmentInsurance(
        provider: InsuranceProvider.fromJson(
          json['provider'] as Map<String, dynamic>,
        ),
        memberNumber: (json['memberNumber'] as String?) ?? '',
        status: InsuranceStatus.parse(json['status'] as String?),
        note: json['note'] as String?,
      );
}

/// The insurance choice sent with `POST /appointments`.
class InsuranceChoice {
  const InsuranceChoice({required this.providerId, required this.memberNumber});

  final String providerId;
  final String memberNumber;

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'memberNumber': memberNumber,
  };
}
