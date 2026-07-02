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
import '../widgets/orderStatusStyle.dart';
import 'merchantOrdersPage.dart' show kOrdersSplitWidth;

MerchantOrdersProvider _ordersProvider(BuildContext context) =>
    MerchantOrdersProvider(
      service: MerchantOrdersService(
        authService: context.read<AuthService>(),
        firestoreService: context.read<FirestoreService>(),
      ),
    )..watch();

/// Tisch-Einsicht: alle aktiven Bestellungen gruppiert nach Tisch.
class MerchantOrderTablesPage extends StatelessWidget {
  const MerchantOrderTablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: _ordersProvider,
      child: const _MerchantOrderTablesView(),
    );
  }
}

class _MerchantOrderTablesView extends StatelessWidget {
  const _MerchantOrderTablesView();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantOrdersProvider>();
    final groups = provider.tableGroups;
    final tableKeys = groups.keys.toList();
    final areaNames = provider.tableAreaNames;
    final showAreaFilter = areaNames.length >= 2;

    return MerchantToolScaffold(
      title: texts.text('merchant.orders.tablesTitle'),
      subtitle: texts.text('merchant.orders.tablesSubtitle'),
      backPath: '/merchant/orders',
      // Arbeits-Terminal (Kasse/Tablet) – wie die Bestellungen-Seite breiter.
      maxWidth: 980,
      trailing:
          MerchantInfoTooltip(message: texts.text('merchant.orders.tablesTooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showAreaFilter) ...[
            _AreaFilterRow(
              areaNames: areaNames,
              selected: provider.tableAreaFilter,
              onSelect: provider.setTableAreaFilter,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (provider.isLoading)
            const MerchantLoadingCards(count: 4)
          else if (provider.error != null)
            MerchantErrorState(
                message: provider.error!, onRetry: () => provider.watch())
          else if (tableKeys.isEmpty)
            MerchantEmptyState(
              title: texts.text('merchant.orders.tablesEmptyTitle'),
              message: texts.text('merchant.orders.tablesEmptyMessage'),
              actionLabel: texts.text('merchant.orders.title'),
              onAction: () => context.go('/merchant/orders'),
            )
          else
            ...tableKeys.map(
              (key) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TableTile(
                  tableKey: key,
                  orders: groups[key]!,
                  onTap: () => context.push('/merchant/orders/tables/$key'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.tableKey,
    required this.orders,
    required this.onTap,
  });

  final String tableKey;
  final List<OrderModel> orders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final openCount = orders.where((order) => order.isOpen).length;
    final total = orders
        .where((order) => order.status != 'cancelled')
        .fold<num>(0, (sum, order) => sum + order.totalPrice);
    final label = orders.isNotEmpty ? orders.first.tableDisplayLabel : tableKey;
    final isOpen = openCount > 0;
    // Offen = noch zu bearbeiten (warm), Beendet = alles fertig (grün).
    final accent =
        isOpen ? MerchantPremiumColors.warning : MerchantPremiumColors.success;

    return MerchantPremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Tisch-Symbol, farblich nach Status.
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.30)),
            ),
            child: Icon(Icons.table_restaurant_rounded, color: accent, size: 24),
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
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MerchantPremiumColors.ink,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OrderStatusPill(
                      label: isOpen
                          ? texts.text('merchant.orders.tableStatusOpen')
                          : texts.text('merchant.orders.tableStatusClosed'),
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  isOpen
                      ? '${orders.length} ${texts.text('merchant.orders.title')} · $openCount ${texts.text('merchant.orders.open')} · ${_euro(total, texts)}'
                      : '${orders.length} ${texts.text('merchant.orders.title')} · ${_euro(total, texts)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: MerchantPremiumColors.muted),
        ],
      ),
    );
  }
}

/// Tisch-Detail: alle Bestellungen eines Tisches mit Aktionen je Bestellung.
class MerchantTableOrdersPage extends StatelessWidget {
  const MerchantTableOrdersPage({super.key, required this.tableKey});

  final String tableKey;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: _ordersProvider,
      child: _MerchantTableOrdersView(tableKey: tableKey),
    );
  }
}

class _MerchantTableOrdersView extends StatefulWidget {
  const _MerchantTableOrdersView({required this.tableKey});

  final String tableKey;

  @override
  State<_MerchantTableOrdersView> createState() =>
      _MerchantTableOrdersViewState();
}

