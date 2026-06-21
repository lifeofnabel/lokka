import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../models/dashboardModules.dart';
import '../services/merchantDashboardService.dart';
import 'merchantTodaySummarySheet.dart';

/// Alle Dashboard-BottomSheets gebündelt, damit die Page schlank bleibt (#229).

void showFeedActionsSheet(BuildContext context) {
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
              fontWeight: FontWeight.w800,
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

void showMoreToolsSheet(BuildContext context, MerchantDashboardData data) {
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
              fontWeight: FontWeight.w800,
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
              tool: kDashboardCatalogToolEntry,
              onTap: () {
                Navigator.of(sheetContext).pop();
                showCatalogToolsSheet(context);
              },
            ),
          ),
          ...kDashboardToolEntries.map(
            (tool) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ToolSheetRow(
                tool: tool,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  final path = tool.path;
                  if (path != null) context.push(path);
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void showCatalogToolsSheet(BuildContext context) {
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
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...kDashboardCatalogToolEntries.map(
            (tool) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ToolSheetRow(
                tool: tool,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  final path = tool.path;
                  if (path != null) context.push(path);
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void showTodaySheet(BuildContext context, MerchantDashboardData data) {
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

void showDisabledSheet(BuildContext context, {required String title}) {
  final texts = context.read<LanguageService>();
  _showInfoSheet(
    context,
    icon: Icons.toggle_off_rounded,
    title: texts.text('merchant.dashboard.disabledTitle').replaceAll('{title}', title),
    message: texts.text('merchant.dashboard.disabledMessage'),
    actionLabel: texts.text('common.ok'),
  );
}

void showComingSoonSheet(
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
              fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
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

class _ToolSheetRow extends StatelessWidget {
  const _ToolSheetRow({
    required this.tool,
    required this.onTap,
  });

  final ToolEntry tool;
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
                color: MerchantPremiumColors.goldSoft,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                tool.icon,
                color: MerchantPremiumColors.ink,
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
                      fontWeight: FontWeight.w800,
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
              message: texts.text(tool.tooltipKey),
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
