import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a web link: payment checkout, video room.
/// Returns false when the link is not a safe web link or nothing could handle it.
typedef UrlOpener = Future<bool> Function(Uri uri, {bool inApp});

/// Parses a link that came from the API. Only absolute `https` links (and
/// `http` while debugging, because the local API is plain http) with a host are
/// accepted; `tel:`, `sms:`, `intent:`, `file:`, custom schemes and malformed
/// text give null. [allowHttp] defaults to debug builds only.
Uri? safeWebUri(String? raw, {bool? allowHttp}) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return uri;
  if (scheme == 'http' && (allowHttp ?? kDebugMode)) return uri;
  return null;
}

/// The platform opener. [inApp] uses an in-app browser tab (the checkout), the
/// default hands the link to the browser (video). Every link is checked with
/// [safeWebUri] first and errors from the platform become `false`.
final urlOpenerProvider = Provider<UrlOpener>(
  (ref) => (uri, {inApp = false}) async {
    if (safeWebUri(uri.toString()) == null) return false;
    try {
      return await launchUrl(
        uri,
        mode: inApp
            ? LaunchMode.inAppBrowserView
            : LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint('could not open $uri: $error');
      return false;
    }
  },
);

/// Dismisses the in-app checkout tab once its return link has arrived (iOS keeps
/// the Safari sheet on top otherwise). Never throws.
final inAppBrowserCloserProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      await closeInAppWebView();
    } catch (error) {
      debugPrint('could not close the in-app browser: $error');
    }
  },
);
