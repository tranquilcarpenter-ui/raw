import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'user_data.dart';
import 'cache_manager.dart';

/// Service to manage unified user data in Firestore
/// Uses a single "users" collection containing both profile and statistics
///
/// PERFORMANCE: Uses caching with request deduplication to reduce Firebase reads
class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  static UserDataService get instance => _instance;

  factory UserDataService() => _instance;
  UserDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // PERFORMANCE: Cache user data to prevent redundant queries
  final _cache = CacheManager<UserData>(
    name: 'UserDataService',
    ttl: const Duration(seconds: 30), // Short TTL for testing
  );

  /// Connect to Firestore emulator
  void useEmulator(String host, int port) {
    _firestore.useFirestoreEmulator(host, port);
  }

  /// Get reference to user's document
  DocumentReference _getUserDoc(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  /// Load user data from Firestore
  /// Returns null if no data exists for the user
  ///
  /// PERFORMANCE: Uses cache + request deduplication to reduce Firebase reads
  Future<UserData?> loadUserData(String userId) async {
    return _cache.getOrFetch(userId, () async {
      try {
        if (kDebugMode) {
          debugPrint('📥 Loading data for user: $userId');
        }
        final docSnapshot = await _getUserDoc(userId).get();

        if (!docSnapshot.exists) {
          if (kDebugMode) {
            debugPrint('⚠️ No data found for user $userId');
          }
          return null;
        }

        final data = docSnapshot.data() as Map<String, dynamic>?;
        if (data == null) {
          if (kDebugMode) {
            debugPrint('⚠️ User data is null for user $userId');
          }
          return null;
        }

        if (kDebugMode) {
          debugPrint('✅ Successfully loaded data for user $userId');
          debugPrint(
            '   Name: ${data['fullName']}, Streak: ${data['dayStreak']}, Hours: ${data['focusHours']}',
          );
          debugPrint('   JSON avatarUrl: ${data['avatarUrl']}');
          debugPrint('   JSON bannerImageUrl: ${data['bannerImageUrl']}');
        }
        final userData = UserData.fromJson(data);
        if (kDebugMode) {
          debugPrint('   Parsed avatarUrl: ${userData.avatarUrl}');
          debugPrint('   Parsed bannerImageUrl: ${userData.bannerImageUrl}');
        }
        return userData;
      } catch (e, st) {
        debugPrint('❌ Error loading data for user $userId: $e');
        if (kDebugMode) {
          debugPrint('$st');
        }
        return null;
      }
    });
  }

  /// Save user data to Firestore
  /// If [merge] is true, merges with existing data. If false, replaces completely.
  ///
  /// PERFORMANCE: Invalidates cache after save to ensure next read gets fresh data
  Future<void> saveUserData(String userId, UserData userData, {bool merge = true}) async {
    try {
      if (kDebugMode) {
        debugPrint('💾 Saving data for user: $userId (merge: $merge)');
        debugPrint(
          '   Name: ${userData.fullName}, Streak: ${userData.dayStreak}, Hours: ${userData.focusHours}',
        );
        debugPrint('   Username: ${userData.username}');
        debugPrint('   AvatarUrl: ${userData.avatarUrl}');
        debugPrint('   BannerUrl: ${userData.bannerImageUrl}');
      }
      final data = userData.toJson();
      if (kDebugMode) {
        debugPrint('   JSON fullName: ${data['fullName']}');
        debugPrint('   JSON username: ${data['username']}');
        debugPrint('   JSON avatarUrl: ${data['avatarUrl']}');
        debugPrint('   JSON bannerImageUrl: ${data['bannerImageUrl']}');
      }

      if (merge) {
        await _getUserDoc(userId).set(data, SetOptions(merge: true));
      } else {
        await _getUserDoc(userId).set(data);
      }

      // PERFORMANCE: Invalidate cache after save
      _cache.remove(userId);

      if (kDebugMode) {
        debugPrint('✅ Successfully saved data for user $userId to Firestore');
      }
    } catch (e, st) {
      debugPrint('❌ Error saving data for user $userId: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      rethrow;
    }
  }

  /// Delete user data from Firestore
  ///
  /// PERFORMANCE: Invalidates cache after delete
  Future<void> deleteUserData(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑️ Deleting data for user: $userId');
      }
      await _getUserDoc(userId).delete();

      // PERFORMANCE: Invalidate cache after delete
      _cache.remove(userId);

      if (kDebugMode) {
        debugPrint('✅ Successfully deleted data for user $userId');
      }
    } catch (e, st) {
      debugPrint('❌ Error deleting data for user $userId: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      rethrow;
    }
  }

  /// Stream of user data (for real-time updates)
  Stream<UserData?> streamUserData(String userId) {
    return _getUserDoc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserData.fromJson(snapshot.data() as Map<String, dynamic>);
    });
  }

  /// Upload avatar image file to Firebase Storage and update user document
  /// Returns the download URL on success, or null on failure.
  ///
  /// PERFORMANCE: Invalidates cache after upload
  Future<String?> uploadAvatarFile(String userId, File file) async {
    try {
      if (kDebugMode) {
        debugPrint('📤 Uploading avatar for user $userId');
      }
      final ref = FirebaseStorage.instance.ref().child(
        'users/$userId/avatar.jpg',
      );
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      if (kDebugMode) {
        debugPrint('✅ Avatar uploaded, download URL: $downloadUrl');
      }

      // Save URL to Firestore user doc
      await _getUserDoc(
        userId,
      ).set({'avatarUrl': downloadUrl}, SetOptions(merge: true));

      // PERFORMANCE: Invalidate cache after upload
      _cache.remove(userId);

      if (kDebugMode) {
        debugPrint('✅ Saved avatarUrl to Firestore for user $userId');
      }
      return downloadUrl;
    } catch (e, st) {
      debugPrint('❌ Failed to upload avatar for $userId: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      return null;
    }
  }

  /// Upload banner image file to Firebase Storage and update user document
  ///
  /// PERFORMANCE: Invalidates cache after upload
  Future<String?> uploadBannerFile(String userId, File file) async {
    try {
      if (kDebugMode) {
        debugPrint('📤 Uploading banner image for user $userId');
      }
      final ref = FirebaseStorage.instance.ref().child(
        'users/$userId/banner.jpg',
      );
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      if (kDebugMode) {
        debugPrint('✅ Banner uploaded, download URL: $downloadUrl');
      }

      // Save URL to Firestore user doc
      await _getUserDoc(
        userId,
      ).set({'bannerImageUrl': downloadUrl}, SetOptions(merge: true));

      // PERFORMANCE: Invalidate cache after upload
      _cache.remove(userId);

      if (kDebugMode) {
        debugPrint('✅ Saved bannerImageUrl to Firestore for user $userId');
      }
      return downloadUrl;
    } catch (e, st) {
      debugPrint('❌ Failed to upload banner for $userId: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      return null;
    }
  }

  /// Get cache statistics (useful for debugging performance)
  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }

  /// Clear cache for specific user
  void invalidateCache(String userId) {
    _cache.remove(userId);
  }

  /// Clear all cached user data
  void clearCache() {
    _cache.clear();
  }
}

