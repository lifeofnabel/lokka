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
import '../widgets/orderCard.dart';
import '../widgets/orderDetailPanel.dart';

/// Ab dieser Breite zeigt die Seite Liste links + Detail rechts (Split-View).
const double kOrdersSplitWidth = 900;

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

class _MerchantOrdersView extends StatefulWidget {
  const _MerchantOrdersView();

  @override
  State<_MerchantOrdersView> createState() => _MerchantOrdersViewState();
}

class _MerchantOrdersViewState extends State<_MerchantOrdersView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantOrdersProvider>();
    return MerchantToolScaffold(
      title: texts.text('merchant.orders.title'),
      subtitle: texts.text('merchant.orders.subtitle'),
      backPath: '/merchant/catalog',
      // Tisch-Einsicht oben rechts neben dem Info-Tooltip.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TableViewAction(count: provider.tableGroups.length),
          const SizedBox(width: 8),
          MerchantInfoTooltip(message: texts.text('merchant.orders.tooltip')),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ControlBox(provider: provider),
          const SizedBox(height: AppSpacing.md),
          _ordersArea(context, provider, texts),
        ],
      ),
    );
  }

  Widget _ordersArea(
    BuildContext context,
    MerchantOrdersProvider provider,
    LanguageService texts,
  ) {
    if (provider.isLoading) return const MerchantLoadingCards(count: 5);
    if (provider.error != null) {
      return MerchantErrorState(
          message: provider.error!, onRetry: () => provider.watch());
    }
    if (provider.visibleOrders.isEmpty) {
      return MerchantEmptyState(
        title: texts.text('merchant.orders.emptyTitle'),
        message: texts.text('merchant.orders.emptyMessage'),
        actionLabel: texts.text('merchant.catalog.title'),
        onAction: () => context.push('/merchant/catalog'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kOrdersSplitWidth;
        final cards = [
          for (final order in provider.visibleOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OrderCard(
                order: order,
                onTap: wide
                    ? () => setState(() => _selectedId = order.id)
                    : () => context.push('/merchant/orders/${order.id}'),
                onAccept: order.status == 'new'
                    ? () => provider.updateStatus(order.id, 'preparing')
                    : null,
                onDone: order.status == 'preparing'
                    ? () => provider.updateStatus(order.id, 'done')
                    : null,
                onCancel: order.status == 'done' || order.status == 'cancelled'
                    ? null
                    : () => provider.updateStatus(order.id, 'cancelled'),
              ),
            ),
        ];
        if (!wide) return Column(children: cards);

        OrderModel? selected;
        for (final order in provider.orders) {
          if (order.id == _selectedId) {
            selected = order;
            break;
          }
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: Column(children: cards)),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: selected == null
                  ? _SelectHint(texts: texts)
                  : OrderDetailPanel(
                      order: selected,
                      isSaving: provider.isSaving,
                      onAccept: () => provider.updateStatus(selected!.id, 'preparing'),
                      onDone: () => provider.updateStatus(selected!.id, 'done'),
                      onCancel: () => provider.updateStatus(selected!.id, 'cancelled'),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Platzhalter im Detail-Panel, solange keine Bestellung ausgewählt ist.
class _SelectHint extends StatelessWidget {
  const _SelectHint({required this.texts});

  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          const MerchantPremiumIconBox(
            icon: Icons.touch_app_rounded,
            size: 52,
            iconSize: 24,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            texts.text('merchant.orders.selectHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tisch-Einsicht als kompakte Aktion oben rechts (neben dem Info-Tooltip):
/// rundes Icon im Tooltip-Stil + kleine Anzahl-Badge; öffnet die Tisch-Einsicht.
class _TableViewAction extends StatelessWidget {
  const _TableViewAction({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Tooltip(
      message: texts.text('merchant.orders.tableView'),
      triggerMode: TooltipTriggerMode.tap,
      child: InkWell(
        onTap: () => context.push('/merchant/orders/tables'),
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: MerchantPremiumColors.line),
              ),
              child: const Icon(
                Icons.table_restaurant_rounded,
                color: MerchantPremiumColors.ink,
                size: 18,
              ),
            ),
            if (count > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MerchantPremiumColors.gold,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: MerchantPremiumColors.base, width: 1.5),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: MerchantPremiumColors.base,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Suche + Datum-Filter + Status-Filter (Qoucher-Kontrollbox im Dark-Theme).
class _ControlBox extends StatelessWidget {
  const _ControlBox({required this.provider});

  final MerchantOrdersProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    // Reine Status-Filter (keine Datums-Filter mehr). „Alle" zeigt nur die
    // aktiven Bestellungen (Neue + In Bearbeitung).
    final statusOptions = {
      'all': texts.text('common.all'),
      'new': texts.text('merchant.orders.filter.new'),
      'preparing': texts.text('merchant.orders.filter.preparing'),
      'done': texts.text('merchant.orders.filter.done'),
      'cancelled': texts.text('merchant.orders.filter.cancelled'),
    };

    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: provider.setSearch,
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: texts.text('merchant.orders.searchHint'),
              hintStyle: TextStyle(
                color: MerchantPremiumColors.muted.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: MerchantPremiumColors.muted),
              filled: true,
              fillColor: MerchantPremiumColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MerchantPremiumColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MerchantPremiumColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: MerchantPremiumColors.gold, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in statusOptions.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: entry.value,
                      selected: provider.filter == entry.key,
                      onTap: () => provider.setFilter(entry.key),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? MerchantPremiumColors.gold
          : MerchantPremiumColors.surfaceAlt,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? MerchantPremiumColors.gold
                  : MerchantPremiumColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? MerchantPremiumColors.base
                  : MerchantPremiumColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
