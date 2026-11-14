class Specialty {
  const Specialty({required this.id, required this.name});

  final String id;
  final String name;

  factory Specialty.fromJson(Map<String, dynamic> json) =>
      Specialty(id: json['id'] as String, name: json['name'] as String);
}
