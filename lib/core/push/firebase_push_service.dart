import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_service.dart';

/// [PushService] on Firebase Cloud Messaging.
///
/// Firebase config (`google-services.json`) is per clinic and is not in the
/// repo, so [tryCreate] returns null when Firebase cannot start and the app
/// keeps the no-op push service.
class FirebasePushService implements PushService {
  FirebasePushService._(this._messaging);

  final FirebaseMessaging _messaging;
  bool _initialized = false;

  /// Starts Firebase and returns the service, or null when there is no config.
  static Future<FirebasePushService?> tryCreate() async {
    try {
      await Firebase.initializeApp();
      return FirebasePushService._(FirebaseMessaging.instance);
    } catch (e) {
      debugPrint('Push disabled: Firebase did not start ($e)');
      return null;
    }
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _messaging.requestPermission();
    } catch (e) {
      debugPrint('Push permission request failed ($e)');
    }
  }

  @override
  Future<String?> currentToken() async {
    try {
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Push token unavailable ($e)');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<String> get openedAppointmentIds async* {
    final initial = await _messaging.getInitialMessage();
    final first = appointmentIdOf(initial?.data);
    if (first != null) yield first;
    yield* FirebaseMessaging.onMessageOpenedApp
        .map((message) => appointmentIdOf(message.data))
        .where((id) => id != null)
        .cast<String>();
  }

  /// The `appointmentId` of a notification payload, or null when it has none.
  @visibleForTesting
  static String? appointmentIdOf(Map<String, dynamic>? data) {
    final id = data?['appointmentId'];
    return id is String && id.isNotEmpty ? id : null;
  }
}
