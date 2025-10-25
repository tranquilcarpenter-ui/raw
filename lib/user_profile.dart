/// User Profile Data Model
class UserProfile {
  String fullName;
  DateTime? birthday;
  String? avatarUrl;
  bool onboardingCompleted;
  DateTime createdAt;
  DateTime updatedAt;

  UserProfile({
    required this.fullName,
    this.birthday,
    this.avatarUrl,
    this.onboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to JSON for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'birthday': birthday?.toIso8601String(),
      'avatarUrl': avatarUrl,
      'onboardingCompleted': onboardingCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (Firestore data)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['fullName'] as String? ?? 'User',
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      avatarUrl: json['avatarUrl'] as String?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Factory constructor for a new user
  factory UserProfile.newUser({String? fullName}) {
    final now = DateTime.now();
    return UserProfile(
      fullName: fullName ?? 'User',
      onboardingCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
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

  /// Copy with method for updating fields
  UserProfile copyWith({
    String? fullName,
    DateTime? birthday,
    String? avatarUrl,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      birthday: birthday ?? this.birthday,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
