import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../providers/merchantDashboardProvider.dart';
import '../services/merchantDashboardService.dart';
import '../widgets/merchantFeedActionCard.dart';
import '../widgets/merchantHeroCard.dart';
import '../widgets/merchantModuleCard.dart';
import '../widgets/merchantTodaySummarySheet.dart';
import '../widgets/scannerCard.dart';
import '../../display_studio/widgets/display_studio_dashboard_card.dart';

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
    final texts = context.watch<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (provider.isLoading) return const _LoadingDashboard();
            if (provider.error != null) {
              return _DashboardMessage(
                title: texts.text('merchant.dashboard.loadErrorTitle'),
                message: provider.error!,
                actionLabel: texts.text('common.refresh'),
                onAction: provider.load,
              );
            }

            final data = provider.data;
            if (data == null) {
              return _DashboardMessage(
                title: texts.text('merchant.dashboard.noMerchantTitle'),
                message: texts.text('merchant.dashboard.noMerchantMessage'),
                actionLabel: texts.text('auth.signOut'),
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
                  weekCredits: data.weekCredits,
                  hasBillingData: data.hasBillingData,
                  onShopTap: () => _showComingSoonSheet(context, title: texts.text('merchant.dashboard.shopPreview')),
                  onEditTap: () => context.push('/merchant/shop'),
                  onBillingTap: () => context.push('/merchant/billing'),
                  onCustomersTap: () => context.push('/merchant/customers'),
                  onSettingsTap: () => context.push('/merchant/features'),
                  onTodayTap: () => _showTodaySheet(context, data),
                ),
                const SizedBox(height: AppSpacing.lg),
                ScannerCard(onTap: () => _showComingSoonSheet(context, title: texts.text('merchant.dashboard.scanner'))),
                const SizedBox(height: AppSpacing.md),
                _OrdersStrip(
                  enabled: _ordersEnabled(data),
                  onTap: () {
                    if (_ordersEnabled(data)) {
                      context.push('/merchant/orders');
                    } else {
                      _showDisabledSheet(context, title: texts.text('merchant.orders.title'));
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                MerchantFeedActionCard(
                  onCreateTap: () => context.push('/merchant/feed/create'),
                  onManageTap: () => context.push('/merchant/feed/manage'),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionTitle(
                  title: texts.text('merchant.dashboard.systems'),
                  subtitle: texts.text('merchant.dashboard.systemsTip'),
                ),
                const SizedBox(height: AppSpacing.md),
                _ModuleGrid(
                  data: data,
                  modules: _mainModules,
                  onModuleTap: (module) => _handleModuleTap(context, data, module, texts),
                ),
                const SizedBox(height: AppSpacing.md),
                DisplayStudioDashboardCard(
                  onTap: () => context.push('/merchant/display-studio'),
                ),
                const SizedBox(height: AppSpacing.md),
                _MoreToolsLauncher(onTap: () => _showMoreToolsSheet(context, data)),
                const SizedBox(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: () async {
                    await provider.signOut();
                    if (context.mounted) context.go('/');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(texts.text('auth.signOut')),
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

class _OrdersStrip extends StatelessWidget {
  const _OrdersStrip({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: enabled ? AppColors.gray50 : AppColors.border,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: enabled ? AppColors.black : AppColors.gray500,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                texts.text('merchant.orders.title'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            Tooltip(
              message: enabled ? texts.text('merchant.orders.tooltip') : texts.text('merchant.dashboard.enableInFeatures'),
              child: Icon(
                enabled ? Icons.arrow_forward_ios_rounded : Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
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
    final texts = context.watch<LanguageService>();
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
              title: _moduleTitle(texts, module),
              description: _moduleDescription(texts, module),
              icon: module.icon,
              isActive: _isModuleActive(data, module),
              badge: module.badgeKey == null ? null : texts.text(module.badgeKey!),
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
    final texts = context.watch<LanguageService>();
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.text('merchant.dashboard.management'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    texts.text('merchant.dashboard.managementSubtitle'),
                    style: const TextStyle(color: AppColors.gray500),
                  ),
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
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.key,
    this.defaultActive = false,
    this.badgeKey,
    this.comingSoon = false,
    this.path,
  });

  final String key;
  final String titleKey;
  final String descriptionKey;
  final IconData icon;
  final bool defaultActive;
  final String? badgeKey;
  final bool comingSoon;
  final String? path;
}

const _mainModules = [
  _DashboardModule(key: 'stampCards', titleKey: 'merchant.stamps.title', descriptionKey: 'merchant.stamps.tooltip', icon: Icons.loyalty_rounded, path: '/merchant/stamps'),
  _DashboardModule(key: 'pointsSystems', titleKey: 'merchant.points.title', descriptionKey: 'merchant.points.tooltip', icon: Icons.stars_rounded, path: '/merchant/points'),
  _DashboardModule(key: 'menuCatalog', titleKey: 'merchant.catalog.title', descriptionKey: 'merchant.catalog.tooltip', icon: Icons.menu_book_rounded, path: '/merchant/catalog'),
  _DashboardModule(key: 'coupons', titleKey: 'merchant.coupons.title', descriptionKey: 'merchant.coupons.tooltip', icon: Icons.confirmation_number_rounded, path: '/merchant/coupons'),
  _DashboardModule(key: 'campaigns', titleKey: 'merchant.campaigns.title', descriptionKey: 'merchant.campaigns.tooltip', icon: Icons.emoji_events_rounded, badgeKey: 'merchant.dashboard.soon', comingSoon: true, path: '/merchant/campaigns'),
  _DashboardModule(key: 'shiftPlanner', titleKey: 'merchant.shifts.title', descriptionKey: 'merchant.shifts.tooltip', icon: Icons.work_history_rounded, badgeKey: 'merchant.dashboard.soon', comingSoon: true, path: '/merchant/shifts'),
  _DashboardModule(key: 'deliveryService', titleKey: 'merchant.delivery.title', descriptionKey: 'merchant.delivery.tooltip', icon: Icons.delivery_dining_rounded, badgeKey: 'merchant.dashboard.soon', comingSoon: true, path: '/merchant/delivery'),
  _DashboardModule(key: 'reservations', titleKey: 'merchant.reservations.title', descriptionKey: 'merchant.reservations.tooltip', icon: Icons.event_seat_rounded, badgeKey: 'merchant.dashboard.soon', comingSoon: true, path: '/merchant/reservations'),
];

const _toolModules = [
  _DashboardModule(key: 'settings', titleKey: 'merchant.shop.title', descriptionKey: 'merchant.shop.tooltip', icon: Icons.tune_rounded, defaultActive: true),
  _DashboardModule(key: 'support', titleKey: 'merchant.support.title', descriptionKey: 'merchant.support.subtitle', icon: Icons.support_agent_rounded, defaultActive: true),
  _DashboardModule(key: 'invite', titleKey: 'merchant.invite.title', descriptionKey: 'merchant.invite.subtitle', icon: Icons.person_add_alt_1_rounded, defaultActive: true),
  _DashboardModule(key: 'feedManage', titleKey: 'merchant.feedManage.title', descriptionKey: 'merchant.feedManage.tooltip', icon: Icons.dynamic_feed_rounded, defaultActive: true),
];

_DashboardModule _moduleByKey(String key) {
  return [
    ..._mainModules,
    ..._toolModules,
    const _DashboardModule(key: 'feedPosts', titleKey: 'merchant.feedCreate.title', descriptionKey: 'merchant.feedCreate.tooltip', icon: Icons.add_rounded, defaultActive: true, path: '/merchant/feed/create'),
  ].firstWhere((module) => module.key == key);
}

String _moduleTitle(LanguageService texts, _DashboardModule module) => texts.text(module.titleKey);

String _moduleDescription(LanguageService texts, _DashboardModule module) => texts.text(module.descriptionKey);

bool _isModuleActive(MerchantDashboardData data, _DashboardModule module) {
  if (module.key == 'feedPosts' || module.comingSoon) return true;
  return data.moduleActive[module.key] ?? module.defaultActive;
}

bool _ordersEnabled(MerchantDashboardData data) {
  if (data.moduleActive['menuCatalog'] != true) return false;
  return data.moduleActive['catalogOrderQrCashier'] == true ||
      data.moduleActive['catalogOrderSendCashier'] == true ||
      data.moduleActive['catalogTableOrders'] == true;
}

void _handleModuleTap(
  BuildContext context,
  MerchantDashboardData data,
  _DashboardModule module,
  LanguageService texts,
) {
  if (!_isModuleActive(data, module)) {
    _showDisabledSheet(context, title: _moduleTitle(texts, module));
    return;
  }

  if (module.comingSoon) {
    _showComingSoonSheet(
      context,
      title: _moduleTitle(texts, module),
      message: texts.text('merchant.dashboard.preparedSoon'),
    );
    return;
  }

  if (module.path != null) {
    context.push(module.path!);
    return;
  }

  _showComingSoonSheet(
    context,
    title: _moduleTitle(texts, module),
    message: module.comingSoon
        ? texts.text('merchant.dashboard.preparedSoon')
        : texts.text('merchant.dashboard.notConnected'),
  );
}

void _showMoreToolsSheet(BuildContext context, MerchantDashboardData data) {
  final texts = context.read<LanguageService>();
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
          Text(texts.text('merchant.dashboard.management'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            texts.text('merchant.dashboard.managementSheetSubtitle'),
            style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ToolSheetRow(
              tool: _catalogToolEntry,
              enabled: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showCatalogToolsSheet(context);
              },
            ),
          ),
          ..._toolEntries.map(
            (tool) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ToolSheetRow(
                tool: tool,
                enabled: _isToolEnabled(data, tool),
                onTap: () {
                  final enabled = _isToolEnabled(data, tool);
                  Navigator.of(sheetContext).pop();
                  if (enabled) {
                    context.push(tool.path);
                  } else {
                    _showDisabledSheet(context, title: texts.text(tool.titleKey));
                  }
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showCatalogToolsSheet(BuildContext context) {
  final texts = context.read<LanguageService>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
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
          Text(texts.text('merchant.dashboard.catalogTools'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.md),
          ..._catalogToolEntries.map(
            (tool) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ToolSheetRow(
                tool: tool,
                enabled: true,
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
    required this.titleKey,
    required this.subtitleKey,
    required this.tooltipKey,
    required this.icon,
    required this.path,
    this.featureKey,
  });

  final String titleKey;
  final String subtitleKey;
  final String tooltipKey;
  final IconData icon;
  final String path;
  final String? featureKey;
}

class _ToolSheetRow extends StatelessWidget {
  const _ToolSheetRow({
    required this.tool,
    required this.enabled,
    required this.onTap,
  });

  final _ToolEntry tool;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
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
                color: enabled ? AppColors.gray50 : AppColors.border,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(tool.icon, color: enabled ? AppColors.black : AppColors.gray500),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(texts.text(tool.titleKey), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(texts.text(tool.subtitleKey), style: const TextStyle(color: AppColors.gray700, height: 1.25)),
                ],
              ),
            ),
            Tooltip(
              message: enabled ? texts.text(tool.tooltipKey) : texts.text('merchant.dashboard.enableInFeatures'),
              child: const Icon(Icons.info_outline_rounded, size: 19, color: AppColors.gray500),
            ),
            const SizedBox(width: 8),
            Icon(
              enabled ? Icons.arrow_forward_ios_rounded : Icons.lock_outline_rounded,
              size: 16,
              color: AppColors.gray500,
            ),
          ],
        ),
      ),
    );
  }
}

const _toolEntries = [
  _ToolEntry(
    titleKey: 'merchant.shop.title',
    subtitleKey: 'merchant.shop.subtitle',
    tooltipKey: 'merchant.shop.tooltip',
    icon: Icons.storefront_rounded,
    path: '/merchant/shop',
  ),
  _ToolEntry(
    titleKey: 'merchant.support.title',
    subtitleKey: 'merchant.support.subtitle',
    tooltipKey: 'merchant.support.subtitle',
    icon: Icons.support_agent_rounded,
    path: '/merchant/tools/support',
  ),
  _ToolEntry(
    titleKey: 'merchant.invite.title',
    subtitleKey: 'merchant.invite.subtitle',
    tooltipKey: 'merchant.invite.subtitle',
    icon: Icons.person_add_alt_1_rounded,
    path: '/merchant/tools/invite',
  ),
];

const _catalogToolEntry = _ToolEntry(
  titleKey: 'merchant.dashboard.catalogTools',
  subtitleKey: 'merchant.dashboard.catalogToolsSubtitle',
  tooltipKey: 'merchant.dashboard.catalogToolsTip',
  icon: Icons.inventory_2_rounded,
  path: '',
);

const _catalogToolEntries = [
  _ToolEntry(
    titleKey: 'merchant.catalog.categories',
    subtitleKey: 'merchant.catalog.categoriesSubtitle',
    tooltipKey: 'merchant.catalog.categoriesTip',
    icon: Icons.category_rounded,
    path: '/merchant/tools/categories',
  ),
  _ToolEntry(
    titleKey: 'merchant.catalog.items',
    subtitleKey: 'merchant.catalog.itemsSubtitle',
    tooltipKey: 'merchant.catalog.itemsTip',
    icon: Icons.inventory_2_rounded,
    path: '/merchant/tools/items',
  ),
  _ToolEntry(
    titleKey: 'merchant.catalog.tables',
    subtitleKey: 'merchant.catalog.tablesSubtitle',
    tooltipKey: 'merchant.catalog.tablesTip',
    icon: Icons.table_bar_rounded,
    path: '/merchant/tools/tables',
  ),
  _ToolEntry(
    titleKey: 'merchant.itemTags.title',
    subtitleKey: 'merchant.itemTags.subtitle',
    tooltipKey: 'merchant.itemTags.tooltip',
    icon: Icons.fact_check_rounded,
    path: '/merchant/tools/itemTags',
  ),
];

bool _isToolEnabled(MerchantDashboardData data, _ToolEntry tool) {
  final featureKey = tool.featureKey;
  if (featureKey == null) return true;
  return data.moduleActive[featureKey] ?? false;
}

void _showDisabledSheet(BuildContext context, {required String title}) {
  final texts = context.read<LanguageService>();
  _showInfoSheet(
    context,
    icon: Icons.toggle_off_rounded,
    title: texts.text('merchant.dashboard.disabledTitle').replaceAll('{title}', title),
    message: texts.text('merchant.dashboard.disabledMessage'),
    actionLabel: texts.text('common.ok'),
  );
}

void _showComingSoonSheet(
  BuildContext context, {
  required String title,
  String? message,
}) {
  final texts = context.read<LanguageService>();
  _showInfoSheet(
    context,
    icon: Icons.auto_awesome_rounded,
    title: title,
    message: message ?? texts.text('merchant.dashboard.preparedSoon'),
    actionLabel: texts.text('common.ok'),
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
