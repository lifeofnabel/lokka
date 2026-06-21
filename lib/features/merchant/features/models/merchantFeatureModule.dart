import 'package:flutter/material.dart';

/// Statisches Modell der Merchant-Funktionen. Anzeigetexte werden bewusst
/// NICHT hier gehalten: die Funktionen-Seite (merchantFeaturesPage.dart) nutzt
/// eigene, alltagstaugliche Inline-Copy. Frühere `titleKey`/`tooltipKey`/
/// `releaseKey`-Felder waren reiner toter Ballast (#59: Doppelpflege) und sind
/// entfernt – das Modell beschreibt nur noch Identität, Icon und Verhalten.
class MerchantFeatureModule {
  const MerchantFeatureModule({
    required this.key,
    required this.icon,
    this.isRequired = false,
    this.comingSoon = false,
    this.options = const [],
  });

  final String key;
  final IconData icon;
  final bool isRequired;
  final bool comingSoon;
  final List<MerchantFeatureOption> options;
}

class MerchantFeatureOption {
  const MerchantFeatureOption({
    required this.key,
    required this.icon,
  });

  final String key;
  final IconData icon;
}

const merchantFeatureModules = [
  MerchantFeatureModule(
    key: 'feedPosts',
    icon: Icons.dynamic_feed_rounded,
    isRequired: true,
  ),
  MerchantFeatureModule(
    key: 'stampCards',
    icon: Icons.loyalty_rounded,
  ),
  MerchantFeatureModule(
    key: 'pointsSystems',
    icon: Icons.stars_rounded,
  ),
  MerchantFeatureModule(
    key: 'menuCatalog',
    icon: Icons.menu_book_rounded,
    options: [
      MerchantFeatureOption(
        key: 'catalogOnly',
        icon: Icons.visibility_rounded,
      ),
      // Bestell-Modi (mind. 1 Pflicht; Runner & Nur-Karte exklusiv).
      MerchantFeatureOption(
        key: 'catalogModeRunner',
        icon: Icons.directions_run_rounded,
      ),
      MerchantFeatureOption(
        key: 'catalogModeTable',
        icon: Icons.table_bar_rounded,
      ),
      MerchantFeatureOption(
        key: 'catalogModeCashier',
        icon: Icons.point_of_sale_rounded,
      ),
      MerchantFeatureOption(
        key: 'catalogModeMenuOnly',
        icon: Icons.menu_book_rounded,
      ),
    ],
  ),
  MerchantFeatureModule(
    key: 'coupons',
    icon: Icons.confirmation_number_rounded,
    comingSoon: true,
  ),
  MerchantFeatureModule(
    key: 'campaigns',
    icon: Icons.emoji_events_rounded,
    comingSoon: true,
  ),
  MerchantFeatureModule(
    key: 'shiftPlanner',
    icon: Icons.work_history_rounded,
    comingSoon: true,
  ),
  MerchantFeatureModule(
    key: 'deliveryService',
    icon: Icons.delivery_dining_rounded,
    comingSoon: true,
  ),
  MerchantFeatureModule(
    key: 'reservations',
    icon: Icons.event_seat_rounded,
    comingSoon: true,
  ),
];

MerchantFeatureModule? merchantFeatureModuleByKey(String key) {
  for (final module in merchantFeatureModules) {
    if (module.key == key) return module;
  }
  return null;
}
