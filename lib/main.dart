import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'core/services/authService.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Saubere, teilbare URLs ohne `#` (z. B. example.com/lokka für ein Merchant-
  // Profil). Firebase-Hosting hat bereits den `** → /index.html`-Rewrite, daher
  // brechen Deep-Links/Refresh nicht. Nur Web; sonst No-Op.
  if (kIsWeb) usePathUrlStrategy();

  Object? startupError;
  StackTrace? startupStackTrace;

  try {
    await dotenv.load(fileName: '.env', isOptional: true);
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Offline-Persistence + unbegrenzter lokaler Cache: schnellere Kaltstarts
    // (Lesen aus dem Cache) und spürbar weniger Firestore-Reads/Kosten. Muss
    // vor dem ersten Firestore-Zugriff gesetzt werden.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    await AuthService.configurePersistence();
  } catch (error, stackTrace) {
    startupError = error;
    startupStackTrace = stackTrace;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'lokka startup',
      ),
    );
  }

  runApp(
    App(
      startupError: startupError,
      startupStackTrace: startupStackTrace,
    ),
  );
}
