import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/failure.dart';
import '../data/waiting_list_repository.dart';
import '../domain/waiting_entry.dart';

/// The patient's active and recent waiting-list entries.
final waitingListProvider = FutureProvider.autoDispose<List<WaitingEntry>>((
  ref,
) {
  ref.watch(localeProvider);
  return ref.watch(waitingListRepositoryProvider).mine().unwrap();
});
