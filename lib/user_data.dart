import 'dart:math' as math;

/// Focus Session Data Model
class FocusSession {
  DateTime start;
  Duration duration;

  FocusSession({required this.start, required this.duration});

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'start': start.toIso8601String(),
      'duration': duration.inMinutes,
    };
  }

  // Create from JSON
  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      start: DateTime.parse(json['start'] as String),
      duration: Duration(minutes: json['duration'] as int),
    );
  }
}

/// Unified User Data Model - Contains both profile and statistics
class UserData {
  // Profile fields
  String email;
  String fullName;
  String? username;
  DateTime? birthday;
  String? gender;
  String? avatarUrl;
  String? bannerImageUrl;
  bool onboardingCompleted;
  DateTime createdAt;
  DateTime updatedAt;
  Map<String, String>? questionAnswers; // Stores answers to onboarding questions

  // Statistics fields
  int dayStreak;
  int focusHours;
  String rankPercentage;
  String currentBadge;
  String currentBadgeProgress;
  String nextBadge;
  String nextBadgeProgress;
  Map<DateTime, double> dailyActivityData;
  List<FocusSession> focusSessions;
  Map<int, double>? timeOfDayPerformance;
  bool isGeneratedData;
  DateTime? generatedAt;
  bool isPro;

  UserData({
    // Profile
    required this.email,
    required this.fullName,
    this.username,
    this.birthday,
    this.gender,
    this.avatarUrl,
    this.bannerImageUrl,
    this.onboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.questionAnswers,
    // Statistics
    required this.dayStreak,
    required this.focusHours,
    required this.rankPercentage,
    required this.currentBadge,
    required this.currentBadgeProgress,
    required this.nextBadge,
    required this.nextBadgeProgress,
    required this.dailyActivityData,
    required this.focusSessions,
    this.timeOfDayPerformance,
    this.isGeneratedData = false,
    this.generatedAt,
    this.isPro = true,
  });

  /// Factory constructor for a new user (default values)
  factory UserData.newUser({
    required String email,
    required String fullName,
    String? username,
    DateTime? birthday,
    String? gender,
    Map<String, String>? questionAnswers,
  }) {
    final now = DateTime.now();
    final Map<DateTime, double> activityData = {};

    // Initialize 365 days of empty activity data
    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      activityData[date] = 0.0;
    }

    // Empty time of day performance
    final Map<int, double> timePerformance = {};
    for (int i = 0; i < 24; i++) {
      timePerformance[i] = 0.0;
    }

