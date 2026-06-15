import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/orderModel.dart';
import '../providers/merchantOrdersProvider.dart';
import '../services/merchantOrdersService.dart';

class MerchantOrderDetailPage extends StatelessWidget {
  const MerchantOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantOrdersProvider(
        service: MerchantOrdersService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..watchSingle(orderId),
      child: _MerchantOrderDetailView(orderId: orderId),
    );
  }
}

class _MerchantOrderDetailView extends StatelessWidget {
  const _MerchantOrderDetailView({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantOrdersProvider>();
    final order = provider.selectedOrder;

    return MerchantToolScaffold(
      title: texts.text('merchant.orders.detailTitle'),
      subtitle: texts.text('merchant.orders.detailSubtitle'),
      backPath: '/merchant/orders',
      trailing: MerchantInfoTooltip(
        message: texts.text('merchant.orders.detailTooltip'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.isLoading)
            const MerchantLoadingCards(count: 4)
          else if (provider.error != null)
            MerchantErrorState(
              message: provider.error!,
              onRetry: () => provider.watchSingle(orderId),
            )
          else if (order == null)
            MerchantEmptyState(
              title: texts.text('merchant.orders.notFoundTitle'),
              message: texts.text('merchant.orders.notFoundMessage'),
              actionLabel: texts.text('merchant.orders.title'),
              onAction: () => context.go('/merchant/orders'),
            )
          else ...[
            _OrderHeader(order: order),
            const SizedBox(height: AppSpacing.md),
            _OrderItems(order: order),
            const SizedBox(height: AppSpacing.md),
            _StatusActions(order: order, provider: provider),
          ],
        ],
      ),
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
        color: MerchantPremiumColors.ink,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MerchantPremiumColors.ink,
            MerchantPremiumColors.baseElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: MerchantPremiumColors.gold.withOpacity(0.20)),
        boxShadow: MerchantPremiumShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderCode.isEmpty
                      ? texts.text('merchant.orders.order')
                      : order.orderCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.surface,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LightPill(label: _statusLabel(texts, order.status)),
              if (order.placeLabel.isNotEmpty)
                _LightPill(label: order.placeLabel),
              if (order.customerName.isNotEmpty)
                _LightPill(label: order.customerName),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  texts.text('merchant.orders.total'),
                  style: TextStyle(
                    color: MerchantPremiumColors.mutedLight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _price(order.totalPrice, texts),
                style: const TextStyle(
                  color: MerchantPremiumColors.surface,
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
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
              ),
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
    required this.provider,
  });

  final OrderModel order;
  final MerchantOrdersProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (order.status == 'new')
          MerchantPrimaryButton(
            label: texts.text('merchant.orders.accept'),
            icon: Icons.check_rounded,
            isLoading: provider.isSaving,
            onPressed: () => provider.updateStatus(order.id, 'preparing'),
          ),
        if (order.status == 'preparing')
          MerchantPrimaryButton(
            label: texts.text('merchant.orders.markDone'),
            icon: Icons.done_all_rounded,
            isLoading: provider.isSaving,
            onPressed: () => provider.updateStatus(order.id, 'done'),
          ),
        if (order.status != 'done' && order.status != 'cancelled') ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: provider.isSaving
                ? null
                : () => provider.updateStatus(order.id, 'cancelled'),
            icon: const Icon(Icons.cancel_outlined),
            label: Text(texts.text('merchant.orders.cancelOrder')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: Colors.red.shade700,
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
        color: MerchantPremiumColors.gold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.gold.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.goldSoft,
          fontSize: 12,
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

String _price(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}
