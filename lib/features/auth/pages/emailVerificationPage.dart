import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../providers/authProvider.dart';
import '../services/authNavigation.dart';
import '../widgets/authFlowWidgets.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, required this.next});

  final String next;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  String? _statusKey;

  Future<void> _check() async {
    final destination = await context.read<AuthProvider>().reloadVerifyAndResolveDestination();
    if (!mounted) return;
    if (destination == null) {
      setState(() => _statusKey = 'auth.email.notYet');
      return;
    }
    context.go(pathForAuthDestination(destination));
  }

  void _continue() {
    context.go(widget.next == 'merchant' ? '/auth/merchantPending' : '/user/discover');
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<AuthProvider>();
    return AuthPageShell(
      titleKey: 'auth.email.title',
      subtitleKey: widget.next == 'merchant'
          ? 'auth.email.merchantSubtitle'
          : 'auth.email.subtitle',
      dark: widget.next == 'merchant',
      icon: Icons.mark_email_read_rounded,
      children: [
        AuthErrorBox(message: provider.error),
        const AuthWarningBox(messageKey: 'auth.email.warning'),
        if (_statusKey != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(texts.text(_statusKey!)),
          ),
        AuthPrimaryButton(
          labelKey: 'auth.email.resend',
          onPressed: () => context.read<AuthProvider>().sendVerificationAgain(),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _check,
          child: Text(texts.text('auth.email.checked')),
        ),
        TextButton(
          onPressed: _continue,
          child: Text(texts.text('auth.continue')),
        ),
      ],
    );
  }
}
