import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../providers/authProvider.dart';
import '../widgets/authFlowWidgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final texts = context.read<LanguageService>();
    final error = validateRequiredAuth(
      texts: texts,
      values: [_email.text],
      email: _email.text,
    );
    if (error != null) {
      setState(() => _localError = error);
      return;
    }
    await context.read<AuthProvider>().resetPassword(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    final texts = context.watch<LanguageService>();
    return AuthPageShell(
      titleKey: 'auth.forgotPassword.title',
      subtitleKey: 'auth.forgotPassword.subtitle',
      icon: Icons.lock_reset_rounded,
      children: [
        AuthErrorBox(message: _localError ?? provider.error),
        if (provider.message != null) const AuthWarningBox(messageKey: 'auth.reset.sent'),
        AuthTextField(
          controller: _email,
          labelKey: 'auth.email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 4),
        AuthPrimaryButton(labelKey: 'auth.reset.button', onPressed: _send),
        TextButton(
          onPressed: () => context.go('/auth/userLogin'),
          child: Text(texts.text('auth.backToLogin')),
        ),
      ],
    );
  }
}
