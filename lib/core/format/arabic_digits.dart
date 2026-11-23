import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';

/// intl's `ar` number symbols use Western digits, while Flutter's Arabic date
/// symbols use Arabic-Indic ones, so an Arabic page showed ١٠:٠٠ ص next to 450
/// جنيه. Point `ar` at Egypt's symbols so every NumberFormat in the Arabic UI
/// matches the dates. The English locale is untouched.
void useArabicIndicDigits() {
  final egypt = numberFormatSymbols['ar_EG'];
  if (egypt != null) numberFormatSymbols['ar'] = egypt;
}

/// TextField counter that renders digits with the current locale's symbols
/// (Arabic-Indic in the Arabic UI) instead of Material's Latin "0 / 500".
Widget? localizedFieldCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) {
  if (maxLength == null) return null;
  final locale = Localizations.localeOf(context);
  final format = NumberFormat.decimalPattern(locale.toString());
  return Text(
    '${format.format(currentLength)} / ${format.format(maxLength)}',
    style: Theme.of(context).textTheme.bodySmall,
    maxLines: 1,
    overflow: TextOverflow.clip,
  );
}
