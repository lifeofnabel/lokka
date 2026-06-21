import 'package:flutter/material.dart';

import '../../../../core/services/languageService.dart';
import '../services/merchantDashboardService.dart';

/// Ein Haupt-Modul auf dem Dashboard (Feed, Stempel, Punkte, Katalog).
///
/// Registry + Sichtbarkeits-/Aktiv-Logik liegen hier gebündelt, damit die
/// Dashboard-Page auf View + Wiring reduziert bleibt (#229).
class DashboardModule {
  const DashboardModule({
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.key,
    this.defaultActive = false,
    this.path,
  });

  final String key;
  final String titleKey;
  final String descriptionKey;
  final IconData icon;
  final bool defaultActive;
  final String? path;

  String title(LanguageService texts) => texts.text(titleKey);
  String description(LanguageService texts) => texts.text(descriptionKey);
}

const kDashboardMainModules = [
  DashboardModule(
    key: 'feedPosts',
    titleKey: 'merchant.dashboard.feedHub',
    descriptionKey: 'merchant.dashboard.feedHubTip',
    icon: Icons.campaign_rounded,
    defaultActive: true,
  ),
  DashboardModule(
    key: 'stampCards',
    titleKey: 'merchant.stamps.title',
    descriptionKey: 'merchant.stamps.tooltip',
    icon: Icons.loyalty_rounded,
    path: '/merchant/stamps',
  ),
  DashboardModule(
    key: 'pointsSystems',
    titleKey: 'merchant.points.title',
    descriptionKey: 'merchant.points.tooltip',
    icon: Icons.stars_rounded,
    path: '/merchant/points',
  ),
  DashboardModule(
    key: 'menuCatalog',
    titleKey: 'merchant.catalog.title',
    descriptionKey: 'merchant.catalog.tooltip',
    icon: Icons.menu_book_rounded,
    path: '/merchant/catalog',
  ),
];

bool isModuleActive(MerchantDashboardData data, DashboardModule module) {
  if (module.key == 'feedPosts') return true;
  return data.moduleActive[module.key] ?? module.defaultActive;
}

List<DashboardModule> visibleMainModules(MerchantDashboardData data) {
  return kDashboardMainModules.where((module) {
    if (module.key == 'feedPosts') return true;
    return isModuleActive(data, module);
  }).toList();
}

/// Ein Eintrag im Verwaltungs-/Tools-Sheet.
class ToolEntry {
  const ToolEntry({
    required this.titleKey,
    required this.subtitleKey,
    required this.tooltipKey,
    required this.icon,
    this.path,
    this.opensSheet = false,
  });

  final String titleKey;
  final String subtitleKey;
  final String tooltipKey;
  final IconData icon;

  /// Ziel-Route; null bei Sheet-Einträgen (siehe [opensSheet]) (#241).
  final String? path;

  /// true = Eintrag öffnet ein Sub-Sheet statt zu navigieren (#241),
  /// damit ein leerer Pfad nie versehentlich als Route genutzt wird.
  final bool opensSheet;
}

const kDashboardToolEntries = [
  ToolEntry(
    titleKey: 'merchant.shop.title',
    subtitleKey: 'merchant.shop.subtitle',
    tooltipKey: 'merchant.shop.tooltip',
    icon: Icons.storefront_rounded,
    path: '/merchant/shop',
  ),
  ToolEntry(
    titleKey: 'merchant.finance.title',
    subtitleKey: 'merchant.finance.subtitle',
    tooltipKey: 'merchant.finance.tooltip',
    icon: Icons.insights_rounded,
    path: '/merchant/finance',
  ),
  ToolEntry(
    titleKey: 'merchant.support.title',
    subtitleKey: 'merchant.support.subtitle',
    tooltipKey: 'merchant.support.subtitle',
    icon: Icons.support_agent_rounded,
    path: '/merchant/tools/support',
  ),
  ToolEntry(
    titleKey: 'merchant.invite.title',
    subtitleKey: 'merchant.invite.subtitle',
    tooltipKey: 'merchant.invite.subtitle',
    icon: Icons.person_add_alt_1_rounded,
    path: '/merchant/tools/invite',
  ),
];

const kDashboardCatalogToolEntry = ToolEntry(
  titleKey: 'merchant.dashboard.catalogTools',
  subtitleKey: 'merchant.dashboard.catalogToolsSubtitle',
  tooltipKey: 'merchant.dashboard.catalogToolsTip',
  icon: Icons.inventory_2_rounded,
  opensSheet: true,
);

const kDashboardCatalogToolEntries = [
  ToolEntry(
    titleKey: 'merchant.catalog.categories',
    subtitleKey: 'merchant.catalog.categoriesSubtitle',
    tooltipKey: 'merchant.catalog.categoriesTip',
    icon: Icons.category_rounded,
    path: '/merchant/tools/categories',
  ),
  ToolEntry(
    titleKey: 'merchant.catalog.items',
    subtitleKey: 'merchant.catalog.itemsSubtitle',
    tooltipKey: 'merchant.catalog.itemsTip',
    icon: Icons.inventory_2_rounded,
    path: '/merchant/tools/items',
  ),
  ToolEntry(
    titleKey: 'merchant.catalog.tables',
    subtitleKey: 'merchant.catalog.tablesSubtitle',
    tooltipKey: 'merchant.catalog.tablesTip',
    icon: Icons.table_bar_rounded,
    path: '/merchant/tools/tables',
  ),
  ToolEntry(
    titleKey: 'merchant.itemTags.title',
    subtitleKey: 'merchant.itemTags.subtitle',
    tooltipKey: 'merchant.itemTags.tooltip',
    icon: Icons.fact_check_rounded,
    path: '/merchant/tools/itemTags',
  ),
];
