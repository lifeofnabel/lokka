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
import '../services/merchantOrdersService.dart';

enum _Range { today, week, month }

/// Finanzen-Übersicht: bezahlte Bestellungen je Zeitraum (Heute/Woche/Monat),
/// Gesamtsumme und der Schalter für die Tagesumsatz-Pause.
///
/// Datenquelle ist [MerchantOrdersService.loadPaidOrdersBetween] (Range auf
/// `paidAt`). Die Historie zeigt ALLE bezahlten Bestellungen – auch die, die
/// während einer Pause abgeschlossen wurden (die zählen nur im Tageszähler
/// nicht mit).
class MerchantFinancePage extends StatefulWidget {
  const MerchantFinancePage({super.key});

  @override
  State<MerchantFinancePage> createState() => _MerchantFinancePageState();
}

class _MerchantFinancePageState extends State<MerchantFinancePage> {
  _Range _range = _Range.today;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _paused = false;
  List<OrderModel> _orders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  MerchantOrdersService _service() => MerchantOrdersService(
        authService: context.read<AuthService>(),
        firestoreService: context.read<FirestoreService>(),
      );

  (DateTime, DateTime?) _rangeBounds() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      _Range.today => (startOfDay, null),
      _Range.week => (
          startOfDay.subtract(Duration(days: now.weekday - 1)),
          null,
        ),
      _Range.month => (DateTime(now.year, now.month, 1), null),
    };
  }

  Future<void> _load() async {
    final service = _service();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (since, until) = _rangeBounds();
      final orders = await service.loadPaidOrdersBetween(since, until);
      final paused = await service.loadRevenuePaused();
      orders.sort(
        (a, b) => (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)),
      );
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _paused = paused;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _togglePause() async {
    if (_busy) return;
    final service = _service();
    setState(() => _busy = true);
    final next = !_paused;
    try {
      await service.setRevenuePaused(next);
      if (mounted) setState(() => _paused = next);
    } catch (_) {
      // Pause ist unkritisch – Fehler still verschlucken.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  num get _total => _orders.fold<num>(0, (acc, order) => acc + order.totalPrice);

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.finance.title'),
      subtitle: texts.text('merchant.finance.subtitle'),
      backPath: '/merchant/catalog',
      trailing: MerchantInfoTooltip(
        message: texts.text('merchant.finance.tooltip'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RangeTabs(
            range: _range,
            texts: texts,
            onChanged: (next) {
              setState(() => _range = next);
              _load();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const MerchantLoadingCards(count: 3)
          else if (_error != null)
            MerchantErrorState(message: _error!, onRetry: _load)
          else ...[
            _SummaryCard(total: _total, count: _orders.length, texts: texts),
            const SizedBox(height: AppSpacing.md),
            _PauseCard(
              paused: _paused,
              busy: _busy,
              onToggle: _togglePause,
              texts: texts,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_orders.isEmpty)
              MerchantEmptyState(
                title: texts.text('merchant.finance.emptyTitle'),
                message: texts.text('merchant.finance.empty'),
                actionLabel: texts.text('merchant.orders.title'),
                onAction: () => context.go('/merchant/orders'),
              )
            else
              for (final order in _orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PaidOrderRow(order: order, texts: texts),
                ),
          ],
        ],
      ),
    );
  }
}

String _euro(num value, LanguageService texts) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({
    required this.range,
    required this.texts,
    required this.onChanged,
  });

  final _Range range;
  final LanguageService texts;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <_Range, String>{
      _Range.today: texts.text('merchant.finance.period.today'),
      _Range.week: texts.text('merchant.finance.period.week'),
      _Range.month: texts.text('merchant.finance.period.month'),
    };
    return Row(
      children: [
        for (final entry in entries.entries) ...[
          Expanded(
            child: _RangeChip(
              label: entry.value,
              selected: range == entry.key,
              onTap: () => onChanged(entry.key),
            ),
          ),
          if (entry.key != _Range.month) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
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
          height: 44,
          alignment: Alignment.center,
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
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.count,
    required this.texts,
  });

  final num total;
  final int count;
  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      child: Row(
        children: [
          const MerchantPremiumIconBox(
            icon: Icons.account_balance_wallet_rounded,
            size: 54,
            iconSize: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texts.text('merchant.finance.total'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _euro(total, texts),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
          MerchantPremiumPill(
            icon: Icons.receipt_long_rounded,
            label: '$count ${texts.text('merchant.finance.orders')}',
          ),
        ],
      ),
    );
  }
}

class _PauseCard extends StatelessWidget {
  const _PauseCard({
    required this.paused,
    required this.busy,
    required this.onToggle,
    required this.texts,
  });

  final bool paused;
  final bool busy;
  final VoidCallback onToggle;
  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texts.text('merchant.finance.pauseTitle'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paused
                      ? texts.text('merchant.finance.pauseActiveInfo')
                      : texts.text('merchant.finance.pauseInfo'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch(
            value: paused,
            onChanged: busy ? null : (_) => onToggle(),
            activeThumbColor: MerchantPremiumColors.warning,
          ),
        ],
      ),
    );
  }
}

class _PaidOrderRow extends StatelessWidget {
  const _PaidOrderRow({required this.order, required this.texts});

  final OrderModel order;
  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MerchantPremiumColors.success.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: MerchantPremiumColors.success,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.dateText} • ${order.timeText}',
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (order.excludeFromDaily) ...[
            MerchantPremiumPill(
              label: texts.text('merchant.finance.excluded'),
              background: MerchantPremiumColors.warningSoft,
              foreground: MerchantPremiumColors.warning,
              borderColor: MerchantPremiumColors.warning.withValues(alpha: 0.30),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _euro(order.totalPrice, texts),
            style: const TextStyle(
              color: MerchantPremiumColors.gold,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
