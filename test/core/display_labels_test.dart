import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/format/display_labels.dart';
import 'package:moonlight/core/l10n/generated/app_localizations_ar.dart';
import 'package:moonlight/core/l10n/generated/app_localizations_en.dart';

void main() {
  final ar = AppLocalizationsAr();
  final en = AppLocalizationsEn();

  test('known cities and zones are shown in the UI language', () {
    expect(cityLabel('Cairo', ar), 'القاهرة');
    expect(cityLabel('Cairo', en), 'Cairo');
    expect(timezoneLabel('Africa/Cairo', ar), 'القاهرة');
    expect(timezoneLabel('Africa/Cairo', en), 'Cairo');
  });

  test(
    'unknown values pass through (already-localized mock data included)',
    () {
      expect(cityLabel('القاهرة', ar), 'القاهرة');
      expect(cityLabel('Giza', ar), 'Giza');
      expect(timezoneLabel('Europe/London', ar), 'Europe/London');
    },
  );

  test('the clinic-time note reads as a place, not a zone id', () {
    expect(
      ar.clinicTimeNote(timezoneLabel('Africa/Cairo', ar)),
      'المواعيد بتوقيت القاهرة.',
    );
    expect(
      en.clinicTimeNote(timezoneLabel('Africa/Cairo', en)),
      'Times are shown in Cairo time.',
    );
  });
}
