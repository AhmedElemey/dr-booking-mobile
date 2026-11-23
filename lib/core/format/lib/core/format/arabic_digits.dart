import 'package:intl/number_symbols_data.dart';

/// intl's `ar` number symbols use Western digits, while Flutter's Arabic date
/// symbols use Arabic-Indic ones, so an Arabic page showed ١٠:٠٠ ص next to 450
/// جنيه. Point `ar` at Egypt's symbols so every NumberFormat in the Arabic UI
/// matches the dates. The English locale is untouched.
void useArabicIndicDigits() {
  final egypt = numberFormatSymbols['ar_EG'];
  if (egypt != null) numberFormatSymbols['ar'] = egypt;
}
