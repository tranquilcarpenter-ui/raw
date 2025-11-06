import 'dart:async';
import 'package:flutter/foundation.dart';

/// Lightweight in-memory cache with TTL (Time To Live) support
///
/// TESTING-FRIENDLY: Short TTLs ensure you see recent data changes
/// while still reducing redundant Firebase queries during testing.
class CacheManager<T> {
  final Map<String, _CacheEntry<T>> _cache = {};
  final Map<String, Future<T?>> _pendingRequests = {};
  final Duration ttl;
  final String name;

  CacheManager({
    required this.name,
    this.ttl = const Duration(seconds: 30), // Short TTL for testing
  });

  /// Get cached value or null if expired/missing
  T? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      if (kDebugMode) {
        debugPrint('🔄 Cache[$name]: expired $key');
      }
      return null;
    }

    if (kDebugMode) {
      debugPrint('✅ Cache[$name]: hit $key');
    }
    return entry.value;
  }

  /// Store value in cache
  void set(String key, T value) {
    _cache[key] = _CacheEntry(value, DateTime.now().add(ttl));
    if (kDebugMode) {
      debugPrint('💾 Cache[$name]: stored $key (TTL: ${ttl.inSeconds}s)');
    }
  }

  /// Get value with deduplication - prevents multiple simultaneous requests
  ///
  /// If a request for this key is already pending, returns that future instead
  /// of starting a new request.
  Future<T?> getOrFetch(
    String key,
    Future<T?> Function() fetcher,
  ) async {
    // Check cache first
    final cached = get(key);
    if (cached != null) return cached;

    // Check if request is already pending
    if (_pendingRequests.containsKey(key)) {
      if (kDebugMode) {
        debugPrint('⏳ Cache[$name]: deduplicating request for $key');
      }
      return _pendingRequests[key];
    }

    // Start new request
    if (kDebugMode) {
      debugPrint('🔍 Cache[$name]: fetching $key');
    }

    final future = fetcher().then((value) {
      _pendingRequests.remove(key);
      if (value != null) {
        set(key, value);
      }
      return value;
    }).catchError((error) {
      _pendingRequests.remove(key);
      if (kDebugMode) {
        debugPrint('❌ Cache[$name]: fetch failed for $key - $error');
      }
      return null;
    });

    _pendingRequests[key] = future;
    return future;
  }

  /// Clear specific key
  void remove(String key) {
    _cache.remove(key);
    if (kDebugMode) {
      debugPrint('🗑️ Cache[$name]: removed $key');
    }
  }

  /// Clear all cached entries
  void clear() {
    final count = _cache.length;
    _cache.clear();
    _pendingRequests.clear();
    if (kDebugMode) {
      debugPrint('🗑️ Cache[$name]: cleared $count entries');
    }
  }

  /// Get cache statistics (useful for debugging)
  Map<String, dynamic> getStats() {
    return {
      'name': name,
      'size': _cache.length,
      'pending': _pendingRequests.length,
      'ttl_seconds': ttl.inSeconds,
    };
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  _CacheEntry(this.value, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
