/// Friend Request Status
enum FriendRequestStatus {
  pending, // Request sent but not yet accepted
  accepted, // Request accepted, users are friends
  rejected, // Request was rejected
}

/// Friend Data Model
/// Represents a friendship connection or friend request between two users
class Friend {
  final String userId; // The friend's user ID
  final String fullName; // Friend's display name
  final String? avatarUrl; // Friend's profile picture URL
  final DateTime addedAt; // When friendship/request was created
  final int focusHours; // Friend's total focus hours (all time)
  final int focusHoursMonth; // Friend's focus hours this month
  final int dayStreak; // Friend's current streak
  final String? rankPercentage; // Friend's rank (e.g., "Top 5%")
  final FriendRequestStatus status; // Request status
  final bool isRequester; // True if this user sent the request

  Friend({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.addedAt,
    this.focusHours = 0,
    this.focusHoursMonth = 0,
    this.dayStreak = 0,
    this.rankPercentage,
    this.status = FriendRequestStatus.accepted,
    this.isRequester = false,
  });

  /// Convert to JSON for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'addedAt': addedAt.toIso8601String(),
      'focusHours': focusHours,
      'focusHoursMonth': focusHoursMonth,
      'dayStreak': dayStreak,
      'rankPercentage': rankPercentage,
      'status': status.name,
      'isRequester': isRequester,
    };
  }

  /// Create from JSON (Firestore data)
  factory Friend.fromJson(Map<String, dynamic> json) {
    FriendRequestStatus status = FriendRequestStatus.accepted;
    final statusStr = json['status'] as String?;
    if (statusStr != null) {
      status = FriendRequestStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => FriendRequestStatus.accepted,
      );
    }

    return Friend(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String?,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'] as String)
          : DateTime.now(),
      focusHours: json['focusHours'] as int? ?? 0,
      focusHoursMonth: json['focusHoursMonth'] as int? ?? 0,
      dayStreak: json['dayStreak'] as int? ?? 0,
      rankPercentage: json['rankPercentage'] as String?,
      status: status,
      isRequester: json['isRequester'] as bool? ?? false,
    );
  }

  /// Copy with method for updating fields
  Friend copyWith({
    String? userId,
    String? fullName,
    String? avatarUrl,
    DateTime? addedAt,
    int? focusHours,
    int? focusHoursMonth,
    int? dayStreak,
    String? rankPercentage,
    FriendRequestStatus? status,
    bool? isRequester,
  }) {
    return Friend(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      addedAt: addedAt ?? this.addedAt,
      focusHours: focusHours ?? this.focusHours,
      focusHoursMonth: focusHoursMonth ?? this.focusHoursMonth,
      dayStreak: dayStreak ?? this.dayStreak,
      rankPercentage: rankPercentage ?? this.rankPercentage,
      status: status ?? this.status,
      isRequester: isRequester ?? this.isRequester,
    );
  }
}
