import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../providers/merchantDashboardProvider.dart';
import '../services/merchantDashboardService.dart';
import '../widgets/merchantHeroCard.dart';
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
    final texts = context.watch<LanguageService>();

    return Scaffold(
      backgroundColor: MerchantPremiumColors.base,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MerchantPremiumColors.base,
              MerchantPremiumColors.baseElevated,
              MerchantPremiumColors.base,
            ],
          ),
        ),
        child: SafeArea(
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

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    MerchantHeroCard(
                      merchant: data.merchant,
                      metrics: data.metrics,
                      onShopTap: () {
                        final merchantId = context.read<AuthService>().currentUser?.uid;
                        if (merchantId == null || merchantId.isEmpty) {
                          _showComingSoonSheet(context, title: texts.text('merchant.dashboard.shopPreview'));
                          return;
                        }
                        context.push('/shop/$merchantId');
                      },
                      onCustomersTap: () => context.push('/merchant/customers'),
                      onSettingsTap: () => context.push('/merchant/shop'),
                      onTodayTap: () => _showTodaySheet(context, data),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ScannerCard(onTap: () => _showComingSoonSheet(context, title: texts.text('merchant.dashboard.scanner'))),
                    if (_ordersEnabled(data)) ...[
                      const SizedBox(height: AppSpacing.md),
                      _OrdersStrip(
                        enabled: true,
                        onTap: () => context.push('/merchant/orders'),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _SectionTitle(
                      title: texts.text('merchant.dashboard.systems'),
                      subtitle: texts.text('merchant.dashboard.systemsTip'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ActiveSystemsList(
                      data: data,
                      modules: _visibleMainModules(data),
                      onModuleTap: (module) => _handleModuleTap(context, data, module, texts),
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
                        foregroundColor: MerchantPremiumColors.mutedLight,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
            },
          ),
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
        Text(
          title,
          style: const TextStyle(
            color: MerchantPremiumColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: MerchantPremiumColors.muted,
            fontWeight: FontWeight.w700,
          ),
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
      child: MerchantPremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: AppRadius.large,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: enabled ? MerchantPremiumColors.goldSoft : MerchantPremiumColors.line,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: enabled ? MerchantPremiumColors.ink : MerchantPremiumColors.muted,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                texts.text('merchant.orders.title'),
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Tooltip(
              message: enabled ? texts.text('merchant.orders.tooltip') : texts.text('merchant.dashboard.enableInFeatures'),
              child: Icon(
                enabled ? Icons.arrow_forward_ios_rounded : Icons.lock_outline_rounded,
                size: 16,
                color: MerchantPremiumColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSystemsList extends StatelessWidget {
  const _ActiveSystemsList({
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
    return Column(
      children: modules
          .map(
            (module) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SystemButton(
                title: _moduleTitle(texts, module),
                tooltip: _moduleDescription(texts, module),
                icon: module.icon,
                isPrimary: module.key == 'feedPosts',
                onTap: () => onModuleTap(module),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SystemButton extends StatelessWidget {
  const _SystemButton({
    required this.title,
    required this.tooltip,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  final String title;
  final String tooltip;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const foreground = MerchantPremiumColors.ink;
    const muted = MerchantPremiumColors.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isPrimary
              ? MerchantPremiumColors.goldSoft
              : MerchantPremiumColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isPrimary
                ? MerchantPremiumColors.gold.withValues(alpha: 0.45)
                : MerchantPremiumColors.line,
          ),
          boxShadow: MerchantPremiumShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isPrimary
                    ? MerchantPremiumColors.gold.withValues(alpha: 0.22)
                    : MerchantPremiumColors.surfaceAlt,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: MerchantPremiumColors.gold.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                icon,
                color: MerchantPremiumColors.gold,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Tooltip(
              message: tooltip,
              child: const Icon(Icons.info_outline_rounded,
                  size: 19, color: muted),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isPrimary
                    ? MerchantPremiumColors.gold
                    : MerchantPremiumColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isPrimary
                    ? MerchantPremiumColors.goldSoft
                    : muted,
              ),
            ),
          ],
        ),
      ),
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
      child: MerchantPremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.goldSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.auto_awesome_motion_rounded,
                color: MerchantPremiumColors.ink,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.text('merchant.dashboard.management'),
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    texts.text('merchant.dashboard.managementSubtitle'),
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_up_rounded, color: MerchantPremiumColors.ink),
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
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, index) => Container(
        height: index == 0 ? 220 : 112,
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surface.withValues(alpha: index == 0 ? 0.55 : 0.40),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.12)),
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
        child: MerchantPremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MerchantPremiumIconBox(icon: Icons.storefront_rounded, size: 54),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MerchantPremiumColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
    // ignore: unused_element_parameter — bewusster Default für künftige „Demnächst"-Module
    this.comingSoon = false,
    this.path,
  });

  final String key;
  final String titleKey;
  final String descriptionKey;
  final IconData icon;
  final bool defaultActive;
  final bool comingSoon;
  final String? path;
}

const _mainModules = [
  _DashboardModule(key: 'feedPosts', titleKey: 'merchant.dashboard.feedHub', descriptionKey: 'merchant.dashboard.feedHubTip', icon: Icons.campaign_rounded, defaultActive: true),
  _DashboardModule(key: 'stampCards', titleKey: 'merchant.stamps.title', descriptionKey: 'merchant.stamps.tooltip', icon: Icons.loyalty_rounded, path: '/merchant/stamps'),
  _DashboardModule(key: 'pointsSystems', titleKey: 'merchant.points.title', descriptionKey: 'merchant.points.tooltip', icon: Icons.stars_rounded, path: '/merchant/points'),
  _DashboardModule(key: 'menuCatalog', titleKey: 'merchant.catalog.title', descriptionKey: 'merchant.catalog.tooltip', icon: Icons.menu_book_rounded, path: '/merchant/catalog'),
];

String _moduleTitle(LanguageService texts, _DashboardModule module) => texts.text(module.titleKey);

String _moduleDescription(LanguageService texts, _DashboardModule module) => texts.text(module.descriptionKey);

bool _isModuleActive(MerchantDashboardData data, _DashboardModule module) {
  if (module.key == 'feedPosts' || module.comingSoon) return true;
  return data.moduleActive[module.key] ?? module.defaultActive;
}

List<_DashboardModule> _visibleMainModules(MerchantDashboardData data) {
  return _mainModules.where((module) {
    if (module.key == 'feedPosts') return true;
    return _isModuleActive(data, module);
  }).toList();
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
  if (module.key == 'feedPosts') {
    _showFeedActionsSheet(context);
    return;
  }

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

void _showFeedActionsSheet(BuildContext context) {
  final texts = context.read<LanguageService>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => _PremiumSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texts.text('merchant.dashboard.feedHub'),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FeedSheetRow(
            icon: Icons.edit_note_rounded,
            title: texts.text('merchant.dashboard.newPost'),
            tooltip: texts.text('merchant.dashboard.newPostTip'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/merchant/feed/create?kind=post');
            },
          ),
          const SizedBox(height: 10),
          _FeedSheetRow(
            icon: Icons.local_activity_rounded,
            title: texts.text('merchant.dashboard.newAction'),
            tooltip: texts.text('merchant.dashboard.newActionTip'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/merchant/feed/create?kind=action');
            },
          ),
          const SizedBox(height: 10),
          _FeedSheetRow(
            icon: Icons.dynamic_feed_rounded,
            title: texts.text('merchant.dashboard.feedManage'),
            tooltip: texts.text('merchant.feedManage.tooltip'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/merchant/feed/manage');
            },
          ),
        ],
      ),
    ),
  );
}

class _FeedSheetRow extends StatelessWidget {
  const _FeedSheetRow({
    required this.icon,
    required this.title,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: MerchantPremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: AppRadius.large,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.goldSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: MerchantPremiumColors.gold),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
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
    );
  }
}

void _showMoreToolsSheet(BuildContext context, MerchantDashboardData data) {
  final texts = context.read<LanguageService>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => _PremiumSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texts.text('merchant.dashboard.management'),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texts.text('merchant.dashboard.managementSheetSubtitle'),
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w700,
            ),
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
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => _PremiumSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texts.text('merchant.dashboard.catalogTools'),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
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
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => _PremiumSheetFrame(
      child: MerchantTodaySummarySheet(data: data),
    ),
  );
}

