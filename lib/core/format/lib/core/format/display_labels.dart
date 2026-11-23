import '../l10n/generated/app_localizations.dart';

/// The catalog API returns a city's English name whatever the UI language is;
/// map the names we know to the UI language and pass the rest through. The raw
/// server value is still what queries send back.
String cityLabel(String city, AppLocalizations l10n) => switch (city) {
  'Cairo' => l10n.cityCairo,
  _ => city,
};

/// The API sends the clinic's IANA zone id (`Africa/Cairo`); show the place,
/// not the id, and pass unknown zones through.
String timezoneLabel(String iana, AppLocalizations l10n) => switch (iana) {
  'Africa/Cairo' => l10n.timezoneCairo,
  _ => iana,
};
