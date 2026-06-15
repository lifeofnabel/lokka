import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../providers/authProvider.dart';
import '../widgets/authFlowWidgets.dart';

class MerchantForgotPasswordPage extends StatefulWidget {
  const MerchantForgotPasswordPage({super.key});

  @override
  State<MerchantForgotPasswordPage> createState() => _MerchantForgotPasswordPageState();
}

class _MerchantForgotPasswordPageState extends State<MerchantForgotPasswordPage> {
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
      titleKey: 'auth.merchantForgotPassword.title',
      subtitleKey: 'auth.merchantForgotPassword.subtitle',
      dark: true,
      icon: Icons.lock_reset_rounded,
      children: [
        AuthErrorBox(message: _localError ?? provider.error),
        if (provider.message != null) const AuthWarningBox(messageKey: 'auth.reset.sent'),
        AuthTextField(
          controller: _email,
          labelKey: 'auth.email',
          keyboardType: TextInputType.emailAddress,
        ),
        AuthPrimaryButton(labelKey: 'auth.reset.button', onPressed: _send),
        TextButton(
          onPressed: () => context.go('/auth/merchantLogin'),
          child: Text(texts.text('auth.backToMerchantLogin')),
        ),
      ],
    );
  }
}
