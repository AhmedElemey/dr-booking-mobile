import '../l10n/generated/app_localizations.dart';
import 'brand.g.dart';

/// The clinic's name and tagline in the current language.
extension BrandText on AppLocalizations {
  String get brandName => localeName == 'en' ? Brand.nameEn : Brand.nameAr;
  String get brandTagline =>
      localeName == 'en' ? Brand.taglineEn : Brand.taglineAr;
}
