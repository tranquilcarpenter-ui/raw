/// Group Data Model
/// Represents a study/focus group that users can join
class Group {
  final String groupId; // Unique group identifier
  final String name; // Group name
  final String? description; // Optional group description
  final String inviteCode; // 6-character invite code to join
  final String creatorId; // User ID of the group creator
  final DateTime createdAt; // When the group was created
  final List<String> memberIds; // List of member user IDs
  final int memberCount; // Number of members

  Group({
    required this.groupId,
    required this.name,
    this.description,
    required this.inviteCode,
    required this.creatorId,
    required this.createdAt,
    required this.memberIds,
    required this.memberCount,
  });

  /// Convert to JSON for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'creatorId': creatorId,
      'createdAt': createdAt.toIso8601String(),
      'memberIds': memberIds,
      'memberCount': memberCount,
    };
  }

  /// Create from JSON (Firestore data)
  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      groupId: json['groupId'] as String,
      name: json['name'] as String? ?? 'Unnamed Group',
      description: json['description'] as String?,
      inviteCode: json['inviteCode'] as String,
      creatorId: json['creatorId'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      memberIds: (json['memberIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      memberCount: json['memberCount'] as int? ?? 0,
    );
  }

  /// Copy with method for updating fields
  Group copyWith({
    String? groupId,
    String? name,
    String? description,
    String? inviteCode,
    String? creatorId,
    DateTime? createdAt,
    List<String>? memberIds,
    int? memberCount,
  }) {
    return Group(
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      memberIds: memberIds ?? this.memberIds,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  /// Check if a user is a member
  bool isMember(String userId) {
    return memberIds.contains(userId);
  }

  /// Check if a user is the creator
  bool isCreator(String userId) {
    return creatorId == userId;
  }
}

/// Group Member Model (for leaderboard display)
class GroupMember {
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final int focusHours; // All-time focus hours
  final int focusHoursMonth; // Focus hours this month
  final int dayStreak;
  final DateTime joinedAt;

  GroupMember({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.focusHours,
    this.focusHoursMonth = 0,
    required this.dayStreak,
    required this.joinedAt,
  });

  /// Convert to JSON for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'focusHours': focusHours,
      'focusHoursMonth': focusHoursMonth,
      'dayStreak': dayStreak,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  /// Create from JSON (Firestore data)
  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String?,
      focusHours: json['focusHours'] as int? ?? 0,
      focusHoursMonth: json['focusHoursMonth'] as int? ?? 0,
      dayStreak: json['dayStreak'] as int? ?? 0,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Copy with method for updating fields
  GroupMember copyWith({
    String? userId,
    String? fullName,
    String? avatarUrl,
    int? focusHours,
    int? focusHoursMonth,
    int? dayStreak,
    DateTime? joinedAt,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      focusHours: focusHours ?? this.focusHours,
      focusHoursMonth: focusHoursMonth ?? this.focusHoursMonth,
      dayStreak: dayStreak ?? this.dayStreak,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
