import '../../../shared/domain/clinic.dart';
import '../../insurance/domain/insurance.dart';
import '../../reviews/domain/review.dart';
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
    this.offersVideo = false,
    this.rating,
    this.insuranceProviders = const [],
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

  /// Phase 2: video consultations, average rating and accepted insurers.
  final bool offersVideo;
  final DoctorRating? rating;
  final List<InsuranceProvider> insuranceProviders;

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
      offersVideo: json['offersVideo'] == true,
      rating: DoctorRating.fromJson(json['rating']),
      insuranceProviders: [
        if (json['insuranceProviders'] is List)
          for (final p in json['insuranceProviders'] as List)
            InsuranceProvider.fromJson(p as Map<String, dynamic>),
      ],
    );
  }
}
