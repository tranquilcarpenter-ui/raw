// Project and Subproject Data Models

/// Subproject Model
class Subproject {
  final String id; // Unique identifier for the subproject
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subproject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (Firestore data)
  factory Subproject.fromJson(Map<String, dynamic> json) {
    return Subproject(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Copy with method for updating fields
  Subproject copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subproject(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Project Model
class Project {
  final String id; // Unique identifier for the project
  final String name;
  final String? color; // Hex color code (e.g., "#FF5733")
  final String? emoji; // Optional emoji icon
  final List<Subproject> subprojects;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDefault; // True for the "Unset" default project

  Project({
    required this.id,
    required this.name,
    this.color,
    this.emoji,
    List<Subproject>? subprojects,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
  }) : subprojects = subprojects ?? [];

  /// Factory constructor for the default "Unset" project
  factory Project.unset() {
    final now = DateTime.now();
    return Project(
      id: 'unset',
      name: 'Unset',
      color: '#8E8E93', // Gray color
      emoji: '📝',
      subprojects: [],
      createdAt: now,
      updatedAt: now,
      isDefault: true,
    );
  }

  /// Factory constructor for a new project
  factory Project.create({
    required String name,
    String? color,
    String? emoji,
  }) {
    final now = DateTime.now();
    // Generate a unique ID using timestamp + random string
    final id = '${now.millisecondsSinceEpoch}_${name.hashCode}';

    return Project(
      id: id,
      name: name,
      color: color ?? '#007AFF', // Default blue color
      emoji: emoji,
      subprojects: [],
      createdAt: now,
      updatedAt: now,
      isDefault: false,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'emoji': emoji,
      'subprojects': subprojects.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDefault': isDefault,
    };
  }

  /// Create from JSON (Firestore data)
  factory Project.fromJson(Map<String, dynamic> json) {
    // Parse subprojects
    final List<Subproject> subprojects = [];
    final subprojectsJson = json['subprojects'] as List<dynamic>?;
    if (subprojectsJson != null) {
      for (final subprojectData in subprojectsJson) {
        subprojects.add(
          Subproject.fromJson(subprojectData as Map<String, dynamic>),
        );
      }
    }

    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      emoji: json['emoji'] as String?,
      subprojects: subprojects,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  /// Copy with method for updating fields
  Project copyWith({
    String? id,
    String? name,
    String? color,
    String? emoji,
    List<Subproject>? subprojects,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      subprojects: subprojects ?? this.subprojects,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// Add a subproject to this project
  Project addSubproject(Subproject subproject) {
    return copyWith(
      subprojects: [...subprojects, subproject],
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a subproject by ID
  Project removeSubproject(String subprojectId) {
    return copyWith(
      subprojects: subprojects.where((s) => s.id != subprojectId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Update a subproject
  Project updateSubproject(Subproject updatedSubproject) {
    return copyWith(
      subprojects: subprojects.map((s) {
        return s.id == updatedSubproject.id ? updatedSubproject : s;
      }).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Get subproject by ID
  Subproject? getSubproject(String subprojectId) {
    try {
      return subprojects.firstWhere((s) => s.id == subprojectId);
    } catch (e) {
      return null;
    }
  }
}
