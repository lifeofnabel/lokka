import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../providers/authProvider.dart';
import '../services/authNavigation.dart';
import '../widgets/authFlowWidgets.dart';

class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _localError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
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

    final provider = context.read<AuthProvider>();
    final destination = await provider.signInUser(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted || destination == null) return;
    if (provider.currentUser?.emailVerified == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageService>().text('auth.email.warning'),
          ),
        ),
      );
    }
    context.go(pathForAuthDestination(destination));
  }

  @override
  Widget build(BuildContext context) {
    final scopedProvider = context.watch<AuthProvider>();
    final texts = context.watch<LanguageService>();
    return AuthPageShell(
      titleKey: 'auth.userLogin.title',
      subtitleKey: 'auth.userLogin.subtitle',
      icon: Icons.lock_open_rounded,
      children: [
        AuthErrorBox(message: _localError ?? scopedProvider.error),
        AuthTextField(
          controller: _email,
          focusNode: _emailFocus,
          labelKey: 'auth.email',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        AuthTextField(
          controller: _password,
          focusNode: _passwordFocus,
          labelKey: 'auth.password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _login(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.go('/auth/forgotPassword'),
            child: Text(texts.text('auth.forgot.link')),
          ),
        ),
        const SizedBox(height: 4),
        AuthPrimaryButton(
          labelKey: 'auth.login.button',
          onPressed: _login,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Noch kein Konto?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            TextButton(
              onPressed: () => context.go('/auth/userRegister'),
              child: const Text('Konto erstellen'),
            ),
          ],
        ),
      ],
    );
  }
}
