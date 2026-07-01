import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';

/// Einheitlicher Leerzustand für Listen/Seiten.
///
/// Entweder strukturiert über [icon]/[title]/[message]/[action] nutzen
/// oder einen eigenen [child] übergeben (Fallback, abwärtskompatibel).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon,
    this.title,
    this.message,
    this.action,
    this.child,
  });

  final IconData? icon;
  final String? title;
  final String? message;
  final Widget? action;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child != null) return Center(child: child);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasStructuredContent =
        icon != null || title != null || message != null;
    if (!hasStructuredContent) {
      return Center(
        child: Text(
          'Keine Inhalte vorhanden.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Icon(icon, size: 36, color: cs.onSecondaryContainer),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              if (message != null) const SizedBox(height: AppSpacing.sm),
            ],
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
