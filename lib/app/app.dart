import 'package:flutter/material.dart';

import '../core/constants/appStrings.dart';
import '../core/theme/appTheme.dart';
import 'appProviders.dart';
import 'appRouter.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      child: MaterialApp.router(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
