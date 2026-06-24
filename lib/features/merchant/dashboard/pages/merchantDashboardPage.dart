import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../../core/widgets/appEmptyState.dart';
import '../../../../core/widgets/appErrorState.dart';
import '../../../../core/widgets/appLoadingState.dart';
import '../../orders/services/merchantOrdersService.dart';
import '../../orders/widgets/merchantScanOrderSheet.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../../stamps/widgets/customerScanFlow.dart';
import '../models/dashboardModules.dart';
import '../providers/merchantDashboardProvider.dart';
import '../services/merchantDashboardService.dart';
import '../widgets/merchantDashboardSheets.dart';
import '../widgets/merchantHeroCard.dart';
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
              if (provider.isLoading) {
                // Standard-State-Konvention erfüllt via child-Slot; der premium
                // Skeleton bleibt als bewusste Merchant-Dark-Optik erhalten (#244).
                return const AppLoadingState(child: _LoadingDashboard());
              }
              if (provider.error != null) {
                // provider.error ist ein i18n-Key (#249), kein Roh-Fehlertext.
                return AppErrorState(
                  onRetry: provider.load,
                  child: _DashboardMessage(
                    title: texts.text('merchant.dashboard.loadErrorTitle'),
                    message: texts.text(provider.error!),
                    actionLabel: texts.text('common.refresh'),
                    onAction: provider.load,
                  ),
                );
              }

              final data = provider.data;
              if (data == null) {
                return AppEmptyState(
                  child: _DashboardMessage(
                    title: texts.text('merchant.dashboard.noMerchantTitle'),
                    message: texts.text('merchant.dashboard.noMerchantMessage'),
                    actionLabel: texts.text('auth.signOut'),
                    onAction: () async {
                      await provider.signOut();
                      if (context.mounted) context.go('/');
                    },
                  ),
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    children: [
                      MerchantHeroCard(
                        hero: data.hero,
                        metrics: data.metrics,
                        onShopTap: () {
                          // merchantId stammt aus dem geladenen Snapshot (#237),
                          // kein erneuter AuthService-Read.
                          final merchantId = data.merchantId;
                          if (merchantId.isEmpty) {
                            showComingSoonSheet(context, title: texts.text('merchant.dashboard.shopPreview'));
                            return;
                          }
                          context.push('/shop/$merchantId');
                        },
                        onCustomersTap: () => context.push('/merchant/customers'),
                        onSettingsTap: () => context.push('/merchant/shop'),
                        onFeedTap: () => context.push('/merchant/feed/manage'),
                        onTodayTap: () => showTodaySheet(context, data),
                        onSaveFocus: provider.saveCoverFocus,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ScannerCard(
                        onTap: () => _openScannerChooser(context),
                      ),
                      if (data.ordersEnabled) ...[
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
                        modules: visibleMainModules(data),
                        onModuleTap: (module) => _handleModuleTap(context, data, module, texts),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _MoreToolsLauncher(onTap: () => showMoreToolsSheet(context, data)),
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
                          textStyle: const TextStyle(fontWeight: FontWeight.w700),
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

/// The dashboard scanner serves two "scan the customer" jobs: stamping a stamp
/// card and confirming a pre-paid order. A quick chooser keeps both one tap away
/// without coupling the QR formats.
Future<void> _openScannerChooser(BuildContext context) async {
  final texts = context.read<LanguageService>();
  final merchantId = context.read<AuthService>().currentUser?.uid;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              texts.text('merchant.dashboard.scanCustomer'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              tileColor: MerchantPremiumColors.surfaceAlt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.loyalty_rounded,
                  color: MerchantPremiumColors.gold),
              title: Text(texts.text('merchant.stampScan.chooseStamp'),
                  style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w800)),
              onTap: () => Navigator.of(ctx).pop('stamp'),
            ),
            const SizedBox(height: 10),
            ListTile(
              tileColor: MerchantPremiumColors.surfaceAlt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.receipt_long_rounded,
                  color: MerchantPremiumColors.gold),
              title: Text(texts.text('merchant.stampScan.chooseOrder'),
                  style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w800)),
              onTap: () => Navigator.of(ctx).pop('order'),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice == 'stamp') {
    if (merchantId == null) return;
    await startStampCustomerScan(context, merchantId: merchantId);
  } else {
    final ordersService = MerchantOrdersService(
      authService: context.read<AuthService>(),
      firestoreService: context.read<FirestoreService>(),
    );
    await showOrderScanner(context, onConfirm: ordersService.confirmPendingByCode);
  }
}

void _handleModuleTap(
  BuildContext context,
  MerchantDashboardData data,
  DashboardModule module,
  LanguageService texts,
) {
  if (module.key == 'feedPosts') {
    showFeedActionsSheet(context);
    return;
  }

  if (!isModuleActive(data, module)) {
    showDisabledSheet(context, title: module.title(texts));
    return;
  }

  if (module.path != null) {
    context.push(module.path!);
    return;
  }

  showComingSoonSheet(
    context,
    title: module.title(texts),
    message: texts.text('merchant.dashboard.notConnected'),
  );
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
            fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
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
  final List<DashboardModule> modules;
  final ValueChanged<DashboardModule> onModuleTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      children: modules
          .map(
            (module) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SystemButton(
                title: module.title(texts),
                tooltip: module.description(texts),
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
                  fontWeight: FontWeight.w800,
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
                      fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
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
