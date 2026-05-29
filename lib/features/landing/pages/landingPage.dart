import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../../../core/theme/appColors.dart';
import '../../../core/theme/appRadius.dart';
import '../../../core/theme/appShadows.dart';
import '../../../core/theme/appSpacing.dart';
import '../../../core/theme/appTextStyles.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      _Logo(texts: texts),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/dev/foundation'),
                        child: Text(texts.text('landing.devLink')),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    texts.text('landing.headline'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.black,
                      fontSize: 42,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    texts.text('landing.subline'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _WalletMockup(),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: () => context.go('/auth/userLogin'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(texts.text('landing.login')),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.go('/auth/userRegister'),
                    child: Text(texts.text('landing.register')),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/auth/demoComingSoon'),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: Text(texts.text('landing.demo')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () => context.go('/auth/merchantLogin'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gray500,
                    ),
                    child: Text(texts.text('landing.merchantLogin')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.texts});

  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          texts.text('app.name'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _WalletMockup extends StatelessWidget {
  const _WalletMockup();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.mintSoft,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_offer_rounded,
                        color: AppColors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Lokka'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  texts.text('landing.walletTitle'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  texts.text('landing.walletSubtitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.gray700,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: List.generate(
                    5,
                    (index) => Expanded(
                      child: Container(
                        height: 12,
                        margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
                        decoration: BoxDecoration(
                          color: index < 3 ? AppColors.mintStrong : AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
