import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_profile.dart';

/// Service to manage user profiles in Firestore
class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  static UserProfileService get instance => _instance;

  factory UserProfileService() => _instance;
  UserProfileService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Connect to Firestore emulator
  void useEmulator(String host, int port) {
    _firestore.useFirestoreEmulator(host, port);
  }

  /// Get reference to user's profile document
  DocumentReference _getUserProfileDoc(String userId) {
    return _firestore.collection('user_profiles').doc(userId);
  }

  /// Load user profile from Firestore
  /// Returns null if no profile exists for the user
  Future<UserProfile?> loadUserProfile(String userId) async {
    try {
      debugPrint('📥 Loading profile for user: $userId');
      final docSnapshot = await _getUserProfileDoc(userId).get();

      if (!docSnapshot.exists) {
        debugPrint('⚠️ No profile found for user $userId');
        return null;
      }

      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('⚠️ Profile data is null for user $userId');
        return null;
      }

      debugPrint('✅ Successfully loaded profile for user $userId');
      return UserProfile.fromJson(data);
    } catch (e, st) {
      debugPrint('❌ Error loading profile for user $userId: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Save user profile to Firestore
  Future<void> saveUserProfile(String userId, UserProfile profile) async {
    try {
      debugPrint('💾 Saving profile for user: $userId');
      debugPrint('   Name: ${profile.fullName}');
      final data = profile.toJson();
      await _getUserProfileDoc(userId).set(data, SetOptions(merge: true));
      debugPrint('✅ Successfully saved profile for user $userId to Firestore');
    } catch (e, st) {
      debugPrint('❌ Error saving profile for user $userId: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Delete user profile from Firestore
  Future<void> deleteUserProfile(String userId) async {
    try {
      debugPrint('🗑️ Deleting profile for user: $userId');
      await _getUserProfileDoc(userId).delete();
      debugPrint('✅ Successfully deleted profile for user $userId');
    } catch (e, st) {
      debugPrint('❌ Error deleting profile for user $userId: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding(String userId) async {
    final profile = await loadUserProfile(userId);
    return profile?.onboardingCompleted ?? false;
  }

  /// Stream of user profile (for real-time updates)
  Stream<UserProfile?> streamUserProfile(String userId) {
    return _getUserProfileDoc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserProfile.fromJson(snapshot.data() as Map<String, dynamic>);
    });
  }
}
