import 'package:flutter/material.dart';

import '../core/constants/appStrings.dart';
import '../core/services/languageService.dart';
import '../core/theme/appTheme.dart';
import 'appProviders.dart';
import 'appRouter.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    this.startupError,
    this.startupStackTrace,
  });

  final Object? startupError;
  final StackTrace? startupStackTrace;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LanguageService>(
      future: LanguageService.loadDefault(),
      builder: (context, snapshot) {
        final languageService = snapshot.data ?? LanguageService.fallback();

        return AppProviders(
          languageService: languageService,
          child: MaterialApp.router(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
            builder: (context, child) {
              if (startupError != null) {
                return _StartupErrorView(error: startupError);
              }
              return child ?? const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAFBF8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 42),
                const SizedBox(height: 16),
                Text(
                  'Lokka konnte nicht gestartet werden.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error?.toString() ?? 'Unbekannter Fehler',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
