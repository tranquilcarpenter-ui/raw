import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

/// Helper utilities for optimized image loading and caching
///
/// PERFORMANCE: Provides consistent image loading with proper cache configuration
class ImageCacheHelper {
  /// Helper to safely convert dimension to int, returns null if invalid
  static int? safeDimensionToInt(double? value, double multiplier) {
    if (value == null) return null;
    final result = value * multiplier;
    // Sanity checks: must be finite, positive, and reasonable size
    if (!result.isFinite || result <= 0 || result > 10000) return null;
    return result.round();
  }

  /// Build optimized image widget from either local file or network URL
  ///
  /// PERFORMANCE:
  /// - Uses CachedNetworkImage for network images (memory + disk cache)
  /// - Optimizes cache dimensions to reduce memory footprint
  /// - Uses Image.file for local paths with cache dimensions
  static Widget buildImageFromPath(
    String imagePath, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Alignment alignment = Alignment.center,
    Widget? errorWidget,
    Widget? placeholder,
  }) {
    final isNetworkImage =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');

    if (isNetworkImage) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        placeholder: (context, url) =>
            placeholder ??
            Container(
              width: width,
              height: height,
              color: const Color(0xFF2C2C2E),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                  ),
                ),
              ),
            ),
        errorWidget: (context, url, error) =>
            errorWidget ?? const Icon(Icons.error),
        // PERFORMANCE: Cache dimensions to reduce memory usage
        memCacheWidth: safeDimensionToInt(width, 2),
        memCacheHeight: safeDimensionToInt(height, 2),
        maxWidthDiskCache: safeDimensionToInt(width, 3),
        maxHeightDiskCache: safeDimensionToInt(height, 3),
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        // PERFORMANCE: Cache width/height to reduce decoding overhead
        cacheWidth: safeDimensionToInt(width, 2),
        cacheHeight: safeDimensionToInt(height, 2),
        errorBuilder: errorWidget != null
            ? (context, error, stackTrace) => errorWidget
            : null,
      );
    }
  }

  /// Preload network images into cache
  ///
  /// PERFORMANCE: Call this before navigating to a screen with many images
  static Future<void> preloadNetworkImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    if (!kDebugMode) {
      // Only log in debug mode
      return Future.wait(
        imageUrls
            .where((url) => url.startsWith('http'))
            .map((url) => precacheImage(CachedNetworkImageProvider(url), context))
            .toList(),
      );
    }

    debugPrint('🖼️ Preloading ${imageUrls.length} images...');
    final stopwatch = Stopwatch()..start();

    try {
      await Future.wait(
        imageUrls
            .where((url) => url.startsWith('http'))
            .map((url) => precacheImage(CachedNetworkImageProvider(url), context))
            .toList(),
      );

      debugPrint(
        '✅ Preloaded ${imageUrls.length} images in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      debugPrint('⚠️ Error preloading images: $e');
    }
  }

  /// Preload a single image
  static Future<void> preloadImage(BuildContext context, String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return precacheImage(CachedNetworkImageProvider(imageUrl), context);
    }
    return Future.value();
  }

  /// Clear image cache (useful for testing or freeing memory)
  static Future<void> clearCache() async {
    await CachedNetworkImage.evictFromCache('');
    if (kDebugMode) {
      debugPrint('🗑️ Cleared image cache');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    // CachedNetworkImage doesn't expose cache stats directly
    // This is a placeholder for future enhancement
    return {
      'info': 'Cache stats not available in current CachedNetworkImage version',
    };
  }
}

/// Extension for convenient image preloading
extension ImagePreloadExtension on BuildContext {
  /// Preload images before they're needed
  Future<void> preloadImages(List<String> imageUrls) {
    return ImageCacheHelper.preloadNetworkImages(this, imageUrls);
  }

  /// Preload a single image
  Future<void> preloadImage(String imageUrl) {
    return ImageCacheHelper.preloadImage(this, imageUrl);
  }
}
