import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../providers/merchantDashboardProvider.dart';
import '../services/merchantDashboardService.dart';
import '../widgets/creditUsageCard.dart';
import '../widgets/merchantCustomersPreviewCard.dart';
import '../widgets/merchantFeedActionCard.dart';
import '../widgets/merchantHeroCard.dart';
import '../widgets/merchantModuleCard.dart';
import '../widgets/merchantTodaySummarySheet.dart';
import '../widgets/scannerCard.dart';

class MerchantDashboardPage extends StatelessWidget {
  const MerchantDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantDashboardProvider(
        service: MerchantDashboardService(
          firestoreService: context.read<FirestoreService>(),
          authService: context.read<AuthService>(),
        ),
      )..load(),
      child: const _MerchantDashboardView(),
    );
  }
}

class _MerchantDashboardView extends StatelessWidget {
  const _MerchantDashboardView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantDashboardProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (provider.isLoading) return const _LoadingDashboard();
            if (provider.error != null) {
              return _DashboardMessage(
                title: 'Dashboard konnte nicht geladen werden.',
                message: provider.error!,
                actionLabel: 'Erneut versuchen',
                onAction: provider.load,
              );
            }

            final data = provider.data;
            if (data == null) {
              return _DashboardMessage(
                title: 'Geschaeftsdaten nicht gefunden',
                message: 'Melde dich ab und pruefe, ob dein Haendlerkonto vollstaendig angelegt wurde.',
                actionLabel: 'Abmelden',
                onAction: () async {
                  await provider.signOut();
                  if (context.mounted) context.go('/');
                },
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              children: [
                MerchantHeroCard(
                  merchant: data.merchant,
                  metrics: data.metrics,
                  onShopTap: () => _showComingSoonSheet(context, title: 'Shop ansehen'),
                  onSettingsTap: () => _showComingSoonSheet(context, title: 'Funktionen verwalten'),
                  onTodayTap: () => _showTodaySheet(context, data),
                ),
                const SizedBox(height: AppSpacing.lg),
                ScannerCard(onTap: () => _showComingSoonSheet(context, title: 'Scanner')),
                const SizedBox(height: AppSpacing.lg),
                MerchantFeedActionCard(
                  onCreateTap: () => _handleModuleTap(context, data, _moduleByKey('feedPosts')),
                  onManageTap: () => _handleModuleTap(context, data, _moduleByKey('feedManage')),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionTitle(
                  title: 'Systeme',
                  subtitle: 'Aktive Tools fuer dein lokales Geschaeft.',
                ),
                const SizedBox(height: AppSpacing.md),
                _ModuleGrid(
                  data: data,
                  modules: _mainModules,
                  onModuleTap: (module) => _handleModuleTap(context, data, module),
                ),
                const SizedBox(height: AppSpacing.lg),
                CreditUsageCard(
                  weekCredits: data.weekCredits,
                  hasBillingData: data.hasBillingData,
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantCustomersPreviewCard(
                  customersCount: data.metrics.customers,
                  onTap: () => _showComingSoonSheet(context, title: 'Kunden ansehen'),
                ),
                const SizedBox(height: AppSpacing.md),
                _MoreToolsLauncher(onTap: () => _showMoreToolsSheet(context)),
                const SizedBox(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: () async {
                    await provider.signOut();
                    if (context.mounted) context.go('/');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Abmelden'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gray500,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({
    required this.data,
    required this.modules,
    required this.onModuleTap,
  });

  final MerchantDashboardData data;
  final List<_DashboardModule> modules;
  final ValueChanged<_DashboardModule> onModuleTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 620;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 3 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isWide ? 1.16 : 0.94,
          ),
          itemBuilder: (context, index) {
            final module = modules[index];
            return MerchantModuleCard(
              title: module.title,
              description: module.description,
              icon: module.icon,
              isActive: _isModuleActive(data, module),
              badge: module.badge,
              onTap: () => onModuleTap(module),
            );
          },
        );
      },
    );
  }
}

