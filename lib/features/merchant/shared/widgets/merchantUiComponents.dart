import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import 'merchantPremiumUi.dart';

class MerchantSectionHeader extends StatelessWidget {
  const MerchantSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

class MerchantFormSection extends StatelessWidget {
  const MerchantFormSection({
    super.key,
    required this.title,
    required this.tooltip,
    required this.child,
  });

  final String title;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantSectionHeader(
            title: title,
            trailing: Tooltip(
              message: tooltip,
              child: const Icon(
                Icons.info_outline_rounded,
                color: MerchantPremiumColors.muted,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class MerchantStatusChip extends StatelessWidget {
  const MerchantStatusChip({
    super.key,
    required this.label,
    this.status = 'neutral',
  });

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class MerchantStatTile extends StatelessWidget {
  const MerchantStatTile({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.large,
      borderColor: MerchantPremiumColors.line,
      color: MerchantPremiumColors.surface,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: MerchantPremiumColors.ink,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
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
        ],
      ),
    );
    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: tile,
    );
  }
}

class MerchantActionCard extends StatelessWidget {
  const MerchantActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.isDark = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? MerchantPremiumColors.baseElevated : MerchantPremiumColors.surface;
    final fg = isDark ? Colors.white : MerchantPremiumColors.ink;
    final muted = isDark ? Colors.white.withOpacity(0.66) : MerchantPremiumColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MerchantPremiumColors.baseElevated,
                    MerchantPremiumColors.ink,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.10) : MerchantPremiumColors.line,
          ),
          boxShadow: MerchantPremiumShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? MerchantPremiumColors.gold.withOpacity(0.18)
                        : MerchantPremiumColors.goldSoft,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: isDark ? MerchantPremiumColors.goldSoft : MerchantPremiumColors.ink),
                ),
                const Spacer(),
                if (badge != null)
                  MerchantStatusChip(
                    label: badge!,
                    status: isDark ? 'dark' : 'neutral',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 19, fontWeight: FontWeight.w900, height: 1.05),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontWeight: FontWeight.w700, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantActionTypeChip extends StatelessWidget {
  const MerchantActionTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      selectedColor: MerchantPremiumColors.coral,
      backgroundColor: MerchantPremiumColors.surface,
      side: const BorderSide(color: MerchantPremiumColors.line),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : MerchantPremiumColors.ink,
            ),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : MerchantPremiumColors.ink,
        fontWeight: FontWeight.w900,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class MerchantDashboardGrid extends StatelessWidget {
  const MerchantDashboardGrid({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 680 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 3 ? 1.14 : 0.94,
          children: children,
        );
      },
    );
  }
}

class MerchantSimpleEmptyState extends StatelessWidget {
  const MerchantSimpleEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_rounded,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          MerchantPremiumIconBox(icon: icon),
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
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel ?? texts.text('common.ok')),
            ),
          ],
        ],
      ),
    );
  }
}

_StatusColors _colorsFor(String status) {
  return switch (status) {
    'success' || 'active' => _StatusColors(
        background: MerchantPremiumColors.successSoft,
        foreground: MerchantPremiumColors.success,
        border: MerchantPremiumColors.success.withOpacity(0.18),
      ),
    'warning' || 'paused' => _StatusColors(
        background: MerchantPremiumColors.warningSoft,
        foreground: MerchantPremiumColors.warning,
        border: MerchantPremiumColors.warning.withOpacity(0.20),
      ),
    'danger' || 'archived' => _StatusColors(
        background: MerchantPremiumColors.dangerSoft,
        foreground: MerchantPremiumColors.danger,
        border: MerchantPremiumColors.danger.withOpacity(0.18),
      ),
    'dark' => _StatusColors(
        background: MerchantPremiumColors.gold.withOpacity(0.16),
        foreground: MerchantPremiumColors.goldSoft,
        border: MerchantPremiumColors.gold.withOpacity(0.22),
      ),
    _ => const _StatusColors(
        background: MerchantPremiumColors.surfaceAlt,
        foreground: MerchantPremiumColors.ink,
        border: MerchantPremiumColors.line,
      ),
  };
}

class _StatusColors {
  const _StatusColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
