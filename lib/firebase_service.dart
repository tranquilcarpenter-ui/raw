import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'user_data_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  static bool _initialized = false;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  static FirebaseService get instance => _instance;

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('FirebaseService: already marked initialized - returning');
      return;
    }

    // If any Firebase app already exists (for example initialized on native
    // side or by a previous run), don't try to initialize again.
    try {
      final appsNotEmpty = Firebase.apps.isNotEmpty;
      debugPrint('FirebaseService: Firebase.apps.isNotEmpty -> $appsNotEmpty');
      if (appsNotEmpty) {
        debugPrint(
          'FirebaseService: detected existing Firebase app(s); marking initialized',
        );
        _initialized = true;
        return;
      }
    } catch (err, st) {
      debugPrint('FirebaseService: could not read Firebase.apps: $err');
      debugPrint('$st');
      // If accessing Firebase.apps throws for some reason, fall through and
      // attempt to initialize normally; errors will be handled below.
    }

    try {
      debugPrint('FirebaseService: calling Firebase.initializeApp()');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // After initializing the core Firebase app, configure the local
      // emulators for any services we want to use in debug mode.
      await _configureEmulatorsIfNeeded();
      _initialized = true;
      debugPrint('FirebaseService: initialize() completed successfully');
    } on FirebaseException catch (e, st) {
      debugPrint(
        'FirebaseService: Firebase.initializeApp threw FirebaseException(${e.code}): ${e.message}',
      );
      debugPrint('$st');
      if (e.code == 'duplicate-app') {
        // Already initialized by another context; treat as initialized.
        debugPrint(
          'FirebaseService: duplicate-app detected; marking initialized',
        );
        _initialized = true;
        // Still attempt to configure emulators since another context may
        // not have configured Dart-side emulator bindings.
        await _configureEmulatorsIfNeeded();
      } else {
        rethrow;
      }
    }
  }

  FirebaseAuth get auth => FirebaseAuth.instance;

  /// Configure local emulators for services we use during development.
  ///
  /// - Uses Storage emulator on port 9199 by default.
  /// - Uses Firestore / Auth emulator should be configured elsewhere
  ///   (UserDataService has a helper to configure Firestore emulator).
  Future<void> _configureEmulatorsIfNeeded() async {
    if (!kDebugMode) return;

    try {
      // Allow overriding emulator host via a dart-define at debug time.
      // Example: flutter run --dart-define=EMULATOR_HOST=192.168.1.42
      const envHost = String.fromEnvironment('EMULATOR_HOST');
      final defaultHost = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final host = envHost.isNotEmpty ? envHost : defaultHost;

      // Storage emulator (default 9199)
      const storagePort = 9199;
      try {
        FirebaseStorage.instance.useStorageEmulator(host, storagePort);
        debugPrint(
          'FirebaseService: Storage emulator configured at $host:$storagePort',
        );
      } catch (e, st) {
        debugPrint('FirebaseService: failed to configure Storage emulator: $e');
        debugPrint('$st');
      }

      // Firestore emulator (default 8080): tell the UserDataService to use it
      try {
        const firestorePort = 8080;
        UserDataService.instance.useEmulator(host, firestorePort);
        debugPrint(
          'FirebaseService: Firestore emulator configured at $host:$firestorePort',
        );
      } catch (e, st) {
        debugPrint(
          'FirebaseService: failed to configure Firestore emulator: $e',
        );
        debugPrint('$st');
      }

      // Auth emulator (default 9099)
      try {
        const authPort = 9099;
        FirebaseAuth.instance.useAuthEmulator(host, authPort);
        debugPrint(
          'FirebaseService: Auth emulator configured at $host:$authPort',
        );
      } catch (e, st) {
        debugPrint('FirebaseService: failed to configure Auth emulator: $e');
        debugPrint('$st');
      }
    } catch (e, st) {
      // In case Platform isn't available (web builds), fall back to localhost
      debugPrint('FirebaseService: emulator configuration fallback: $e');
      debugPrint('$st');
      try {
        FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
        debugPrint(
          'FirebaseService: Storage emulator configured at localhost:9199 (fallback)',
        );
      } catch (e2, st2) {
        debugPrint(
          'FirebaseService: failed to configure Storage emulator on fallback: $e2',
        );
        debugPrint('$st2');
      }
    }
  }
}
