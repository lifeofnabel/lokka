import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../providers/authProvider.dart';
import '../services/authNavigation.dart';
import '../widgets/authFlowWidgets.dart';
import '../widgets/legalSheet.dart';

class UserRegisterPage extends StatefulWidget {
  const UserRegisterPage({super.key});

  @override
  State<UserRegisterPage> createState() => _UserRegisterPageState();
}

class _UserRegisterPageState extends State<UserRegisterPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;
  String? _localError;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final texts = context.read<LanguageService>();
    final error = validateRequiredAuth(
      texts: texts,
      values: [_firstName.text, _lastName.text, _email.text, _password.text],
      email: _email.text,
      password: _password.text,
      checksRequired: true,
      checksAccepted: _terms && _privacy, // AGB + Datenschutz Pflicht; Marketing optional
    );
    if (error != null) {
      setState(() => _localError = error);
      return;
    }

    final destination = await context.read<AuthProvider>().registerUser(
          firstName: _firstName.text,
          lastName: _lastName.text,
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AuthPageShell(
      titleKey: 'auth.userRegister.title',
      subtitleKey: 'auth.userRegister.subtitle',
      icon: Icons.person_add_alt_1_rounded,
      children: [
        AuthErrorBox(message: _localError ?? provider.error),

        // Name nebeneinander
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AuthTextField(
                controller: _firstName,
                labelKey: 'auth.firstName',
                required: true,
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                onSubmitted: (_) => _lastNameFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AuthTextField(
                controller: _lastName,
                focusNode: _lastNameFocus,
                labelKey: 'auth.lastName',
                required: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                onSubmitted: (_) => _emailFocus.requestFocus(),
              ),
            ),
          ],
        ),
        AuthTextField(
          controller: _email,
          focusNode: _emailFocus,
          labelKey: 'auth.email',
          required: true,
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        AuthTextField(
          controller: _password,
          focusNode: _passwordFocus,
          labelKey: 'auth.password',
          required: true,
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _register(),
        ),

        const SizedBox(height: 8),
        Text(
          '* Pflichtfeld',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        // Pflicht-Einwilligungen mit Link auf die Dokumente
        AuthConsentCheck(
          value: _terms,
          onChanged: (v) => setState(() => _terms = v),
          leading: 'Ich akzeptiere die ',
          linkLabel: 'AGB',
          trailing: ' *',
          onLinkTap: () => showLegalSheet(context, 'assets/legal/agb.json'),
        ),
        AuthConsentCheck(
          value: _privacy,
          onChanged: (v) => setState(() => _privacy = v),
          leading: 'Ich akzeptiere die ',
          linkLabel: 'Datenschutzhinweise',
          trailing: ' *',
          onLinkTap: () =>
              showLegalSheet(context, 'assets/legal/datenschutz.json'),
        ),
        AuthCheck(
          value: _marketing,
          onChanged: (value) => setState(() => _marketing = value),
          labelKey: 'auth.acceptMarketing',
        ),

        const SizedBox(height: 14),
        AuthPrimaryButton(
          labelKey: 'auth.register.button',
          onPressed: _register,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Schon ein Konto?',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            TextButton(
              onPressed: () => context.go('/auth/userLogin'),
              child: const Text('Einloggen'),
            ),
          ],
        ),
      ],
    );
  }
}
