import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/appointments/domain/appointment.dart';

void main() {
  test('parse maps the live queue and pending statuses', () {
    expect(AppointmentStatus.parse('Pending'), AppointmentStatus.pending);
    expect(AppointmentStatus.parse('CheckedIn'), AppointmentStatus.checkedIn);
    expect(AppointmentStatus.parse('InProgress'), AppointmentStatus.inProgress);
    expect(AppointmentStatus.parse('Confirmed'), AppointmentStatus.confirmed);
    expect(AppointmentStatus.parse('NoShow'), AppointmentStatus.noShow);
  });
}
