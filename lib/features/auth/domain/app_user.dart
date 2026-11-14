/// The signed-in user (`GET /me`).
class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.role,
    required this.preferredLanguage,
    this.fullName,
    this.whatsAppOptIn = true,
    this.marketingOptIn = true,
  });

  final String id;
  final String phone;
  final String role;
  final String preferredLanguage;

  /// Null until the profile is completed after the first login.
  final String? fullName;

  /// Reminder and offer opt-ins (default on until the patient says otherwise).
  final bool whatsAppOptIn;
  final bool marketingOptIn;

  bool get isPatient => role == 'Patient';
  bool get hasName => (fullName ?? '').trim().isNotEmpty;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    phone: json['phone'] as String,
    role: (json['role'] as String?) ?? 'Patient',
    preferredLanguage: (json['preferredLanguage'] as String?) ?? 'ar',
    fullName: json['fullName'] as String?,
    whatsAppOptIn: json['whatsAppOptIn'] as bool? ?? true,
    marketingOptIn: json['marketingOptIn'] as bool? ?? true,
  );
}

/// Result of `POST /auth/otp/verify` (tokens are already stored).
class VerifiedLogin {
  const VerifiedLogin({required this.user, required this.isNewUser});

  final AppUser user;
  final bool isNewUser;
}
