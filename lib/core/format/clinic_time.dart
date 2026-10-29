import 'package:intl/intl.dart';

/// Formats clinic wall-clock values. Inputs are zone-less [DateTime]s taken
/// from the API's `startsAtLocal` / `local` / `date` fields, so the device
/// timezone never shifts what the patient sees.
abstract final class ClinicTime {
  static String date(DateTime local, String locale) =>
      DateFormat.yMMMEd(locale).format(local);

  static String shortDate(DateTime local, String locale) =>
      DateFormat.MMMEd(locale).format(local);

  static String weekday(DateTime local, String locale) =>
      DateFormat.E(locale).format(local);

  static String dayNumber(DateTime local, String locale) =>
      DateFormat.d(locale).format(local);

  static String time(DateTime local, String locale) =>
      DateFormat.jm(locale).format(local);

  static String dateAndTime(DateTime local, String locale) =>
      '${date(local, locale)} · ${time(local, locale)}';

  /// `HH:mm` as sent in a slot's `local` field.
  static DateTime parseTime(String hhmm, {DateTime? onDate}) {
    final parts = hhmm.split(':');
    final base = onDate ?? DateTime(2000);
    return DateTime(
      base.year,
      base.month,
      base.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// `yyyy-MM-dd` as sent in a slot day's `date` field.
  static DateTime parseDate(String ymd) {
    final p = ymd.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }
}
