import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/brand.g.dart';

/// Demo-mode backend: a stateful, in-memory implementation of the endpoints
/// the patient app uses (spec §4), served through Dio's adapter so the real
/// repositories, interceptor and screens run unchanged.
///
/// Fixtures: one Cairo clinic, three doctors, a week of open slots and a
/// signed-in-able patient with upcoming and past appointments. Any phone logs
/// in with code `123456` as the demo patient, except [newUserPhone], which
/// signs up a brand-new patient (to see profile completion).
///
/// Clinic time is fixed at UTC+2 here; the real API derives it from tzdata.
class MockApiAdapter implements HttpClientAdapter {
  MockApiAdapter({this.latency = const Duration(milliseconds: 250)}) {
    _seedAppointments();
  }

  static const otpCode = '123456';
  static const newUserPhone = '+201000000000';
  static const _utcOffset = Duration(hours: 2);

  final Duration latency;

  /// The clinic's feature switches served by `GET /features`. Starts from the
  /// brand defaults; change entries to preview a clinic with features off.
  final Map<String, bool> features = Map.of(Brand.defaultFeatures.toJson());

  // --- fixtures --------------------------------------------------------

  static const _specialties = [
    ('sp-general', 'General Dentistry', 'طب الأسنان العام'),
    ('sp-ortho', 'Orthodontics', 'تقويم الأسنان'),
    ('sp-pedo', 'Pediatric Dentistry', 'أسنان الأطفال'),
    ('sp-endo', 'Endodontics', 'علاج الجذور'),
    ('sp-cosmetic', 'Cosmetic Dentistry', 'تجميل الأسنان'),
    ('sp-surgery', 'Oral Surgery', 'جراحة الفم'),
  ];

  static const _doctors = [
    _MockDoctor(
      id: 'doc-1',
      slug: 'mona-hassan',
      nameEn: 'Dr. Mona Hassan',
      nameAr: 'د. منى حسن',
      specialtyId: 'sp-general',
      years: 12,
      fee: 300,
      bioEn:
          'General dentist focused on preventive care, fillings and gentle '
          'check-ups for the whole family.',
      bioAr:
          'طبيبة أسنان عامة تهتم بالوقاية والحشوات والكشف اللطيف لكل العائلة.',
    ),
    _MockDoctor(
      id: 'doc-2',
      slug: 'karim-adel',
      nameEn: 'Dr. Karim Adel',
      nameAr: 'د. كريم عادل',
      specialtyId: 'sp-ortho',
      years: 9,
      fee: 450,
      bioEn:
          'Orthodontist treating braces, clear aligners and bite correction '
          'for teens and adults.',
      bioAr: 'أخصائي تقويم الأسنان: التقويم الثابت والشفاف وتصحيح الإطباق للمراهقين والكبار.',
    ),
    _MockDoctor(
      id: 'doc-3',
      slug: 'salma-farouk',
      nameEn: 'Dr. Salma Farouk',
      nameAr: 'د. سلمى فاروق',
      specialtyId: 'sp-pedo',
      years: 7,
      fee: 350,
      bioEn:
          'Pediatric dentist who makes first visits calm and fun for little '
          'patients.',
      bioAr: 'طبيبة أسنان أطفال تجعل الزيارة الأولى هادئة وممتعة للصغار.',
    ),
  ];

  static const _services = [
    ('svc-checkup', 'Check-up', 'كشف', 30, 300),
    ('svc-cleaning', 'Cleaning', 'تنظيف الأسنان', 45, 400),
    ('svc-filling', 'Filling', 'حشو', 45, 500),
  ];

  // --- state -----------------------------------------------------------

  final Set<String> _reserved = {};
  final List<_MockAppointment> _appointments = [];
  int _nextAppointment = 100;
  int _tokenCounter = 0;
  String? _validAccess;
  String? _validRefresh;
  _MockUser _user = _MockUser.demo();

