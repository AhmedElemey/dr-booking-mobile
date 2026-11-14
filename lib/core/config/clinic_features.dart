/// The clinic's feature switches (`GET /api/v1/features`).
class ClinicFeatures {
  const ClinicFeatures({
    required this.mobileApp,
    required this.website,
    required this.guestBrowsing,
    required this.patientSelfService,
    required this.pushReminders,
    required this.smsNotifications,
    required this.englishLanguage,
    required this.multiBranch,
  });

  final bool mobileApp;
  final bool website;
  final bool guestBrowsing;
  final bool patientSelfService;
  final bool pushReminders;
  final bool smsNotifications;
  final bool englishLanguage;
  final bool multiBranch;

  /// Reads [json], taking any missing or non-boolean key from [defaults] and
  /// ignoring unknown keys.
  factory ClinicFeatures.fromJson(
    Map<String, dynamic> json, {
    required ClinicFeatures defaults,
  }) {
    bool pick(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    return ClinicFeatures(
      mobileApp: pick('mobileApp', defaults.mobileApp),
      website: pick('website', defaults.website),
      guestBrowsing: pick('guestBrowsing', defaults.guestBrowsing),
      patientSelfService: pick(
        'patientSelfService',
        defaults.patientSelfService,
      ),
      pushReminders: pick('pushReminders', defaults.pushReminders),
      smsNotifications: pick('smsNotifications', defaults.smsNotifications),
      englishLanguage: pick('englishLanguage', defaults.englishLanguage),
      multiBranch: pick('multiBranch', defaults.multiBranch),
    );
  }

  Map<String, bool> toJson() => {
    'mobileApp': mobileApp,
    'website': website,
    'guestBrowsing': guestBrowsing,
    'patientSelfService': patientSelfService,
    'pushReminders': pushReminders,
    'smsNotifications': smsNotifications,
    'englishLanguage': englishLanguage,
    'multiBranch': multiBranch,
  };

  ClinicFeatures copyWith({
    bool? mobileApp,
    bool? website,
    bool? guestBrowsing,
    bool? patientSelfService,
    bool? pushReminders,
    bool? smsNotifications,
    bool? englishLanguage,
    bool? multiBranch,
  }) => ClinicFeatures(
    mobileApp: mobileApp ?? this.mobileApp,
    website: website ?? this.website,
    guestBrowsing: guestBrowsing ?? this.guestBrowsing,
    patientSelfService: patientSelfService ?? this.patientSelfService,
    pushReminders: pushReminders ?? this.pushReminders,
    smsNotifications: smsNotifications ?? this.smsNotifications,
    englishLanguage: englishLanguage ?? this.englishLanguage,
    multiBranch: multiBranch ?? this.multiBranch,
  );

  @override
  bool operator ==(Object other) =>
      other is ClinicFeatures &&
      other.mobileApp == mobileApp &&
      other.website == website &&
      other.guestBrowsing == guestBrowsing &&
      other.patientSelfService == patientSelfService &&
      other.pushReminders == pushReminders &&
      other.smsNotifications == smsNotifications &&
      other.englishLanguage == englishLanguage &&
      other.multiBranch == multiBranch;

  @override
  int get hashCode => Object.hash(
    mobileApp,
    website,
    guestBrowsing,
    patientSelfService,
    pushReminders,
    smsNotifications,
    englishLanguage,
    multiBranch,
  );

  @override
  String toString() => 'ClinicFeatures(${toJson()})';
}
