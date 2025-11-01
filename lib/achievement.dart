import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an achievement that users can unlock
class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconUrl; // URL or asset path for the unlocked badge
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final AchievementCriteria criteria;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.criteria,
  });

  /// Create Achievement from Firestore document
  factory Achievement.fromFirestore(Map<String, dynamic> data) {
    return Achievement(
      id: data['id'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      iconUrl: data['iconUrl'] as String,
      isUnlocked: data['isUnlocked'] as bool? ?? false,
      unlockedAt: data['unlockedAt'] != null
          ? (data['unlockedAt'] as Timestamp).toDate()
          : null,
      criteria: AchievementCriteria.fromMap(
        data['criteria'] as Map<String, dynamic>,
      ),
    );
  }

  /// Convert Achievement to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconUrl': iconUrl,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt != null ? Timestamp.fromDate(unlockedAt!) : null,
      'criteria': criteria.toMap(),
    };
  }

  /// Create a copy of this achievement with updated fields
  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? iconUrl,
    bool? isUnlocked,
    DateTime? unlockedAt,
    AchievementCriteria? criteria,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      criteria: criteria ?? this.criteria,
    );
  }
}

/// Defines the criteria for unlocking an achievement
class AchievementCriteria {
  final AchievementType type;
  final int targetValue;

  AchievementCriteria({
    required this.type,
    required this.targetValue,
  });

  factory AchievementCriteria.fromMap(Map<String, dynamic> data) {
    return AchievementCriteria(
      type: AchievementType.values.firstWhere(
        (e) => e.toString() == 'AchievementType.${data['type']}',
        orElse: () => AchievementType.focusHours,
      ),
      targetValue: data['targetValue'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'targetValue': targetValue,
    };
  }
}

/// Types of achievements users can unlock
enum AchievementType {
  focusHours, // Total focus hours
  dayStreak, // Consecutive days streak
  sessionsCount, // Total number of sessions completed
  singleSession, // Longest single session
}
