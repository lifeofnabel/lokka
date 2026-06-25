import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/orderModel.dart';
import 'orderStatusStyle.dart';

/// Detailansicht einer Bestellung (Header, Artikel, Status-Aktionen).
/// Wird sowohl von der Detailseite als auch vom Split-View (Detail rechts)
/// auf breiten Displays genutzt.
class OrderDetailPanel extends StatelessWidget {
  const OrderDetailPanel({
    super.key,
    required this.order,
    this.onAccept,
    this.onDone,
    this.onCancel,
    this.isSaving = false,
  });

  final OrderModel order;
  final VoidCallback? onAccept;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderHeader(order: order),
        const SizedBox(height: AppSpacing.md),
        _OrderItems(order: order),
        const SizedBox(height: AppSpacing.md),
        _StatusActions(
          order: order,
          onAccept: onAccept,
          onDone: onDone,
          onCancel: onCancel,
          isSaving: isSaving,
        ),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MerchantPremiumColors.surface,
            MerchantPremiumColors.baseElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.22)),
        boxShadow: MerchantPremiumShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.orderCode.isEmpty
                      ? texts.text('merchant.orders.order')
                      : order.orderCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.dateText,
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    order.timeText,
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Farb-kodierte Status-Pille (Neu/In Arbeit/Fertig/Storniert) →
              // an der Kasse sofort erkennbar statt einheitlich gold.
              OrderStatusPill.forStatus(texts, order.status),
              _LightPill(
                label: order.isTakeaway
                    ? texts.text('public.shop.takeaway')
                    : texts.text('public.shop.dineIn'),
              ),
              if (order.isTableOrder)
                _LightPill(label: order.tableDisplayLabel)
              else if (order.placeLabel.isNotEmpty)
                _LightPill(label: order.placeLabel),
              if (order.isTakeaway && order.pickupTime.trim().isNotEmpty)
                _LightPill(label: '${texts.text('public.shop.pickupTime')}: ${order.pickupTime}'),
              if (order.isQrCashier)
                _LightPill(label: texts.text('merchant.orders.fulfillmentQr')),
              if (order.customerName.isNotEmpty)
                _LightPill(label: order.customerName),
            ],
          ),
          if (order.customerNote.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sticky_note_2_outlined,
                    size: 18, color: MerchantPremiumColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.customerNote.trim(),
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  texts.text('merchant.orders.total'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _price(order.totalPrice, texts),
                style: const TextStyle(
                  color: MerchantPremiumColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItems extends StatelessWidget {
  const _OrderItems({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texts.text('merchant.orders.items'),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (order.items.isEmpty)
            Text(
              texts.text('merchant.orders.noItems'),
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...order.items.map((item) => _OrderItemRow(item: item)),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItemModel item;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MerchantPremiumColors.surfaceAlt,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: MerchantPremiumColors.line),
            ),
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.options.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.optionsText,
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (item.note.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '„${item.note.trim()}"',
                      style: const TextStyle(
                        color: MerchantPremiumColors.coral,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _price(item.totalPrice, texts),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.order,
    required this.onAccept,
    required this.onDone,
    required this.onCancel,
    required this.isSaving,
  });

  final OrderModel order;
  final VoidCallback? onAccept;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (order.status == 'new' && onAccept != null)
          MerchantPrimaryButton(
            label: texts.text('merchant.orders.accept'),
            icon: Icons.check_rounded,
            isLoading: isSaving,
            onPressed: onAccept,
          ),
        if (order.status == 'preparing' && onDone != null)
          MerchantPrimaryButton(
            label: texts.text('merchant.orders.markDone'),
            icon: Icons.done_all_rounded,
            isLoading: isSaving,
            onPressed: onDone,
          ),
        if (order.status != 'done' &&
            order.status != 'cancelled' &&
            onCancel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: isSaving ? null : onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(texts.text('merchant.orders.cancelOrder')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: MerchantPremiumColors.danger,
              side: BorderSide(
                  color: MerchantPremiumColors.danger.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LightPill extends StatelessWidget {
  const _LightPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.mint,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _price(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}
