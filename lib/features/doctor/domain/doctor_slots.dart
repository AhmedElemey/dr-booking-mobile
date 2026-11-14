/// One bookable time. `local` is the clinic-local wall-clock time (`HH:mm`).
class Slot {
  const Slot({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.local,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String local;

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
    id: json['id'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String).toUtc(),
    endsAt: DateTime.parse(json['endsAt'] as String).toUtc(),
    local: json['local'] as String,
  );
}

class SlotDay {
  const SlotDay({required this.date, required this.slots});

  /// Clinic-local calendar date, `yyyy-MM-dd`.
  final String date;
  final List<Slot> slots;

  factory SlotDay.fromJson(Map<String, dynamic> json) => SlotDay(
    date: json['date'] as String,
    slots: [
      for (final s in json['slots'] as List)
        Slot.fromJson(s as Map<String, dynamic>),
    ],
  );
}

/// A day the clinic is closed for a holiday (`closedDates`).
class ClosedDate {
  const ClosedDate({required this.date, required this.name});

  /// Clinic-local calendar date, `yyyy-MM-dd`.
  final String date;
  final String name;

  factory ClosedDate.fromJson(Map<String, dynamic> json) => ClosedDate(
    date: (json['date'] as String).substring(0, 10),
    name: (json['name'] as String?) ?? '',
  );
}

/// `GET /doctors/{idOrSlug}/slots`: open slots grouped by clinic-local day.
class DoctorSlots {
  const DoctorSlots({
    required this.doctorId,
    required this.timezone,
    required this.days,
    this.closedDates = const [],
  });

  final String doctorId;
  final String timezone;
  final List<SlotDay> days;

  /// Holidays in the window (empty unless the clinic uses the holiday calendar).
  final List<ClosedDate> closedDates;

  bool get isEmpty => days.every((d) => d.slots.isEmpty);

  factory DoctorSlots.fromJson(Map<String, dynamic> json) => DoctorSlots(
    doctorId: json['doctorId'] as String,
    timezone: json['timezone'] as String,
    days: [
      for (final d in json['days'] as List)
        SlotDay.fromJson(d as Map<String, dynamic>),
    ],
    closedDates: [
      if (json['closedDates'] is List)
        for (final c in json['closedDates'] as List)
          ClosedDate.fromJson(c as Map<String, dynamic>),
    ],
  );

  /// The holiday on [date] (`yyyy-MM-dd`), if the clinic is closed that day.
  ClosedDate? closedOn(String date) {
    for (final c in closedDates) {
      if (c.date == date) return c;
    }
    return null;
  }
}
