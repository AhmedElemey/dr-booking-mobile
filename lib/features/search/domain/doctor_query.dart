/// Filters of a doctor search (`GET /doctors`).
class DoctorQuery {
  const DoctorQuery({this.specialtyId, this.city, this.text});

  final String? specialtyId;
  final String? city;

  /// Free-text doctor name.
  final String? text;

  DoctorQuery copyWith({
    String? Function()? specialtyId,
    String? Function()? city,
    String? Function()? text,
  }) => DoctorQuery(
    specialtyId: specialtyId != null ? specialtyId() : this.specialtyId,
    city: city != null ? city() : this.city,
    text: text != null ? text() : this.text,
  );

  @override
  bool operator ==(Object other) =>
      other is DoctorQuery &&
      other.specialtyId == specialtyId &&
      other.city == city &&
      other.text == text;

  @override
  int get hashCode => Object.hash(specialtyId, city, text);
}
