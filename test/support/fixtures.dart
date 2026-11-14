/// JSON in the shapes the spec defines, shared by the repository tests.
Map<String, dynamic> appointmentJson({
  String id = 'apt-1',
  String status = 'Confirmed',
}) => {
  'id': id,
  'status': status,
  'slotId': 'slot-1',
  'startsAt': '2026-11-02T07:00:00Z',
  'endsAt': '2026-11-02T07:30:00Z',
  'startsAtLocal': '2026-11-02T09:00:00',
  'timezone': 'Africa/Cairo',
  'doctor': {
    'id': 'doc-1',
    'slug': 'mona-hassan',
    'name': 'Dr. Mona Hassan',
    'photoUrl': null,
  },
  'clinic': {
    'id': 'clinic-1',
    'name': 'Nile Smile',
    'address': '12 Road 9, Maadi',
    'phone': '+20227000000',
    'latitude': 29.96,
    'longitude': 31.25,
  },
  'service': {
    'id': 'svc-1',
    'name': 'Check-up',
    'durationMinutes': 30,
    'priceEgp': 300,
  },
  'patientNote': 'first visit',
};

Map<String, dynamic> userJson({String? fullName = 'Nour Samir'}) => {
  'id': 'user-1',
  'phone': '+201012345678',
  'fullName': fullName,
  'role': 'Patient',
  'preferredLanguage': 'ar',
};
