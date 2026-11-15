import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/brand.g.dart';
import '../config/clinic_features.dart';
import 'mock_phase2_data.dart';

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
  MockApiAdapter({
    this.latency = const Duration(milliseconds: 250),
    this.demo = false,
  }) {
    _seedAppointments();
  }

  static const otpCode = '123456';
  static const newUserPhone = '+201000000000';
  static const _utcOffset = Duration(hours: 2);

  final Duration latency;

  /// Demo mode (not unit tests): also seeds a video consultation that is open
  /// to join right now, and allows more upcoming bookings.
  final bool demo;

  /// The clinic's feature switches served by `GET /features`: the brand
  /// defaults with all 13 phase 2 features on. Change entries to preview a
  /// clinic with features off.
  final Map<String, bool> features = {
    ...Brand.defaultFeatures.toJson(),
    for (final key in ClinicFeatures.phase2Keys) key: true,
  };

  bool _on(String key) => features[key] == true;

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
  int _nextId = 1;
  final List<_MockFamily> _family = [
    _MockFamily('fam-1', 'يوسف نور', 'Child', '2016-04-12', 'Male'),
    _MockFamily('fam-2', 'ليلى نور', 'Child', '2019-09-03', 'Female'),
    _MockFamily('fam-3', 'سمير عبد الله', 'Parent', '1958-01-20', 'Male'),
  ];
  final List<_MockWaiting> _waiting = [];
  final Map<String, _MockPayment> _payments = {};

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
        price: _priceFor(doctor, svc),
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
        price: _priceFor(doctor, 1),
      );
    }

    // A child's check-up with a coupon, still to be paid and covered by Bupa.
    final first = upcoming(1, 0, 3, 10, 0)
      ..familyMemberId = 'fam-1'
      ..couponCode = 'SMILE20'
      ..discount = 60
      ..insuranceProviderId = 'ins-bupa'
      ..insuranceMember = 'BUP-2043819'
      ..insuranceStatus = 'Pending';
    // A video consultation that is already paid.
    final second = upcoming(2, 1, 6, 17, 2)
      ..mode = 'Video'
      ..payment = 'Paid';
    final completed = past(3, 2, 20, 'Completed')..payment = 'Paid';
    _appointments.addAll([
      first,
      second,
      completed,
      past(4, 0, 45, 'Cancelled'),
    ]);

    _waiting.addAll([
      _MockWaiting(
        'wl-1',
        0,
        _plainDay(today, 2),
        'Waiting',
        DateTime.now().toUtc().subtract(const Duration(days: 1)),
      ),
      _MockWaiting(
        'wl-2',
        2,
        _plainDay(today, 1),
        'Notified',
        DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        notifiedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      ),
      _MockWaiting(
        'wl-3',
        1,
        _plainDay(today, -4),
        'Expired',
        DateTime.now().toUtc().subtract(const Duration(days: 9)),
      ),
    ]);

    if (demo) {
      // Starts in 10 minutes: inside the video join window.
      final soon = today.add(const Duration(minutes: 10));
      final local = DateTime(
        soon.year,
        soon.month,
        soon.day,
        soon.hour,
        soon.minute,
      );
      final slotId = _slotId(0, local);
      _reserved.add(slotId);
      _appointments.add(
        _MockAppointment(
          id: 'apt-5',
          slotId: slotId,
          doctorIndex: 0,
          startsAtLocal: local,
          minutes: 30,
          serviceIndex: 0,
          status: 'Confirmed',
          price: _priceFor(0, 0),
        )..mode = 'Video',
      );
    }
  }

  static DateTime _plainDay(DateTime base, int offset) =>
      DateTime(base.year, base.month, base.day + offset);

  /// Service price, or the doctor's consultation fee.
  static num _priceFor(int doctor, int? service) =>
      service == null || service < 0
      ? _doctors[doctor].fee
      : _services[service].$5;

  /// The holiday in the demo window, relative to today.
  static const _holidayOffset = 5;

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
    final attachment = RegExp(r'^/me/records/([^/]+)/attachment$')
        .firstMatch(path);
    if (method == 'GET' && attachment != null) {
      return _attachment(attachment.group(1)!);
    }
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
        'reason': ?e.reason,
        'feature': ?e._feature,
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

  /// The authorized attachment download: raw bytes, not JSON.
  ResponseBody _attachment(String id) {
    final known = mockRecords.any((r) => r.id == id && r.attachmentUrl != null);
    if (!known) {
      return _json(404, {
        'status': 404,
        'code': 'NOT_FOUND',
        'detail': 'Not found.',
      });
    }
    return ResponseBody.fromBytes(
      utf8.encode('%PDF-1.4\n% demo attachment\n%%EOF\n'),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/pdf'],
        'content-disposition': ['attachment; filename="panorama.pdf"'],
      },
    );
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
    final doctorMatch = RegExp(r'^/doctors/([^/]+)(/slots|/reviews)?$')
        .firstMatch(path);
    if (method == 'GET' && doctorMatch != null) {
      final index = _doctors.indexWhere(
        (d) => d.id == doctorMatch[1] || d.slug == doctorMatch[1],
      );
      if (index < 0) throw _MockError.notFound();
      return switch (doctorMatch[2]) {
        null => (200, _doctorJson(index, lang, full: true)),
        '/slots' => (200, _slotsJson(index, q, lang)),
        _ => (200, _reviewsPage(index, q)),
      };
    }
    if (method == 'GET' && path == '/insurance-providers') {
      if (!_on('insurance')) throw _MockError.featureDisabled('insurance');
      return (
        200,
        [
          for (final i in mockInsurers)
            {'id': i.$1, 'name': lang == 'en' ? i.$2 : i.$3},
        ],
      );
    }
    if (method == 'GET' && path == '/promotions') {
      if (!_on('promotions')) throw _MockError.featureDisabled('promotions');
      return (200, _promotions(lang));
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
          whatsAppOptIn: body['whatsAppOptIn'] as bool?,
          marketingOptIn: body['marketingOptIn'] as bool?,
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

    final phase2 = _phase2Route(method, path, q, body, lang);
    if (phase2 != null) return phase2;

    if (method == 'GET' && path == '/appointments') {
      return (200, _appointmentPage(q, lang));
    }
    if (method == 'POST' && path == '/appointments') {
      return (201, _book(body, lang));
    }
    final aptMatch = RegExp(
      r'^/appointments/([^/]+)(?:/(cancel|reschedule|pay|review|video))?$',
    ).firstMatch(path);
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
        case ('POST', 'pay'):
          return (200, _startPayment(apt));
        case ('POST', 'review'):
          _review(apt, body);
          return (201, _appointmentJson(apt, lang));
        case ('GET', 'video'):
          return (200, _videoRoom(apt));
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
            (q['insuranceProviderId'] == null ||
                (mockDoctorInsurers[_doctors[i].id] ?? const []).contains(
                  q['insuranceProviderId'],
                )) &&
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
      'offersVideo': mockVideoDoctors.contains(d.id),
      'rating': _on('reviews') && mockRatings[d.id] != null
          ? {'average': mockRatings[d.id]!.$1, 'count': mockRatings[d.id]!.$2}
          : null,
      'insuranceProviders': [
        if (_on('insurance'))
          for (final id in mockDoctorInsurers[d.id] ?? const <String>[])
            {'id': id, 'name': _insurerName(id, lang)},
      ],
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

  Map<String, dynamic> _slotsJson(
    int doctor,
    Map<String, dynamic> q,
    String lang,
  ) {
    final today = _clinicNow();
    final earliest = DateTime.now().toUtc().add(const Duration(minutes: 60));
    final from = DateTime.parse('${q['from']}');
    final to = DateTime.parse('${q['to']}');
    final days = <Map<String, dynamic>>[];
    final closed = <Map<String, dynamic>>[];
    // A week of availability starting today.
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime(today.year, today.month, today.day + offset);
      if (day.isBefore(from) || day.isAfter(to)) continue;
      if (_on('holidayCalendar') && offset == _holidayOffset) {
        closed.add({
          'date': _ymd(day),
          'name': lang == 'en' ? 'Public holiday' : 'إجازة رسمية',
        });
        continue;
      }
      // Dr. Mona is fully booked two days from now: a day to wait for.
      if (doctor == 0 && offset == 2) continue;
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
      if (_on('holidayCalendar')) 'closedDates': closed,
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
    if (_on('holidayCalendar') &&
        _plainDay(_clinicNow(), _holidayOffset) == _plainDay(local, 0)) {
      throw _MockError(
        409,
        'CLINIC_CLOSED',
        lang == 'en'
            ? 'The clinic is closed that day.'
            : 'العيادة مغلقة في هذا اليوم.',
      );
    }
    // Feature-specific fields are ignored when their feature is off.
    final familyId = _on('familyAccounts')
        ? body['familyMemberId'] as String?
        : null;
    if (familyId != null && !_family.any((m) => m.id == familyId)) {
      throw _MockError(422, 'VALIDATION_FAILED', 'Unknown family member.');
    }
    final upcoming = _appointments
        .where((a) => a.status == 'Confirmed' && a.familyMemberId == familyId)
        .length;
    if (upcoming >= 3) {
      throw _MockError(409, 'BOOKING_LIMIT', 'Too many upcoming appointments.');
    }
    final video = _on('videoConsultation') && body['mode'] == 'Video';
    if (video && !mockVideoDoctors.contains(_doctors[doctor].id)) {
      throw _MockError(
        422,
        'VALIDATION_FAILED',
        'This doctor has no video visits.',
      );
    }
    final insurance = _on('insurance')
        ? body['insurance'] as Map<String, dynamic>?
        : null;
    if (insurance != null &&
        !(mockDoctorInsurers[_doctors[doctor].id] ?? const []).contains(
          insurance['providerId'],
        )) {
      throw _MockError(
        422,
        'VALIDATION_FAILED',
        'The doctor does not accept this insurance.',
      );
    }
    final serviceId = body['serviceId'] as String?;
    final serviceIndex = serviceId == null
        ? null
        : _services.indexWhere((s) => s.$1 == serviceId);
    final price = _priceFor(doctor, serviceIndex);
    num discount = 0;
    final code = _on('promotions') ? body['couponCode'] as String? : null;
    if (code != null && code.trim().isNotEmpty) {
      final result = _evaluateCoupon(code, doctor, serviceId, price);
      if (!result.valid) {
        throw _MockError(
          422,
          'COUPON_INVALID',
          lang == 'en'
              ? 'This code cannot be used.'
              : 'لا يمكن استخدام هذا الكود.',
          reason: result.reason,
        );
      }
      discount = result.discount;
    }
    final apt =
        _MockAppointment(
            id: 'apt-${_nextAppointment++}',
            slotId: slotId,
            doctorIndex: doctor,
            startsAtLocal: local,
            minutes: 30,
            serviceIndex: serviceIndex,
            note: body['patientNote'] as String?,
            status: 'Confirmed',
            price: price,
          )
          ..familyMemberId = familyId
          ..mode = video ? 'Video' : 'InPerson'
          ..couponCode = code?.trim().toUpperCase()
          ..discount = discount;
    if (insurance != null) {
      apt
        ..insuranceProviderId = insurance['providerId'] as String
        ..insuranceMember = insurance['memberNumber'] as String?
        ..insuranceStatus = 'Pending';
    }
    _reserved.add(slotId);
    _appointments.add(apt);
    // Booking the doctor on a waited-for day closes the waiting entry.
    for (final w in _waiting) {
      if (w.doctorIndex == doctor &&
          w.date == _plainDay(local, 0) &&
          (w.status == 'Waiting' || w.status == 'Notified')) {
        w.status = 'Booked';
      }
    }
    return _appointmentJson(apt, lang);
  }

  void _cancel(_MockAppointment apt, Map<String, dynamic> body, String lang) {
    _requireChangeable(apt, lang);
    _reserved.remove(apt.slotId);
    apt
      ..status = 'Cancelled'
      ..cancelledBy = 'Patient'
      ..cancelReason = body['reason'] as String?;
    // A paid appointment is refunded automatically.
    if (apt.payment == 'Paid') apt.payment = 'Refunded';
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
      'familyMember': _familyRef(a.familyMemberId),
      'mode': a.mode,
      'priceEgp': a.price,
      'discountEgp': a.discount,
      'totalEgp': a.price - a.discount,
      'paymentStatus': a.payment,
      'insurance': a.insuranceProviderId == null
          ? null
          : {
              'provider': {
                'id': a.insuranceProviderId,
                'name': _insurerName(a.insuranceProviderId!, lang),
              },
              'memberNumber': a.insuranceMember,
              'status': a.insuranceStatus,
              'note': a.insuranceNote,
            },
      'canReview':
          _on('reviews') && a.status == 'Completed' && a.reviewRating == null,
      'review': a.reviewRating == null
          ? null
          : {'rating': a.reviewRating, 'comment': a.reviewComment},
    };
  }

  Map<String, dynamic>? _familyRef(String? id) {
    if (id == null) return null;
    final m = _family.firstWhere((m) => m.id == id);
    return {'id': m.id, 'fullName': m.fullName, 'relation': m.relation};
  }

  String _insurerName(String id, String lang) {
    final i = mockInsurers.firstWhere((i) => i.$1 == id);
    return lang == 'en' ? i.$2 : i.$3;
  }

  // --- phase 2 handlers ---------------------------------------------------

  /// Family, waiting list, coupons, payments and records. Null when [path] is
  /// not one of theirs.
  (int, Object?)? _phase2Route(
    String method,
    String path,
    Map<String, dynamic> q,
    Map<String, dynamic> body,
    String lang,
  ) {
    void requireOn(String key) {
      if (!_on(key)) throw _MockError.featureDisabled(key);
    }

    if (path == '/me/family' || path.startsWith('/me/family/')) {
      requireOn('familyAccounts');
      final id = path == '/me/family'
          ? null
          : path.substring('/me/family/'.length);
      switch ((method, id)) {
        case ('GET', null):
          return (200, [for (final m in _family) m.toJson()]);
        case ('POST', null):
          if (_family.length >= 10) {
            throw _MockError(
              422,
              'VALIDATION_FAILED',
              'At most 10 family members.',
            );
          }
          final member = _MockFamily(
            'fam-${_nextId++ + 10}',
            (body['fullName'] as String).trim(),
            body['relation'] as String,
            body['dateOfBirth'] as String?,
            body['gender'] as String?,
          );
          _family.add(member);
          return (201, member.toJson());
        case ('PUT', final String id):
          final index = _family.indexWhere((m) => m.id == id);
          if (index < 0) throw _MockError.notFound();
          _family[index] = _MockFamily(
            id,
            (body['fullName'] as String).trim(),
            body['relation'] as String,
            body['dateOfBirth'] as String?,
            body['gender'] as String?,
          );
          return (200, _family[index].toJson());
        case ('DELETE', final String id):
          _family.removeWhere((m) => m.id == id);
          return (204, null);
      }
    }

    if (path == '/waiting-list' || path.startsWith('/waiting-list/')) {
      requireOn('waitingList');
      if (method == 'GET') {
        return (
          200,
          [for (final w in _waiting.reversed) _waitingJson(w, lang)],
        );
      }
      if (method == 'POST') {
        final doctorIndex = _doctors.indexWhere(
          (d) => d.id == body['doctorId'],
        );
        if (doctorIndex < 0) throw _MockError.notFound();
        final date = DateTime.parse('${body['date']}');
        final day = DateTime(date.year, date.month, date.day);
        final exists = _waiting.any(
          (w) =>
              w.doctorIndex == doctorIndex &&
              w.date == day &&
              w.familyMemberId == body['familyMemberId'] &&
              (w.status == 'Waiting' || w.status == 'Notified'),
        );
        if (exists) {
          throw _MockError(
            409,
            'ALREADY_WAITING',
            lang == 'en'
                ? 'You are already on this waiting list.'
                : 'أنت بالفعل في قائمة الانتظار.',
          );
        }
        final entry = _MockWaiting(
          'wl-${_nextId++ + 10}',
          doctorIndex,
          day,
          'Waiting',
          DateTime.now().toUtc(),
          familyMemberId: body['familyMemberId'] as String?,
        );
        _waiting.add(entry);
        return (201, _waitingJson(entry, lang));
      }
      if (method == 'DELETE') {
        final id = path.substring('/waiting-list/'.length);
        final entry = _waiting.firstWhere(
          (w) => w.id == id,
          orElse: () => throw _MockError.notFound(),
        );
        entry.status = 'Cancelled';
        return (204, null);
      }
    }

    if (method == 'POST' && path == '/coupons/validate') {
      requireOn('promotions');
      final doctorIndex = _doctors.indexWhere((d) => d.id == body['doctorId']);
      if (doctorIndex < 0) throw _MockError.notFound();
      final serviceId = body['serviceId'] as String?;
      final serviceIndex = serviceId == null
          ? null
          : _services.indexWhere((s) => s.$1 == serviceId);
      final price = _priceFor(doctorIndex, serviceIndex);
      final result = _evaluateCoupon(
        '${body['code']}',
        doctorIndex,
        serviceId,
        price,
      );
      return (
        200,
        {
          'valid': result.valid,
          'discountEgp': result.discount,
          'totalEgp': price - result.discount,
          'reason': ?result.reason,
        },
      );
    }

    final paymentMatch = RegExp(r'^/payments/(?:mock-checkout/)?([^/]+)$')
        .firstMatch(path);
    if (paymentMatch != null) {
      requireOn('onlinePayments');
      final payment = _payments[paymentMatch[1]];
      if (payment == null) throw _MockError.notFound();
      if (method == 'POST' && path.contains('/mock-checkout/')) {
        // The demo stand-in for the provider's checkout page and webhook.
        final paid = body['outcome'] != 'failed';
        payment.status = paid ? 'Paid' : 'Failed';
        _appointments.firstWhere((a) => a.id == payment.appointmentId).payment =
            paid ? 'Paid' : 'Unpaid';
        return (
          200,
          {
            'returnUrl':
                '${Brand.paymentReturnUrl}?paymentId=${payment.id}'
                '&status=${paid ? 'paid' : 'failed'}',
          },
        );
      }
      return (200, payment.toJson());
    }

    if (method == 'GET' && path == '/me/records') {
      requireOn('patientRecords');
      final member = q['familyMemberId'] as String?;
      final info = member == null
          ? mockMedicalInfo
          : mockMedicalInfoByMember[member];
      return (
        200,
        {
          'medicalInfo': info,
          'entries': [
            for (final r in mockRecords)
              if (r.owner == member)
                {
                  'id': r.id,
                  'kind': r.kind,
                  'title': r.title,
                  'body': r.body,
                  'hasAttachment': r.attachmentUrl != null,
                  'doctorName': r.doctorName,
                  'createdAt': _iso(
                    DateTime.now().toUtc().subtract(Duration(days: r.daysAgo)),
                  ),
                },
          ],
        },
      );
    }
    return null;
  }

  Map<String, dynamic> _waitingJson(_MockWaiting w, String lang) {
    final d = _doctors[w.doctorIndex];
    return {
      'id': w.id,
      'doctor': {
        'id': d.id,
        'slug': d.slug,
        'name': lang == 'en' ? d.nameEn : d.nameAr,
        'photoUrl': null,
      },
      'date': _ymd(w.date),
      'status': w.status,
      'familyMember': _familyRef(w.familyMemberId),
      'notifiedAt': w.notifiedAt == null ? null : _iso(w.notifiedAt!),
    };
  }

  List<Map<String, dynamic>> _promotions(String lang) {
    final now = _clinicNow();
    return [
      for (final o in mockOffers)
        {
          'code': o.code,
          'title': lang == 'en' ? o.titleEn : o.titleAr,
          'description': lang == 'en' ? o.descriptionEn : o.descriptionAr,
          'discountType': o.percent ? 'Percent' : 'Fixed',
          'value': o.value,
          'validTo': _ymd(_plainDay(now, o.validInDays)),
          'doctorId': o.doctorId,
          'serviceId': o.serviceId,
        },
    ];
  }

  ({bool valid, num discount, String? reason}) _evaluateCoupon(
    String raw,
    int doctor,
    String? serviceId,
    num price,
  ) {
    final code = raw.trim().toUpperCase();
    ({bool valid, num discount, String? reason}) no(String reason) =>
        (valid: false, discount: 0, reason: reason);
    if (code == mockExpiredCode) return no('Expired');
    if (code == mockUsedCode) return no('PerPatientLimit');
    final offer = mockOffers.where((o) => o.code == code).firstOrNull;
    if (offer == null) return no('NotFound');
    if (offer.doctorId != null && offer.doctorId != _doctors[doctor].id) {
      return no('NotApplicable');
    }
    if (offer.serviceId != null && offer.serviceId != serviceId) {
      return no('NotApplicable');
    }
    if (price <= 0) return no('NoPrice');
    num discount = offer.percent ? price * offer.value / 100 : offer.value;
    if (offer.maxDiscount != null && discount > offer.maxDiscount!) {
      discount = offer.maxDiscount!;
    }
    if (discount > price) discount = price;
    return (valid: true, discount: discount.round(), reason: null);
  }

  Map<String, dynamic> _reviewsPage(int doctor, Map<String, dynamic> q) {
    if (!_on('reviews')) throw _MockError.featureDisabled('reviews');
    final all = mockReviews[_doctors[doctor].id] ?? const <MockReview>[];
    final page = int.parse('${q['page'] ?? 1}');
    final size = int.parse('${q['pageSize'] ?? 10}');
    return {
      'items': [
        for (final r in all.skip((page - 1) * size).take(size))
          {
            'rating': r.rating,
            'comment': r.comment,
            'patientFirstName': r.name,
            'createdAt': _iso(
              DateTime.now().toUtc().subtract(Duration(days: r.daysAgo)),
            ),
            'reply': r.reply,
          },
      ],
      'page': page,
      'pageSize': size,
      'totalCount': all.length,
    };
  }

  Map<String, dynamic> _startPayment(_MockAppointment apt) {
    if (!_on('onlinePayments')) {
      throw _MockError.featureDisabled('onlinePayments');
    }
    final total = apt.price - apt.discount;
    final future = _toUtc(apt.startsAtLocal).isAfter(DateTime.now().toUtc());
    final payable = apt.payment == 'Unpaid' || apt.payment == 'Pending';
    if (apt.status != 'Confirmed' || !future || !payable || total <= 0) {
      throw _MockError(
        409,
        'PAYMENT_NOT_ALLOWED',
        'This appointment cannot be paid online.',
      );
    }
    final payment = _MockPayment('pay-${_nextId++}', apt.id, total);
    _payments[payment.id] = payment;
    apt.payment = 'Pending';
    return {
      'paymentId': payment.id,
      'checkoutUrl':
          'https://mock.moonlight.local/api/v1/payments/mock-checkout/${payment.id}',
    };
  }

  void _review(_MockAppointment apt, Map<String, dynamic> body) {
    if (!_on('reviews')) throw _MockError.featureDisabled('reviews');
    if (apt.reviewRating != null) {
      throw _MockError(
        409,
        'ALREADY_REVIEWED',
        'You already rated this visit.',
      );
    }
    if (apt.status != 'Completed') {
      throw _MockError(409, 'NOT_REVIEWABLE', 'This visit cannot be rated.');
    }
    apt
      ..reviewRating = (body['rating'] as num).toInt()
      ..reviewComment = body['comment'] as String?;
  }

  Map<String, dynamic> _videoRoom(_MockAppointment apt) {
    if (!_on('videoConsultation')) {
      throw _MockError.featureDisabled('videoConsultation');
    }
    final start = _toUtc(apt.startsAtLocal);
    final opens = start.subtract(const Duration(minutes: 15));
    final closes = start.add(Duration(minutes: apt.minutes + 30));
    final now = DateTime.now().toUtc();
    if (apt.mode != 'Video' ||
        apt.status != 'Confirmed' ||
        now.isBefore(opens) ||
        now.isAfter(closes)) {
      throw _MockError(
        409,
        'VIDEO_NOT_OPEN',
        'The video room is not open yet.',
      );
    }
    return {
      'joinUrl': 'https://meet.jit.si/moonlight-${apt.id}-k3x9q7',
      'opensAt': _iso(opens),
      'closesAt': _iso(closes),
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

class _MockFamily {
  const _MockFamily(
    this.id,
    this.fullName,
    this.relation,
    this.dateOfBirth,
    this.gender,
  );

  final String id;
  final String fullName;
  final String relation;
  final String? dateOfBirth;
  final String? gender;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'relation': relation,
    'dateOfBirth': dateOfBirth,
    'gender': gender,
    'createdAt': '2026-09-01T10:00:00Z',
  };
}

class _MockWaiting {
  _MockWaiting(
    this.id,
    this.doctorIndex,
    this.date,
    this.status,
    this.createdAt, {
    this.notifiedAt,
    this.familyMemberId,
  });

  final String id;
  final String? familyMemberId;
  final int doctorIndex;
  final DateTime date;
  String status;
  final DateTime createdAt;
  final DateTime? notifiedAt;
}

class _MockPayment {
  _MockPayment(this.id, this.appointmentId, this.amount);

  final String id;
  final String appointmentId;
  final num amount;
  String status = 'Pending';

  Map<String, dynamic> toJson() => {
    'id': id,
    'appointmentId': appointmentId,
    'amountEgp': amount,
    'status': status,
  };
}

class _MockAppointment {
  _MockAppointment({
    required this.id,
    required this.slotId,
    required this.doctorIndex,
    required this.startsAtLocal,
    required this.minutes,
    required this.status,
    required this.price,
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
  String? familyMemberId;
  String mode = 'InPerson';
  final num price;
  num discount = 0;
  String? couponCode;
  String payment = 'Unpaid';
  String? insuranceProviderId;
  String? insuranceMember;
  String? insuranceStatus;
  String? insuranceNote;
  int? reviewRating;
  String? reviewComment;
}

class _MockUser {
  _MockUser({
    required this.phone,
    this.fullName,
    this.language = 'ar',
    this.whatsAppOptIn = true,
    this.marketingOptIn = true,
  });

  factory _MockUser.demo({String phone = '+201012345678'}) =>
      _MockUser(phone: phone, fullName: 'نور سمير');

  final String phone;
  final String? fullName;
  final String language;
  final bool whatsAppOptIn;
  final bool marketingOptIn;

  _MockUser copyWith({
    String? fullName,
    String? language,
    bool? whatsAppOptIn,
    bool? marketingOptIn,
  }) => _MockUser(
    phone: phone,
    fullName: fullName ?? this.fullName,
    language: language ?? this.language,
    whatsAppOptIn: whatsAppOptIn ?? this.whatsAppOptIn,
    marketingOptIn: marketingOptIn ?? this.marketingOptIn,
  );

  Map<String, dynamic> toJson() => {
    'id': 'user-demo',
    'phone': phone,
    'fullName': fullName,
    'role': 'Patient',
    'preferredLanguage': language,
    'whatsAppOptIn': whatsAppOptIn,
    'marketingOptIn': marketingOptIn,
  };
}

class _MockError implements Exception {
  _MockError(this.status, this.code, this.detail, {this.reason});

  factory _MockError.featureDisabled(String feature) =>
      _MockError(403, 'FEATURE_DISABLED', 'This feature is turned off.')
        .._feature = feature;

  factory _MockError.notFound() => _MockError(404, 'NOT_FOUND', 'Not found.');
  factory _MockError.unauthorized() =>
      _MockError(401, 'UNAUTHORIZED', 'Sign in again.');

  final int status;
  final String code;
  final String detail;
  final String? reason;
  String? _feature;
}
