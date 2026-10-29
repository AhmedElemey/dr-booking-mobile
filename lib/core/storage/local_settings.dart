import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret, per-install settings (language choice, registered push token id).
class LocalSettings {
  LocalSettings(this._prefs);

  static const _languageKey = 'language';
  static const _deviceTokenIdKey = 'device_token_id';

  final SharedPreferences _prefs;

  /// `ar` / `en`, or null until the user picks one on first launch.
  String? get languageCode => _prefs.getString(_languageKey);
  Future<void> setLanguageCode(String code) =>
      _prefs.setString(_languageKey, code);

  /// Id returned by `PUT /me/device-tokens`, kept to unregister on logout.
  String? get deviceTokenId => _prefs.getString(_deviceTokenIdKey);
  Future<void> setDeviceTokenId(String? id) => id == null
      ? _prefs.remove(_deviceTokenIdKey)
      : _prefs.setString(_deviceTokenIdKey, id);
}

/// Overridden in bootstrap() once SharedPreferences has loaded.
final localSettingsProvider = Provider<LocalSettings>(
  (ref) => throw UnimplementedError('localSettingsProvider must be overridden'),
);
