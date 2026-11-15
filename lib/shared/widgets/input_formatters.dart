import 'package:flutter/services.dart';

/// Drops leading whitespace as the patient types (values are trimmed on send).
final noLeadingSpace = FilteringTextInputFormatter.deny(
  RegExp(r'^\s+'),
  replacementString: '',
);
