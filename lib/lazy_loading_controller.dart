import 'package:flutter/material.dart';
import 'dart:async';

/// Lazy loading controller for paginated lists
///
/// PERFORMANCE: Load data incrementally instead of all at once
/// - Reduces initial load time
/// - Decreases memory usage
/// - Better perceived performance
class LazyLoadingController<T> {
  final Future<List<T>> Function(int page, int pageSize) fetchPage;
  final int pageSize;
  final VoidCallback? onLoadingChanged;

  LazyLoadingController({
    required this.fetchPage,
    this.pageSize = 20,
    this.onLoadingChanged,
  });

  final List<T> _items = [];
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty && !_isLoading;

  /// Load the first page (initial load)
  Future<void> loadInitial() async {
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _error = null;
    await loadMore();
  }

  /// Load the next page
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    onLoadingChanged?.call();

    try {
      final newItems = await fetchPage(_currentPage, pageSize);

      _items.addAll(newItems);
      _currentPage++;
      _hasMore = newItems.length >= pageSize;

      if (newItems.isEmpty && _currentPage == 0) {
        _hasMore = false;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ LazyLoadingController error: $e');
    } finally {
      _isLoading = false;
      onLoadingChanged?.call();
    }
  }

  /// Refresh the list (pull-to-refresh)
  Future<void> refresh() async {
    await loadInitial();
  }

  /// Clear all data
  void clear() {
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _isLoading = false;
    _error = null;
  }

  /// Add a single item (e.g., after creating new item)
  void addItem(T item) {
    _items.insert(0, item);
  }

  /// Remove a single item (e.g., after deletion)
  void removeItem(T item) {
    _items.remove(item);
  }

  /// Update an item
  void updateItem(T oldItem, T newItem) {
    final index = _items.indexOf(oldItem);
    if (index != -1) {
      _items[index] = newItem;
    }
  }
}

/// Stateful widget for lazy loading lists
///
/// PERFORMANCE: Automatically handles pagination and scroll detection
class LazyLoadingListView<T> extends StatefulWidget {
  final LazyLoadingController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final double loadMoreThreshold;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const LazyLoadingListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.loadMoreThreshold = 200.0,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<LazyLoadingListView<T>> createState() =>
      _LazyLoadingListViewState<T>();
}

class _LazyLoadingListViewState<T> extends State<LazyLoadingListView<T>> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.controller.items.isEmpty) {
        widget.controller.loadInitial();
      }
    });

    // Listen to controller changes
    widget.controller.onLoadingChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent -
            widget.loadMoreThreshold) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    // Empty state
    if (controller.isEmpty && !controller.isLoading) {
      return widget.emptyWidget ??
          const Center(
            child: Text(
              'No items',
              style: TextStyle(color: Colors.grey),
            ),
          );
    }

    // Error state (with existing items)
    if (controller.error != null && controller.items.isEmpty) {
      return widget.errorWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: ${controller.error}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        itemCount: controller.items.length + (controller.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Loading indicator at the end
          if (index >= controller.items.length) {
            return widget.loadingWidget ??
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
          }

          // PERFORMANCE: Add key for efficient widget reuse
          return widget.itemBuilder(
            context,
            controller.items[index],
            index,
          );
        },
      ),
    );
  }
}

/// Extension for easy pagination
extension ListPaginationExtension<T> on List<T> {
  /// Get a page of items
  List<T> getPage(int page, int pageSize) {
    final start = page * pageSize;
    if (start >= length) return [];

    final end = (start + pageSize).clamp(0, length);
    return sublist(start, end);
  }
}
