import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseService {
  const FirebaseService();

  bool get initialized => Firebase.apps.isNotEmpty;

  Future<FirebaseApp> initialize() {
    if (Firebase.apps.isNotEmpty) {
      return Future.value(Firebase.app());
    }
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Future<bool> healthCheck() async {
    return Firebase.apps.isNotEmpty;
  }
}
