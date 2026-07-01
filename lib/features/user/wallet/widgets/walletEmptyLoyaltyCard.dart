import 'package:flutter/material.dart';
import 'package:lokka/features/user/wallet/theme/walletDesignTokens.dart';

/// A quiet, dashed placeholder card for the loyalty pages of a store that has
/// no (or a not-yet-added) programme. Two variants, no CTA button — just text,
/// with a link to the merchant profile in variant B. Fully theme-aware.
class EmptyLoyaltyCard extends StatelessWidget {
  const EmptyLoyaltyCard({
    super.key,
    required this.merchantName,
    required this.offersProgramme,
    this.programmeLabel = 'Stempelkarten',
    this.onVisitProfile,
  });

  /// Merchant name for variant B.
  final String merchantName;

  /// true  → the store offers the programme, the user just hasn't added it
  ///         → variant B ("… besuche sein Profil um eine hinzuzufügen").
  /// false → the store offers nothing → variant A.
  final bool offersProgramme;

  final String programmeLabel;
  final VoidCallback? onVisitProfile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final body = CustomPaint(
      painter: _DashedRRectPainter(color: cs.outlineVariant),
      child: Container(
        constraints: const BoxConstraints(minHeight: WalletTokens.cardMinHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(WalletTokens.xl),
        child: offersProgramme
            ? _variantB(cs, tt)
            : Text(
                'Dieser Merchant bietet noch kein Treueprogramm an.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
      ),
    );

    if (offersProgramme) {
      return GestureDetector(onTap: onVisitProfile, child: body);
    }
    return body;
  }

  Widget _variantB(ColorScheme cs, TextTheme tt) {
    final base = tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4);
    final name = merchantName.trim().isEmpty ? 'Dieser Merchant' : merchantName.trim();
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '$name bietet $programmeLabel an — '),
          TextSpan(
            text: 'besuche sein Profil',
            style: base?.copyWith(
              color: cs.primary,
              fontWeight: WalletTokens.wSemibold,
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: ' um eine hinzuzufügen.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = WalletTokens.cardRadius;
    const dash = 6.0;
    const gap = 5.0;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color;
}
