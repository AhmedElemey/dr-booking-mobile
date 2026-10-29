import '../../../shared/domain/clinic.dart';
import '../../search/domain/specialty.dart';

/// A published doctor. Search results leave `bio` and `services` empty; the
/// profile (`GET /doctors/{idOrSlug}`) fills them in.
class Doctor {
  const Doctor({
    required this.id,
    required this.slug,
    required this.name,
    this.photoUrl,
    this.bio,
    this.specialty,
    this.clinic,
    this.yearsExperience,
    this.consultationFeeEgp,
    this.services = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String? photoUrl;
  final String? bio;
  final Specialty? specialty;
  final Clinic? clinic;
  final int? yearsExperience;
  final num? consultationFeeEgp;
  final List<ServiceItem> services;

  factory Doctor.fromJson(Map<String, dynamic> json) {
    final specialty = json['specialty'];
    final clinic = json['clinic'];
    final services = json['services'];
    return Doctor(
      id: json['id'] as String,
      slug: (json['slug'] as String?) ?? json['id'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String?,
      specialty: specialty is Map<String, dynamic>
          ? Specialty.fromJson(specialty)
          : null,
      clinic: clinic is Map<String, dynamic> ? Clinic.fromJson(clinic) : null,
      yearsExperience: (json['yearsExperience'] as num?)?.toInt(),
      consultationFeeEgp: json['consultationFeeEgp'] as num?,
      services: [
        if (services is List)
          for (final s in services)
            ServiceItem.fromJson(s as Map<String, dynamic>),
      ],
    );
  }
}
