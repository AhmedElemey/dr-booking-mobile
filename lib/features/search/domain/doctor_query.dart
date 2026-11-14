/// Filters of a doctor search (`GET /doctors`).
class DoctorQuery {
  const DoctorQuery({
    this.specialtyId,
    this.city,
    this.text,
    this.insuranceProviderId,
  });

  final String? specialtyId;
  final String? city;

  /// Free-text doctor name.
  final String? text;

  /// Only doctors that accept this insurance provider (`insurance` feature).
  final String? insuranceProviderId;

  DoctorQuery copyWith({
    String? Function()? specialtyId,
    String? Function()? city,
    String? Function()? text,
    String? Function()? insuranceProviderId,
  }) => DoctorQuery(
    specialtyId: specialtyId != null ? specialtyId() : this.specialtyId,
    city: city != null ? city() : this.city,
    text: text != null ? text() : this.text,
    insuranceProviderId: insuranceProviderId != null
        ? insuranceProviderId()
        : this.insuranceProviderId,
  );

  @override
  bool operator ==(Object other) =>
      other is DoctorQuery &&
      other.specialtyId == specialtyId &&
      other.city == city &&
      other.text == text &&
      other.insuranceProviderId == insuranceProviderId;

  @override
  int get hashCode => Object.hash(specialtyId, city, text, insuranceProviderId);
}