  void _seedAppointments() {
    final today = _clinicNow();
    _MockAppointment upcoming(int id, int doctor, int days, int hour, int svc) {
      final day = DateTime(today.year, today.month, today.day + days);
      final local = DateTime(day.year, day.month, day.day, hour);
      final slotId = _slotId(doctor, local);
      _reserved.add(slotId);
      return _MockAppointment(
        id: 'apt-$id',
        slotId: slotId,
        doctorIndex: doctor,
        startsAtLocal: local,
        minutes: 30,
        serviceIndex: svc,
        status: 'Confirmed',
      );
    }

    _MockAppointment past(int id, int doctor, int days, String status) {
      final day = DateTime(today.year, today.month, today.day - days, 11);
      return _MockAppointment(
        id: 'apt-$id',
        slotId: _slotId(doctor, day),
        doctorIndex: doctor,
        startsAtLocal: day,
        minutes: 30,
        serviceIndex: 1,
        status: status,
        cancelledBy: status == 'Cancelled' ? 'Patient' : null,
      );
    }

    _appointments.addAll([
      upcoming(1, 0, 3, 10, 0),
      upcoming(2, 1, 6, 17, 2),
      past(3, 2, 20, 'Completed'),
      past(4, 0, 45, 'Cancelled'),
    ]);
  }

  /// "Now" on the clinic wall clock, as a zone-less date-time.
  static DateTime _clinicNow() {
    final shifted = DateTime.now().toUtc().add(_utcOffset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
    );
  }

