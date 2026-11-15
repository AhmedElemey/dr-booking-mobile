/// Demo fixtures for the phase 2 features: Egyptian insurers, offers, reviews
/// and a small medical record. Pure data; `MockApiAdapter` serves it.
library;

/// `(id, English name, Arabic name)`
const mockInsurers = [
  ('ins-bupa', 'Bupa Egypt', 'بوبا مصر'),
  ('ins-axa', 'AXA Egypt', 'أكسا مصر'),
  ('ins-misr', 'Misr Insurance', 'مصر للتأمين'),
  ('ins-metlife', 'MetLife Egypt', 'ميت لايف مصر'),
];

/// The insurers each doctor (by id) accepts.
const mockDoctorInsurers = {
  'doc-1': ['ins-bupa', 'ins-axa', 'ins-misr'],
  'doc-2': ['ins-axa', 'ins-metlife'],
  'doc-3': ['ins-bupa', 'ins-misr'],
};

/// Doctors that offer video consultations.
const mockVideoDoctors = {'doc-1', 'doc-2'};

/// `(average, count)` per doctor id.
const mockRatings = {
  'doc-1': (4.8, 126),
  'doc-2': (4.6, 84),
  'doc-3': (4.9, 57),
};

class MockReview {
  const MockReview(
    this.rating,
    this.name,
    this.comment,
    this.daysAgo, {
    this.reply,
  });

  final int rating;
  final String name;
  final String comment;
  final int daysAgo;
  final String? reply;
}

const mockReviews = {
  'doc-1': [
    MockReview(
      5,
      'منى',
      'دكتورة محترمة جدًا والكشف كان بدون ألم. العيادة نضيفة والمواعيد مظبوطة.',
      4,
      reply: 'شكرًا ليكي يا منى، بالسلامة دايمًا.',
    ),
    MockReview(
      5,
      'أحمد',
      'شرحت لي الحالة كلها وأخدت وقتها معايا. أنصح بيها.',
      11,
    ),
    MockReview(
      4,
      'هالة',
      'تعامل راقي، بس استنيت حوالي 10 دقايق قبل الدخول.',
      19,
    ),
    MockReview(5, 'محمود', 'حشو ممتاز وسعر مناسب.', 33),
  ],
  'doc-2': [
    MockReview(
      5,
      'كريم',
      'التقويم الشفاف عمل فرق كبير، الدكتور متابع معايا بدقة.',
      6,
    ),
    MockReview(4, 'نادين', 'شغل نضيف ومتابعة كويسة.', 15),
  ],
  'doc-3': [
    MockReview(
      5,
      'سارة',
      'بنتي كانت خايفة جدًا وخرجت مبسوطة! دكتورة سلمى صبورة جدًا مع الأطفال.',
      3,
    ),
    MockReview(5, 'عمر', 'أحسن دكتورة أسنان أطفال جربناها.', 9),
  ],
};

/// A public offer. `doctorId` / `serviceId` narrow where it applies.
class MockOffer {
  const MockOffer({
    required this.code,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.percent,
    required this.value,
    required this.validInDays,
    this.maxDiscount,
    this.doctorId,
    this.serviceId,
  });

  final String code;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;

  /// Percent off when true, otherwise a fixed amount in EGP.
  final bool percent;
  final num value;
  final num? maxDiscount;
  final int validInDays;
  final String? doctorId;
  final String? serviceId;
}

const mockOffers = [
  MockOffer(
    code: 'SMILE20',
    titleEn: '20% off your first visit',
    titleAr: 'خصم 20٪ على أول زيارة',
    descriptionEn: 'Up to 150 EGP off any check-up or treatment.',
    descriptionAr: 'حتى 150 جنيه خصم على أي كشف أو علاج.',
    percent: true,
    value: 20,
    maxDiscount: 150,
    validInDays: 30,
  ),
  MockOffer(
    code: 'CLEAN100',
    titleEn: 'Cleaning for less',
    titleAr: 'تنظيف الأسنان بخصم',
    descriptionEn: '100 EGP off a professional teeth cleaning.',
    descriptionAr: 'خصم 100 جنيه على تنظيف الأسنان الاحترافي.',
    percent: false,
    value: 100,
    validInDays: 21,
    serviceId: 'svc-cleaning',
  ),
  MockOffer(
    code: 'KIDS15',
    titleEn: 'Kids dentistry',
    titleAr: 'عرض أسنان الأطفال',
    descriptionEn: '15% off visits with Dr. Salma Farouk.',
    descriptionAr: 'خصم 15٪ على الكشف عند د. سلمى فاروق.',
    percent: true,
    value: 15,
    validInDays: 45,
    doctorId: 'doc-3',
  ),
];

/// Codes that exist but are refused, to demo the error messages.
const mockExpiredCode = 'EID2025';
const mockUsedCode = 'WELCOME50';

const mockMedicalInfo = {
  'bloodType': 'A+',
  'allergies': 'حساسية من البنسلين',
  'chronicConditions': null,
  'medications': null,
};

const mockMedicalInfoByMember = {
  'fam-1': {
    'bloodType': 'O+',
    'allergies': 'لا يوجد',
    'chronicConditions': null,
    'medications': null,
  },
  'fam-2': {
    'bloodType': 'A-',
    'allergies': null,
    'chronicConditions': null,
    'medications': null,
  },
};

class MockRecord {
  const MockRecord(
    this.id,
    this.kind,
    this.title,
    this.body,
    this.daysAgo, {
    this.attachmentUrl,
    this.owner,
    this.doctorName,
  });

  final String id;
  final String kind;
  final String title;
  final String? body;
  final int daysAgo;
  final String? attachmentUrl;
  final String? doctorName;

  /// Family member id the entry belongs to; null for the account owner.
  final String? owner;
}

const mockRecords = [
  MockRecord(
    'rec-1',
    'Diagnosis',
    'تسوس في الضرس السفلي الأيمن',
    'تم عمل حشو تجميلي. يُنصح بمتابعة بعد 6 أشهر.',
    20,
    doctorName: 'د. عمرو حسن',
  ),
  MockRecord(
    'rec-2',
    'Prescription',
    'مضاد حيوي ومسكن',
    'أموكسيسيلين 500 مجم كل 8 ساعات لمدة 5 أيام. بروفين 400 مجم عند اللزوم.',
    20,
  ),
  MockRecord(
    'rec-3',
    'Attachment',
    'أشعة بانوراما',
    null,
    20,
    attachmentUrl: 'https://mock.moonlight.local/files/panorama.pdf',
  ),
  MockRecord(
    'rec-4',
    'Note',
    'تعليمات بعد الحشو',
    'تجنب الأكل لمدة ساعتين وتجنب المشروبات الساخنة اليوم.',
    20,
  ),
  MockRecord(
    'rec-5',
    'Note',
    'أول زيارة لطب الأسنان',
    'تعودت على الكرسي بسهولة. تنظيف وفلورايد.',
    60,
    owner: 'fam-1',
  ),
];
