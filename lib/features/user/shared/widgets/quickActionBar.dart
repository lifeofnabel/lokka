import 'package:flutter/material.dart';

/// A single, config-driven quick action.
///
/// When [enabled] is false the action renders dimmed and is inert (the prompt
/// rule: "visible but inactive — never hidden"). Provide [onTap] for the active
/// state; it is ignored while disabled.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
}

/// Horizontally **centered** row of compact action chips, shared by the Post
/// page and the Merchant Profile page. Missing data → the corresponding chip is
/// greyed out instead of removed, so the layout stays stable.
class QuickActionBar extends StatelessWidget {
  const QuickActionBar({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    // Gleich breite Kacheln, gleichmäßig verteilt → ruhige, klare Struktur.
    // Bis 5 Aktionen passen sie in eine Reihe; sonst umbrechen sie sauber.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions) _QuickActionChip(action: action),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final enabled = action.enabled && action.onTap != null;

    // Eine einzige, klare Kachel: weiches Icon-Quadrat + Label darunter.
    // KEIN umrandeter Kasten mehr und keine Box-in-Box-Schachtelung – das wirkte
    // unruhig. Die ganze Kachel ist die Tap-Fläche.
    final tile = SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(action.icon, size: 24, color: cs.onSecondaryContainer),
          ),
          const SizedBox(height: 8),
          Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (!enabled) {
      // Sichtbar, aber inaktiv: gedimmt und aus dem Tap-/Semantik-Baum genommen.
      return Opacity(
        opacity: 0.38,
        child: Semantics(
          enabled: false,
          label: '${action.label} (nicht verfügbar)',
          child: ExcludeSemantics(child: tile),
        ),
      );
    }

    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(18),
      child: tile,
    );
  }
}
