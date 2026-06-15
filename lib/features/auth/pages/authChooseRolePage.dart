import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../providers/authProvider.dart';
import '../widgets/authFlowWidgets.dart';

class AuthChooseRolePage extends StatefulWidget {
  const AuthChooseRolePage({super.key});

  @override
  State<AuthChooseRolePage> createState() => _AuthChooseRolePageState();
}

class _AuthChooseRolePageState extends State<AuthChooseRolePage> {
  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;

  Future<void> _chooseUser() async {
    final destination = await context.read<AuthProvider>().createGoogleUserProfile(
          acceptedTerms: _terms,
          acceptedPrivacy: _privacy,
          marketingConsent: _marketing,
        );
    if (mounted && destination == AuthDestination.userDiscover) {
      context.go('/user/discover');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    final texts = context.watch<LanguageService>();
    return AuthPageShell(
      titleKey: 'auth.chooseRole.title',
      subtitleKey: 'auth.chooseRole.subtitle',
      children: [
        AuthErrorBox(message: provider.error),
        AuthCheck(
          value: _terms,
          onChanged: (value) => setState(() => _terms = value),
          labelKey: 'auth.acceptTerms',
        ),
        AuthCheck(
          value: _privacy,
          onChanged: (value) => setState(() => _privacy = value),
          labelKey: 'auth.acceptPrivacy',
        ),
        AuthCheck(
          value: _marketing,
          onChanged: (value) => setState(() => _marketing = value),
          labelKey: 'auth.acceptMarketing',
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          labelKey: 'auth.chooseRole.user',
          onPressed: _chooseUser,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.go('/auth/merchantRegister'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.storefront_rounded),
          label: Text(texts.text('auth.chooseRole.merchant')),
        ),
      ],
    );
  }
}
