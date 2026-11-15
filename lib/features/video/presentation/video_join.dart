import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/clinic_time.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/links/url_opener.dart';
import '../../appointments/domain/appointment.dart';
import '../data/video_repository.dart';

/// "Join video call" for a video appointment. The button is enabled inside the
/// join window (15 minutes before the visit to 30 minutes after it); tapping it
/// asks the API for the room (`VIDEO_NOT_OPEN` outside the window) and opens
/// the link outside the app.
class VideoJoinCard extends ConsumerStatefulWidget {
  const VideoJoinCard({super.key, required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<VideoJoinCard> createState() => _VideoJoinCardState();
}

class _VideoJoinCardState extends ConsumerState<VideoJoinCard> {
  Timer? _tick;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    // The window opens and closes while the screen is up.
    _tick = Timer.periodic(
      const Duration(seconds: 20),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _joining = true);
    final result = await ref
        .read(videoRepositoryProvider)
        .room(widget.appointment.id);
    if (!mounted) return;
    setState(() => _joining = false);
    final room = result.fold<String?>((failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(failure))),
      );
      return null;
    }, (room) => room.joinUrl);
    if (room == null) return;
    final url = safeWebUri(room);
    final opened = url != null && await ref.read(urlOpenerProvider)(url);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotOpenLink)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final appointment = widget.appointment;
    final now = DateTime.now().toUtc();
    final open = appointment.isVideoOpen(now);
    final closed = now.isAfter(appointment.videoClosesAt);
    final opensLocal = appointment.startsAtLocal.subtract(
      appointment.startsAt.difference(appointment.videoOpensAt),
    );
    final hint = open
        ? l10n.videoOpenNow
        : closed
        ? l10n.videoClosed
        : '${l10n.videoOpensHint} (${ClinicTime.time(opensLocal, locale)})';
    return Card(
      key: const Key('videoCard'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.videocam_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l10n.videoVisit, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(hint, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('joinVideo'),
              onPressed: open && !_joining ? _join : null,
              icon: const Icon(Icons.video_call_outlined),
              label: Text(l10n.joinVideo),
            ),
          ],
        ),
      ),
    );
  }
}
