import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../widgets/authFlowWidgets.dart';

class DemoComingSoonPage extends StatelessWidget {
  const DemoComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return AuthPageShell(
      titleKey: 'auth.demo.title',
      subtitleKey: 'auth.demo.subtitle',
      icon: Icons.play_circle_outline_rounded,
      children: [
        FilledButton(
          onPressed: () => context.go('/'),
          child: Text(texts.text('auth.demo.back')),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/auth/userLogin'),
          child: Text(texts.text('landing.login')),
        ),
      ],
    );
  }
}
