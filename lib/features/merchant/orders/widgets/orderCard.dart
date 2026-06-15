import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../models/orderModel.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: MerchantPremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _statusColor(order.status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.receipt_long_rounded, color: _statusColor(order.status)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.orderCode.isEmpty ? texts.text('merchant.orders.order') : order.orderCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MerchantPremiumColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    order.itemsText.isEmpty ? order.placeLabel : order.itemsText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Pill(label: _statusLabel(texts, order.status)),
                      const SizedBox(width: 8),
                      Text(
                        _price(order.totalPrice, texts),
                        style: const TextStyle(
                          color: MerchantPremiumColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: MerchantPremiumColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _statusLabel(LanguageService texts, String status) {
  return switch (status) {
    'preparing' => texts.text('merchant.orders.status.preparing'),
    'done' => texts.text('merchant.orders.status.done'),
    'cancelled' => texts.text('merchant.orders.status.cancelled'),
    _ => texts.text('merchant.orders.status.new'),
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'preparing' => MerchantPremiumColors.warning,
    'done' => MerchantPremiumColors.success,
    'cancelled' => MerchantPremiumColors.danger,
    _ => MerchantPremiumColors.ink,
  };
}

String _price(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}
