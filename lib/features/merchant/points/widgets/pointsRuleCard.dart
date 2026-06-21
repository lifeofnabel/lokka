import 'package:flutter/material.dart';

import '../../../../core/widgets/appImage.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../models/pointsSystemModel.dart';

/// Quadratisches Vorschaubild einer Belohnung (Bild oder Geschenk-Icon).
/// Wird auf der Punkte-Übersicht und im Belohnungs-Editor verwendet.
class PointsRewardPreview extends StatelessWidget {
  const PointsRewardPreview({
    super.key,
    required this.reward,
    this.size = 120,
  });

  final PointsRewardModel reward;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isExpanding = size.isInfinite;
    // Decode-Breite an die Anzeigegröße koppeln (DevicePixelRatio einkalkuliert),
    // damit große Originalbilder nicht voll in den Speicher geladen werden.
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final memCacheWidth = isExpanding ? null : (size * dpr).round();
    return Container(
      width: size,
      height: isExpanding ? null : size,
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(isExpanding || size > 90 ? 22 : 18),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: reward.imageUrl.isEmpty
          ? const Center(
              child: Icon(Icons.card_giftcard_rounded,
                  color: MerchantPremiumColors.ink),
            )
          : AppImage(
              imageUrl: reward.imageUrl,
              memCacheWidth: memCacheWidth,
              errorWidget: const Center(
                child: Icon(Icons.card_giftcard_rounded,
                    color: MerchantPremiumColors.ink),
              ),
              placeholder: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MerchantPremiumColors.muted,
                  ),
                ),
              ),
            ),
    );
  }
}
