import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantCatalogPage extends StatelessWidget {
  const MerchantCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.catalog.title'),
      subtitle: texts.text('merchant.catalog.subtitle'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.catalog.tooltip')),
      child: Column(
        children: [
          _CatalogPreviewHero(
            onTap: () {
              final merchantId = context.read<AuthService>().currentUser?.uid;
              if (merchantId == null || merchantId.isEmpty) return;
              context.push('/shop/$merchantId');
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _CatalogAction(
            icon: Icons.inventory_2_rounded,
            title: texts.text('merchant.catalog.items'),
            subtitle: texts.text('merchant.catalog.itemsSubtitle'),
            tooltip: texts.text('merchant.catalog.itemsTip'),
            onTap: () => context.push('/merchant/tools/items'),
          ),
          _CatalogAction(
            icon: Icons.category_rounded,
            title: texts.text('merchant.catalog.categories'),
            subtitle: texts.text('merchant.catalog.categoriesSubtitle'),
            tooltip: texts.text('merchant.catalog.categoriesTip'),
            onTap: () => context.push('/merchant/tools/categories'),
          ),
          _CatalogAction(
            icon: Icons.fact_check_rounded,
            title: texts.text('merchant.itemTags.title'),
            subtitle: texts.text('merchant.itemTags.subtitle'),
            tooltip: texts.text('merchant.itemTags.tooltip'),
            onTap: () => context.push('/merchant/tools/itemTags'),
          ),
          _CatalogAction(
            icon: Icons.table_bar_rounded,
            title: texts.text('merchant.catalog.tables'),
            subtitle: texts.text('merchant.catalog.tablesSubtitle'),
            tooltip: texts.text('merchant.catalog.tablesTip'),
            onTap: () => context.push('/merchant/tools/tables'),
          ),
          _CatalogAction(
            icon: Icons.receipt_long_rounded,
            title: texts.text('merchant.catalog.orders'),
            subtitle: texts.text('merchant.orders.subtitle'),
            tooltip: texts.text('merchant.catalog.ordersTip'),
            onTap: () => context.push('/merchant/orders'),
          ),
        ],
      ),
    );
  }
}

class _CatalogPreviewHero extends StatelessWidget {
  const _CatalogPreviewHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.ink,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MerchantPremiumColors.ink,
              MerchantPremiumColors.baseElevated,
            ],
          ),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.20)),
          boxShadow: MerchantPremiumShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.phone_iphone_rounded, color: MerchantPremiumColors.goldSoft),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.text('merchant.catalog.previewTitle'),
                    style: const TextStyle(
                      color: MerchantPremiumColors.surface,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    texts.text('merchant.catalog.previewSubtitle'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MerchantPremiumColors.mutedLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.coral,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogAction extends StatelessWidget {
  const _CatalogAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: MerchantPremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.goldSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: MerchantPremiumColors.ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: tooltip,
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: MerchantPremiumColors.muted,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: MerchantPremiumColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
