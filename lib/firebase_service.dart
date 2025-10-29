import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

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

      if (kDebugMode) {
        debugPrint(
          'FirebaseService: Debug mode detected, configuring for development',
        );
        // Disable reCAPTCHA verification for testing
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
          forceRecaptchaFlow: false,
        );
        // Configure emulators
        await _configureEmulatorsIfNeeded();
      }
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
      // Note: for a physical Android device you must set EMULATOR_HOST to
      // the host machine's LAN IP (e.g. 192.168.x.x). The default of
      // '10.0.2.2' only works for the Android emulator.
      const envHost = String.fromEnvironment('EMULATOR_HOST');
      debugPrint('FirebaseService: EMULATOR_HOST from environment: "$envHost"');
      debugPrint('FirebaseService: Platform.isAndroid: ${Platform.isAndroid}');

      // TEMPORARY: Hardcoded for physical device testing
      // TODO: Remove this and use --dart-define=EMULATOR_HOST once launch config works
      final defaultHost = Platform.isAndroid ? '192.168.1.12' : 'localhost';

      final host = envHost.isNotEmpty ? envHost : defaultHost;
      debugPrint('FirebaseService: Using host: $host (envHost.isNotEmpty=${envHost.isNotEmpty})');

      // Auth emulator (default 9099)
      try {
        const authPort = 9099;
        debugPrint(
          'FirebaseService: Configuring Auth emulator with host=$host, port=$authPort',
        );

        // Ensure app-verification is disabled in debug before any auth ops.
        // This helps avoid reCAPTCHA flows when talking to the Auth emulator.
        try {
          await FirebaseAuth.instance.setSettings(
            appVerificationDisabledForTesting: true,
          );
          debugPrint('FirebaseService: Disabled app verification for testing');
        } catch (e) {
          debugPrint(
            'FirebaseService: setSettings(appVerificationDisabledForTesting) failed: $e',
          );
        }

        // Clear any existing persistence data if supported on this platform.
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.NONE);
          debugPrint('FirebaseService: Cleared FirebaseAuth persistence');
        } catch (e) {
          // setPersistence may not be supported on every platform; log and continue.
          debugPrint(
            'FirebaseService: setPersistence not supported or failed: $e',
          );
        }

        // Configure auth emulator
        await FirebaseAuth.instance.useAuthEmulator(host, authPort);

        // --- REPLACED DEPRECATED CALL ---
        // Old code used fetchSignInMethodsForEmail which is deprecated.
        // Use an anonymous sign-in connectivity check instead. This creates
        // a transient anonymous account which we attempt to delete immediately.
        try {
          final userCred = await FirebaseAuth.instance
              .signInAnonymously()
              .timeout(const Duration(seconds: 5));
          debugPrint(
            'FirebaseService: Auth emulator reachable via anonymous sign-in (uid=${userCred.user?.uid})',
          );
          // Clean up the created anonymous account
          try {
            await userCred.user?.delete();
            debugPrint('FirebaseService: deleted test anonymous user');
          } catch (e) {
            debugPrint(
              'FirebaseService: failed to delete anonymous user (non-fatal): $e',
            );
          }
        } catch (e) {
          debugPrint(
            'FirebaseService: Auth emulator anonymous sign-in test failed (non-fatal): $e',
          );
        }
        // --- END replacement ---

        debugPrint(
          'FirebaseService: Auth emulator successfully configured at $host:$authPort',
        );
      } catch (e, st) {
        debugPrint('FirebaseService: failed to configure Auth emulator: $e');
        debugPrint('$st');
        // Don't rethrow here - keep initialization resilient. The caller
        // can detect emulator absence by log messages and switch strategies.
        debugPrint('FirebaseService: ⚠️ Continuing without Auth emulator');
      }

      // Firestore emulator (default 8080)
      try {
        const firestorePort = 8080;
        debugPrint(
          'FirebaseService: Configuring Firestore emulator with host=$host, port=$firestorePort',
        );
        FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
        debugPrint(
          'FirebaseService: Firestore emulator successfully configured at $host:$firestorePort',
        );
      } catch (e, st) {
        debugPrint('FirebaseService: failed to configure Firestore emulator: $e');
        debugPrint('$st');
        debugPrint('FirebaseService: ⚠️ Continuing without Firestore emulator');
      }

      // Storage emulator (default 9199)
      try {
        const storagePort = 9199;
        debugPrint(
          'FirebaseService: Configuring Storage emulator with host=$host, port=$storagePort',
        );
        FirebaseStorage.instance.useStorageEmulator(host, storagePort);
        debugPrint(
          'FirebaseService: Storage emulator successfully configured at $host:$storagePort',
        );
      } catch (e, st) {
        debugPrint('FirebaseService: failed to configure Storage emulator: $e');
        debugPrint('$st');
        debugPrint('FirebaseService: ⚠️ Continuing without Storage emulator');
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
