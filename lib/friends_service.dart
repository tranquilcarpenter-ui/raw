import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'friend.dart';
import 'user_data.dart';

/// Constants for friends service
class FriendsServiceConstants {
  // Search validation
  static const int searchQueryMinLength = 2;
  static const int searchQueryMaxLength = 50;
  static const int searchResultsLimit = 10;

  // User ID validation (Firebase Auth UIDs)
  static const int userIdMinLength = 20;
  static const int userIdMaxLength = 40;

  // Rate limiting
  static const int maxFriendRequestsPerHour = 10;
  static const Duration rateLimitWindow = Duration(hours: 1);

  // Batch processing
  static const int firestoreBatchSize = 10; // Firestore whereIn/getAll limit
}

/// Result class for friend request operations
class FriendRequestResult {
  final bool success;
  final String? errorMessage;

  FriendRequestResult({required this.success, this.errorMessage});

  factory FriendRequestResult.success() => FriendRequestResult(success: true);
  factory FriendRequestResult.failure(String message) =>
      FriendRequestResult(success: false, errorMessage: message);
}

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

  /// Search for users by username with input validation
  ///
  /// Performs a case-insensitive prefix search on usernames in Firestore.
  /// Includes comprehensive input validation to prevent injection attacks
  /// and performance issues.
  ///
  /// **Validation Rules:**
  /// - Minimum length: 2 characters
  /// - Maximum length: 50 characters
  /// - Allowed characters: alphanumeric, spaces, dots, underscores, hyphens
  ///
  /// **Security Features:**
  /// - Input sanitization to prevent injection attacks
  /// - Length validation to prevent performance degradation
  /// - Character whitelist to block malicious input
  ///
  /// **Parameters:**
  /// - [query]: Username search query (case-insensitive)
  ///
  /// **Returns:**
  /// - Map of userId to UserData for matching users (max 10 results)
  /// - Empty map if validation fails or no matches found
  ///
  /// **Example:**
  /// ```dart
  /// final results = await searchUsersByName('john');
  /// results.forEach((userId, userData) {
  ///   print('Found: ${userData.fullName} (@${userData.username})');
  /// });
  /// ```
  Future<Map<String, UserData>> searchUsersByName(String query) async {
    try {
      debugPrint('🔍 Searching for users with username: $query');

      // Input validation
      final sanitizedQuery = query.trim();

      if (sanitizedQuery.isEmpty) {
        return {};
      }

      // Validate length to prevent performance issues
      if (sanitizedQuery.length < FriendsServiceConstants.searchQueryMinLength) {
        debugPrint('⚠️ Query too short (minimum ${FriendsServiceConstants.searchQueryMinLength} characters)');
        return {};
      }

      if (sanitizedQuery.length > FriendsServiceConstants.searchQueryMaxLength) {
        debugPrint('⚠️ Query too long (maximum ${FriendsServiceConstants.searchQueryMaxLength} characters)');
        return {};
      }

      // Sanitize input: remove potentially dangerous characters
      // Allow only alphanumeric, spaces, and common safe characters
      final sanitizedPattern = RegExp(r'^[a-zA-Z0-9\s._-]+$');
      if (!sanitizedPattern.hasMatch(sanitizedQuery)) {
        debugPrint('⚠️ Query contains invalid characters');
        return {};
      }

      // Convert query to lowercase for case-insensitive search
      final lowercaseQuery = sanitizedQuery.toLowerCase();

      // Query users collection by username
      // Note: Firestore doesn't support full-text search natively
      // This searches for exact matches or prefixes
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('username', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .limit(FriendsServiceConstants.searchResultsLimit)
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

      // Input validation for userId
      final sanitizedUserId = userId.trim();

      if (sanitizedUserId.isEmpty) {
        debugPrint('⚠️ User ID is empty');
        return null;
      }

      // Validate userId format (Firebase UIDs are typically 28 chars, alphanumeric)
      // Allow reasonable length for Firebase Auth UIDs
      if (sanitizedUserId.length < FriendsServiceConstants.userIdMinLength ||
          sanitizedUserId.length > FriendsServiceConstants.userIdMaxLength) {
        debugPrint('⚠️ User ID has invalid length (expected ${FriendsServiceConstants.userIdMinLength}-${FriendsServiceConstants.userIdMaxLength} characters)');
        return null;
      }

      // Validate that userId contains only safe characters (alphanumeric and hyphens)
      final userIdPattern = RegExp(r'^[a-zA-Z0-9-_]+$');
      if (!userIdPattern.hasMatch(sanitizedUserId)) {
        debugPrint('⚠️ User ID contains invalid characters');
        return null;
      }

      final docSnapshot = await _firestore.collection('users').doc(sanitizedUserId).get();

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

  /// Send a friend request with rate limiting and validation
  ///
  /// Creates a pending friend request between two users. Includes
  /// comprehensive validation and rate limiting to prevent spam.
  ///
  /// **Validation Checks:**
  /// - Prevents self-friending
  /// - Rate limit: Maximum 10 requests per hour
  /// - Prevents duplicate requests
  /// - Validates both users exist
  ///
  /// **Rate Limiting:**
  /// - Tracks requests sent in the last hour
  /// - Returns specific error message when limit exceeded
  /// - Helps prevent spam and abuse
  ///
  /// **Parameters:**
  /// - [currentUserId]: ID of user sending the request
  /// - [friendUserId]: ID of user to send request to
  ///
  /// **Returns:**
  /// - [FriendRequestResult] with success status and optional error message
  ///
  /// **Possible Failures:**
  /// - Self-friending attempt
  /// - Rate limit exceeded (10/hour)
  /// - Request already exists
  /// - User not found
  /// - Firestore error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await sendFriendRequest(myUserId, friendUserId);
  /// if (result.success) {
  ///   print('Friend request sent!');
  /// } else {
  ///   print('Error: ${result.errorMessage}');
  /// }
  /// ```
  Future<FriendRequestResult> sendFriendRequest(String currentUserId, String friendUserId) async {
    try {
      debugPrint('📤 Sending friend request: $currentUserId -> $friendUserId');

      // Don't allow adding yourself as a friend
      if (currentUserId == friendUserId) {
        debugPrint('⚠️ Cannot add yourself as a friend');
        return FriendRequestResult.failure('You cannot add yourself as a friend');
      }

      // Rate limiting: Check recent friend requests
      final rateLimitStart = DateTime.now().subtract(FriendsServiceConstants.rateLimitWindow);
      final recentRequestsQuery = await _getFriendsCollection(currentUserId)
          .where('addedAt', isGreaterThan: Timestamp.fromDate(rateLimitStart))
          .where('isRequester', isEqualTo: true)
          .get();

      if (recentRequestsQuery.docs.length >= FriendsServiceConstants.maxFriendRequestsPerHour) {
        debugPrint('⚠️ Rate limit exceeded: ${recentRequestsQuery.docs.length} requests in the last hour');
        return FriendRequestResult.failure('Too many requests. Please wait an hour before sending more friend requests (limit: ${FriendsServiceConstants.maxFriendRequestsPerHour}/hour)');
      }

      // Check if already friends or request exists
      final existingFriend = await _getFriendsCollection(currentUserId)
          .doc(friendUserId)
          .get();

      if (existingFriend.exists) {
        debugPrint('⚠️ Friend request already exists or already friends');
        return FriendRequestResult.failure('Friend request already exists or you are already friends');
      }

      // Get friend's data
      final friendData = await getUserById(friendUserId);
      if (friendData == null) {
        debugPrint('❌ Friend user not found');
        return FriendRequestResult.failure('User not found');
      }

      // Get current user's data
      final currentUserData = await getUserById(currentUserId);
      if (currentUserData == null) {
        debugPrint('❌ Current user not found');
        return FriendRequestResult.failure('Your user data could not be loaded');
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
      return FriendRequestResult.success();
    } catch (e, st) {
      debugPrint('❌ Error sending friend request: $e');
      debugPrint('$st');
      return FriendRequestResult.failure('An error occurred while sending the friend request');
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

      final friendDataList = querySnapshot.docs
          .map((doc) => Friend.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      if (friendDataList.isEmpty) {
        debugPrint('✅ No friends found');
        return [];
      }

      // Batch fetch user data to avoid N+1 queries
      final userIds = friendDataList.map((f) => f.userId).toList();
      final userDataMap = await _batchGetUsers(userIds);

      final friends = <Friend>[];

      // Update friend data with live statistics
      for (final friendData in friendDataList) {
        final userData = userDataMap[friendData.userId];

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

  /// Batch fetch user data to avoid N+1 queries
  ///
  /// This method efficiently fetches multiple user documents from Firestore
  /// using the `whereIn` operator, which allows querying up to 10 documents
  /// per query. For larger lists, it automatically splits the requests into
  /// batches to stay within Firestore's limits.
  ///
  /// **Performance Impact:**
  /// - For 20 users: 2 queries instead of 20 individual queries
  /// - For 50 users: 5 queries instead of 50 individual queries
  ///
  /// **Parameters:**
  /// - [userIds]: List of user IDs to fetch
  ///
  /// **Returns:**
  /// - Map of userId to UserData objects
  /// - Empty map if [userIds] is empty or on error
  ///
  /// **Example:**
  /// ```dart
  /// final userIds = ['uid1', 'uid2', 'uid3'];
  /// final userDataMap = await _batchGetUsers(userIds);
  /// final user1 = userDataMap['uid1'];
  /// ```
  Future<Map<String, UserData>> _batchGetUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    try {
      debugPrint('📦 Batch fetching ${userIds.length} users');

      final userDataMap = <String, UserData>{};

      // Firestore 'whereIn' supports up to a limited number of items per query
      // Split into batches
      for (int i = 0; i < userIds.length; i += FriendsServiceConstants.firestoreBatchSize) {
        final batchIds = userIds.skip(i).take(FriendsServiceConstants.firestoreBatchSize).toList();

        // Use whereIn query to fetch multiple documents in one query
        final querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (final doc in querySnapshot.docs) {
          if (doc.exists) {
            final userData = UserData.fromJson(doc.data());
            userDataMap[doc.id] = userData;
          }
        }
      }

      debugPrint('✅ Batch fetched ${userDataMap.length} users');
      return userDataMap;
    } catch (e, st) {
      debugPrint('❌ Error batch fetching users: $e');
      debugPrint('$st');
      return {};
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
  /// DEPRECATED: This function is obsolete and should not be used
  ///
  /// Previously attempted to update cached friend stats across all users,
  /// but this approach doesn't scale (queries ALL users in database).
  ///
  /// Friend stats are now fetched live using batch queries in getFriends()
  /// which is much more efficient and always returns current data.
  ///
  /// This function is kept for reference but should be removed in future cleanup.
  @Deprecated('Use live data fetching in getFriends() instead')
  Future<void> updateFriendStats(
    String userId,
    String fullName,
    String? avatarUrl,
    int focusHours,
    int dayStreak,
    String? rankPercentage,
  ) async {
    // This function is deprecated and intentionally does nothing
    // to prevent accidental use of the inefficient implementation
    debugPrint('⚠️ updateFriendStats is deprecated - stats are now fetched live');
    return;
  }
}
