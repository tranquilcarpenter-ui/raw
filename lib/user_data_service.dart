import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
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
  /// If [merge] is true, merges with existing data. If false, replaces completely.
  Future<void> saveUserData(String userId, UserData userData, {bool merge = true}) async {
    try {
      debugPrint('💾 Saving data for user: $userId (merge: $merge)');
      debugPrint(
        '   Name: ${userData.fullName}, Streak: ${userData.dayStreak}, Hours: ${userData.focusHours}',
      );
      debugPrint('   Username: ${userData.username}');
      debugPrint('   AvatarUrl: ${userData.avatarUrl}');
      debugPrint('   BannerUrl: ${userData.bannerImageUrl}');
      final data = userData.toJson();
      debugPrint('   JSON fullName: ${data['fullName']}');
      debugPrint('   JSON username: ${data['username']}');
      debugPrint('   JSON avatarUrl: ${data['avatarUrl']}');
      debugPrint('   JSON bannerImageUrl: ${data['bannerImageUrl']}');

      if (merge) {
        await _getUserDoc(userId).set(data, SetOptions(merge: true));
      } else {
        await _getUserDoc(userId).set(data);
      }
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

  /// Compress image file to reduce size and improve performance
  /// Returns compressed file or original if compression fails
  Future<File> _compressImage(File file, {int quality = 85, int maxWidth = 1024}) async {
    try {
      debugPrint('🗜️ Compressing image: ${file.path}');
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxWidth,
      );

      if (result != null) {
        final originalSize = await file.length();
        final compressedSize = await result.length();
        final reduction = ((originalSize - compressedSize) / originalSize * 100).toStringAsFixed(1);
        debugPrint('✅ Image compressed: ${originalSize} -> ${compressedSize} bytes ($reduction% reduction)');
        return File(result.path);
      } else {
        debugPrint('⚠️ Compression returned null, using original image');
        return file;
      }
    } catch (e) {
      debugPrint('⚠️ Image compression failed, using original: $e');
      return file;
    }
  }

  /// Upload avatar image file to Firebase Storage and update user document
  /// Returns the download URL on success, or null on failure.
  /// Images are automatically compressed to max 512px and 85% quality
  Future<String?> uploadAvatarFile(String userId, File file) async {
    try {
      debugPrint('📤 Uploading avatar for user $userId');

      // Compress image before upload (avatars: 512px max, 85% quality)
      final compressedFile = await _compressImage(file, quality: 85, maxWidth: 512);

      final ref = FirebaseStorage.instance.ref().child(
        'users/$userId/avatar.jpg',
      );
      await ref.putFile(compressedFile);
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
  /// Images are automatically compressed to max 1920px and 85% quality
  Future<String?> uploadBannerFile(String userId, File file) async {
    try {
      debugPrint('📤 Uploading banner image for user $userId');

      // Compress image before upload (banners: 1920px max, 85% quality)
      final compressedFile = await _compressImage(file, quality: 85, maxWidth: 1920);

      final ref = FirebaseStorage.instance.ref().child(
        'users/$userId/banner.jpg',
      );
      await ref.putFile(compressedFile);
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