class _MoreToolsLauncher extends StatelessWidget {
  const _MoreToolsLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.auto_awesome_motion_rounded),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mehr Tools', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  SizedBox(height: 3),
                  Text('Kategorien, Artikel, Shopdaten und Support.', style: TextStyle(color: AppColors.gray500)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_up_rounded),
          ],
        ),
      ),
    );
  }
}

class _LoadingDashboard extends StatelessWidget {
  const _LoadingDashboard();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, index) => Container(
        height: index == 0 ? 220 : 112,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final FutureOr<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_rounded, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.sm),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray700)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: () => onAction(), child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardModule {
  const _DashboardModule({
    required this.title,
    required this.description,
    required this.icon,
    required this.key,
    this.defaultActive = false,
    this.badge,
    this.comingSoon = false,
  });

  final String key;
  final String title;
  final String description;
  final IconData icon;
  final bool defaultActive;
  final String? badge;
  final bool comingSoon;
}

const _mainModules = [
  _DashboardModule(key: 'orders', title: 'Bestellungen', description: 'Neue und offene Bestellungen.', icon: Icons.receipt_long_rounded, defaultActive: true),
  _DashboardModule(key: 'stampCards', title: 'Stempel', description: 'Digitale Karten fuer Stammkunden.', icon: Icons.loyalty_rounded, defaultActive: true),
  _DashboardModule(key: 'pointsSystems', title: 'Punkte', description: 'Belohnungen pro Einkauf.', icon: Icons.stars_rounded, defaultActive: true),
  _DashboardModule(key: 'coupons', title: 'Gutscheine', description: 'Rabatte und Vorteile.', icon: Icons.confirmation_number_rounded, defaultActive: true),
  _DashboardModule(key: 'menuCatalog', title: 'Katalog', description: 'Speisen, Artikel und Preise.', icon: Icons.menu_book_rounded, defaultActive: true),
  _DashboardModule(key: 'tables', title: 'Tische', description: 'QR-Tische und Bereiche.', icon: Icons.table_bar_rounded, defaultActive: true),
  _DashboardModule(key: 'campaigns', title: 'Gewinnspiel', description: 'Organizer fuer Aktionen.', icon: Icons.emoji_events_rounded, defaultActive: true, badge: 'Bald', comingSoon: true),
  _DashboardModule(key: 'shiftPlanner', title: 'Schichtplan', description: 'Teamplanung vorbereiten.', icon: Icons.work_history_rounded, defaultActive: true, badge: 'Bald', comingSoon: true),
];

const _toolModules = [
  _DashboardModule(key: 'itemCategories', title: 'Kategorien', description: 'Artikelgruppen', icon: Icons.category_rounded, defaultActive: true),
  _DashboardModule(key: 'menuItems', title: 'Artikel', description: 'Produkte pflegen', icon: Icons.inventory_2_rounded, defaultActive: true),
  _DashboardModule(key: 'settings', title: 'Shopdaten', description: 'Profil und Module', icon: Icons.tune_rounded, defaultActive: true),
  _DashboardModule(key: 'support', title: 'Support', description: 'Hilfe anfragen', icon: Icons.support_agent_rounded, defaultActive: true),
  _DashboardModule(key: 'invite', title: 'Einladen', description: 'Team oder Kunden', icon: Icons.person_add_alt_1_rounded, defaultActive: true),
  _DashboardModule(key: 'feedManage', title: 'Feed', description: 'Aktionen verwalten', icon: Icons.dynamic_feed_rounded, defaultActive: true),
];

_DashboardModule _moduleByKey(String key) {
  return [
    ..._mainModules,
    ..._toolModules,
    const _DashboardModule(key: 'feedPosts', title: 'Neue Aktion', description: 'Aktion veroeffentlichen.', icon: Icons.add_rounded, defaultActive: true),
  ].firstWhere((module) => module.key == key);
}

bool _isModuleActive(MerchantDashboardData data, _DashboardModule module) {
  return data.moduleActive[module.key] ?? module.defaultActive;
}

