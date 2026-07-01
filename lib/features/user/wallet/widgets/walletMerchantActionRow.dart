import 'package:flutter/material.dart';
import 'package:lokka/features/user/wallet/theme/walletDesignTokens.dart';

/// A single merchant action (route / call / social / hours …).
class MerchantAction {
  const MerchantAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Centered row of merchant actions for the QR sheet. Each is a 48×48 filled
/// tile (brand @ 10% opacity) with the icon in the brand colour and an 11px
/// label below. Only the actions passed in are rendered — no empty slots.
/// Theme-aware.
class MerchantActionRow extends StatelessWidget {
  const MerchantActionRow({super.key, required this.actions});

  final List<MerchantAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: WalletTokens.xl,
      runSpacing: WalletTokens.md,
      children: [
        for (final a in actions)
          SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: a.onTap,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(a.icon, color: cs.primary, size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  a.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
