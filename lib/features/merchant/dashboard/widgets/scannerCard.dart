import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';

class ScannerCard extends StatelessWidget {
  const ScannerCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surface,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MerchantPremiumColors.surface,
              MerchantPremiumColors.baseElevated,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.30)),
          boxShadow: MerchantPremiumShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.28)),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: MerchantPremiumColors.gold,
                size: 31,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.text('merchant.dashboard.scanCustomer'),
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    texts.text('merchant.dashboard.scanCustomerTip'),
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: MerchantPremiumColors.gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: MerchantPremiumColors.goldSoft),
            ),
          ],
        ),
      ),
    );
  }
}
