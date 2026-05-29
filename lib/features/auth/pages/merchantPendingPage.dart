import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../providers/authProvider.dart';
import '../widgets/authFlowWidgets.dart';

class MerchantPendingPage extends StatefulWidget {
  const MerchantPendingPage({super.key, this.status});

  final String? status;

  @override
  State<MerchantPendingPage> createState() => _MerchantPendingPageState();
}

class _MerchantPendingPageState extends State<MerchantPendingPage> {
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _status = widget.status ?? 'pending';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  Future<void> _loadStatus() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    final merchant = await context.read<FirestoreService>().getMerchantProfile(user.uid);
    final status = merchant?['verificationStatus'] as String?;
    if (mounted && status != null) setState(() => _status = status);
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return AuthPageShell(
      titleKey: 'auth.merchantPending.title',
      subtitleKey: 'auth.merchantPending.$_status',
      dark: true,
      icon: Icons.verified_user_rounded,
      children: [
        AuthPrimaryButton(
          labelKey: 'auth.email.resend',
          onPressed: () => context.read<AuthProvider>().sendVerificationAgain(),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {},
          child: Text(texts.text('auth.support')),
        ),
        const SizedBox(height: 12),
        if (_status == 'approved')
          FilledButton(
            onPressed: () => context.go('/merchant/dashboard'),
            child: Text(texts.text('auth.dashboard')),
          ),
        TextButton(
          onPressed: _signOut,
          child: Text(texts.text('auth.signOut')),
        ),
      ],
    );
  }
}
