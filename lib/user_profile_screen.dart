import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:ui' as ui;
import 'user_data.dart';
import 'friends_service.dart';
import 'groups_service.dart';
import 'notification_service.dart';
import 'achievement.dart';
import 'achievements_service.dart';
import 'achievements_screen.dart';
import 'main.dart'; // For AppCard widget
import 'project_service.dart';

/// User Profile Screen - Shows individual user's profile and statistics
/// Matches the design of the own profile page
class UserProfileScreen extends StatefulWidget {
  final UserData userData;
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userData,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isFriend = false;
  bool _isLoadingFriendStatus = true;
  int _friendsCount = 0;
  int _groupsCount = 0;
  bool _isLoadingCounts = true;

  List<Achievement> _achievements = [];
  bool _isLoadingAchievements = true;

  // Period navigation
  int _selectedPeriod = 0; // 0: Week, 1: Month, 2: Year
  int _currentOffset =
      0; // Offset for navigation (0 = current period, 1 = previous period, etc.)

  // Get the number of days based on selected period
  int get _daysInPeriod {
    switch (_selectedPeriod) {
      case 0: // Week
        return 7;
      case 1: // Month
        return 30;
      case 2: // Year
        return 365;
      default:
        return 7;
    }
  }

  // Get period label
  String get _periodLabel {
    final now = DateTime.now();
    final daysBack = _currentOffset * _daysInPeriod;

    if (_currentOffset == 0) {
      switch (_selectedPeriod) {
        case 0:
          return 'This Week';
        case 1:
          return 'This Month';
        case 2:
          return 'This Year';
        default:
          return 'This Week';
      }
    } else {
      final startDate = now.subtract(
        Duration(days: daysBack + _daysInPeriod - 1),
      );
      final endDate = now.subtract(Duration(days: daysBack));

      if (_selectedPeriod == 0) {
        // Week format
        return '${startDate.month}/${startDate.day} - ${endDate.month}/${endDate.day}';
      } else if (_selectedPeriod == 1) {
        // Month format
        final monthNames = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${monthNames[startDate.month - 1]} ${startDate.year}';
      } else {
        // Year format - show the year being viewed
        return '${now.year - _currentOffset}';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFriendStatus();
    _loadCounts();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    try {
      final achievements =
          await AchievementsService.instance.getUserAchievements(widget.userId);

      if (mounted) {
        setState(() {
          _achievements = achievements;
          _isLoadingAchievements = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading achievements: $e');
      if (mounted) {
        setState(() {
          _isLoadingAchievements = false;
        });
      }
    }
  }

  Future<void> _loadFriendStatus() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final friends = await FriendsService.instance.getFriends(currentUser.uid);
      final isFriend = friends.any((friend) => friend.userId == widget.userId);

      if (mounted) {
        setState(() {
          _isFriend = isFriend;
          _isLoadingFriendStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFriendStatus = false;
        });
      }
    }
  }

  Future<void> _loadCounts() async {
    try {
      final friends = await FriendsService.instance.getFriends(widget.userId);
      final groups = await GroupsService.instance.getUserGroups(widget.userId);

      if (mounted) {
        setState(() {
          _friendsCount = friends.length;
          _groupsCount = groups.length;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCounts = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FriendsService.instance.sendFriendRequest(
        currentUser.uid,
        widget.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _sendNudge() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Get current user's data for the notification
      final currentUserData = await FriendsService.instance.getUserById(
        currentUser.uid,
      );

      // Send nudge notification
      await NotificationService.instance.sendNudge(
        toUserId: widget.userId,
        fromUserId: currentUser.uid,
        fromUserName: currentUserData?.fullName ?? 'Someone',
        fromUserAvatar: currentUserData?.avatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nudged ${widget.userData.fullName}! 👋'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF30D158),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send nudge: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  void _navigatePrevious() {
    setState(() {
      _currentOffset++;
    });
  }

  void _navigateNext() {
    if (_currentOffset > 0) {
      setState(() {
        _currentOffset--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner and Profile Header Stack
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Banner Image with alpha fade and gradient overlay
                SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: Stack(
                    children: [
                      // Banner image with alpha fade
                      Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black,
                                Colors.black,
                                Colors.black,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.5, 0.7, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: widget.userData.bannerImageUrl != null
                              ? Image.network(
                                  widget.userData.bannerImageUrl!,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/pfbannerplaceholder.jpg',
                                      fit: BoxFit.fitWidth,
                                      alignment: Alignment.topCenter,
                                      width: double.infinity,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/pfbannerplaceholder.jpg',
                                  fit: BoxFit.fitWidth,
                                  alignment: Alignment.topCenter,
                                  width: double.infinity,
                                ),
                        ),
                      ),
                      // Gradient overlay for darkening
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.transparent,
                                const Color(0xFF000000).withValues(alpha: 0.05),
                                const Color(0xFF000000).withValues(alpha: 0.15),
                                const Color(0xFF000000).withValues(alpha: 0.3),
                                const Color(0xFF000000).withValues(alpha: 0.5),
                                const Color(0xFF000000).withValues(alpha: 0.7),
                                const Color(0xFF000000).withValues(alpha: 0.88),
                                const Color(0xFF000000),
                              ],
                              stops: const [
                                0.0,
                                0.15,
                                0.3,
                                0.42,
                                0.54,
                                0.65,
                                0.75,
                                0.85,
                                0.95,
                                1.0,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Profile picture centered overlaying the banner bottom
                Positioned(
                  top: 140,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF000000),
                              width: 4,
                            ),
                            color: const Color(0xFF2C2C2E),
                          ),
                          child: ClipOval(
                            child: widget.userData.avatarUrl != null
                                ? Image.network(
                                    widget.userData.avatarUrl!,
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 60,
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                          ),
                        ),
                        // Currently Focusing indicator
                        if (widget.userData.currentlyFocusing) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2C2C2E),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF30D158),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Currently Focusing',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // Profile name, counters, and username (centered)
            Column(
              children: [
                // Full Name
                Text(
                  widget.userData.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Friends counter, username, and clubs counter row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Friends counter (hidden if 0)
                    if (!_isLoadingCounts && _friendsCount > 0) ...[
                      Text(
                        '$_friendsCount ${_friendsCount == 1 ? 'Friend' : 'Friends'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // Username
                    if (widget.userData.username != null &&
                        widget.userData.username!.isNotEmpty)
                      Text(
                        '@${widget.userData.username}',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                    // Clubs counter (hidden if 0)
                    if (!_isLoadingCounts && _groupsCount > 0) ...[
                      const SizedBox(width: 16),
                      Text(
                        '$_groupsCount ${_groupsCount == 1 ? 'Club' : 'Clubs'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons - Friend Request and Nudge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  // Friend Request / Friend button
                  Expanded(
                    child: GestureDetector(
                      onTap: _isFriend ? null : _sendFriendRequest,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isFriend
                              ? const Color(0xFF1C1C1E)
                              : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isFriend
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFF3A3A3C),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isFriend
                                  ? Icons.check
                                  : Icons.person_add_outlined,
                              color: _isFriend
                                  ? const Color(0xFF30D158)
                                  : Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isLoadingFriendStatus
                                  ? '...'
                                  : (_isFriend
                                        ? 'Friend'
                                        : 'Send Friend Request'),
                              style: TextStyle(
                                color: _isFriend
                                    ? const Color(0xFF30D158)
                                    : Colors.white,
                                fontSize: 15,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nudge button
                  Expanded(
                    child: GestureDetector(
                      onTap: _sendNudge,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF3A3A3C),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Nudge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Horizontally scrollable achievements row
            SizedBox(
              height: 50,
              child: _isLoadingAchievements
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _achievements.length,
                      itemBuilder: (context, index) {
                        final achievement = _achievements[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AchievementsScreen(userId: widget.userId),
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.only(
                              right: index < _achievements.length - 1 ? 8 : 0,
                            ),
                            width: 50,
                            height: 50,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: achievement.isUnlocked
                                  ? Image.asset(
                                      achievement.iconUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        // Fallback to stone if badge image not found
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
                                        opacity: 0.4,
                                        child: Image.asset(
                                          'assets/images/achievements/stone.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 24),

            // Rest of content with padding
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards Row (Day Streak and Focus Hours)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 140,
                          child: AppCard(
                            borderRadius: 16,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${widget.userData.dayStreak}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 48,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'DAY STREAK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 140,
                          child: AppCard(
                            borderRadius: 16,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${widget.userData.focusHours}',
                                  style: const TextStyle(
                                    color: Color(0xFFB794F6),
                                    fontSize: 48,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'FOCUS HOURS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Period selection buttons and navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Period navigation
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _navigatePrevious,
                            child: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _periodLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _navigateNext,
                            child: Icon(
                              Icons.chevron_right,
                              color: _currentOffset > 0
                                  ? Colors.white
                                  : const Color(0xFF3A3A3C),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      // Period buttons
                      Row(
                        children: [
                          _buildPeriodButton('Week', 0),
                          const SizedBox(width: 8),
                          _buildPeriodButton('Month', 1),
                          const SizedBox(width: 8),
                          _buildPeriodButton('Year', 2),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Activity Graph
                  _buildActivityGraph(),

                  const SizedBox(height: 24),

                  // Project Distribution Pie Chart
                  _buildProjectDistributionGraph(),

                  const SizedBox(height: 24),

                  // Time of Day Performance Graph
                  _buildTimeOfDayGraph(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityGraph() {
    final now = DateTime.now();
    final daysBack = _currentOffset * _daysInPeriod;

    // Get data for the current period
    List<double> periodData = [];
    List<String> labels = [];

    if (_selectedPeriod == 0) {
      // Week view (Monday-Sunday)
      final currentWeekday = now.weekday;
      final mondayOffset = currentWeekday - 1;
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: mondayOffset + daysBack));

      labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final hours = widget.userData.dailyActivityData[date] ?? 0.0;
        periodData.add(hours);
      }
    } else if (_selectedPeriod == 1) {
      // Month view (30 days)
      final startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysBack + 29));

      for (int i = 0; i < 30; i++) {
        final date = startDate.add(Duration(days: i));
        final hours = widget.userData.dailyActivityData[date] ?? 0.0;
        periodData.add(hours);
        if (i % 3 == 0) {
          labels.add('${date.month}/${date.day}');
        } else {
          labels.add('');
        }
      }
    } else {
      // Year view (365 days aggregated into ~52 weeks)
      final startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysBack + 364));

      for (int week = 0; week < 52; week++) {
        double weekTotal = 0;
        for (int day = 0; day < 7; day++) {
          final date = startDate.add(Duration(days: week * 7 + day));
          weekTotal += widget.userData.dailyActivityData[date] ?? 0.0;
        }
        periodData.add(weekTotal / 7);
        if (week % 4 == 0) {
          final weekDate = startDate.add(Duration(days: week * 7));
          labels.add('${weekDate.month}/${weekDate.day}');
        } else {
          labels.add('');
        }
      }
    }

    // Find max value for scaling
    final maxValue = periodData.isEmpty
        ? 1.0
        : periodData.reduce((a, b) => a > b ? a : b);
    final ceiledMax = maxValue.ceil();
    final yAxisMax = maxValue == 0
        ? 1
        : (ceiledMax - maxValue < 1.0 ? ceiledMax + 1 : ceiledMax);

    // Calculate average
    final nonZeroDays = periodData.where((value) => value > 0).toList();
    final showAverage = nonZeroDays.length >= 2;
    final displayValue = nonZeroDays.isEmpty
        ? 0.0
        : nonZeroDays.reduce((a, b) => a + b) / nonZeroDays.length;

    // Format hours and minutes
    final hours = displayValue.floor();
    final minutes = ((displayValue - hours) * 60).round();
    final timeString = minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';

    return SizedBox(
      height: 290,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label showing average
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Average',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeString,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bar chart
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bars container
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Horizontal line at top
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 0.5,
                            color: const Color(
                              0xFF8E8E93,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        // Horizontal line at bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 0.5,
                            color: const Color(
                              0xFF8E8E93,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        // Dashed line for average
                        if (showAverage)
                          Positioned(
                            bottom:
                                150 * (displayValue / yAxisMax).clamp(0.0, 1.0),
                            left: 0,
                            right: 0,
                            child: CustomPaint(
                              size: const Size(double.infinity, 1),
                              painter: DashedLinePainter(
                                color: const Color(
                                  0xFF8E8E93,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        // Bars
                        SizedBox(
                          height: 150,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(periodData.length, (index) {
                              final value = periodData[index];
                              final heightPercent = yAxisMax > 0
                                  ? (value / yAxisMax).clamp(0.0, 1.0)
                                  : 0.0;

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Container(
                                    height: 150 * heightPercent,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Color.fromARGB(255, 48, 48, 48),
                                          Color.fromARGB(255, 73, 73, 73),
                                          Color.fromARGB(255, 109, 109, 109),
                                          Color.fromARGB(255, 190, 190, 190),
                                        ],
                                        stops: [0.0, 0.25, 0.5, 1.0],
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(6),
                                        topRight: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Y-axis labels
                  SizedBox(
                    width: 13,
                    height: 150,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -6,
                          child: Text(
                            '${yAxisMax}h',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                        ),
                        if (showAverage)
                          Positioned(
                            bottom:
                                150 *
                                    (displayValue / yAxisMax).clamp(0.0, 1.0) -
                                5,
                            child: const Text(
                              'avg',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 9,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        const Positioned(
                          bottom: -5,
                          child: Text(
                            '0',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // X-axis labels
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: List.generate(labels.length, (index) {
                      return Expanded(
                        child: Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 10,
                            fontFamily: 'Inter',
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 4),
                const SizedBox(width: 13),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOfDayGraph() {
    // Calculate time of day performance from all sessions
    final timePerformance = UserData.calculateTimeOfDayPerformance(
      widget.userData.focusSessions,
    );
    final sortedData = List.generate(24, (i) => timePerformance[i] ?? 0.0);

    // Y-axis max is always 60 minutes
    final yAxisMax = 60.0;

    // Find peak hour
    double maxMinutes = 0;
    int peakHour = 10;
    for (int i = 0; i < sortedData.length; i++) {
      if (sortedData[i] > maxMinutes) {
        maxMinutes = sortedData[i];
        peakHour = i;
      }
    }

    final hourString = peakHour.toString().padLeft(2, '0');

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most Focused Period of the Day',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Most focused at $hourString:00 every day in general',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: LineChartPainter(
                data: sortedData,
                maxValue: yAxisMax,
                selectedHourIndex: null,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProjectDistributionGraph() {
    return FutureBuilder<Map<String, String>>(
      future: _loadProjectNames(),
      builder: (context, snapshot) {
        final projectNames = snapshot.data ?? {};
        return _buildProjectDistributionContent(projectNames);
      },
    );
  }

  Future<Map<String, String>> _loadProjectNames() async {
    try {
      final projects = await ProjectService.instance.loadAllProjects(widget.userId);
      final Map<String, String> projectNames = {};
      for (final project in projects) {
        projectNames[project.id] = project.name;
      }
      return projectNames;
    } catch (e) {
      debugPrint('Error loading project names: $e');
      return {};
    }
  }

  String _getProjectDisplayName(String projectId, Map<String, String> projectNames) {
    // First check if we have the actual project name
    if (projectNames.containsKey(projectId)) {
      return projectNames[projectId]!;
    }

    // Handle "unset" special case
    if (projectId == 'unset') {
      return 'Unset';
    }

    // Format generated project IDs like "project_1" to "Project 1"
    final match = RegExp(r'^project_(\d+)$').firstMatch(projectId);
    if (match != null) {
      return 'Project ${match.group(1)}';
    }

    // Format generated subproject IDs like "project_1_sub_0" to "Project 1 - Subtask 1"
    final subMatch = RegExp(r'^project_(\d+)_sub_(\d+)$').firstMatch(projectId);
    if (subMatch != null) {
      final projectNum = int.parse(subMatch.group(1)!);
      final subNum = int.parse(subMatch.group(2)!) + 1; // Add 1 for 1-based indexing
      return 'Project $projectNum - Subtask $subNum';
    }

    // Default: return the ID as-is
    return projectId;
  }

  Widget _buildProjectDistributionContent(Map<String, String> projectNames) {
    // Calculate total minutes per project from all focus sessions
    final Map<String, double> projectMinutes = {};

    for (final session in widget.userData.focusSessions) {
      final projectId = session.projectId;
      final minutes = session.duration.inMinutes.toDouble();
      projectMinutes[projectId] = (projectMinutes[projectId] ?? 0.0) + minutes;
    }

    // Convert to hours and sort by value
    final projectHours = projectMinutes.map(
      (key, value) => MapEntry(key, value / 60.0),
    );

    // Sort by hours (descending)
    final sortedEntries = projectHours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // If no data, show empty state
    if (sortedEntries.isEmpty || sortedEntries.every((e) => e.value == 0)) {
      return AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project Distribution',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No focus sessions recorded yet',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            const Center(
              child: Icon(
                Icons.pie_chart_outline,
                color: Color(0xFF8E8E93),
                size: 64,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    // Calculate total hours
    final totalHours = sortedEntries.fold(0.0, (total, entry) => total + entry.value);

    // Predefined colors for projects (matching the app's color scheme)
    final List<Color> projectColors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFFF9500), // Orange
      const Color(0xFF34C759), // Green
      const Color(0xFFFF3B30), // Red
      const Color(0xFFFFCC00), // Yellow
      const Color(0xFFFF2D55), // Pink
      const Color(0xFF5856D6), // Indigo
    ];

    // Build data for pie chart
    final List<PieChartData> chartData = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final percentage = (entry.value / totalHours) * 100;
      chartData.add(PieChartData(
        projectId: entry.key,
        hours: entry.value,
        percentage: percentage,
        color: projectColors[i % projectColors.length],
      ));
    }

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: ${totalHours.toStringAsFixed(1)} hours',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          // Pie chart
          RepaintBoundary(
            child: SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: PieChartPainter(data: chartData),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          ...chartData.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getProjectDisplayName(item.projectId, projectNames),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${item.hours.toStringAsFixed(1)}h (${item.percentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String text, int index) {
    final isSelected = _selectedPeriod == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = index;
          _currentOffset = 0; // Reset to current period when switching
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 11,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// Custom painter for dashed line
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DashedLinePainter({
    required this.color,
    this.dashWidth = 4,
    this.dashSpace = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }
}

// Custom painter for line chart
class LineChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;
  final int? selectedHourIndex;

  LineChartPainter({
    required this.data,
    required this.maxValue,
    this.selectedHourIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue == 0) return;

    final paint = Paint()
      ..color = const Color.fromARGB(255, 190, 190, 190)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          const Color.fromARGB(255, 150, 150, 150).withValues(alpha: 0.8),
          const Color.fromARGB(255, 80, 80, 80).withValues(alpha: 0.3),
          const Color.fromARGB(255, 50, 50, 50).withValues(alpha: 0.0),
        ],
        const [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = const Color(0xFF3A3A3C).withValues(alpha: 0.3)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final leftPadding = 8.0;
    final rightPadding = 18.0;
    final graphWidth = size.width - leftPadding - rightPadding;

    // Draw horizontal grid lines
    for (int i = 0; i <= 3; i++) {
      final y = (size.height / 3) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + graphWidth, y),
        gridPaint,
      );
    }

    // Calculate points
    final points = <Offset>[];
    final spacing = graphWidth / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = leftPadding + (i * spacing);
      final normalizedValue = data[i] / maxValue;
      final y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y));
    }

    // Draw filled area under the line
    if (points.isNotEmpty) {
      final path = Path();
      path.moveTo(points.first.dx, size.height);
      path.lineTo(points.first.dx, points.first.dy);

      for (final point in points) {
        path.lineTo(point.dx, point.dy);
      }

      path.lineTo(points.last.dx, size.height);
      path.close();
      canvas.drawPath(path, fillPaint);
    }

    // Draw the line
    if (points.length > 1) {
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }

      canvas.drawPath(linePath, paint);
    }

    // Draw hour labels on X-axis
    final xAxisHours = [0, 6, 12, 18, 23];
    for (int hour in xAxisHours) {
      final x = leftPadding + (hour * spacing);
      final hourString = hour.toString().padLeft(2, '0');
      textPainter.text = TextSpan(
        text: '$hourString:00',
        style: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 9,
          fontFamily: 'Inter',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 10),
      );
    }

    // Draw Y-axis labels
    final yLabels = ['60', '40', '20', '0'];
    for (int i = 0; i <= 3; i++) {
      final y = (size.height / 3) * i;
      textPainter.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 9,
          fontFamily: 'Inter',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.selectedHourIndex != selectedHourIndex;
  }
}
