import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../services/merchantDashboardService.dart';
import 'merchantMetricCard.dart';

class MerchantTodaySummarySheet extends StatelessWidget {
  const MerchantTodaySummarySheet({super.key, required this.data});

  final MerchantDashboardData data;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    // textScale-bewusste feste Höhe statt fixem AspectRatio, damit große
    // Schriften nicht überlaufen (#250).
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final cardExtent = 84.0 * textScale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texts.text('merchant.dashboard.today'),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            texts.text('merchant.dashboard.todaySubtitle'),
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: cardExtent,
            ),
            children: [
              MerchantMetricCard(label: texts.text('merchant.customers.title'), value: data.metrics.customers.toString(), icon: Icons.groups_rounded),
              MerchantMetricCard(label: texts.text('merchant.feedManage.shortTitle'), value: data.metrics.feedPosts.toString(), icon: Icons.campaign_rounded),
              MerchantMetricCard(label: texts.text('merchant.stamps.title'), value: data.metrics.stampCards.toString(), icon: Icons.loyalty_rounded),
              MerchantMetricCard(label: texts.text('merchant.dashboard.modules'), value: data.metrics.activeModules.toString(), icon: Icons.extension_rounded),
            ],
          ),
        ],
      ),
    );
  }
}
