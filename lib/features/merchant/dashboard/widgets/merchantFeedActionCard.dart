import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';

class MerchantFeedActionCard extends StatelessWidget {
  const MerchantFeedActionCard({
    super.key,
    required this.onCreateTap,
    required this.onManageTap,
  });

  final VoidCallback onCreateTap;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.goldSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.campaign_rounded, color: MerchantPremiumColors.ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texts.text('merchant.dashboard.startPost'),
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: texts.text('merchant.feedCreate.tooltip'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: MerchantPremiumColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: MerchantPremiumColors.line),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: MerchantPremiumColors.muted,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCreateTap,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(texts.text('merchant.feedCreate.title')),
                  style: FilledButton.styleFrom(
                    backgroundColor: MerchantPremiumColors.coral,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onManageTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MerchantPremiumColors.ink,
                  minimumSize: const Size(112, 52),
                  side: const BorderSide(color: MerchantPremiumColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(texts.text('merchant.feedManage.shortTitle')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
