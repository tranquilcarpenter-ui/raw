import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'achievement.dart';
import 'achievements_service.dart';
import 'main.dart'; // For AppCard widget

/// Achievements Screen - Shows all achievements (locked and unlocked)
class AchievementsScreen extends StatefulWidget {
  final String? userId; // If null, uses current user

  const AchievementsScreen({super.key, this.userId});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    // Use provided userId or fall back to current user
    String? userId = widget.userId;
    if (userId == null) {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;
      userId = user.uid;
    }

    try {
      final achievements =
          await AchievementsService.instance.getUserAchievements(userId);

      if (mounted) {
        setState(() {
          _achievements = achievements;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading achievements: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getCriteriaText(Achievement achievement) {
    switch (achievement.criteria.type) {
      case AchievementType.focusHours:
        return '${achievement.criteria.targetValue} focus hours';
      case AchievementType.dayStreak:
        return '${achievement.criteria.targetValue} day streak';
      case AchievementType.sessionsCount:
        return '${achievement.criteria.targetValue} sessions';
      case AchievementType.singleSession:
        return '${achievement.criteria.targetValue} minute session';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedAchievements =
        _achievements.where((a) => a.isUnlocked).toList();
    final lockedAchievements = _achievements.where((a) => !a.isUnlocked).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Achievements',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress summary
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${unlockedAchievements.length}',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 32,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Unlocked',
                                style: TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: const Color(0xFF3A3A3C),
                          ),
                          Column(
                            children: [
                              Text(
                                '${_achievements.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Total',
                                style: TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Unlocked Achievements Section
                    if (unlockedAchievements.isNotEmpty) ...[
                      const Text(
                        'Unlocked',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...unlockedAchievements.map((achievement) =>
                          _buildAchievementCard(achievement, true)),
                      const SizedBox(height: 24),
                    ],

                    // Locked Achievements Section
                    if (lockedAchievements.isNotEmpty) ...[
                      Text(
                        'Locked',
                        style: TextStyle(
                          color: unlockedAchievements.isEmpty
                              ? Colors.white
                              : const Color(0xFF8E8E93),
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...lockedAchievements.map((achievement) =>
                          _buildAchievementCard(achievement, false)),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isUnlocked) {
    // PERFORMANCE: RepaintBoundary isolates card repaints
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Achievement Badge
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnlocked
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF2C2C2E),
                    width: isUnlocked ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isUnlocked
                      ? Image.asset(
                          achievement.iconUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/achievements/stone.png',
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      : ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.black45,
                            BlendMode.darken,
                          ),
                          child: Opacity(
                            opacity: 0.3,
                            child: Image.asset(
                              'assets/images/achievements/stone.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 16),

              // Achievement Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title,
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : const Color(0xFF8E8E93),
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: TextStyle(
                        color: isUnlocked
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF636366),
                        fontSize: 13,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          isUnlocked ? Icons.check_circle : Icons.lock,
                          size: 14,
                          color: isUnlocked
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF636366),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUnlocked
                              ? _formatUnlockedDate(achievement.unlockedAt!)
                              : _getCriteriaText(achievement),
                          style: TextStyle(
                            color: isUnlocked
                                ? const Color(0xFFFFD700)
                                : const Color(0xFF636366),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatUnlockedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Unlocked ${difference.inMinutes}m ago';
      }
      return 'Unlocked ${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return 'Unlocked ${difference.inDays}d ago';
    } else {
      return 'Unlocked ${date.month}/${date.day}/${date.year}';
    }
  }
}
