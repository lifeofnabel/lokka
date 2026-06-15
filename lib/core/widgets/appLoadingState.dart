import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appSpacing.dart';

/// Einheitlicher Ladezustand mit optionalem Hinweistext.
///
/// Entweder [message] nutzen oder einen eigenen [child] übergeben
/// (Fallback, abwärtskompatibel).
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message, this.child});

  final String? message;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child != null) return Center(child: child);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
