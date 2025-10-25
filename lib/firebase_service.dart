import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      } else {
        rethrow;
      }
    }
  }

  FirebaseAuth get auth => FirebaseAuth.instance;
}
