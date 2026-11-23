import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:moonlight/core/format/arabic_digits.dart';

void main() {
  test('Arabic numbers use Arabic-Indic digits after the override', () {
    // Before: intl's `ar` symbols format 450 as "450".
    expect(NumberFormat.decimalPattern('ar').format(450), '450');

    useArabicIndicDigits();

    expect(NumberFormat.decimalPattern('ar').format(450), '٤٥٠');
    expect(NumberFormat.decimalPattern('ar').format(1234.5), '١٬٢٣٤٫٥');
    // English is untouched.
    expect(NumberFormat.decimalPattern('en').format(450), '450');
  });
}
