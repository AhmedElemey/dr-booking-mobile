import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Push notifications behind an interface, so the app compiles and runs without
/// a Firebase project. See "Push notifications and deep links" in README.md for
/// how to plug in `firebase_messaging`.
/// A push that arrived while the app was open. The system shows nothing in
/// that case, so the app shows it itself.
class ForegroundPush {
  const ForegroundPush({this.title, this.body, this.appointmentId});

  final String? title;
  final String? body;

  /// The appointment the push is about, if its payload names one.
  final String? appointmentId;

  /// The text to show, or null when the push has nothing to show.
  String? get text {
    final parts = <String>[];
    for (final part in [title, body]) {
      final trimmed = part?.trim();
      if (trimmed != null && trimmed.isNotEmpty) parts.add(trimmed);
    }
    return parts.isEmpty ? null : parts.join(': ');
  }
}

abstract class PushService {
  /// Requests permission and starts listening. Safe to call more than once.
  Future<void> initialize();

  /// The current FCM registration token, or null if push is unavailable.
  Future<String?> currentToken();

  /// Emits a new token whenever FCM rotates it.
  Stream<String> get tokenRefreshes;

  /// Emits the `appointmentId` of a notification the user tapped (the payload is
  /// `data: {type, appointmentId}`), whether the app was running or cold-started.
  Stream<String> get openedAppointmentIds;

  /// Emits each push that arrives while the app is open (`onMessage`).
  Stream<ForegroundPush> get foregroundMessages;
}

/// Used until Firebase is configured: no token, no events.
class NoopPushService implements PushService {
  const NoopPushService();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<String> get openedAppointmentIds => const Stream.empty();

  @override
  Stream<ForegroundPush> get foregroundMessages => const Stream.empty();
}

final pushServiceProvider = Provider<PushService>(
  (ref) => const NoopPushService(),
);
