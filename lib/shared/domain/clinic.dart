class Clinic {
  const Clinic({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.phone,
    this.latitude,
    this.longitude,
    this.timezone,
  });

  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? phone;
  final double? latitude;
  final double? longitude;

  /// IANA zone of the clinic (`Africa/Cairo`); informational, since the API
  /// already returns clinic-local times.
  final String? timezone;

  factory Clinic.fromJson(Map<String, dynamic> json) => Clinic(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String?,
    city: json['city'] as String?,
    phone: json['phone'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    timezone: json['timezone'] as String?,
  );
}

/// A treatment type a doctor offers (informational: duration and price).
class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    this.durationMinutes,
    this.priceEgp,
  });

  final String id;
  final String name;
  final int? durationMinutes;
  final num? priceEgp;

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
    id: json['id'] as String,
    name: json['name'] as String,
    durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    priceEgp: json['priceEgp'] as num?,
  );
}
