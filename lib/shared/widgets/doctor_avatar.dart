import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Doctor photo (cached), or the initial of their name when there is none.
class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 28,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        _initial(name),
        style: TextStyle(
          fontSize: radius * 0.8,
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, image) =>
          CircleAvatar(radius: radius, backgroundImage: image),
      placeholder: (context, _) => fallback,
      errorWidget: (context, _, _) => fallback,
    );
  }

  /// First letter of the name, skipping a leading "Dr." / "د.".
  static String _initial(String name) {
    final cleaned = name
        .replaceFirst(RegExp(r'^\s*(dr\.?|د\.?)\s*', caseSensitive: false), '')
        .trim();
    return cleaned.isEmpty ? '?' : String.fromCharCode(cleaned.runes.first);
  }
}
