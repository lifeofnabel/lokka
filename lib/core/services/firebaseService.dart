import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseService {
  const FirebaseService();

  Future<FirebaseApp> initialize() {
    if (Firebase.apps.isNotEmpty) {
      return Future.value(Firebase.app());
    }
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
