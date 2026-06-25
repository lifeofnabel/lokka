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
    // Primär-Aktion an der Kasse → bewusst die AUFFÄLLIGSTE Karte: gefüllter
    // Marken-Grün-Verlauf + größeres Icon + Glow, hebt sich klar von den
    // dunklen Surface-Karten ab.
    return Semantics(
      button: true,
      label: texts.text('merchant.dashboard.scanCustomer'),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          child: Ink(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2FB389), Color(0xFF0E3A2C)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(
                  color: MerchantPremiumColors.gold.withValues(alpha: 0.55),
                  width: 1.5),
              boxShadow: [
                // Grüner Glow + Tiefe → „leuchtet" gegenüber den anderen Karten.
                BoxShadow(
                  color: const Color(0xFF2FB389).withValues(alpha: 0.34),
                  blurRadius: 28,
                  spreadRadius: -4,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30)),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 32,
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
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
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
                        // 14px bold auf Grün = „large text" → AA erfüllt.
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.25,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
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
