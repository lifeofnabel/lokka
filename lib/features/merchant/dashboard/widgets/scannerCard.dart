import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';

class ScannerCard extends StatelessWidget {
  const ScannerCard({super.key, required this.onTap, this.comingSoon = false});

  final VoidCallback onTap;

  /// Scanner ist noch nicht angebunden – sekundär/kleiner darstellen und klar
  /// als „Demnächst" kennzeichnen, statt als gleichwertige Primäraktion (#233).
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: MerchantPremiumColors.line),
          boxShadow: MerchantPremiumShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.22)),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: MerchantPremiumColors.gold,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          texts.text('merchant.dashboard.scanCustomer'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MerchantPremiumColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      if (comingSoon) ...[
                        const SizedBox(width: 8),
                        const _ComingSoonBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    texts.text('merchant.dashboard.scanCustomerTip'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      height: 1.25,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: MerchantPremiumColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.32)),
      ),
      child: Text(
        texts.text('merchant.features.comingSoon'),
        style: const TextStyle(
          color: MerchantPremiumColors.gold,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
