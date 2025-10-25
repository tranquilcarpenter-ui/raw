import 'package:flutter/material.dart';
import 'firebase_service.dart';

/// Debug screen to create test users - ONLY FOR DEVELOPMENT
class TestUsersScreen extends StatefulWidget {
  const TestUsersScreen({super.key});

  @override
  State<TestUsersScreen> createState() => _TestUsersScreenState();
}

class _TestUsersScreenState extends State<TestUsersScreen> {
  bool _isCreating = false;
  final List<String> _createdUsers = [];
  String _statusMessage = '';

  // Test user credentials
  final List<Map<String, String>> _testUsers = [
    {'email': 'test1@example.com', 'password': 'password123'},
    {'email': 'test2@example.com', 'password': 'password123'},
    {'email': 'test3@example.com', 'password': 'password123'},
    {'email': 'test4@example.com', 'password': 'password123'},
    {'email': 'test5@example.com', 'password': 'password123'},
    {'email': 'alice@example.com', 'password': 'password123'},
    {'email': 'bob@example.com', 'password': 'password123'},
    {'email': 'charlie@example.com', 'password': 'password123'},
    {'email': 'diana@example.com', 'password': 'password123'},
    {'email': 'eve@example.com', 'password': 'password123'},
  ];

  Future<void> _createTestUsers() async {
    setState(() {
      _isCreating = true;
      _createdUsers.clear();
      _statusMessage = 'Creating test users...';
    });

    for (var user in _testUsers) {
      try {
        await FirebaseService.instance.auth.createUserWithEmailAndPassword(
          email: user['email']!,
          password: user['password']!,
        );

        // Sign out immediately after creating
        await FirebaseService.instance.auth.signOut();

        setState(() {
          _createdUsers.add('✅ ${user['email']}');
        });
      } catch (e) {
        setState(() {
          if (e.toString().contains('email-already-in-use')) {
            _createdUsers.add('⚠️ ${user['email']} (already exists)');
          } else {
            _createdUsers.add('❌ ${user['email']} - Error: $e');
          }
        });
      }
    }

    setState(() {
      _isCreating = false;
      _statusMessage = 'Done! Created ${_testUsers.length} test users.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Test Users',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug Tool - Test Users',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will create ${_testUsers.length} test accounts in Firebase Auth Emulator.\n\nAll accounts use password: password123',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Create button
            ElevatedButton(
              onPressed: _isCreating ? null : _createTestUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Create Test Users',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Status message
            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: const TextStyle(
                  color: Color(0xFF06B6D4),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

            const SizedBox(height: 16),

            // Created users list
            Expanded(
              child: _createdUsers.isEmpty
                  ? const Center(
                      child: Text(
                        'Press the button to create test users',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _createdUsers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _createdUsers[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Courier',
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Test credentials reference
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Credentials:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._testUsers.take(5).map((user) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${user['email']} / ${user['password']}',
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                            fontFamily: 'Courier',
                          ),
                        ),
                      )),
                  const Text(
                    '... and 5 more',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
