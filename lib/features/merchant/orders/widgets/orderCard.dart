import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../models/orderModel.dart';

/// Bestellkarte (Qoucher-Struktur im lokka-Premium-Dark-Theme):
/// Status-Icon, Code + Zeit, Status-Pille, Tisch-Tag, Ort + Summe,
/// Artikel-Vorschau und optionale Inline-Aktionen.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onAccept,
    this.onDone,
    this.onCancel,
    this.runnerName = '',
  });

  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;
  final String runnerName;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final statusColor = _statusColor(order.status);
    final highlight = order.status == 'new';

    return MerchantPremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: highlight
          ? MerchantPremiumColors.gold.withValues(alpha: 0.55)
          : MerchantPremiumColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  order.isTableOrder
                      ? Icons.table_restaurant_rounded
                      : Icons.receipt_long_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderCode.isEmpty
                          ? texts.text('merchant.orders.order')
                          : order.orderCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.dateText} • ${order.timeText}',
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: _statusLabel(texts, order.status), color: statusColor),
            ],
          ),
          if (order.isTableOrder || runnerName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (order.isTableOrder)
                  MerchantPremiumPill(
                    icon: Icons.table_restaurant_rounded,
                    label: order.tableDisplayLabel,
                    background: MerchantPremiumColors.goldSoft,
                    foreground: MerchantPremiumColors.mint,
                    borderColor: MerchantPremiumColors.gold.withValues(alpha: 0.22),
                  ),
                if (runnerName.isNotEmpty)
                  MerchantPremiumPill(
                    icon: Icons.directions_run_rounded,
                    label: runnerName,
                    background: MerchantPremiumColors.surface,
                    foreground: MerchantPremiumColors.muted,
                    borderColor: MerchantPremiumColors.glassBorder,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: 17, color: MerchantPremiumColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.placeLabel.isEmpty
                      ? texts.text('merchant.orders.order')
                      : order.placeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _price(order.totalPrice, texts),
                style: const TextStyle(
                  color: MerchantPremiumColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              order.items
                  .take(3)
                  .map((item) => '${item.quantity}x ${item.title}')
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (onAccept != null || onDone != null || onCancel != null) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                if (onAccept != null)
                  Expanded(
                    child: _ActionButton(
                      label: texts.text('merchant.orders.accept'),
                      color: MerchantPremiumColors.gold,
                      foreground: MerchantPremiumColors.base,
                      onTap: onAccept!,
                    ),
                  ),
                if (onDone != null)
                  Expanded(
                    child: _ActionButton(
                      label: texts.text('merchant.orders.status.done'),
                      color: MerchantPremiumColors.success,
                      foreground: MerchantPremiumColors.base,
                      onTap: onDone!,
                    ),
                  ),
                if (onCancel != null) ...[
                  if (onAccept != null || onDone != null)
                    const SizedBox(width: 8),
                  _IconButton(
                    icon: Icons.close_rounded,
                    color: MerchantPremiumColors.danger,
                    onTap: onCancel!,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: color, size: 20),
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
    'preparing' => MerchantPremiumColors.gold,
    'done' => MerchantPremiumColors.success,
    'cancelled' => MerchantPremiumColors.danger,
    _ => MerchantPremiumColors.warning,
  };
}

String _price(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}
