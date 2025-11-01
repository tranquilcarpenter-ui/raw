import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'friend.dart';
import 'user_data.dart';

/// Service to manage friends in Firestore
/// Stores friendships as subcollections under each user
class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  static FriendsService get instance => _instance;

  factory FriendsService() => _instance;
  FriendsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get reference to user's friends collection
  CollectionReference _getFriendsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('friends');
  }

  /// Get list of user IDs that are already connected (friends or pending requests)
  Future<Set<String>> getExistingConnectionIds(String userId) async {
    try {
      final querySnapshot = await _getFriendsCollection(userId).get();
      return querySnapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      debugPrint('❌ Error getting existing connections: $e');
      return {};
    }
  }

  /// Search for users by username
  /// Returns map of userId -> UserData
  Future<Map<String, UserData>> searchUsersByName(String query) async {
    try {
      debugPrint('🔍 Searching for users with username: $query');

      if (query.trim().isEmpty) {
        return {};
      }

      // Convert query to lowercase for case-insensitive search
      final lowercaseQuery = query.trim().toLowerCase();

      // Query users collection by username
      // Note: Firestore doesn't support full-text search natively
      // This searches for exact matches or prefixes
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('username', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .limit(10)
          .get();

      final users = <String, UserData>{};
      for (final doc in querySnapshot.docs) {
        final userData = UserData.fromJson(doc.data());
        // Only include users who have a username set
        if (userData.username != null && userData.username!.isNotEmpty) {
          users[doc.id] = userData;
        }
      }

      debugPrint('✅ Found ${users.length} users');
      return users;
    } catch (e, st) {
      debugPrint('❌ Error searching users: $e');
      debugPrint('$st');
      return {};
    }
  }

  /// Search for user by exact user ID
  Future<UserData?> getUserById(String userId) async {
    try {
      debugPrint('🔍 Searching for user with ID: $userId');

      final docSnapshot = await _firestore.collection('users').doc(userId).get();

      if (!docSnapshot.exists) {
        debugPrint('⚠️ User not found with ID: $userId');
        return null;
      }

      final userData = UserData.fromJson(docSnapshot.data()!);
      debugPrint('✅ Found user: ${userData.fullName}');
      return userData;
    } catch (e, st) {
      debugPrint('❌ Error getting user by ID: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Send a friend request
  Future<bool> sendFriendRequest(String currentUserId, String friendUserId) async {
    try {
      debugPrint('📤 Sending friend request: $currentUserId -> $friendUserId');

      // Don't allow adding yourself as a friend
      if (currentUserId == friendUserId) {
        debugPrint('⚠️ Cannot add yourself as a friend');
        return false;
      }

      // Check if already friends or request exists
      final existingFriend = await _getFriendsCollection(currentUserId)
          .doc(friendUserId)
          .get();

      if (existingFriend.exists) {
        debugPrint('⚠️ Friend request already exists or already friends');
        return false;
      }

      // Get friend's data
      final friendData = await getUserById(friendUserId);
      if (friendData == null) {
        debugPrint('❌ Friend user not found');
        return false;
      }

      // Get current user's data
      final currentUserData = await getUserById(currentUserId);
      if (currentUserData == null) {
        debugPrint('❌ Current user not found');
        return false;
      }

      final now = DateTime.now();

      // Create pending request for current user (outgoing request)
      final outgoingRequest = Friend(
        userId: friendUserId,
        fullName: friendData.fullName,
        avatarUrl: friendData.avatarUrl,
        addedAt: now,
        focusHours: friendData.focusHours,
        focusHoursMonth: friendData.focusHoursThisMonth,
        dayStreak: friendData.dayStreak,
        rankPercentage: friendData.rankPercentage,
        status: FriendRequestStatus.pending,
        isRequester: true, // Current user sent the request
      );

      // Create pending request for friend (incoming request)
      final incomingRequest = Friend(
        userId: currentUserId,
        fullName: currentUserData.fullName,
        avatarUrl: currentUserData.avatarUrl,
        addedAt: now,
        focusHours: currentUserData.focusHours,
        focusHoursMonth: currentUserData.focusHoursThisMonth,
        dayStreak: currentUserData.dayStreak,
        rankPercentage: currentUserData.rankPercentage,
        status: FriendRequestStatus.pending,
        isRequester: false, // Friend received the request
      );

      // Add to both users' friends collections
      await _getFriendsCollection(currentUserId)
          .doc(friendUserId)
          .set(outgoingRequest.toJson());

      await _getFriendsCollection(friendUserId)
          .doc(currentUserId)
          .set(incomingRequest.toJson());

      debugPrint('✅ Friend request sent successfully');
      return true;
    } catch (e, st) {
      debugPrint('❌ Error sending friend request: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String currentUserId, String friendUserId) async {
    try {
      debugPrint('✅ Accepting friend request: $currentUserId <- $friendUserId');

      // Update both documents to accepted status
      await _getFriendsCollection(currentUserId)
          .doc(friendUserId)
          .update({'status': FriendRequestStatus.accepted.name});

      await _getFriendsCollection(friendUserId)
          .doc(currentUserId)
          .update({'status': FriendRequestStatus.accepted.name});

      debugPrint('✅ Friend request accepted');
      return true;
    } catch (e, st) {
      debugPrint('❌ Error accepting friend request: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest(String currentUserId, String friendUserId) async {
    try {
      debugPrint('❌ Rejecting friend request: $currentUserId <- $friendUserId');

      // Delete both documents (remove the request entirely)
      await _getFriendsCollection(currentUserId).doc(friendUserId).delete();
      await _getFriendsCollection(friendUserId).doc(currentUserId).delete();

      debugPrint('✅ Friend request rejected and removed');
      return true;
    } catch (e, st) {
      debugPrint('❌ Error rejecting friend request: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Remove a friend (removes from both users' collections)
  Future<bool> removeFriend(String currentUserId, String friendUserId) async {
    try {
      debugPrint('👥 Removing friend: $currentUserId -> $friendUserId');

      // Remove from both users' collections
      await _getFriendsCollection(currentUserId).doc(friendUserId).delete();
      await _getFriendsCollection(friendUserId).doc(currentUserId).delete();

      debugPrint('✅ Friend removed successfully');
      return true;
    } catch (e, st) {
      debugPrint('❌ Error removing friend: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Get list of user's accepted friends only
  Future<List<Friend>> getFriends(String userId) async {
    try {
      debugPrint('📥 Loading friends for user: $userId');

      final querySnapshot = await _getFriendsCollection(userId)
          .where('status', isEqualTo: FriendRequestStatus.accepted.name)
          .get();

      final friends = <Friend>[];

      // Fetch live statistics for each friend
      for (final doc in querySnapshot.docs) {
        final friendData = Friend.fromJson(doc.data() as Map<String, dynamic>);

        // Fetch current user data to get latest statistics
        try {
          final userData = await getUserById(friendData.userId);
          if (userData != null) {
            // Update friend with live statistics (including monthly hours)
            friends.add(friendData.copyWith(
              fullName: userData.fullName,
              avatarUrl: userData.avatarUrl,
              focusHours: userData.focusHours,
              focusHoursMonth: userData.focusHoursThisMonth,
              dayStreak: userData.dayStreak,
              rankPercentage: userData.rankPercentage,
            ));
          } else {
            // Use cached data if user not found
            friends.add(friendData);
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching stats for friend ${friendData.userId}: $e');
          // Use cached data if stats fetch fails
          friends.add(friendData);
        }
      }

      // Sort by focus hours (all time, descending)
      friends.sort((a, b) => b.focusHours.compareTo(a.focusHours));

      debugPrint('✅ Loaded ${friends.length} accepted friends with live stats');
      return friends;
    } catch (e, st) {
      debugPrint('❌ Error loading friends: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Get list of pending friend requests (incoming requests that need to be accepted/rejected)
  Future<List<Friend>> getPendingRequests(String userId) async {
    try {
      debugPrint('📥 Loading pending friend requests for user: $userId');

      final querySnapshot = await _getFriendsCollection(userId)
          .where('status', isEqualTo: FriendRequestStatus.pending.name)
          .where('isRequester', isEqualTo: false) // Incoming requests only
          .get();

      final requests = querySnapshot.docs
          .map((doc) => Friend.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Sort by date (most recent first)
      requests.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      debugPrint('✅ Loaded ${requests.length} pending requests');
      return requests;
    } catch (e, st) {
      debugPrint('❌ Error loading pending requests: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Get list of outgoing friend requests (requests sent by this user)
  Future<List<Friend>> getOutgoingRequests(String userId) async {
    try {
      debugPrint('📥 Loading outgoing friend requests for user: $userId');

      final querySnapshot = await _getFriendsCollection(userId)
          .where('status', isEqualTo: FriendRequestStatus.pending.name)
          .where('isRequester', isEqualTo: true) // Outgoing requests only
          .get();

      final requests = querySnapshot.docs
          .map((doc) => Friend.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Sort by date (most recent first)
      requests.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      debugPrint('✅ Loaded ${requests.length} outgoing requests');
      return requests;
    } catch (e, st) {
      debugPrint('❌ Error loading outgoing requests: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Stream of user's friends (real-time updates)
  Stream<List<Friend>> streamFriends(String userId) {
    return _getFriendsCollection(userId).snapshots().map((snapshot) {
      final friends = snapshot.docs
          .map((doc) => Friend.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Sort by focus hours (descending)
      friends.sort((a, b) => b.focusHours.compareTo(a.focusHours));

      return friends;
    });
  }

  /// Update friend's stats (called when user's stats change)
  /// This keeps friend data in sync across all users who have them as a friend
  Future<void> updateFriendStats(
    String userId,
    String fullName,
    String? avatarUrl,
    int focusHours,
    int dayStreak,
    String? rankPercentage,
  ) async {
    try {
      debugPrint('🔄 Updating friend stats for user: $userId');

      // Get all users who have this user as a friend
      final usersSnapshot = await _firestore.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final friendDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('friends')
            .doc(userId)
            .get();

        if (friendDoc.exists) {
          // Update this friend's data in their collection
          await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('friends')
              .doc(userId)
              .update({
            'fullName': fullName,
            'avatarUrl': avatarUrl,
            'focusHours': focusHours,
            'dayStreak': dayStreak,
            'rankPercentage': rankPercentage,
          });
        }
      }

      debugPrint('✅ Friend stats updated');
    } catch (e, st) {
      debugPrint('❌ Error updating friend stats: $e');
      debugPrint('$st');
    }
  }
}
