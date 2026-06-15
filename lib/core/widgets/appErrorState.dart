import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appButton.dart';

/// Einheitlicher Fehlerzustand mit optionalem „Erneut versuchen".
///
/// Entweder [message]/[onRetry] nutzen oder einen eigenen [child] übergeben
/// (Fallback, abwärtskompatibel).
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.message,
    this.onRetry,
    this.icon = Icons.wifi_off_rounded,
    this.child,
  });

  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child != null) return Center(child: child);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 34, color: cs.onErrorContainer),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message ?? 'Ein Fehler ist aufgetreten.',
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Erneut versuchen',
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