void _handleModuleTap(BuildContext context, MerchantDashboardData data, _DashboardModule module) {
  if (!_isModuleActive(data, module)) {
    _showDisabledSheet(context, title: module.title);
    return;
  }

  _showComingSoonSheet(
    context,
    title: module.title,
    message: module.comingSoon
        ? 'Dieses Modul ist vorbereitet und wird bald vollstaendig verbunden.'
        : 'Dieses Modul wird im naechsten Sprint verbunden.',
  );
}

void _showMoreToolsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Mehr Tools', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'Verwalte Sortiment, Shopdaten und Kommunikation an einem Ort.',
            style: TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._toolEntries.map(
            (tool) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ToolSheetRow(
                tool: tool,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push(tool.path);
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showTodaySheet(BuildContext context, MerchantDashboardData data) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => MerchantTodaySummarySheet(data: data),
  );
}

class _ToolEntry {
  const _ToolEntry({
    required this.title,
    required this.subtitle,
    required this.tooltip,
    required this.icon,
    required this.path,
  });

  final String title;
  final String subtitle;
  final String tooltip;
  final IconData icon;
  final String path;
}

class _ToolSheetRow extends StatelessWidget {
  const _ToolSheetRow({
    required this.tool,
    required this.onTap,
  });

  final _ToolEntry tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(tool.icon),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(tool.subtitle, style: const TextStyle(color: AppColors.gray700, height: 1.25)),
                ],
              ),
            ),
            Tooltip(
              message: tool.tooltip,
              child: const Icon(Icons.info_outline_rounded, size: 19, color: AppColors.gray500),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

const _toolEntries = [
  _ToolEntry(
    title: 'Kategorien',
    subtitle: 'Gruppen fuer dein Sortiment.',
    tooltip: 'Gruppen helfen Kunden, deine Artikel schneller zu finden.',
    icon: Icons.category_rounded,
    path: '/merchant/tools/categories',
  ),
  _ToolEntry(
    title: 'Artikel',
    subtitle: 'Produkte, Preise und Verfuegbarkeit.',
    tooltip: 'Hier pflegst du Produkte, Preise und Verfuegbarkeit.',
    icon: Icons.inventory_2_rounded,
    path: '/merchant/tools/items',
  ),
  _ToolEntry(
    title: 'Shopdaten',
    subtitle: 'Profil, Bilder und Oeffnungszeiten.',
    tooltip: 'Diese Daten sehen Kunden in deinem oeffentlichen Profil.',
    icon: Icons.storefront_rounded,
    path: '/merchant/tools/shop',
  ),
  _ToolEntry(
    title: 'Support',
    subtitle: 'Hilfe oder Rueckfrage senden.',
    tooltip: 'Schreib uns, wenn etwas nicht funktioniert oder du Hilfe brauchst.',
    icon: Icons.support_agent_rounded,
    path: '/merchant/tools/support',
  ),
  _ToolEntry(
    title: 'Einladen',
    subtitle: 'Links fuer Kunden und Haendler.',
    tooltip: 'Teile deinen persoenlichen Link mit Kunden oder anderen Geschaeften.',
    icon: Icons.person_add_alt_1_rounded,
    path: '/merchant/tools/invite',
  ),
  _ToolEntry(
    title: 'Feed verwalten',
    subtitle: 'Beitraege pausieren oder archivieren.',
    tooltip: 'Hier pausierst oder aenderst du bereits veroeffentlichte Beitraege.',
    icon: Icons.dynamic_feed_rounded,
    path: '/merchant/tools/feedManage',
  ),
];

void _showDisabledSheet(BuildContext context, {required String title}) {
  _showInfoSheet(
    context,
    icon: Icons.toggle_off_rounded,
    title: '$title ist ausgeschaltet',
    message: 'Du hast diese Funktion nicht aktiviert. Sie ist deshalb im Dashboard gesperrt.',
    actionLabel: 'Verstanden',
  );
}

void _showComingSoonSheet(
  BuildContext context, {
  required String title,
  String message = 'Dieser Bereich ist vorbereitet und wird bald verbunden.',
}) {
  _showInfoSheet(
    context,
    icon: Icons.auto_awesome_rounded,
    title: title,
    message: message,
    actionLabel: 'Okay',
  );
}

void _showInfoSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String actionLabel,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: AppColors.mint),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray700, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.black,
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
