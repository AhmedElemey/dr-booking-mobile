import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'failure.dart';
import 'paged.dart';

class PagedState<T> {
  const PagedState({
    required this.items,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<T> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  PagedState<T> copyWith({
    List<T>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) => PagedState(
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// An infinite-scroll list: the first page loads in `build`, `loadMore` appends
/// the next one. Subclasses supply [fetchPage] and `watch` whatever should
/// reload the list (for example the locale) in [watchInputs].
abstract class PagedNotifier<T> extends AsyncNotifier<PagedState<T>> {
  ApiResult<Paged<T>> fetchPage(int page);

  void watchInputs() {}

  @override
  Future<PagedState<T>> build() async {
    watchInputs();
    final first = await fetchPage(1).unwrap();
    return PagedState(items: first.items, page: 1, hasMore: first.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    final result = await fetchPage(current.page + 1);
    result.fold(
      // Keep what is on screen; the user can scroll again to retry.
      (_) => state = AsyncData(current.copyWith(loadingMore: false)),
      (next) => state = AsyncData(
        PagedState(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      ),
    );
  }
}
