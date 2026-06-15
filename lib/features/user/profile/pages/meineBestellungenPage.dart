import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';

class MeineBestellungenPage extends StatefulWidget {
  const MeineBestellungenPage({super.key});

  @override
  State<MeineBestellungenPage> createState() => _MeineBestellungenPageState();
}

class _MeineBestellungenPageState extends State<MeineBestellungenPage> {
  late final FirestoreService _firestoreService;
  late final AuthService _authService;

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _authService = context.read<AuthService>();
    _load();
  }

  Future<void> _load() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; });
      return;
    }
    try {
      final snap = await _firestoreService
          .collection(FirebasePaths.userOrders(uid))
          .orderBy('createdAt', descending: true)
          .get();
      final orders = snap.docs.map((d) => d.data()).toList();
      if (mounted) setState(() { _orders = orders; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Meine Bestellungen'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingState();
    if (_error != null) {
      return AppErrorState(message: 'Laden fehlgeschlagen', onRetry: _load);
    }
    if (_orders.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Noch keine Bestellungen',
        message: 'Bestellungen bei Partnern erscheinen hier.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _OrderTile(order: _orders[i]),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final id = order['orderId'] as String? ?? '–';
    final merchant = order['merchantName'] as String? ?? 'Händler';
    final status = order['status'] as String? ?? 'offen';
    final total = (order['totalAmount'] as num?)?.toDouble();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: cs.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '#$id · $status',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (total != null)
            Text(
              '${total.toStringAsFixed(2).replaceAll('.', ',')} €',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
