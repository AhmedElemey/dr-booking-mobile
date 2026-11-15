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
    required this.videoConsultation,
    required this.waitingList,
    required this.familyAccounts,
    required this.whatsappReminders,
    required this.onlinePayments,
    required this.insurance,
    required this.holidayCalendar,
    required this.workingHoursTemplates,
    required this.patientRecords,
    required this.reviews,
    required this.promotions,
    required this.recallCampaigns,
    required this.reports,
  });

  final bool mobileApp;
  final bool website;
  final bool guestBrowsing;
  final bool patientSelfService;
  final bool pushReminders;
  final bool smsNotifications;
  final bool englishLanguage;
  final bool multiBranch;
  final bool videoConsultation;
  final bool waitingList;
  final bool familyAccounts;
  final bool whatsappReminders;
  final bool onlinePayments;
  final bool insurance;
  final bool holidayCalendar;
  final bool workingHoursTemplates;
  final bool patientRecords;
  final bool reviews;
  final bool promotions;
  final bool recallCampaigns;
  final bool reports;

  /// The thirteen phase 2 switches; every one defaults to off in the template
  /// clinic.config.json.
  static const phase2Keys = [
    'videoConsultation',
    'waitingList',
    'familyAccounts',
    'whatsappReminders',
    'onlinePayments',
    'insurance',
    'holidayCalendar',
    'workingHoursTemplates',
    'patientRecords',
    'reviews',
    'promotions',
    'recallCampaigns',
    'reports',
  ];

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
      videoConsultation: pick('videoConsultation', defaults.videoConsultation),
      waitingList: pick('waitingList', defaults.waitingList),
      familyAccounts: pick('familyAccounts', defaults.familyAccounts),
      whatsappReminders: pick('whatsappReminders', defaults.whatsappReminders),
      onlinePayments: pick('onlinePayments', defaults.onlinePayments),
      insurance: pick('insurance', defaults.insurance),
      holidayCalendar: pick('holidayCalendar', defaults.holidayCalendar),
      workingHoursTemplates: pick(
        'workingHoursTemplates',
        defaults.workingHoursTemplates,
      ),
      patientRecords: pick('patientRecords', defaults.patientRecords),
      reviews: pick('reviews', defaults.reviews),
      promotions: pick('promotions', defaults.promotions),
      recallCampaigns: pick('recallCampaigns', defaults.recallCampaigns),
      reports: pick('reports', defaults.reports),
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
    'videoConsultation': videoConsultation,
    'waitingList': waitingList,
    'familyAccounts': familyAccounts,
    'whatsappReminders': whatsappReminders,
    'onlinePayments': onlinePayments,
    'insurance': insurance,
    'holidayCalendar': holidayCalendar,
    'workingHoursTemplates': workingHoursTemplates,
    'patientRecords': patientRecords,
    'reviews': reviews,
    'promotions': promotions,
    'recallCampaigns': recallCampaigns,
    'reports': reports,
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
    bool? videoConsultation,
    bool? waitingList,
    bool? familyAccounts,
    bool? whatsappReminders,
    bool? onlinePayments,
    bool? insurance,
    bool? holidayCalendar,
    bool? workingHoursTemplates,
    bool? patientRecords,
    bool? reviews,
    bool? promotions,
    bool? recallCampaigns,
    bool? reports,
  }) => ClinicFeatures(
    mobileApp: mobileApp ?? this.mobileApp,
    website: website ?? this.website,
    guestBrowsing: guestBrowsing ?? this.guestBrowsing,
    patientSelfService: patientSelfService ?? this.patientSelfService,
    pushReminders: pushReminders ?? this.pushReminders,
    smsNotifications: smsNotifications ?? this.smsNotifications,
    englishLanguage: englishLanguage ?? this.englishLanguage,
    multiBranch: multiBranch ?? this.multiBranch,
    videoConsultation: videoConsultation ?? this.videoConsultation,
    waitingList: waitingList ?? this.waitingList,
    familyAccounts: familyAccounts ?? this.familyAccounts,
    whatsappReminders: whatsappReminders ?? this.whatsappReminders,
    onlinePayments: onlinePayments ?? this.onlinePayments,
    insurance: insurance ?? this.insurance,
    holidayCalendar: holidayCalendar ?? this.holidayCalendar,
    workingHoursTemplates: workingHoursTemplates ?? this.workingHoursTemplates,
    patientRecords: patientRecords ?? this.patientRecords,
    reviews: reviews ?? this.reviews,
    promotions: promotions ?? this.promotions,
    recallCampaigns: recallCampaigns ?? this.recallCampaigns,
    reports: reports ?? this.reports,
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
      other.multiBranch == multiBranch &&
      other.videoConsultation == videoConsultation &&
      other.waitingList == waitingList &&
      other.familyAccounts == familyAccounts &&
      other.whatsappReminders == whatsappReminders &&
      other.onlinePayments == onlinePayments &&
      other.insurance == insurance &&
      other.holidayCalendar == holidayCalendar &&
      other.workingHoursTemplates == workingHoursTemplates &&
      other.patientRecords == patientRecords &&
      other.reviews == reviews &&
      other.promotions == promotions &&
      other.recallCampaigns == recallCampaigns &&
      other.reports == reports;

  @override
  int get hashCode => Object.hashAll([
    mobileApp,
    website,
    guestBrowsing,
    patientSelfService,
    pushReminders,
    smsNotifications,
    englishLanguage,
    multiBranch,
    videoConsultation,
    waitingList,
    familyAccounts,
    whatsappReminders,
    onlinePayments,
    insurance,
    holidayCalendar,
    workingHoursTemplates,
    patientRecords,
    reviews,
    promotions,
    recallCampaigns,
    reports,
  ]);

  @override
  String toString() => 'ClinicFeatures(${toJson()})';
}
