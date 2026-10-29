import '../../appointments/domain/appointment.dart';

/// A Google Calendar "create event" link for [appointment]. It opens in the
/// calendar app or browser and needs no device calendar permission.
Uri calendarUri(Appointment appointment, {required String title}) {
  String stamp(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}T'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  final clinic = appointment.clinic;
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${stamp(appointment.startsAt)}/${stamp(appointment.endsAt)}',
    'details': appointment.doctor.name,
    'location': [clinic.name, ?clinic.address].join(', '),
  });
}
