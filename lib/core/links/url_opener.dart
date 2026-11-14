import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a web link: payment checkout, video room, record attachments.
/// Returns false when nothing could handle it.
typedef UrlOpener = Future<bool> Function(Uri uri, {bool inApp});

/// The platform opener. [inApp] uses an in-app browser tab (the checkout), the
/// default hands the link to the browser or another app (video, files).
final urlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (uri, {inApp = false}) => launchUrl(
        uri,
        mode: inApp
            ? LaunchMode.inAppBrowserView
            : LaunchMode.externalApplication,
      ),
);
