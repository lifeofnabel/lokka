import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/theme/appColors.dart';
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
  bool _emailVerified = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status ?? 'pending';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  Future<void> _loadStatus() async {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final user = auth.currentUser;
    if (user == null) return;
    await auth.reloadCurrentUser();
    final merchant = await firestore.getMerchantProfile(user.uid);
    final status = merchant?['verificationStatus'] as String?;
    if (!mounted) return;
    setState(() {
      _status = status ?? _status;
      _emailVerified = auth.currentUser?.emailVerified ?? false;
    });
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
      subtitleKey: 'auth.merchantPending.subtitle',
      dark: true,
      icon: Icons.verified_user_rounded,
      children: [
        _StatusCard(status: _status),
        const SizedBox(height: 16),
        if (!_emailVerified && _status == 'pending')
          AuthPrimaryButton(
            labelKey: 'auth.email.resend',
            onPressed: () => context.read<AuthProvider>().sendVerificationAgain(),
          ),
        if (_status == 'approved')
          FilledButton.icon(
            onPressed: () => context.go('/merchant/dashboard'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.dashboard_rounded),
            label: Text(texts.text('auth.dashboard')),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _showSupport(context, texts),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.support_agent_rounded),
          label: Text(texts.text('auth.support')),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _signOut,
          child: Text(texts.text('auth.signOut')),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final content = _content(status, texts);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(content.icon, color: cs.onSecondaryContainer, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            content.title,
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...content.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: tt.bodyMedium?.copyWith(
                  height: 1.45,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

({String title, List<String> lines, IconData icon}) _content(
  String status,
  LanguageService texts,
) {
  return switch (status) {
    'approved' => (
        title: texts.text('auth.merchantPending.approvedTitle'),
        lines: [texts.text('auth.merchantPending.approvedLine')],
        icon: Icons.check_circle_rounded,
      ),
    'rejected' => (
        title: texts.text('auth.merchantPending.rejectedTitle'),
        lines: [texts.text('auth.merchantPending.rejectedLine')],
        icon: Icons.cancel_rounded,
      ),
    'blocked' => (
        title: texts.text('auth.merchantPending.blockedTitle'),
        lines: [texts.text('auth.merchantPending.blockedLine')],
        icon: Icons.block_rounded,
      ),
    'paused' => (
        title: texts.text('auth.merchantPending.pausedTitle'),
        lines: [texts.text('auth.merchantPending.pausedLine')],
        icon: Icons.pause_circle_rounded,
      ),
    _ => (
        title: texts.text('auth.merchantPending.pendingTitle'),
        lines: [
          texts.text('auth.merchantPending.pendingLine1'),
          texts.text('auth.merchantPending.pendingLine2'),
          texts.text('auth.merchantPending.pendingLine3'),
        ],
        icon: Icons.hourglass_top_rounded,
      ),
  };
}

void _showSupport(BuildContext context, LanguageService texts) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.support_agent_rounded,
                    color: cs.onSecondaryContainer, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                texts.text('auth.support'),
                textAlign: TextAlign.center,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                texts.text('auth.supportSoon'),
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
