import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';

class MeinePartnerPage extends StatefulWidget {
  const MeinePartnerPage({super.key});

  @override
  State<MeinePartnerPage> createState() => _MeinePartnerPageState();
}

class _MeinePartnerPageState extends State<MeinePartnerPage> {
  late final FirestoreService _firestoreService;
  late final AuthService _authService;

  List<WalletCardModel> _cards = [];
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
          .collection(FirebasePaths.userWalletCards(uid))
          .get();
      final cards = snap.docs
          .map((d) => WalletCardModel.fromMap(d.data()))
          .where((c) => c.merchantId.isNotEmpty)
          .toList();
      if (mounted) setState(() { _cards = cards; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openPartner(BuildContext context, String merchantId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final doc = await _firestoreService
          .document(FirebasePaths.publicMerchant(merchantId))
          .get();
      if (!context.mounted) return;
      Navigator.pop(context);
      if (doc.exists && doc.data() != null) {
        final merchant = PublicMerchantUserModel.fromMap(
            {...doc.data()!, 'merchantId': doc.id});
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => UserPartnerDetailPage(merchant: merchant)),
        );
      }
    } catch (_) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Meine Partner'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingState();
    if (_error != null) {
      return AppErrorState(message: 'Laden fehlgeschlagen', onRetry: _load);
    }
    if (_cards.isEmpty) {
      return const AppEmptyState(
        icon: Icons.store_outlined,
        title: 'Noch keine Partner',
        message: 'Scanne einen QR-Code oder besuche einen Partner.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, i) => _PartnerTile(
        card: _cards[i],
        onTap: () => _openPartner(ctx, _cards[i].merchantId),
      ),
    );
  }
}

class _PartnerTile extends StatelessWidget {
  const _PartnerTile({required this.card, required this.onTap});

  final WalletCardModel card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.large),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                clipBehavior: Clip.antiAlias,
                child: card.merchantLogoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: card.merchantLogoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.store_rounded,
                          size: 22,
                          color: cs.onSecondaryContainer,
                        ),
                      )
                    : Icon(Icons.store_rounded,
                        size: 22, color: cs.onSecondaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.merchantName,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (card.merchantArea.isNotEmpty)
                      Text(
                        card.merchantArea,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
