import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantComingSoonPage extends StatelessWidget {
  const MerchantComingSoonPage({
    super.key,
    required this.titleKey,
    required this.subtitleKey,
    required this.tooltipKey,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String titleKey;
  final String subtitleKey;
  final String tooltipKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text(titleKey),
      subtitle: texts.text(subtitleKey),
      backPath: '/merchant/dashboard',
      trailing: MerchantInfoTooltip(message: texts.text(tooltipKey)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: MerchantPremiumColors.ink,
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              boxShadow: MerchantPremiumShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  texts.text(titleKey),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  texts.text(tooltipKey),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantPrimaryButton(
            label: texts.text('merchant.dashboard.title'),
            icon: Icons.dashboard_rounded,
            onPressed: () => context.go('/merchant/dashboard'),
          ),
        ],
      ),
    );
  }
}
