import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/paged_notifier.dart';
import 'error_view.dart';

/// A pull-to-refresh, infinite-scroll `ListView.builder` over a
/// [PagedNotifier]'s state, with loading, error and empty states.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    required this.empty,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
  });

  final AsyncValue<PagedState<T>> value;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget empty;
  final EdgeInsetsGeometry padding;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.value.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(error: error, onRetry: widget.onRefresh),
      data: (page) {
        if (page.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: widget.empty,
                ),
              ),
            ),
          );
        }
        final extra = page.loadingMore ? 1 : 0;
        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView.separated(
            controller: _controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: widget.padding,
            itemCount: page.items.length + extra,
            separatorBuilder: (context, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= page.items.length) {
                return const Padding(
                  padding: EdgeInsetsDirectional.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return widget.itemBuilder(context, page.items[index]);
            },
          ),
        );
      },
    );
  }
}