class _MerchantTableOrdersViewState extends State<_MerchantTableOrdersView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantOrdersProvider>();
    final orders = provider.ordersForTable(widget.tableKey);
    final label = orders.isNotEmpty
        ? orders.first.tableDisplayLabel
        : texts.text('merchant.orders.tablesTitle');

    return MerchantToolScaffold(
      title: label,
      subtitle: texts.text('merchant.orders.tableOrdersSubtitle'),
      backPath: '/merchant/orders/tables',
      // Arbeits-Terminal (Kasse/Tablet) – wie die Bestellungen-Seite breiter.
      maxWidth: 980,
      trailing:
          MerchantInfoTooltip(message: texts.text('merchant.orders.tablesTooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.isLoading)
            const MerchantLoadingCards(count: 4)
          else if (provider.error != null)
            MerchantErrorState(
                message: provider.error!, onRetry: () => provider.watch())
          else if (orders.isEmpty)
            MerchantEmptyState(
              title: texts.text('merchant.orders.tablesEmptyTitle'),
              message: texts.text('merchant.orders.tablesEmptyMessage'),
              actionLabel: texts.text('merchant.orders.tablesTitle'),
              onAction: () => context.go('/merchant/orders/tables'),
            )
          else ...[
            _TableSummary(orders: orders),
            const SizedBox(height: AppSpacing.md),
            _CloseTableBar(
              hasOpen: orders.any((order) => order.isOpen),
              isSaving: provider.isSaving,
              onClose: () => _closeTable(context, provider),
              onClean: () => _cleanTable(context, provider),
            ),
            const SizedBox(height: AppSpacing.md),
            _tableOrdersArea(context, provider, orders, texts),
          ],
        ],
      ),
    );
  }

  /// „Tisch abschließen": fragt nach und markiert alle offenen Bestellungen
  /// des Tisches als fertig (danach gilt der Tisch als beendet).
  Future<void> _closeTable(
    BuildContext context,
    MerchantOrdersProvider provider,
  ) async {
    final texts = context.read<LanguageService>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(texts.text('merchant.orders.closeTable')),
        content: Text(texts.text('merchant.orders.closeTableConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(texts.text('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(texts.text('merchant.orders.closeTable')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await provider.closeTable(widget.tableKey);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(texts.text('merchant.orders.tableClosedToast'))),
    );
  }

  /// „Tisch aufräumen": leert den Tisch (entfernt ihn aus der Einsicht) und
  /// zählt alle noch offenen Bestellungen als bezahlt. Danach zurück zur Liste.
  Future<void> _cleanTable(
    BuildContext context,
    MerchantOrdersProvider provider,
  ) async {
    final texts = context.read<LanguageService>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(texts.text('merchant.orders.cleanTable')),
        content: Text(texts.text('merchant.orders.cleanTableConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(texts.text('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(texts.text('merchant.orders.cleanTable')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await provider.cleanTable(widget.tableKey);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(texts.text('merchant.orders.tableCleanedToast'))),
    );
    if (context.mounted) context.pop();
  }

  Widget _tableOrdersArea(
    BuildContext context,
    MerchantOrdersProvider provider,
    List<OrderModel> orders,
    LanguageService texts,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kOrdersSplitWidth;
        final cards = [
          for (final order in orders)
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
        for (final order in orders) {
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
                  ? _TableSelectHint(texts: texts)
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

class _TableSelectHint extends StatelessWidget {
  const _TableSelectHint({required this.texts});

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

class _TableSummary extends StatelessWidget {
  const _TableSummary({required this.orders});

  final List<OrderModel> orders;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final openCount = orders.where((order) => order.isOpen).length;
    final total = orders
        .where((order) => order.status != 'cancelled')
        .fold<num>(0, (sum, order) => sum + order.totalPrice);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.20)),
        boxShadow: MerchantPremiumShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              value: orders.length.toString(),
              label: texts.text('merchant.orders.title'),
            ),
          ),
          const _DividerLine(),
          Expanded(
            child: _SummaryValue(
              value: openCount.toString(),
              label: texts.text('merchant.orders.open'),
            ),
          ),
          const _DividerLine(),
          Expanded(
            child: _SummaryValue(
              value: _euro(total, texts),
              label: texts.text('merchant.orders.total'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: MerchantPremiumColors.surface,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: MerchantPremiumColors.mutedLight,
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
      color: MerchantPremiumColors.gold.withValues(alpha: 0.18),
    );
  }
}

/// Bereich-Filter der Tisch-Einsicht (horizontale Chips: Alle Bereiche + je Bereich).
class _AreaFilterRow extends StatelessWidget {
  const _AreaFilterRow({
    required this.areaNames,
    required this.selected,
    required this.onSelect,
  });

  final List<String> areaNames;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _AreaChip(
            label: texts.text('merchant.orders.allAreas'),
            selected: selected == 'all',
            onTap: () => onSelect('all'),
          ),
          const SizedBox(width: 8),
          for (final area in areaNames) ...[
            _AreaChip(
              label: area.isEmpty
                  ? texts.text('merchant.orders.noArea')
                  : area,
              selected: selected == area,
              onTap: () => onSelect(area),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
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

/// „Tisch abschließen"-Leiste: Button, solange offene Bestellungen da sind –
/// danach eine grüne „Beendet"-Bestätigung.
class _CloseTableBar extends StatelessWidget {
  const _CloseTableBar({
    required this.hasOpen,
    required this.isSaving,
    required this.onClose,
    required this.onClean,
  });

  final bool hasOpen;
  final bool isSaving;
  final VoidCallback onClose;
  final VoidCallback onClean;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    if (!hasOpen) {
      // Tisch ist fertig → „Aufräumen" (leeren + alles als bezahlt zählen).
      return FilledButton.icon(
        onPressed: isSaving ? null : onClean,
        icon: const Icon(Icons.cleaning_services_rounded),
        label: Text(texts.text('merchant.orders.cleanTable')),
        style: FilledButton.styleFrom(
          backgroundColor: MerchantPremiumColors.success,
          foregroundColor: MerchantPremiumColors.base,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: isSaving ? null : onClose,
      icon: const Icon(Icons.task_alt_rounded),
      label: Text(texts.text('merchant.orders.closeTable')),
      style: FilledButton.styleFrom(
        backgroundColor: MerchantPremiumColors.gold,
        foregroundColor: MerchantPremiumColors.base,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

String _euro(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}