  static DateTime _toUtc(DateTime local) => DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
  ).subtract(_utcOffset);

  static String _slotId(int doctor, DateTime local) =>
      's_${doctor}_${_ymd(local).replaceAll('-', '')}_'
      '${_two(local.hour)}${_two(local.minute)}';

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _iso(DateTime utc) =>
      '${utc.toIso8601String().split('.').first}Z';

  /// Slots for [doctor] on [day], keyed by id, including reserved ones.
  Iterable<(String, DateTime)> _daySlots(int doctor, DateTime day) sync* {
    final starts = [
      for (var m = 9 * 60; m < 13 * 60; m += 30) m,
      for (var m = 16 * 60; m < 19 * 60; m += 30) m,
    ];
    for (final m in starts) {
      final local = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
      final id = _slotId(doctor, local);
      // A deterministic scatter of already-taken slots.
      final taken = (doctor * 7 + day.day * 3 + m ~/ 30) % 5 == 0;
      if (taken) _reserved.add(id);
      yield (id, local);
    }
  }

  // --- routing ---------------------------------------------------------

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final lang = '${options.headers['Accept-Language']}' == 'en' ? 'en' : 'ar';
    final path = options.path.replaceFirst(RegExp(r'^/api/v1'), '');
    final method = options.method.toUpperCase();
    final body = _body(options.data);
    try {
      final result = _route(method, path, options, body, lang);
      return _json(result.$1, result.$2);
    } on _MockError catch (e) {
      return _json(e.status, {
        'type': 'https://moonlight.example/errors/${e.code.toLowerCase()}',
        'title': e.code,
        'status': e.status,
        'code': e.code,
        'detail': e.detail,
      });
    }
  }

  @override
  void close({bool force = false}) {}

  Map<String, dynamic> _body(Object? data) {
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.isNotEmpty) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return const {};
  }

  ResponseBody _json(int status, Object? data) => ResponseBody.fromString(
    data == null ? '' : jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  (int, Object?) _route(
    String method,
    String path,
    RequestOptions options,
    Map<String, dynamic> body,
    String lang,
  ) {
    final q = options.queryParameters;

    // Clinic identity and feature switches.
    if (method == 'GET' && path == '/features') {
      return (
        200,
        {
          'features': features,
          'source': 'defaults',
          'updatedAt': _iso(DateTime.now().toUtc()),
        },
      );
    }
    if (method == 'GET' && path == '/branding') {
      return (
        200,
        {
          'slug': Brand.slug,
          'name': {'ar': Brand.nameAr, 'en': Brand.nameEn},
          'tagline': {'ar': Brand.taglineAr, 'en': Brand.taglineEn},
          'colors': {
            'primary': _hex(Brand.primary.toARGB32()),
            'accent': _hex(Brand.accent.toARGB32()),
          },
          'supportPhone': Brand.supportPhone,
          'logoUrl': '/api/v1/branding/logo',
        },
      );
    }

    // Public catalog.
    if (method == 'GET' && path == '/specialties') {
      return (
        200,
        [
          for (final s in _specialties)
            {'id': s.$1, 'name': lang == 'en' ? s.$2 : s.$3},
        ],
      );
    }
    if (method == 'GET' && path == '/cities') {
      return (200, [lang == 'en' ? 'Cairo' : 'القاهرة']);
    }
    if (method == 'GET' && path == '/doctors') return (200, _search(q, lang));
    final doctorMatch = RegExp(r'^/doctors/([^/]+)(/slots)?$').firstMatch(path);
    if (method == 'GET' && doctorMatch != null) {
      final index = _doctors.indexWhere(
        (d) => d.id == doctorMatch[1] || d.slug == doctorMatch[1],
      );
      if (index < 0) throw _MockError.notFound();
      return doctorMatch[2] == null
          ? (200, _doctorJson(index, lang, full: true))
          : (200, _slotsJson(index, q));
    }

    // Auth.
    if (method == 'POST' && path == '/auth/otp/request') return (204, null);
    if (method == 'POST' && path == '/auth/otp/verify') {
      if (body['code'] != otpCode) {
        throw _MockError(
          400,
          'OTP_INVALID',
          lang == 'en' ? 'The code is incorrect.' : 'الرمز غير صحيح.',
        );
      }
      final phone = body['phone'] as String;
      _user = phone == newUserPhone
          ? _MockUser(phone: phone)
          : _MockUser.demo(phone: phone);
      return (
        200,
        {
          ..._issueTokens(),
          'isNewUser': phone == newUserPhone,
          'user': _user.toJson(),
        },
      );
    }
    if (method == 'POST' && path == '/auth/refresh') {
      if (body['refreshToken'] != _validRefresh) {
        throw _MockError.unauthorized();
      }
      return (200, _issueTokens());
    }

    // Everything below needs a session.
    if (options.headers['Authorization'] != 'Bearer $_validAccess') {
      throw _MockError.unauthorized();
    }
    if (method == 'POST' && path == '/auth/logout') {
      _validAccess = _validRefresh = null;
      return (204, null);
    }
    if (path == '/me') {
      if (method == 'PUT') {
        _user = _user.copyWith(
          fullName: body['fullName'] as String?,
          language: body['preferredLanguage'] as String?,
        );
      }
      return (200, _user.toJson());
    }
    if (method == 'PUT' && path == '/me/device-tokens') {
      return (200, {'id': 'device-token-1'});
    }
    if (method == 'DELETE' && path.startsWith('/me/device-tokens/')) {
      return (204, null);
    }

    if (method == 'GET' && path == '/appointments') {
      return (200, _appointmentPage(q, lang));
    }
    if (method == 'POST' && path == '/appointments') {
      return (201, _book(body, lang));
    }
    final aptMatch = RegExp(r'^/appointments/([^/]+)(?:/(cancel|reschedule))?$')
        .firstMatch(path);
    if (aptMatch != null) {
      final apt = _appointments.firstWhere(
        (a) => a.id == aptMatch[1],
        orElse: () => throw _MockError.notFound(),
      );
      switch ((method, aptMatch[2])) {
        case ('GET', null):
          break;
        case ('POST', 'cancel'):
          _cancel(apt, body, lang);
        case ('POST', 'reschedule'):
          _reschedule(apt, body, lang);
        default:
          throw _MockError.notFound();
      }
      return (200, _appointmentJson(apt, lang));
    }
    throw _MockError.notFound();
  }

  // --- handlers ----------------------------------------------------------

  Map<String, dynamic> _issueTokens() {
    _tokenCounter++;
    _validAccess = 'mock-access-$_tokenCounter';
    _validRefresh = 'mock-refresh-$_tokenCounter';
    return {
      'accessToken': _validAccess,
      'refreshToken': _validRefresh,
      'expiresIn': 900,
    };
  }

  Map<String, dynamic> _search(Map<String, dynamic> q, String lang) {
    final text = '${q['q'] ?? ''}'.trim().toLowerCase();
    final city = q['city'];
    final matches = [
      for (var i = 0; i < _doctors.length; i++)
        if ((q['specialtyId'] == null ||
                q['specialtyId'] == _doctors[i].specialtyId) &&
            (city == null || city == 'Cairo' || city == 'القاهرة') &&
            (text.isEmpty ||
                _doctors[i].nameEn.toLowerCase().contains(text) ||
                _doctors[i].nameAr.contains(text)))
          i,
    ];
    final page = int.parse('${q['page'] ?? 1}');
    final size = int.parse('${q['pageSize'] ?? 20}');
    return {
      'items': [
        for (final i in matches.skip((page - 1) * size).take(size))
          _doctorJson(i, lang),
      ],
      'page': page,
      'pageSize': size,
      'totalCount': matches.length,
    };
  }

  Map<String, dynamic> _clinicJson(String lang) => {
    'id': 'clinic-1',
    'name': lang == 'en'
        ? 'Nile Smile Dental Clinic'
        : 'عيادة نايل سمايل للأسنان',
    'address': lang == 'en'
        ? '12 Road 9, Maadi, Cairo'
        : '١٢ شارع ٩، المعادي، القاهرة',
    'city': lang == 'en' ? 'Cairo' : 'القاهرة',
    'phone': '+20227000000',
    'latitude': 29.9602,
    'longitude': 31.2569,
    'timezone': 'Africa/Cairo',
  };

  Map<String, dynamic> _doctorJson(int i, String lang, {bool full = false}) {
    final d = _doctors[i];
    final specialty = _specialties.firstWhere((s) => s.$1 == d.specialtyId);
    return {
      'id': d.id,
      'slug': d.slug,
      'name': lang == 'en' ? d.nameEn : d.nameAr,
      'photoUrl': null,
      'specialty': {
        'id': specialty.$1,
        'name': lang == 'en' ? specialty.$2 : specialty.$3,
      },
      'clinic': _clinicJson(lang),
      'yearsExperience': d.years,
      'consultationFeeEgp': d.fee,
      if (full) ...{
        'bio': lang == 'en' ? d.bioEn : d.bioAr,
        'services': [for (final s in _services) _serviceJson(s, lang)],
      },
    };
  }

  Map<String, dynamic> _serviceJson(
    (String, String, String, int, int) s,
    String lang,
  ) => {
    'id': s.$1,
    'name': lang == 'en' ? s.$2 : s.$3,
    'durationMinutes': s.$4,
    'priceEgp': s.$5,
  };

  Map<String, dynamic> _slotsJson(int doctor, Map<String, dynamic> q) {
    final today = _clinicNow();
    final earliest = DateTime.now().toUtc().add(const Duration(minutes: 60));
    final from = DateTime.parse('${q['from']}');
    final to = DateTime.parse('${q['to']}');
    final days = <Map<String, dynamic>>[];
    // A week of availability starting today.
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime(today.year, today.month, today.day + offset);
      if (day.isBefore(from) || day.isAfter(to)) continue;
      final slots = [
        for (final (id, local) in _daySlots(doctor, day))
          if (!_reserved.contains(id) && _toUtc(local).isAfter(earliest))
            {
              'id': id,
              'startsAt': _iso(_toUtc(local)),
              'endsAt': _iso(_toUtc(local.add(const Duration(minutes: 30)))),
              'local': '${_two(local.hour)}:${_two(local.minute)}',
            },
      ];
      if (slots.isNotEmpty) days.add({'date': _ymd(day), 'slots': slots});
    }
    return {
      'doctorId': _doctors[doctor].id,
      'timezone': 'Africa/Cairo',
      'days': days,
    };
  }

  /// Reads `s_<doctor>_<yyyyMMdd>_<HHmm>` back into a doctor and a local time.
  (int, DateTime) _parseSlot(String slotId) {
    final m = RegExp(r'^s_(\d)_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})$')
        .firstMatch(slotId);
    if (m == null) throw _MockError.notFound();
    final n = [for (var i = 1; i <= 6; i++) int.parse(m[i]!)];
    return (n[0], DateTime(n[1], n[2], n[3], n[4], n[5]));
  }

  Map<String, dynamic> _book(Map<String, dynamic> body, String lang) {
    final slotId = body['slotId'] as String;
    final (doctor, local) = _parseSlot(slotId);
    if (_reserved.contains(slotId)) {
      throw _MockError(
        409,
        'SLOT_TAKEN',
        lang == 'en'
            ? 'Someone just booked this time. Please pick another slot.'
            : 'تم حجز هذا الموعد للتو. اختر موعدًا آخر.',
      );
    }
    final upcoming = _appointments.where((a) => a.status == 'Confirmed').length;
    if (upcoming >= 3) {
      throw _MockError(409, 'BOOKING_LIMIT', 'Too many upcoming appointments.');
    }
    final serviceId = body['serviceId'];
    final apt = _MockAppointment(
      id: 'apt-${_nextAppointment++}',
      slotId: slotId,
      doctorIndex: doctor,
      startsAtLocal: local,
      minutes: 30,
      serviceIndex: serviceId == null
          ? null
          : _services.indexWhere((s) => s.$1 == serviceId),
      note: body['patientNote'] as String?,
      status: 'Confirmed',
    );
    _reserved.add(slotId);
    _appointments.add(apt);
    return _appointmentJson(apt, lang);
  }

  void _cancel(_MockAppointment apt, Map<String, dynamic> body, String lang) {
    _requireChangeable(apt, lang);
    _reserved.remove(apt.slotId);
    apt
      ..status = 'Cancelled'
      ..cancelledBy = 'Patient'
      ..cancelReason = body['reason'] as String?;
  }

  void _reschedule(
    _MockAppointment apt,
    Map<String, dynamic> body,
    String lang,
  ) {
    _requireChangeable(apt, lang);
    final slotId = body['slotId'] as String;
    final (doctor, local) = _parseSlot(slotId);
    if (doctor != apt.doctorIndex) throw _MockError.notFound();
    if (_reserved.contains(slotId)) {
      throw _MockError(409, 'SLOT_TAKEN', 'Slot already taken.');
    }
    _reserved
      ..remove(apt.slotId)
      ..add(slotId);
    apt
      ..slotId = slotId
      ..startsAtLocal = local;
  }

  void _requireChangeable(_MockAppointment apt, String lang) {
    if (apt.status != 'Confirmed') {
      throw _MockError(409, 'INVALID_TRANSITION', 'Appointment is not active.');
    }
    final cutoff = _toUtc(apt.startsAtLocal).subtract(const Duration(hours: 2));
    if (DateTime.now().toUtc().isAfter(cutoff)) {
      throw _MockError(
        409,
        'CANCEL_WINDOW_PASSED',
        lang == 'en'
            ? 'It is too late to change this appointment online.'
            : 'فات وقت تعديل الموعد عبر التطبيق.',
      );
    }
  }

  Map<String, dynamic> _appointmentPage(Map<String, dynamic> q, String lang) {
    final now = DateTime.now().toUtc();
    final upcoming = q['scope'] == 'upcoming';
    final matches =
        [
          for (final a in _appointments)
            if (upcoming
                ? a.status == 'Confirmed' &&
                      _toUtc(a.startsAtLocal).isAfter(now)
                : !(a.status == 'Confirmed' &&
                      _toUtc(a.startsAtLocal).isAfter(now)))
              a,
        ]..sort(
          (a, b) => upcoming
              ? a.startsAtLocal.compareTo(b.startsAtLocal)
              : b.startsAtLocal.compareTo(a.startsAtLocal),
        );
    final page = int.parse('${q['page'] ?? 1}');
    final size = int.parse('${q['pageSize'] ?? 20}');
    return {
      'items': [
        for (final a in matches.skip((page - 1) * size).take(size))
          _appointmentJson(a, lang),
      ],
      'page': page,
      'pageSize': size,
      'totalCount': matches.length,
    };
  }

  Map<String, dynamic> _appointmentJson(_MockAppointment a, String lang) {
    final d = _doctors[a.doctorIndex];
    final start = _toUtc(a.startsAtLocal);
    final svc = a.serviceIndex;
    return {
      'id': a.id,
      'status': a.status,
      'slotId': a.slotId,
      'startsAt': _iso(start),
      'endsAt': _iso(start.add(Duration(minutes: a.minutes))),
      'startsAtLocal':
          '${_ymd(a.startsAtLocal)}T${_two(a.startsAtLocal.hour)}:'
          '${_two(a.startsAtLocal.minute)}:00',
      'timezone': 'Africa/Cairo',
      'doctor': {
        'id': d.id,
        'slug': d.slug,
        'name': lang == 'en' ? d.nameEn : d.nameAr,
        'photoUrl': null,
      },
      'clinic': _clinicJson(lang),
      'service': svc == null || svc < 0
          ? null
          : _serviceJson(_services[svc], lang),
      'patientNote': a.note,
      'cancelledBy': a.cancelledBy,
      'cancelReason': a.cancelReason,
    };
  }
}

