import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../pages/publicCartPage.dart';
import '../providers/publicShopProvider.dart';
import 'publicShopTheme.dart';

/// Schwebende Warenkorb-Leiste. Tippen öffnet die Warenkorb-Seite
/// (eigene Route mit demselben Provider – kein Bottom-Sheet mehr).
class PublicShopActionBar extends StatelessWidget {
  const PublicShopActionBar({
    super.key,
    required this.provider,
    required this.palette,
    required this.merchantId,
  });

  final PublicShopProvider provider;
  final PublicShopPalette palette;
  final String merchantId;

  void _openCart(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: PublicCartPage(palette: palette, merchantId: merchantId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final itemCount = provider.cart.fold<int>(0, (sum, item) => sum + item.quantity);
    final ordered = provider.createdOrderId != null;
    final bg = ordered ? palette.accent : palette.ink;
    final fg = ordered ? palette.onAccent : palette.background;
    final muted = palette.muted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        elevation: 0,
        child: InkWell(
          onTap: ordered ? null : () => _openCart(context),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ordered
                ? Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: fg, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          texts.text('public.shop.orderSent'),
                          style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.shopping_bag_rounded, color: fg),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              itemCount == 0
                                  ? texts.text('public.shop.cart')
                                  : texts
                                      .text('public.shop.orderWithCount')
                                      .replaceAll('{count}', itemCount.toString()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              provider.cart.isEmpty
                                  ? texts.text('public.shop.cartEmpty')
                                  : _price(provider.totalPrice, texts),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_up_rounded, color: fg),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

String _price(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}
