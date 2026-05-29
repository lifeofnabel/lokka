import 'package:flutter/material.dart';

import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appShadows.dart';
import '../../../../core/theme/appSpacing.dart';

class ScannerCard extends StatelessWidget {
  const ScannerCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.09),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.white.withOpacity(0.12)),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.mint, size: 31),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kunde scannen',
                    style: TextStyle(color: AppColors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Punkte, Stempel oder Bestellung pruefen',
                    style: TextStyle(color: Color(0xFFD7DED6), height: 1.25, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: AppColors.black),
            ),
          ],
        ),
      ),
    );
  }
}
