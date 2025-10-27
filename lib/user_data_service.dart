import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'user_data.dart';

/// Service to manage unified user data in Firestore
/// Uses a single "users" collection containing both profile and statistics
class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  static UserDataService get instance => _instance;

  factory UserDataService() => _instance;
  UserDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  Future<UserData?> loadUserData(String userId) async {
    try {
      debugPrint('📥 Loading data for user: $userId');
      final docSnapshot = await _getUserDoc(userId).get();

      if (!docSnapshot.exists) {
        debugPrint('⚠️ No data found for user $userId');
        return null;
      }

      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('⚠️ User data is null for user $userId');
        return null;
      }

      debugPrint('✅ Successfully loaded data for user $userId');
      debugPrint(
        '   Name: ${data['fullName']}, Streak: ${data['dayStreak']}, Hours: ${data['focusHours']}',
      );
      debugPrint('   JSON avatarUrl: ${data['avatarUrl']}');
      debugPrint('   JSON bannerImageUrl: ${data['bannerImageUrl']}');
      final userData = UserData.fromJson(data);
      debugPrint('   Parsed avatarUrl: ${userData.avatarUrl}');
      debugPrint('   Parsed bannerImageUrl: ${userData.bannerImageUrl}');
      return userData;
    } catch (e, st) {
      debugPrint('❌ Error loading data for user $userId: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Save user data to Firestore
  Future<void> saveUserData(String userId, UserData userData) async {
    try {
      debugPrint('💾 Saving data for user: $userId');
      debugPrint(
        '   Name: ${userData.fullName}, Streak: ${userData.dayStreak}, Hours: ${userData.focusHours}',
      );
      debugPrint('   AvatarUrl: ${userData.avatarUrl}');
      debugPrint('   BannerUrl: ${userData.bannerImageUrl}');
      final data = userData.toJson();
      debugPrint('   JSON avatarUrl: ${data['avatarUrl']}');
      debugPrint('   JSON bannerImageUrl: ${data['bannerImageUrl']}');
      await _getUserDoc(userId).set(data, SetOptions(merge: true));
      debugPrint('✅ Successfully saved data for user $userId to Firestore');
    } catch (e, st) {
      debugPrint('❌ Error saving data for user $userId: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Delete user data from Firestore
  Future<void> deleteUserData(String userId) async {
    try {
      debugPrint('🗑️ Deleting data for user: $userId');
      await _getUserDoc(userId).delete();
      debugPrint('✅ Successfully deleted data for user $userId');
    } catch (e, st) {
      debugPrint('❌ Error deleting data for user $userId: $e');
      debugPrint('$st');
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
  Future<String?> uploadAvatarFile(String userId, File file) async {
    try {
      debugPrint('📤 Uploading avatar for user $userId');
      final ref = FirebaseStorage.instance.ref().child(
        'users/$userId/avatar.jpg',
      );
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('✅ Avatar uploaded, download URL: $downloadUrl');

      // Save URL to Firestore user doc
      await _getUserDoc(
        userId,
      ).set({'avatarUrl': downloadUrl}, SetOptions(merge: true));
      debugPrint('✅ Saved avatarUrl to Firestore for user $userId');
      return downloadUrl;
    } catch (e, st) {
      debugPrint('❌ Failed to upload avatar for $userId: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Upload banner image file to Firebase Storage and update user document
  Future<String?> uploadBannerFile(String userId, File file) async {
    try {
      debugPrint('📤 Uploading banner image for user $userId');
      final ref = FirebaseStorage.instance.ref().child(
        'users/$userId/banner.jpg',
      );
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('✅ Banner uploaded, download URL: $downloadUrl');

      // Save URL to Firestore user doc
      await _getUserDoc(
        userId,
      ).set({'bannerImageUrl': downloadUrl}, SetOptions(merge: true));
      debugPrint('✅ Saved bannerImageUrl to Firestore for user $userId');
      return downloadUrl;
    } catch (e, st) {
      debugPrint('❌ Failed to upload banner for $userId: $e');
      debugPrint('$st');
      return null;
    }
  }
}
