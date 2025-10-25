import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

/// Authentication Provider - Manages auth state throughout the app
class AuthProvider extends InheritedWidget {
  final User? user;
  final bool isLoading;

  const AuthProvider({
    super.key,
    required this.user,
    required this.isLoading,
    required super.child,
  });

  static AuthProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthProvider>();
  }

  @override
  bool updateShouldNotify(AuthProvider oldWidget) {
    return user != oldWidget.user || isLoading != oldWidget.isLoading;
  }
}

/// Wrapper widget that provides authentication state
class AuthStateProvider extends StatefulWidget {
  final Widget child;

  const AuthStateProvider({super.key, required this.child});

  @override
  State<AuthStateProvider> createState() => _AuthStateProviderState();
}

class _AuthStateProviderState extends State<AuthStateProvider> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Listen to auth state changes with error handling
    FirebaseService.instance.auth.authStateChanges().listen(
      (User? user) {
        if (mounted) {
          setState(() {
            _user = user;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        // If there's an error, still stop loading and proceed without user
        if (mounted) {
          setState(() {
            _user = null;
            _isLoading = false;
          });
        }
      },
    );

    // Fallback: If no auth state change is received within 3 seconds, stop loading
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthProvider(
      user: _user,
      isLoading: _isLoading,
      child: widget.child,
    );
  }
}
