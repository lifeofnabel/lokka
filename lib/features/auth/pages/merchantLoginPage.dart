import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../providers/authProvider.dart';
import '../services/authNavigation.dart';
import '../widgets/authFlowWidgets.dart';

class MerchantLoginPage extends StatefulWidget {
  const MerchantLoginPage({super.key});

  @override
  State<MerchantLoginPage> createState() => _MerchantLoginPageState();
}

class _MerchantLoginPageState extends State<MerchantLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final texts = context.read<LanguageService>();
    final error = validateRequiredAuth(
      texts: texts,
      values: [_email.text, _password.text],
      email: _email.text,
      password: _password.text,
    );
    if (error != null) {
      setState(() => _localError = error);
      return;
    }

    final destination = await context.read<AuthProvider>().signInMerchant(
          email: _email.text,
          password: _password.text,
        );
    if (mounted && destination != null) {
      context.go(pathForAuthDestination(destination));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    return AuthPageShell(
            titleKey: 'auth.merchantLogin.title',
            subtitleKey: 'auth.merchantLogin.subtitle',
            dark: true,
            icon: Icons.storefront_rounded,
            children: [
              AuthErrorBox(message: _localError ?? provider.error),
              AuthTextField(
                controller: _email,
                labelKey: 'auth.email',
                keyboardType: TextInputType.emailAddress,
              ),
              AuthTextField(
                controller: _password,
                labelKey: 'auth.password',
                obscureText: true,
              ),
              AuthPrimaryButton(
                labelKey: 'auth.merchantLogin.button',
                onPressed: _login,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => context.go('/auth/merchantForgotPassword'),
                child: Text(context.watch<LanguageService>().text('auth.forgot.link')),
              ),
              TextButton(
                onPressed: () => context.go('/auth/merchantRegister'),
                child: Text(context.watch<LanguageService>().text('auth.merchantRegister.link')),
              ),
            ],
    );
  }
}
