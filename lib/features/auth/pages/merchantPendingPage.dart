import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/theme/appColors.dart';
import '../../../core/theme/appRadius.dart';
import '../../../core/theme/appSpacing.dart';
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
    final user = auth.currentUser;
    if (user == null) return;
    await auth.reloadCurrentUser();
    final merchant = await context.read<FirestoreService>().getMerchantProfile(user.uid);
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
      icon: Icons.verified_user_rounded,
      children: [
        _StatusCard(status: _status),
        const SizedBox(height: AppSpacing.md),
        if (!_emailVerified && _status == 'pending')
          AuthPrimaryButton(
            labelKey: 'auth.email.resend',
            onPressed: () => context.read<AuthProvider>().sendVerificationAgain(),
          ),
        if (_status == 'approved') ...[
          FilledButton.icon(
            onPressed: () => context.go('/merchant/dashboard'),
            icon: const Icon(Icons.dashboard_rounded),
            label: Text(texts.text('auth.dashboard')),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _showSupport(context, texts),
          icon: const Icon(Icons.support_agent_rounded),
          label: Text(texts.text('auth.support')),
        ),
        const SizedBox(height: AppSpacing.sm),
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
    final content = _content(status, texts);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(content.icon, size: 34, color: AppColors.black),
          const SizedBox(height: AppSpacing.md),
          Text(
            content.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...content.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: const TextStyle(height: 1.45, color: AppColors.gray700)),
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
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Text(texts.text('auth.supportSoon')),
    ),
  );
}
