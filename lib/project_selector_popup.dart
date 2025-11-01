import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'project.dart';
import 'project_service.dart';

/// Project Selector Popup with full CRUD operations
class ProjectSelectorPopup extends StatefulWidget {
  final String? currentProjectId;
  final String? currentSubprojectId;
  final Function(String projectId, String? subprojectId)? onProjectSelected;

  const ProjectSelectorPopup({
    super.key,
    this.currentProjectId,
    this.currentSubprojectId,
    this.onProjectSelected,
  });

  @override
  State<ProjectSelectorPopup> createState() => _ProjectSelectorPopupState();
}

class _ProjectSelectorPopupState extends State<ProjectSelectorPopup> {
  List<Project> _projects = [];
  bool _isLoading = true;
  String? _selectedProjectId;
  String? _selectedSubprojectId;
  Project? _expandedProject;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.currentProjectId;
    _selectedSubprojectId = widget.currentSubprojectId;
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final projects = await ProjectService.instance.loadAllProjects(userId);
    setState(() {
      _projects = projects;
      _isLoading = false;
    });
  }

  Future<void> _createProject() async {
    final nameController = TextEditingController();
    String? selectedEmoji;
    Color? selectedColor = const Color(0xFF007AFF);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1D1D1D),
          title: const Text(
            'Create Project',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Project name input
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Project Name',
                    hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Emoji picker
                const Text(
                  'Select Emoji (Optional)',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['📚', '💼', '🎯', '🏃', '🎨', '💻', '🎮', '📝'].map((emoji) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedEmoji = emoji),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selectedEmoji == emoji
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Color picker
                const Text(
                  'Select Color (Optional)',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    const Color(0xFF007AFF), // Blue
                    const Color(0xFFFF3B30), // Red
                    const Color(0xFF34C759), // Green
                    const Color(0xFFFF9500), // Orange
                    const Color(0xFF5856D6), // Purple
                    const Color(0xFFFF2D55), // Pink
                    const Color(0xFFFFCC00), // Yellow
                    const Color(0xFF8E8E93), // Gray
                  ].map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: selectedColor == color
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create', style: TextStyle(color: Color(0xFF007AFF))),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await ProjectService.instance.createProject(
        userId,
        name: nameController.text.trim(),
        emoji: selectedEmoji,
        color: _colorToHex(selectedColor ?? const Color(0xFF007AFF)),
      );
      await _loadProjects();
    }
  }

  Future<void> _editProject(Project project) async {
    final nameController = TextEditingController(text: project.name);
    String? selectedEmoji = project.emoji;
    Color? selectedColor = project.color != null ? _hexToColor(project.color!) : const Color(0xFF007AFF);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1D1D1D),
          title: const Text(
            'Edit Project',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Project Name',
                    hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Emoji (Optional)',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['📚', '💼', '🎯', '🏃', '🎨', '💻', '🎮', '📝'].map((emoji) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedEmoji = emoji),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selectedEmoji == emoji
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Color (Optional)',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    const Color(0xFF007AFF),
                    const Color(0xFFFF3B30),
                    const Color(0xFF34C759),
                    const Color(0xFFFF9500),
                    const Color(0xFF5856D6),
                    const Color(0xFFFF2D55),
                    const Color(0xFFFFCC00),
                    const Color(0xFF8E8E93),
                  ].map((color) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: selectedColor == color
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save', style: TextStyle(color: Color(0xFF007AFF))),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final updatedProject = project.copyWith(
        name: nameController.text.trim(),
        emoji: selectedEmoji,
        color: _colorToHex(selectedColor ?? const Color(0xFF007AFF)),
      );
      await ProjectService.instance.updateProject(userId, updatedProject);
      await _loadProjects();
    }
  }

  Future<void> _deleteProject(Project project) async {
    if (project.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the default project'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1D),
        title: const Text('Delete Project?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${project.name}"?',
          style: const TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await ProjectService.instance.deleteProject(userId, project.id);
      await _loadProjects();
    }
  }

  Future<void> _addSubproject(Project project) async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1D),
        title: const Text('Add Subproject', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Subproject Name',
            hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
            filled: true,
            fillColor: const Color(0xFF2C2C2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Add', style: TextStyle(color: Color(0xFF007AFF))),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await ProjectService.instance.addSubproject(userId, project.id, result.trim());
      await _loadProjects();
    }
  }

  Future<void> _deleteSubproject(Project project, Subproject subproject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1D),
        title: const Text('Delete Subproject?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${subproject.name}"?',
          style: const TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await ProjectService.instance.removeSubproject(userId, project.id, subproject.id);
      await _loadProjects();
    }
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Project',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFF007AFF)),
                        onPressed: _createProject,
                        tooltip: 'Create Project',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2C2C2E), height: 1),

            // Projects list
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF007AFF)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    final isExpanded = _expandedProject?.id == project.id;
                    final isSelected = _selectedProjectId == project.id;

                    return Column(
                      children: [
                        ListTile(
                          leading: project.emoji != null
                              ? Text(project.emoji!, style: const TextStyle(fontSize: 24))
                              : Icon(
                                  Icons.folder,
                                  color: project.color != null
                                      ? _hexToColor(project.color!)
                                      : const Color(0xFF007AFF),
                                ),
                          title: Text(
                            project.name,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF007AFF) : Colors.white,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (project.subprojects.isNotEmpty)
                                IconButton(
                                  icon: Icon(
                                    isExpanded ? Icons.expand_less : Icons.expand_more,
                                    color: const Color(0xFF8E8E93),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _expandedProject = isExpanded ? null : project;
                                    });
                                  },
                                ),
                              if (!project.isDefault)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Color(0xFF8E8E93)),
                                  color: const Color(0xFF1D1D1D),
                                  onSelected: (value) {
                                    if (value == 'edit') _editProject(project);
                                    if (value == 'delete') _deleteProject(project);
                                    if (value == 'add_sub') _addSubproject(project);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit', style: TextStyle(color: Colors.white)),
                                    ),
                                    const PopupMenuItem(
                                      value: 'add_sub',
                                      child: Text('Add Subproject', style: TextStyle(color: Colors.white)),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete', style: TextStyle(color: Color(0xFFFF3B30))),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _selectedProjectId = project.id;
                              _selectedSubprojectId = null;
                            });
                          },
                        ),
                        // Subprojects
                        if (isExpanded && project.subprojects.isNotEmpty)
                          ...project.subprojects.map((subproject) {
                            final isSubSelected = _selectedSubprojectId == subproject.id;
                            return ListTile(
                              contentPadding: const EdgeInsets.only(left: 72, right: 16),
                              title: Text(
                                subproject.name,
                                style: TextStyle(
                                  color: isSubSelected ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
                                  fontWeight: isSubSelected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30), size: 20),
                                onPressed: () => _deleteSubproject(project, subproject),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedProjectId = project.id;
                                  _selectedSubprojectId = subproject.id;
                                });
                              },
                            );
                          }),
                      ],
                    );
                  },
                ),
              ),

            // Select button
            const Divider(color: Color(0xFF2C2C2E), height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedProjectId != null
                      ? () {
                          widget.onProjectSelected?.call(
                            _selectedProjectId!,
                            _selectedSubprojectId,
                          );
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    disabledBackgroundColor: const Color(0xFF2C2C2E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Select Project',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
