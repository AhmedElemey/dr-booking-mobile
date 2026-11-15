enum FamilyRelation {
  child('Child'),
  spouse('Spouse'),
  parent('Parent'),
  sibling('Sibling'),
  other('Other');

  const FamilyRelation(this.wire);

  /// The PascalCase string the API uses.
  final String wire;

  static FamilyRelation parse(String? value) =>
      values.firstWhere((r) => r.wire == value, orElse: () => other);
}

enum FamilyGender {
  male('Male'),
  female('Female');

  const FamilyGender(this.wire);

  final String wire;

  static FamilyGender? parse(String? value) {
    for (final g in values) {
      if (g.wire == value) return g;
    }
    return null;
  }
}

/// A person the account owner books for (`/me/family`).
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.fullName,
    required this.relation,
    this.dateOfBirth,
    this.gender,
  });

  final String id;
  final String fullName;
  final FamilyRelation relation;

  /// Calendar date, `yyyy-MM-dd`.
  final String? dateOfBirth;
  final FamilyGender? gender;

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    relation: FamilyRelation.parse(json['relation'] as String?),
    dateOfBirth: _dateOnly(json['dateOfBirth'] as String?),
    gender: FamilyGender.parse(json['gender'] as String?),
  );

  FamilyMemberRef get ref =>
      FamilyMemberRef(id: id, fullName: fullName, relation: relation);

  static String? _dateOnly(String? value) =>
      value == null || value.length < 10 ? null : value.substring(0, 10);
}

/// The `{id, fullName, relation}` summary an appointment carries.
class FamilyMemberRef {
  const FamilyMemberRef({
    required this.id,
    required this.fullName,
    required this.relation,
  });

  final String id;
  final String fullName;
  final FamilyRelation relation;

  factory FamilyMemberRef.fromJson(Map<String, dynamic> json) =>
      FamilyMemberRef(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        relation: FamilyRelation.parse(json['relation'] as String?),
      );
}
