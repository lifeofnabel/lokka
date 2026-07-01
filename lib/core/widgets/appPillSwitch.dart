import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';

/// Padding rund um den obersten Umschalter (Modus-/Sortier-Pille) einer
/// Tab-Seite – IDENTISCH auf Feed/Suche/Wallet, damit der obere Bereich in
/// der ganzen App an derselben Stelle sitzt (kein visuelles „Springen" beim
/// Tab-Wechsel, ruhiger fürs Auge). Gehört bewusst hier neben [AppPillSwitch],
/// da beide zusammen den einheitlichen „Kopfbereich" jeder Tab-Seite bilden.
const kSwitcherPadding =
    EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm);

/// Wiederverwendbarer M3-Segment-Umschalter (Pille mit gleitender Aktiv-
/// Fläche + Icon + Label je Segment). Geteilt zwischen der Suche-Seite
/// (Deals/Partner, Top/Näheste), der Feed-Seite (Für dich/Folge ich/
/// Neben mir) und der Wallet-Seite (Zuletzt benutzt/Nähste von mir) – EINE
/// Quelle der Wahrheit, damit alle drei optisch identisch bleiben statt als
/// Kopien auseinanderzudriften.
class AppPillSwitch<T> extends StatelessWidget {
  const AppPillSwitch({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.expand = false,
  });

  final T value;
  final List<({T value, String label, IconData icon})> segments;
  final ValueChanged<T> onChanged;

  /// `true` = Segmente teilen sich die volle Breite (z. B. 2 Segmente über
  /// die ganze Zeile); `false` = jedes Segment ist nur so breit wie nötig.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget seg(({T value, String label, IconData icon}) s) {
      final cs = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;
      final active = s.value == value;
      final child = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(s.icon,
                size: 18, color: active ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
      final tappable = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => onChanged(s.value),
          borderRadius: BorderRadius.circular(999),
          child: child,
        ),
      );
      return expand ? Expanded(child: tappable) : tappable;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: segments.map(seg).toList(),
      ),
    );
  }
}