    return UserData(
      // Profile
      email: email,
      fullName: fullName,
      username: username,
      birthday: birthday,
      gender: gender,
      onboardingCompleted: true,
      createdAt: now,
      updatedAt: now,
      questionAnswers: questionAnswers,
      // Statistics (all zeros/defaults)
      dayStreak: 0,
      focusHours: 0,
      rankPercentage: 'N/A',
      currentBadge: 'None',
      currentBadgeProgress: '0/30 days',
      nextBadge: 'None',
      nextBadgeProgress: '0/500 days',
      dailyActivityData: activityData,
      focusSessions: [],
      timeOfDayPerformance: timePerformance,
      isGeneratedData: false,
      isPro: true,
    );
  }

  /// Generate random statistical data for testing
  /// Preserves all profile information (email, fullName, birthday, avatarUrl, bannerImageUrl)
  /// Only replaces statistical data (dayStreak, focusHours, sessions, etc.)
  UserData withRandomStatistics() {
    final random = math.Random();
    final now = DateTime.now();

    // Generate random statistics
    final dayStreak = random.nextInt(365) + 1;
    final focusHours = random.nextInt(1950) + 50;
    final rankPercent = random.nextInt(99) + 1;
    final rankPercentage = 'Top $rankPercent%';

    // Generate activity data
    final Map<DateTime, double> activityData = {};
    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      activityData[date] = random.nextDouble() * 8;
    }

    // Generate focus sessions
    final List<FocusSession> sessions = [];
    for (int day = 0; day < 60; day++) {
      final date = now.subtract(Duration(days: day));
      final sessionsPerDay = 1 + random.nextInt(6);

      for (int s = 0; s < sessionsPerDay; s++) {
        final hour = 6 + random.nextInt(17);
        final minute = random.nextInt(60);
        final sessionStart = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );
        final durationMinutes = 10 + random.nextInt(111);

        sessions.add(FocusSession(
          start: sessionStart,
          duration: Duration(minutes: durationMinutes),
        ));
      }
    }

    // Calculate time of day performance
    final timePerformance = UserData.calculateTimeOfDayPerformance(sessions);

    // Return copy with only statistics replaced, keeping all profile data
    return copyWith(
      dayStreak: dayStreak,
      focusHours: focusHours,
      rankPercentage: rankPercentage,
      currentBadge: 'Radiant',
      currentBadgeProgress: '${dayStreak % 30}/30 days',
      nextBadge: 'Dutiful',
      nextBadgeProgress: '$focusHours/500 days',
      dailyActivityData: activityData,
      focusSessions: sessions,
      timeOfDayPerformance: timePerformance,
      isGeneratedData: true,
      generatedAt: now,
      updatedAt: now,
    );
  }

  /// Reset statistics to default values
  /// Preserves all profile information (email, fullName, birthday, avatarUrl, bannerImageUrl)
  /// Resets all statistical data to initial/zero values
  UserData withDefaultStatistics() {
    final now = DateTime.now();
    final Map<DateTime, double> activityData = {};

    // Initialize 365 days of empty activity data
    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      activityData[date] = 0.0;
    }

    // Empty time of day performance
    final Map<int, double> timePerformance = {};
    for (int i = 0; i < 24; i++) {
      timePerformance[i] = 0.0;
    }

    return copyWith(
      dayStreak: 0,
      focusHours: 0,
      rankPercentage: 'N/A',
      currentBadge: 'None',
      currentBadgeProgress: '0/30 days',
      nextBadge: 'None',
      nextBadgeProgress: '0/500 days',
      dailyActivityData: activityData,
      focusSessions: [],
      timeOfDayPerformance: timePerformance,
      isGeneratedData: false,
      generatedAt: null,
      updatedAt: now,
    );
  }

  // Calculate time of day performance from focus sessions
  static Map<int, double> calculateTimeOfDayPerformance(
    List<FocusSession> sessions,
  ) {
    final Map<int, double> totalMinutes = {};
    final Map<int, int> sessionCounts = {};

    for (int i = 0; i < 24; i++) {
      totalMinutes[i] = 0.0;
      sessionCounts[i] = 0;
    }

    for (final session in sessions) {
      DateTime currentTime = session.start;
      int remainingMinutes = session.duration.inMinutes;

      while (remainingMinutes > 0) {
        final hour = currentTime.hour;
        final minutesUntilNextHour = 60 - currentTime.minute;
        final minutesInThisHour = remainingMinutes < minutesUntilNextHour
            ? remainingMinutes
            : minutesUntilNextHour;

        totalMinutes[hour] = (totalMinutes[hour] ?? 0.0) + minutesInThisHour;
        sessionCounts[hour] = (sessionCounts[hour] ?? 0) + 1;

        remainingMinutes -= minutesInThisHour;
        currentTime = currentTime.add(Duration(minutes: minutesInThisHour));
      }
    }

    final Map<int, double> averages = {};
    for (int i = 0; i < 24; i++) {
      final daysWithSessions = sessions
          .map((s) => DateTime(s.start.year, s.start.month, s.start.day))
          .toSet()
          .length;
      averages[i] = daysWithSessions > 0
          ? totalMinutes[i]! / daysWithSessions
          : 0.0;
      averages[i] = averages[i]!.clamp(0.0, 60.0);
    }

    return averages;
  }

  /// Calculate age from birthday
  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - birthday!.year;
    if (now.month < birthday!.month ||
        (now.month == birthday!.month && now.day < birthday!.day)) {
      age--;
    }
    return age;
  }

  /// Calculate focus hours for the current month
  int get focusHoursThisMonth {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      int totalMinutes = 0;
      for (final session in focusSessions) {
        // Check if session is within this month
        if (session.start.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            session.start.isBefore(monthEnd.add(const Duration(seconds: 1)))) {
          totalMinutes += session.duration.inMinutes;
        }
      }

      return (totalMinutes / 60).floor();
    } catch (e) {
      // If calculation fails, return 0
      return 0;
    }
  }

  /// Convert to JSON for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      // Profile
      'email': email,
      'fullName': fullName,
      'username': username,
      'birthday': birthday?.toIso8601String(),
      'gender': gender,
      'avatarUrl': avatarUrl,
      'bannerImageUrl': bannerImageUrl,
      'onboardingCompleted': onboardingCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'questionAnswers': questionAnswers,
      // Statistics
      'dayStreak': dayStreak,
      'focusHours': focusHours,
      'rankPercentage': rankPercentage,
      'currentBadge': currentBadge,
      'currentBadgeProgress': currentBadgeProgress,
      'nextBadge': nextBadge,
      'nextBadgeProgress': nextBadgeProgress,
      'dailyActivityData': dailyActivityData.map(
        (date, hours) => MapEntry(date.toIso8601String(), hours),
      ),
      'focusSessions': focusSessions.map((s) => s.toJson()).toList(),
      'timeOfDayPerformance': timeOfDayPerformance?.map(
        (hour, minutes) => MapEntry(hour.toString(), minutes),
      ),
      'isGeneratedData': isGeneratedData,
      'generatedAt': generatedAt?.toIso8601String(),
      'isPro': isPro,
    };
  }

  /// Create from JSON (Firestore data)
  factory UserData.fromJson(Map<String, dynamic> json) {
    // Parse daily activity data
    final Map<DateTime, double> dailyActivityData = {};
    final dailyActivityJson = json['dailyActivityData'] as Map<String, dynamic>?;
    if (dailyActivityJson != null) {
      dailyActivityJson.forEach((dateStr, hours) {
        dailyActivityData[DateTime.parse(dateStr)] = (hours as num).toDouble();
      });
    }

    // Parse focus sessions
    final List<FocusSession> focusSessions = [];
    final sessionsJson = json['focusSessions'] as List<dynamic>?;
    if (sessionsJson != null) {
      for (final sessionData in sessionsJson) {
        focusSessions
            .add(FocusSession.fromJson(sessionData as Map<String, dynamic>));
      }
    }

    // Parse time of day performance
    Map<int, double>? timeOfDayPerformance;
    final timeOfDayJson = json['timeOfDayPerformance'] as Map<String, dynamic>?;
    if (timeOfDayJson != null) {
      timeOfDayPerformance = {};
      timeOfDayJson.forEach((hourStr, value) {
        timeOfDayPerformance![int.parse(hourStr)] = (value as num).toDouble();
      });
    }

    return UserData(
      // Profile
      email: json['email'] as String? ?? 'user@example.com',
      fullName: json['fullName'] as String? ?? 'User',
      username: json['username'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      gender: json['gender'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bannerImageUrl: json['bannerImageUrl'] as String?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      questionAnswers: json['questionAnswers'] != null
          ? Map<String, String>.from(json['questionAnswers'] as Map)
          : null,
      // Statistics
      dayStreak: json['dayStreak'] as int? ?? 0,
      focusHours: json['focusHours'] as int? ?? 0,
      rankPercentage: json['rankPercentage'] as String? ?? 'N/A',
      currentBadge: json['currentBadge'] as String? ?? 'None',
      currentBadgeProgress: json['currentBadgeProgress'] as String? ?? '0/30 days',
      nextBadge: json['nextBadge'] as String? ?? 'None',
      nextBadgeProgress: json['nextBadgeProgress'] as String? ?? '0/500 days',
      dailyActivityData: dailyActivityData,
      focusSessions: focusSessions,
      timeOfDayPerformance: timeOfDayPerformance,
      isGeneratedData: json['isGeneratedData'] as bool? ?? false,
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : null,
      isPro: json['isPro'] as bool? ?? true,
    );
  }

  /// Copy with method for updating fields
  UserData copyWith({
    String? email,
    String? fullName,
    String? username,
    DateTime? birthday,
    String? gender,
    String? avatarUrl,
    String? bannerImageUrl,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? questionAnswers,
    int? dayStreak,
    int? focusHours,
    String? rankPercentage,
    String? currentBadge,
    String? currentBadgeProgress,
    String? nextBadge,
    String? nextBadgeProgress,
    Map<DateTime, double>? dailyActivityData,
    List<FocusSession>? focusSessions,
    Map<int, double>? timeOfDayPerformance,
    bool? isGeneratedData,
    DateTime? generatedAt,
    bool? isPro,
  }) {
    return UserData(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      questionAnswers: questionAnswers ?? this.questionAnswers,
      dayStreak: dayStreak ?? this.dayStreak,
      focusHours: focusHours ?? this.focusHours,
      rankPercentage: rankPercentage ?? this.rankPercentage,
      currentBadge: currentBadge ?? this.currentBadge,
      currentBadgeProgress: currentBadgeProgress ?? this.currentBadgeProgress,
      nextBadge: nextBadge ?? this.nextBadge,
      nextBadgeProgress: nextBadgeProgress ?? this.nextBadgeProgress,
      dailyActivityData: dailyActivityData ?? this.dailyActivityData,
      focusSessions: focusSessions ?? this.focusSessions,
      timeOfDayPerformance: timeOfDayPerformance ?? this.timeOfDayPerformance,
      isGeneratedData: isGeneratedData ?? this.isGeneratedData,
      generatedAt: generatedAt ?? this.generatedAt,
      isPro: isPro ?? this.isPro,
    );
  }
}
