import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appSpacing.dart';
import '../providers/publicShopProvider.dart';

class PublicShopActionBar extends StatelessWidget {
  const PublicShopActionBar({
    super.key,
    required this.provider,
    required this.onOrder,
  });

  final PublicShopProvider provider;
  final Future<bool> Function() onOrder;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final itemCount = provider.cart.fold<int>(0, (sum, item) => sum + item.quantity);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: provider.createdOrderId != null
            ? _SuccessContent(orderId: provider.createdOrderId!)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.cart.isEmpty)
                    Text(
                      texts.text('public.shop.cartEmpty'),
                      style: TextStyle(
                        color: AppColors.white.withOpacity(0.64),
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    _CartLines(provider: provider),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${provider.totalPrice.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: provider.cart.isEmpty || provider.isSaving ? null : onOrder,
                        icon: provider.isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.shopping_bag_rounded),
                        label: Text(
                          itemCount == 0
                              ? texts.text('public.shop.order')
                              : texts.text('public.shop.orderWithCount').replaceAll('{count}', itemCount.toString()),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _CartLines extends StatelessWidget {
  const _CartLines({required this.provider});

  final PublicShopProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: provider.cart
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.quantity}x ${entry.item.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => provider.removeItem(entry.item.id),
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.white),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.white, size: 34),
        const SizedBox(height: AppSpacing.sm),
        Text(
          texts.text('public.shop.orderSent'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
