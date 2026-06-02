import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';

class MerchantModuleCard extends StatelessWidget {
  const MerchantModuleCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final foreground = isActive ? AppColors.white : AppColors.black;
    final muted = isActive ? const Color(0xFFC9D1CB) : AppColors.gray500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive ? AppColors.black : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: isActive ? AppColors.black : AppColors.border),
          boxShadow: [
            if (isActive)
              const BoxShadow(
                color: Color(0x24171A18),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.mint.withOpacity(0.16) : AppColors.gray50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: isActive ? AppColors.mint : AppColors.gray700),
                ),
                const Spacer(),
                Tooltip(
                  message: description,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: isActive ? AppColors.white.withOpacity(0.72) : AppColors.gray500,
                  ),
                ),
                const SizedBox(width: 6),
                _StatusPill(
                  label: isActive ? (badge ?? texts.text('common.active')) : texts.text('merchant.features.disabled'),
                  isActive: isActive,
                  isBadge: isActive && badge != null,
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(isActive ? texts.text('common.ready') : texts.text('merchant.dashboard.disabledShort'), style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.isActive,
    required this.isBadge,
  });

  final String label;
  final bool isActive;
  final bool isBadge;

  @override
  Widget build(BuildContext context) {
    final background = isBadge
        ? AppColors.mint
        : isActive
            ? AppColors.white.withOpacity(0.12)
            : AppColors.gray50;
    final color = isBadge
        ? AppColors.black
        : isActive
            ? AppColors.white
            : AppColors.gray700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isActive ? AppColors.white.withOpacity(0.12) : AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}
