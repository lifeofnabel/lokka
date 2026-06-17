import 'package:flutter/material.dart';

class MerchantFeatureModule {
  const MerchantFeatureModule({
    required this.key,
    required this.titleKey,
    required this.tooltipKey,
    required this.icon,
    this.isRequired = false,
    this.comingSoon = false,
    this.releaseKey,
    this.options = const [],
  });

  final String key;
  final String titleKey;
  final String tooltipKey;
  final IconData icon;
  final bool isRequired;
  final bool comingSoon;
  final String? releaseKey;
  final List<MerchantFeatureOption> options;
}

class MerchantFeatureOption {
  const MerchantFeatureOption({
    required this.key,
    required this.titleKey,
    required this.tooltipKey,
    required this.icon,
  });

  final String key;
  final String titleKey;
  final String tooltipKey;
  final IconData icon;
}

const merchantFeatureModules = [
  MerchantFeatureModule(
    key: 'feedPosts',
    titleKey: 'merchant.features.feedPosts',
    tooltipKey: 'merchant.features.feedPostsTip',
    icon: Icons.dynamic_feed_rounded,
    isRequired: true,
  ),
  MerchantFeatureModule(
    key: 'stampCards',
    titleKey: 'merchant.features.stampCards',
    tooltipKey: 'merchant.features.stampCardsTip',
    icon: Icons.loyalty_rounded,
  ),
  MerchantFeatureModule(
    key: 'pointsSystems',
    titleKey: 'merchant.features.pointsSystems',
    tooltipKey: 'merchant.features.pointsSystemsTip',
    icon: Icons.stars_rounded,
  ),
  MerchantFeatureModule(
    key: 'menuCatalog',
    titleKey: 'merchant.features.catalog',
    tooltipKey: 'merchant.features.catalogTip',
    icon: Icons.menu_book_rounded,
    options: [
      MerchantFeatureOption(
        key: 'catalogOnly',
        titleKey: 'merchant.features.catalogOnly',
        tooltipKey: 'merchant.features.catalogOnlyTip',
        icon: Icons.visibility_rounded,
      ),
      // Bestell-Modi (mind. 1 Pflicht; Runner & Nur-Karte exklusiv).
      MerchantFeatureOption(
        key: 'catalogModeRunner',
        titleKey: 'merchant.features.catalogModeRunner',
        tooltipKey: 'merchant.features.catalogModeRunnerTip',
        icon: Icons.directions_run_rounded,
      ),
      MerchantFeatureOption(
        key: 'catalogModeTable',
        titleKey: 'merchant.features.catalogModeTable',
        tooltipKey: 'merchant.features.catalogModeTableTip',
        icon: Icons.table_bar_rounded,
      ),
      MerchantFeatureOption(
        key: 'catalogModeCashier',
        titleKey: 'merchant.features.catalogModeCashier',
        tooltipKey: 'merchant.features.catalogModeCashierTip',
        icon: Icons.point_of_sale_rounded,
      ),
      MerchantFeatureOption(
        key: 'catalogModeMenuOnly',
        titleKey: 'merchant.features.catalogModeMenuOnly',
        tooltipKey: 'merchant.features.catalogModeMenuOnlyTip',
        icon: Icons.menu_book_rounded,
      ),
    ],
  ),
  MerchantFeatureModule(
    key: 'coupons',
    titleKey: 'merchant.features.couponsPortal',
    tooltipKey: 'merchant.features.couponsTip',
    icon: Icons.confirmation_number_rounded,
    comingSoon: true,
    releaseKey: 'merchant.features.release.midOctober',
  ),
  MerchantFeatureModule(
    key: 'campaigns',
    titleKey: 'merchant.features.campaigns',
    tooltipKey: 'merchant.features.campaignsTip',
    icon: Icons.emoji_events_rounded,
    comingSoon: true,
    releaseKey: 'merchant.features.release.midOctober',
  ),
  MerchantFeatureModule(
    key: 'shiftPlanner',
    titleKey: 'merchant.features.shifts',
    tooltipKey: 'merchant.features.shiftsTip',
    icon: Icons.work_history_rounded,
    comingSoon: true,
    releaseKey: 'merchant.features.release.endSeptember',
  ),
  MerchantFeatureModule(
    key: 'deliveryService',
    titleKey: 'merchant.features.deliveryService',
    tooltipKey: 'merchant.features.deliveryServiceTip',
    icon: Icons.delivery_dining_rounded,
    comingSoon: true,
    releaseKey: 'merchant.features.release.endOctoberWestend',
  ),
  MerchantFeatureModule(
    key: 'reservations',
    titleKey: 'merchant.features.reservations',
    tooltipKey: 'merchant.features.reservationsTip',
    icon: Icons.event_seat_rounded,
    comingSoon: true,
    releaseKey: 'merchant.features.release.midOctober',
  ),
];

MerchantFeatureModule? merchantFeatureModuleByKey(String key) {
  for (final module in merchantFeatureModules) {
    if (module.key == key) return module;
  }
  return null;
}
