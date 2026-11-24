import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/appointments/domain/appointment.dart';
import 'package:moonlight/features/payments/domain/payment.dart';

void main() {
  test('parse maps the live queue and pending statuses', () {
    expect(AppointmentStatus.parse('Pending'), AppointmentStatus.pending);
    expect(AppointmentStatus.parse('CheckedIn'), AppointmentStatus.checkedIn);
    expect(AppointmentStatus.parse('InProgress'), AppointmentStatus.inProgress);
    expect(AppointmentStatus.parse('Confirmed'), AppointmentStatus.confirmed);
    expect(AppointmentStatus.parse('NoShow'), AppointmentStatus.noShow);
  });

  test('parse maps the deposit-paid payment status and the paid deposit', () {
    expect(
      AppointmentPaymentStatus.parse('DepositPaid'),
      AppointmentPaymentStatus.depositPaid,
    );
    expect(
      AppointmentPaymentStatus.parse('Paid'),
      AppointmentPaymentStatus.paid,
    );
    expect(
      AppointmentPaymentStatus.parse(null),
      AppointmentPaymentStatus.unpaid,
    );
  });
}
