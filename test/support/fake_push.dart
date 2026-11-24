import 'dart:async';

import 'package:moonlight/core/push/push_service.dart';

/// A push service whose token and notification taps the test controls.
class FakePushService implements PushService {
  FakePushService({this.token = 'fcm-token-1'});

  String? token;
  final tokenController = StreamController<String>.broadcast();
  final tapController = StreamController<String>.broadcast();
  final foregroundController = StreamController<ForegroundPush>.broadcast();
  int initializeCalls = 0;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get tokenRefreshes => tokenController.stream;

  @override
  Stream<String> get openedAppointmentIds => tapController.stream;

  @override
  Stream<ForegroundPush> get foregroundMessages => foregroundController.stream;
}
