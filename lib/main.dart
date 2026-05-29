import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  StackTrace? startupStackTrace;

  try {
    await dotenv.load(fileName: '.env', isOptional: true);
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
