import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'achievement.dart';
import 'user_data.dart';

/// Service for managing user achievements
class AchievementsService {
  static final AchievementsService instance = AchievementsService._internal();
  AchievementsService._internal();

  /// Predefined achievements that all users can unlock
  static final List<Achievement> predefinedAchievements = [
    // Focus Hours Achievements
    Achievement(
      id: 'focus_hours_10',
      title: 'Getting Started',
      description: 'Reach 10 total focus hours',
      iconUrl: 'assets/images/achievements/badge_10h.png',
      criteria: AchievementCriteria(
        type: AchievementType.focusHours,
        targetValue: 10,
      ),
    ),
    Achievement(
      id: 'focus_hours_50',
      title: 'Dedicated Learner',
      description: 'Reach 50 total focus hours',
      iconUrl: 'assets/images/achievements/badge_50h.png',
      criteria: AchievementCriteria(
        type: AchievementType.focusHours,
        targetValue: 50,
      ),
    ),
    Achievement(
      id: 'focus_hours_100',
      title: 'Century Club',
      description: 'Reach 100 total focus hours',
      iconUrl: 'assets/images/achievements/badge_100h.png',
      criteria: AchievementCriteria(
        type: AchievementType.focusHours,
        targetValue: 100,
      ),
    ),
    Achievement(
      id: 'focus_hours_500',
      title: 'Master of Focus',
      description: 'Reach 500 total focus hours',
      iconUrl: 'assets/images/achievements/badge_500h.png',
      criteria: AchievementCriteria(
        type: AchievementType.focusHours,
        targetValue: 500,
      ),
    ),

    // Day Streak Achievements
    Achievement(
      id: 'streak_7',
      title: 'One Week Warrior',
      description: 'Maintain a 7-day streak',
      iconUrl: 'assets/images/achievements/badge_7d.png',
      criteria: AchievementCriteria(
        type: AchievementType.dayStreak,
        targetValue: 7,
      ),
    ),
    Achievement(
      id: 'streak_30',
      title: 'Monthly Dedication',
      description: 'Maintain a 30-day streak',
      iconUrl: 'assets/images/achievements/badge_30d.png',
      criteria: AchievementCriteria(
        type: AchievementType.dayStreak,
        targetValue: 30,
      ),
    ),
    Achievement(
      id: 'streak_100',
      title: 'Unstoppable',
      description: 'Maintain a 100-day streak',
      iconUrl: 'assets/images/achievements/badge_100d.png',
      criteria: AchievementCriteria(
        type: AchievementType.dayStreak,
        targetValue: 100,
      ),
    ),
    Achievement(
      id: 'streak_365',
      title: 'Year of Focus',
      description: 'Maintain a 365-day streak',
      iconUrl: 'assets/images/achievements/badge_365d.png',
      criteria: AchievementCriteria(
        type: AchievementType.dayStreak,
        targetValue: 365,
      ),
    ),
  ];

  /// Get user's achievements from Firestore
  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .get();

      if (doc.docs.isEmpty) {
        // Initialize achievements for new user
        return await _initializeUserAchievements(userId);
      }

      return doc.docs
          .map((doc) => Achievement.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading user achievements: $e');
      return [];
    }
  }

  /// Initialize achievements for a new user
  Future<List<Achievement>> _initializeUserAchievements(String userId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final achievementsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('achievements');

      for (final achievement in predefinedAchievements) {
        batch.set(
          achievementsRef.doc(achievement.id),
          achievement.toFirestore(),
        );
      }

      await batch.commit();
      return predefinedAchievements;
    } catch (e) {
      debugPrint('❌ Error initializing user achievements: $e');
      return predefinedAchievements;
    }
  }

  /// Check and unlock achievements based on user's current stats
  Future<List<Achievement>> checkAndUnlockAchievements(
    String userId,
    UserData userData,
  ) async {
    try {
      final achievements = await getUserAchievements(userId);
      final newlyUnlocked = <Achievement>[];
      final batch = FirebaseFirestore.instance.batch();

      for (final achievement in achievements) {
        if (achievement.isUnlocked) continue;

        bool shouldUnlock = false;

        switch (achievement.criteria.type) {
          case AchievementType.focusHours:
            shouldUnlock =
                userData.focusHours >= achievement.criteria.targetValue;
            break;
          case AchievementType.dayStreak:
            shouldUnlock =
                userData.dayStreak >= achievement.criteria.targetValue;
            break;
          case AchievementType.sessionsCount:
            shouldUnlock =
                userData.focusSessions.length >=
                achievement.criteria.targetValue;
            break;
          case AchievementType.singleSession:
            // Check if any session duration meets the target
            final longestSession = userData.focusSessions.isEmpty
                ? 0
                : userData.focusSessions
                      .map((s) => s.duration.inMinutes)
                      .reduce((a, b) => a > b ? a : b);
            shouldUnlock = longestSession >= achievement.criteria.targetValue;
            break;
        }

        if (shouldUnlock) {
          final unlockedAchievement = achievement.copyWith(
            isUnlocked: true,
            unlockedAt: DateTime.now(),
          );
          newlyUnlocked.add(unlockedAchievement);

          // Update in Firestore
          final docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('achievements')
              .doc(achievement.id);

          batch.update(docRef, {
            'isUnlocked': true,
            'unlockedAt': Timestamp.fromDate(unlockedAchievement.unlockedAt!),
          });
        }
      }

      if (newlyUnlocked.isNotEmpty) {
        await batch.commit();
        debugPrint('🏆 Unlocked ${newlyUnlocked.length} new achievements!');
      }

      return newlyUnlocked;
    } catch (e) {
      debugPrint('❌ Error checking achievements: $e');
      return [];
    }
  }

  /// Manually unlock a specific achievement (for testing or special cases)
  Future<void> unlockAchievement(String userId, String achievementId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc(achievementId)
          .update({
            'isUnlocked': true,
            'unlockedAt': Timestamp.fromDate(DateTime.now()),
          });
      debugPrint('🏆 Achievement unlocked: $achievementId');
    } catch (e) {
      debugPrint('❌ Error unlocking achievement: $e');
    }
  }

  /// Get count of unlocked achievements
  Future<int> getUnlockedCount(String userId) async {
    final achievements = await getUserAchievements(userId);
    return achievements.where((a) => a.isUnlocked).length;
  }
}
