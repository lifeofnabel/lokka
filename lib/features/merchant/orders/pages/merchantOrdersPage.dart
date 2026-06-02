import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../providers/merchantOrdersProvider.dart';
import '../services/merchantOrdersService.dart';
import '../widgets/orderCard.dart';

class MerchantOrdersPage extends StatelessWidget {
  const MerchantOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantOrdersProvider(
        service: MerchantOrdersService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..watch(),
      child: const _MerchantOrdersView(),
    );
  }
}

class _MerchantOrdersView extends StatelessWidget {
  const _MerchantOrdersView();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantOrdersProvider>();
    return MerchantToolScaffold(
      title: texts.text('merchant.orders.title'),
      subtitle: texts.text('merchant.orders.subtitle'),
      backPath: '/merchant/catalog',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.orders.tooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OrderSummary(provider: provider),
          const SizedBox(height: AppSpacing.md),
          _FilterBar(provider: provider),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards(count: 5)
          else if (provider.error != null)
            MerchantErrorState(message: provider.error!, onRetry: () => provider.watch())
          else if (provider.visibleOrders.isEmpty)
            MerchantEmptyState(
              title: texts.text('merchant.orders.emptyTitle'),
              message: texts.text('merchant.orders.emptyMessage'),
              actionLabel: texts.text('merchant.catalog.demoTitle'),
              onAction: () => context.push('/merchant/catalog/demo'),
            )
          else
            ...provider.visibleOrders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OrderCard(
                  order: order,
                  onTap: () => context.push('/merchant/orders/${order.id}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.provider});

  final MerchantOrdersProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              value: provider.activeCount.toString(),
              label: texts.text('merchant.orders.summary.active'),
            ),
          ),
          _DividerLine(),
          Expanded(
            child: _SummaryValue(
              value: provider.newCount.toString(),
              label: texts.text('merchant.orders.status.new'),
            ),
          ),
          _DividerLine(),
          Expanded(
            child: _SummaryValue(
              value: provider.preparingCount.toString(),
              label: texts.text('merchant.orders.status.preparing'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.white.withOpacity(0.66),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: AppColors.white.withOpacity(0.12),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.provider});

  final MerchantOrdersProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final options = {
      'active': texts.text('merchant.orders.filter.active'),
      'new': texts.text('merchant.orders.status.new'),
      'preparing': texts.text('merchant.orders.status.preparing'),
      'done': texts.text('merchant.orders.status.done'),
      'all': texts.text('common.all'),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.entries.map((entry) {
          final selected = provider.filter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) => provider.setFilter(entry.key),
              selectedColor: AppColors.black,
              labelStyle: TextStyle(
                color: selected ? AppColors.white : AppColors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
