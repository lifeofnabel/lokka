import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/services/sessionService.dart';
import '../../../core/theme/appColors.dart';

class AuthRoleGatePage extends StatefulWidget {
  const AuthRoleGatePage({super.key});

  @override
  State<AuthRoleGatePage> createState() => _AuthRoleGatePageState();
}

class _AuthRoleGatePageState extends State<AuthRoleGatePage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    try {
      final auth = context.read<AuthService>();
      final firestore = context.read<FirestoreService>();
      final session = context.read<SessionService>();
      final user = auth.currentUser;
      if (user == null) {
        context.go('/auth/userLogin');
        return;
      }

      final profile = await firestore.getUserProfile(user.uid);
      if (!mounted) return;
      if (profile == null) {
        context.go('/auth/chooseRole');
        return;
      }

      await session.markLastSeenIfNeeded();
      if (!mounted) return;

      if (profile['role'] == 'user') {
        context.go('/user/discover');
        return;
      }

      if (profile['role'] == 'merchant') {
        final merchant = await firestore.getMerchantProfile(user.uid);
        if (!mounted) return;
        final status = merchant?['verificationStatus'] as String? ?? 'pending';
        if (status == 'approved') {
          context.go('/merchant/dashboard');
        } else {
          context.go('/auth/merchantPending?status=$status');
        }
        return;
      }

      context.go('/auth/chooseRole');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  texts.text('auth.roleGate.title'),
                  textAlign: TextAlign.center,
                  style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