class _ToolEntry {
  const _ToolEntry({
    required this.titleKey,
    required this.subtitleKey,
    required this.tooltipKey,
    required this.icon,
    required this.path,
    // ignore: unused_element_parameter — Reserve-Feld für künftige Feature-Gates
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
      child: MerchantPremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: AppRadius.large,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: enabled ? MerchantPremiumColors.goldSoft : MerchantPremiumColors.line,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                tool.icon,
                color: enabled ? MerchantPremiumColors.ink : MerchantPremiumColors.muted,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.text(tool.titleKey),
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    texts.text(tool.subtitleKey),
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: enabled ? texts.text(tool.tooltipKey) : texts.text('merchant.dashboard.enableInFeatures'),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 19,
                color: MerchantPremiumColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              enabled ? Icons.arrow_forward_ios_rounded : Icons.lock_outline_rounded,
              size: 16,
              color: MerchantPremiumColors.muted,
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
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => _PremiumSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: MerchantPremiumColors.goldSoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: MerchantPremiumColors.gold),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: MerchantPremiumColors.gold,
              foregroundColor: MerchantPremiumColors.goldSoft,
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

class _PremiumSheetFrame extends StatelessWidget {
  const _PremiumSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: MerchantPremiumCard(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        radius: 32,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
