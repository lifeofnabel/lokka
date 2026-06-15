import 'package:flutter/material.dart';

import '../../../core/theme/appColors.dart';

class AuthLoadingPage extends StatelessWidget {
  const AuthLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surfaceBg,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
