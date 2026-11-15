enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
  cancelled;

  static PaymentStatus parse(String? value) => switch (value) {
    'Paid' => paid,
    'Failed' => failed,
    'Refunded' => refunded,
    'Cancelled' => cancelled,
    _ => pending,
  };

  bool get isFinal => this != pending;
}

/// `GET /payments/{id}`
class Payment {
  const Payment({
    required this.id,
    required this.appointmentId,
    required this.amountEgp,
    required this.status,
  });

  final String id;
  final String appointmentId;
  final num amountEgp;
  final PaymentStatus status;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    appointmentId: json['appointmentId'] as String,
    amountEgp: (json['amountEgp'] as num?) ?? 0,
    status: PaymentStatus.parse(json['status'] as String?),
  );
}

/// `POST /appointments/{id}/pay`
class Checkout {
  const Checkout({required this.paymentId, required this.checkoutUrl});

  final String paymentId;
  final String checkoutUrl;

  factory Checkout.fromJson(Map<String, dynamic> json) => Checkout(
    paymentId: json['paymentId'] as String,
    checkoutUrl: json['checkoutUrl'] as String,
  );
}

/// The appointment's own view of its payment: `Unpaid|Pending|Paid|Refunded`.
enum AppointmentPaymentStatus {
  unpaid,
  pending,
  paid,
  refunded;

  static AppointmentPaymentStatus parse(String? value) => switch (value) {
    'Pending' => pending,
    'Paid' => paid,
    'Refunded' => refunded,
    _ => unpaid,
  };
}
