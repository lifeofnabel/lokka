import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../merchant/orders/models/orderModel.dart';
import '../services/publicShopService.dart';
import '../widgets/publicShopTheme.dart';

/// „Meine Bestellungen" (nur Runner-Modus): zeigt dem Mitarbeiter alle von ihm
/// abgegebenen Bestellungen mit Live-Status (Eingegangen → In Arbeit →
/// Abholbereit), damit er weiß, wann er abholen kann. Optik passt zur Shop-Seite.
class PublicMyOrdersPage extends StatefulWidget {
  const PublicMyOrdersPage({
    super.key,
    required this.palette,
    required this.merchantId,
    required this.runnerId,
  });

  final PublicShopPalette palette;
  final String merchantId;
  final String runnerId;

  @override
  State<PublicMyOrdersPage> createState() => _PublicMyOrdersPageState();
}

class _PublicMyOrdersPageState extends State<PublicMyOrdersPage> {
  late final Stream<List<OrderModel>> _stream;
  PublicShopPalette get _p => widget.palette;

  @override
  void initState() {
    super.initState();
    final service =
        PublicShopService(firestoreService: context.read<FirestoreService>());
    _stream = service.watchRunnerOrders(widget.merchantId, widget.runnerId);
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Scaffold(
      backgroundColor: _p.background,
      appBar: AppBar(
        backgroundColor: _p.background,
        foregroundColor: _p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          texts.text('public.shop.myOrders'),
          style: TextStyle(color: _p.ink, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<OrderModel>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: _p.accent));
            }
            final orders = snapshot.data ?? const <OrderModel>[];
            if (orders.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded, color: _p.muted, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        texts.text('public.shop.myOrdersEmpty'),
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: _p.muted, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  _MyOrderCard(palette: _p, texts: texts, order: orders[i]),
            );
          },
        ),
      ),
    );
  }
}

class _MyOrderCard extends StatelessWidget {
  const _MyOrderCard({
    required this.palette,
    required this.texts,
    required this.order,
  });

  final PublicShopPalette palette;
  final LanguageService texts;
  final OrderModel order;

  int get _statusIndex {
    switch (order.status) {
      case 'preparing':
        return 1;
      case 'done':
        return 2;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = order.status == 'done';
    final isCancelled = order.status == 'cancelled';
    const amber = Color(0xFFF59E0B);
    const red = Color(0xFFE05260);
    final Color statusColor = isCancelled
        ? red
        : isDone
            ? palette.accent
            : order.status == 'preparing'
                ? amber
                : palette.muted;
    final String statusLabel = isCancelled
        ? texts.text('public.shop.statusCancelled')
        : isDone
            ? texts.text('public.shop.readyPickup')
            : order.status == 'preparing'
                ? texts.text('public.shop.statusPreparing')
                : texts.text('public.shop.statusNew');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? palette.accent : palette.line,
          width: isDone ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : isCancelled
                              ? Icons.cancel_rounded
                              : Icons.schedule_rounded,
                      color: statusColor,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.itemsText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.muted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          // Status-Skala: Eingegangen → In Arbeit → Abholbereit.
          if (!isCancelled)
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= _statusIndex
                            ? statusColor
                            : palette.line.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 5),
                ],
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: palette.muted),
              const SizedBox(width: 4),
              Text(
                order.timeText,
                style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              if (order.tableLabel.trim().isNotEmpty) ...[
                const SizedBox(width: 10),
                Icon(Icons.table_restaurant_rounded,
                    size: 13, color: palette.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.tableLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ] else
                const Spacer(),
              Text(
                '${order.totalPrice.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}',
                style: TextStyle(
                    color: palette.ink, fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