class _MockDoctor {
  const _MockDoctor({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameAr,
    required this.specialtyId,
    required this.years,
    required this.fee,
    required this.bioEn,
    required this.bioAr,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String nameAr;
  final String specialtyId;
  final int years;
  final int fee;
  final String bioEn;
  final String bioAr;
}

class _MockAppointment {
  _MockAppointment({
    required this.id,
    required this.slotId,
    required this.doctorIndex,
    required this.startsAtLocal,
    required this.minutes,
    required this.status,
    this.serviceIndex,
    this.note,
    this.cancelledBy,
  });

  final String id;
  String slotId;
  final int doctorIndex;
  DateTime startsAtLocal;
  final int minutes;
  String status;
  final int? serviceIndex;
  final String? note;
  String? cancelledBy;
  String? cancelReason;
}

class _MockUser {
  _MockUser({required this.phone, this.fullName, this.language = 'ar'});

  factory _MockUser.demo({String phone = '+201012345678'}) =>
      _MockUser(phone: phone, fullName: 'نور سمير');

  final String phone;
  final String? fullName;
  final String language;

  _MockUser copyWith({String? fullName, String? language}) => _MockUser(
    phone: phone,
    fullName: fullName ?? this.fullName,
    language: language ?? this.language,
  );

  Map<String, dynamic> toJson() => {
    'id': 'user-demo',
    'phone': phone,
    'fullName': fullName,
    'role': 'Patient',
    'preferredLanguage': language,
  };
}

class _MockError implements Exception {
  _MockError(this.status, this.code, this.detail);

  factory _MockError.notFound() => _MockError(404, 'NOT_FOUND', 'Not found.');
  factory _MockError.unauthorized() =>
      _MockError(401, 'UNAUTHORIZED', 'Sign in again.');

  final int status;
  final String code;
  final String detail;
}
