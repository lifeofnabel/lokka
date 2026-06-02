import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/services/authService.dart';
import '../core/services/cloudinaryService.dart';
import '../core/services/firebaseService.dart';
import '../core/services/firestoreService.dart';
import '../core/services/languageService.dart';
import '../core/services/localCacheService.dart';
import '../core/services/qrService.dart';
import '../core/services/scannerService.dart';
import '../core/services/sessionService.dart';
import '../core/services/uploadService.dart';
import '../features/auth/providers/authProvider.dart';

class AppProviders extends StatelessWidget {
  const AppProviders({
    super.key,
    required this.languageService,
    required this.child,
  });

  final LanguageService languageService;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LanguageService>.value(value: languageService),
        Provider<FirebaseService>(create: (_) => const FirebaseService()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<LocalCacheService>(create: (_) => LocalCacheService()),
        ProxyProvider3<AuthService, FirestoreService, LocalCacheService, SessionService>(
          update: (_, authService, firestoreService, cacheService, __) =>
              SessionService(
            authService: authService,
            firestoreService: firestoreService,
            cacheService: cacheService,
          ),
        ),
        ChangeNotifierProxyProvider3<AuthService, FirestoreService,
            LanguageService, AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
            firestoreService: context.read<FirestoreService>(),
            languageService: context.read<LanguageService>(),
          ),
          update: (_, authService, firestoreService, languageService, previous) =>
              previous ??
              AuthProvider(
                authService: authService,
                firestoreService: firestoreService,
                languageService: languageService,
              ),
        ),
        Provider<CloudinaryService>(create: (_) => CloudinaryService()),
        Provider<QrService>(create: (_) => const QrService()),
        Provider<ScannerService>(create: (_) => const ScannerService()),
        ProxyProvider<CloudinaryService, UploadService>(
          update: (_, cloudinaryService, __) =>
              UploadService(cloudinaryService: cloudinaryService),
        ),
      ],
      child: child,
    );
  }
}
