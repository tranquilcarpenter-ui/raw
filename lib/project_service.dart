import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'project.dart';

/// Service to manage Projects and Subprojects in Firestore
/// Projects are stored in a subcollection under each user: users/{userId}/projects
class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  static ProjectService get instance => _instance;

  factory ProjectService() => _instance;
  ProjectService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get reference to user's projects collection
  CollectionReference _getProjectsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('projects');
  }

  /// Get reference to a specific project document
  DocumentReference _getProjectDoc(String userId, String projectId) {
    return _getProjectsCollection(userId).doc(projectId);
  }

  /// Initialize default "Unset" project for a new user
  /// This should be called when a new user signs up
  Future<void> initializeDefaultProject(String userId) async {
    try {
      debugPrint('🎯 Initializing default "Unset" project for user: $userId');
      final unsetProject = Project.unset();
      await saveProject(userId, unsetProject);
      debugPrint('✅ Default "Unset" project created for user $userId');
    } catch (e, st) {
      debugPrint('❌ Error creating default project for user $userId: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Create a new project
  Future<void> createProject(
    String userId, {
    required String name,
    String? color,
    String? emoji,
  }) async {
    try {
      debugPrint('📝 Creating new project for user $userId: $name');
      final project = Project.create(
        name: name,
        color: color,
        emoji: emoji,
      );
      await saveProject(userId, project);
      debugPrint('✅ Project created: ${project.id}');
    } catch (e, st) {
      debugPrint('❌ Error creating project for user $userId: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Save or update a project
  Future<void> saveProject(String userId, Project project) async {
    try {
      debugPrint('💾 Saving project ${project.id} for user $userId');
      await _getProjectDoc(userId, project.id).set(project.toJson());
      debugPrint('✅ Project saved successfully');
    } catch (e, st) {
      debugPrint('❌ Error saving project ${project.id}: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Load a specific project
  Future<Project?> loadProject(String userId, String projectId) async {
    try {
      debugPrint('📥 Loading project $projectId for user $userId');
      final docSnapshot = await _getProjectDoc(userId, projectId).get();

      if (!docSnapshot.exists) {
        debugPrint('⚠️ Project $projectId not found');
        return null;
      }

      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('⚠️ Project data is null for $projectId');
        return null;
      }

      debugPrint('✅ Project loaded: ${data['name']}');
      return Project.fromJson(data);
    } catch (e, st) {
      debugPrint('❌ Error loading project $projectId: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Load all projects for a user
  Future<List<Project>> loadAllProjects(String userId) async {
    try {
      debugPrint('📥 Loading all projects for user $userId');
      final querySnapshot = await _getProjectsCollection(userId)
          .orderBy('createdAt', descending: false)
          .get();

      final projects = <Project>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          projects.add(Project.fromJson(data));
        }
      }

      debugPrint('✅ Loaded ${projects.length} projects');
      return projects;
    } catch (e, st) {
      debugPrint('❌ Error loading projects for user $userId: $e');
      debugPrint('$st');
      return [];
    }
  }

  /// Stream all projects for a user (real-time updates)
  Stream<List<Project>> streamProjects(String userId) {
    return _getProjectsCollection(userId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      final projects = <Project>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          projects.add(Project.fromJson(data));
        }
      }
      return projects;
    });
  }

  /// Update a project
  Future<void> updateProject(String userId, Project project) async {
    try {
      debugPrint('🔄 Updating project ${project.id} for user $userId');
      final updatedProject = project.copyWith(updatedAt: DateTime.now());
      await saveProject(userId, updatedProject);
      debugPrint('✅ Project updated successfully');
    } catch (e, st) {
      debugPrint('❌ Error updating project ${project.id}: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Delete a project (cannot delete the default "Unset" project)
  Future<void> deleteProject(String userId, String projectId) async {
    try {
      // Prevent deletion of the default "Unset" project
      if (projectId == 'unset') {
        throw Exception('Cannot delete the default "Unset" project');
      }

      debugPrint('🗑️ Deleting project $projectId for user $userId');
      await _getProjectDoc(userId, projectId).delete();
      debugPrint('✅ Project deleted successfully');
    } catch (e, st) {
      debugPrint('❌ Error deleting project $projectId: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Add a subproject to a project
  Future<void> addSubproject(
    String userId,
    String projectId,
    String subprojectName,
  ) async {
    try {
      debugPrint('➕ Adding subproject to project $projectId');
      final project = await loadProject(userId, projectId);
      if (project == null) {
        throw Exception('Project not found: $projectId');
      }

      final now = DateTime.now();
      final subprojectId = '${now.millisecondsSinceEpoch}_${subprojectName.hashCode}';
      final subproject = Subproject(
        id: subprojectId,
        name: subprojectName,
        createdAt: now,
        updatedAt: now,
      );

      final updatedProject = project.addSubproject(subproject);
      await saveProject(userId, updatedProject);
      debugPrint('✅ Subproject added: $subprojectId');
    } catch (e, st) {
      debugPrint('❌ Error adding subproject: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Update a subproject
  Future<void> updateSubproject(
    String userId,
    String projectId,
    Subproject subproject,
  ) async {
    try {
      debugPrint('🔄 Updating subproject ${subproject.id} in project $projectId');
      final project = await loadProject(userId, projectId);
      if (project == null) {
        throw Exception('Project not found: $projectId');
      }

      final updatedSubproject = subproject.copyWith(updatedAt: DateTime.now());
      final updatedProject = project.updateSubproject(updatedSubproject);
      await saveProject(userId, updatedProject);
      debugPrint('✅ Subproject updated successfully');
    } catch (e, st) {
      debugPrint('❌ Error updating subproject: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Remove a subproject from a project
  Future<void> removeSubproject(
    String userId,
    String projectId,
    String subprojectId,
  ) async {
    try {
      debugPrint('➖ Removing subproject $subprojectId from project $projectId');
      final project = await loadProject(userId, projectId);
      if (project == null) {
        throw Exception('Project not found: $projectId');
      }

      final updatedProject = project.removeSubproject(subprojectId);
      await saveProject(userId, updatedProject);
      debugPrint('✅ Subproject removed successfully');
    } catch (e, st) {
      debugPrint('❌ Error removing subproject: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Get the default "Unset" project for a user
  Future<Project?> getDefaultProject(String userId) async {
    return await loadProject(userId, 'unset');
  }
}
