/// `GET /appointments/{id}/video`
class VideoRoom {
  const VideoRoom({
    required this.joinUrl,
    required this.opensAt,
    required this.closesAt,
  });

  final String joinUrl;
  final DateTime opensAt;
  final DateTime closesAt;

  factory VideoRoom.fromJson(Map<String, dynamic> json) => VideoRoom(
    joinUrl: json['joinUrl'] as String,
    opensAt: DateTime.parse(json['opensAt'] as String).toUtc(),
    closesAt: DateTime.parse(json['closesAt'] as String).toUtc(),
  );
}

/// The join window the API enforces: start minus 15 minutes to end plus 30.
const videoOpensBefore = Duration(minutes: 15);
const videoClosesAfter = Duration(minutes: 30);
