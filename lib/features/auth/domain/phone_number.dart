/// Egyptian mobile numbers only (`+20 1x xxxx xxxx`), per the v1 scope.
abstract final class PhoneNumber {
  static final _valid = RegExp(r'^\+201[0125]\d{8}$');

  /// Normalizes what a user types (`01012345678`, `+20 101 234 5678`,
  /// Arabic-Indic digits…) to E.164, or returns null when it is not a valid
  /// Egyptian mobile number.
  static String? normalize(String input) {
    final ascii = toAsciiDigits(input);
    var digits = ascii.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) {
      digits = '+${digits.substring(1).replaceAll('+', '')}';
    } else if (digits.startsWith('0020')) {
      digits = '+${digits.substring(2)}';
    } else if (digits.startsWith('20') && digits.length == 12) {
      digits = '+$digits';
    } else if (digits.startsWith('0')) {
      digits = '+20${digits.substring(1)}';
    } else if (digits.startsWith('1')) {
      digits = '+20$digits';
    }
    return _valid.hasMatch(digits) ? digits : null;
  }

  /// Arabic-Indic and Eastern Arabic-Indic digits to 0-9.
  static String toAsciiDigits(String input) {
    final buffer = StringBuffer();
    for (final unit in input.runes) {
      if (unit >= 0x0660 && unit <= 0x0669) {
        buffer.writeCharCode(unit - 0x0660 + 0x30); // Arabic-Indic
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        buffer.writeCharCode(unit - 0x06F0 + 0x30); // Eastern Arabic-Indic
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }
}
