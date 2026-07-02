import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../providers/merchantOrdersProvider.dart';
import '../services/merchantOrdersService.dart';
import '../widgets/orderDetailPanel.dart';

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
      // Bestellungen-Familie einheitlich breit (Kasse/Tablet).
      maxWidth: 980,
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
          else
            OrderDetailPanel(
              order: order,
              isSaving: provider.isSaving,
              onAccept: () => provider.updateStatus(order.id, 'preparing'),
              onDone: () => provider.updateStatus(order.id, 'done'),
              onCancel: () => provider.updateStatus(order.id, 'cancelled'),
            ),
        ],
      ),
    );
  }
}
