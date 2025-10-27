import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'group.dart';
import 'user_data_service.dart';

/// Service to manage groups in Firestore
class GroupsService {
  static final GroupsService _instance = GroupsService._internal();
  static GroupsService get instance => _instance;

  factory GroupsService() => _instance;
  GroupsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a unique 6-character invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Create a new group
  Future<Group?> createGroup({
    required String userId,
    required String name,
    String? description,
  }) async {
    try {
      debugPrint('🏗️ Creating group: $name by user: $userId');

      final groupId = _firestore.collection('groups').doc().id;
      final inviteCode = _generateInviteCode();
      final now = DateTime.now();

      // Get creator's data
      final userData = await UserDataService.instance.loadUserData(userId);
      if (userData == null) {
        debugPrint('❌ User data not found');
        return null;
      }

      final group = Group(
        groupId: groupId,
        name: name,
        description: description,
        inviteCode: inviteCode,
        creatorId: userId,
        createdAt: now,
        memberIds: [userId], // Creator is first member
        memberCount: 1,
      );

      // Create group document
      await _firestore.collection('groups').doc(groupId).set(group.toJson());

      // Add creator as first member
      final member = GroupMember(
        userId: userId,
        fullName: userData.fullName,
        avatarUrl: userData.avatarUrl,
        focusHours: userData.focusHours,
        dayStreak: userData.dayStreak,
        joinedAt: now,
      );

      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(userId)
          .set(member.toJson());

      // Add group to user's groups list
      await _firestore.collection('users').doc(userId).update({
        'groupIds': FieldValue.arrayUnion([groupId]),
      });

      debugPrint('✅ Group created successfully: $groupId');
      return group;
    } catch (e, st) {
      debugPrint('❌ Error creating group: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Join a group using invite code
  Future<bool> joinGroup(String userId, String inviteCode) async {
    try {
      debugPrint('🚪 Joining group with code: $inviteCode');

      // Find group by invite code
      final querySnapshot = await _firestore
          .collection('groups')
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('⚠️ Group not found with code: $inviteCode');
        return false;
      }

      final groupDoc = querySnapshot.docs.first;
      final group = Group.fromJson(groupDoc.data());

      // Check if already a member
      if (group.isMember(userId)) {
        debugPrint('⚠️ User already a member');
        return false;
      }

      // Get user's data
      final userData = await UserDataService.instance.loadUserData(userId);
      if (userData == null) {
        debugPrint('❌ User data not found');
        return false;
      }

      final now = DateTime.now();
      final member = GroupMember(
        userId: userId,
        fullName: userData.fullName,
        avatarUrl: userData.avatarUrl,
        focusHours: userData.focusHours,
        focusHoursMonth: userData.focusHoursThisMonth,
        dayStreak: userData.dayStreak,
        joinedAt: now,
      );

      // Add member to group
      await _firestore
          .collection('groups')
          .doc(group.groupId)
          .collection('members')
          .doc(userId)
          .set(member.toJson());

      // Update group member count and IDs
      await _firestore.collection('groups').doc(group.groupId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
      });

      // Add group to user's groups list
      await _firestore.collection('users').doc(userId).update({
        'groupIds': FieldValue.arrayUnion([group.groupId]),
      });

      debugPrint('✅ Joined group successfully');
      return true;
    } catch (e, st) {
      debugPrint('❌ Error joining group: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Leave a group
  Future<bool> leaveGroup(String userId, String groupId) async {
    try {
      debugPrint('🚪 Leaving group: $groupId');

      // Get group data
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        debugPrint('❌ Group not found');
        return false;
      }

      final group = Group.fromJson(groupDoc.data()!);

      // If user is the creator and last member, delete the group
      if (group.isCreator(userId) && group.memberCount == 1) {
        await deleteGroup(groupId);
        return true;
      }

      // Remove member from group
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(userId)
          .delete();

      // Update group member count and IDs
      await _firestore.collection('groups').doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'memberCount': FieldValue.increment(-1),
      });

      // Remove group from user's groups list
      await _firestore.collection('users').doc(userId).update({
        'groupIds': FieldValue.arrayRemove([groupId]),
      });

      debugPrint('✅ Left group successfully');
      return true;
    } catch (e, st) {
      debugPrint('❌ Error leaving group: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Delete a group (only creator can do this)
  Future<bool> deleteGroup(String groupId) async {
    try {
      debugPrint('🗑️ Deleting group: $groupId');

      // Get all members
      final membersSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .get();

      // Remove group from all members' lists
      for (final memberDoc in membersSnapshot.docs) {
        await _firestore.collection('users').doc(memberDoc.id).update({
          'groupIds': FieldValue.arrayRemove([groupId]),
        });
      }

      // Delete all members
      for (final memberDoc in membersSnapshot.docs) {
        await memberDoc.reference.delete();
      }

      // Delete group document
      await _firestore.collection('groups').doc(groupId).delete();

      debugPrint('✅ Group deleted successfully');
      return true;
    } catch (e, st) {
      debugPrint('❌ Error deleting group: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Get user's groups
  Future<List<Group>> getUserGroups(String userId) async {
    try {
      debugPrint('📥 Loading groups for user: $userId');

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final groupIds = (userDoc.data()?['groupIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [];

      if (groupIds.isEmpty) {
        debugPrint('✅ No groups found');
        return [];
      }

      final groups = <Group>[];
      for (final groupId in groupIds) {
        final groupDoc =
            await _firestore.collection('groups').doc(groupId).get();
        if (groupDoc.exists) {
          groups.add(Group.fromJson(groupDoc.data()!));
        }
      }

      // Sort by creation date (newest first)
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('✅ Loaded ${groups.length} groups');
      return groups;
    } catch (e, st) {
      debugPrint('❌ Error loading groups: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Get group members with their live statistics
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    try {
      debugPrint('📥 Loading members for group: $groupId');

      final membersSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .get();

      final members = <GroupMember>[];

      // Fetch live statistics for each member
      for (final doc in membersSnapshot.docs) {
        final memberData = GroupMember.fromJson(doc.data());

        // Fetch current user data to get latest statistics
        try {
          final userData = await UserDataService.instance.loadUserData(memberData.userId);
          if (userData != null) {
            // Update member with live statistics (including monthly hours)
            members.add(memberData.copyWith(
              fullName: userData.fullName,
              avatarUrl: userData.avatarUrl,
              focusHours: userData.focusHours,
              focusHoursMonth: userData.focusHoursThisMonth,
              dayStreak: userData.dayStreak,
            ));
          } else {
            // Use cached data if user not found
            members.add(memberData);
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching stats for member ${memberData.userId}: $e');
          // Use cached data if stats fetch fails
          members.add(memberData);
        }
      }

      // Sort by focus hours (descending)
      members.sort((a, b) => b.focusHours.compareTo(a.focusHours));

      debugPrint('✅ Loaded ${members.length} members with live stats');
      return members;
    } catch (e, st) {
      debugPrint('❌ Error loading members: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Get a single group by ID
  Future<Group?> getGroup(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        return null;
      }
      return Group.fromJson(groupDoc.data()!);
    } catch (e) {
      debugPrint('❌ Error getting group: $e');
      return null;
    }
  }

  /// Stream of user's groups (real-time updates)
  Stream<List<Group>> streamUserGroups(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap(
      (userDoc) async {
        final groupIds = (userDoc.data()?['groupIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [];

        if (groupIds.isEmpty) {
          return <Group>[];
        }

        final groups = <Group>[];
        for (final groupId in groupIds) {
          final groupDoc =
              await _firestore.collection('groups').doc(groupId).get();
          if (groupDoc.exists) {
            groups.add(Group.fromJson(groupDoc.data()!));
          }
        }

        groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return groups;
      },
    );
  }
}
