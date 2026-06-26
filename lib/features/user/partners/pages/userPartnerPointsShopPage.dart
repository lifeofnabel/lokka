import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/widgets/responsiveContentWidth.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/merchant/points/models/pointsSystemModel.dart';
import 'package:lokka/features/user/partners/services/userLoyaltyService.dart';

/// Punktshop eines Partners (read-only User-Sicht).
///
/// Listet alle aktiven Punkte-Geschenke. Alles im Shop kostet symbolisch
/// 0,01 € plus die benötigten Punkte — reine Anzeige, kein Checkout.
class UserPartnerPointsShopPage extends StatefulWidget {
  const UserPartnerPointsShopPage({
    super.key,
    required this.merchantId,
    required this.shopName,
  });

  final String merchantId;
  final String shopName;

  @override
  State<UserPartnerPointsShopPage> createState() =>
      _UserPartnerPointsShopPageState();
}

class _UserPartnerPointsShopPageState extends State<UserPartnerPointsShopPage> {
  late final UserLoyaltyService _service;
  List<PointsRewardModel> _rewards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = UserLoyaltyService(
      firestoreService: context.read<FirestoreService>(),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rewards = await _service.fetchPointsRewards(widget.merchantId);
      if (mounted) {
        setState(() {
          _rewards = rewards;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.greenTint,
      body: ResponsiveContentWidth(
        child: CustomScrollView(
        slivers: [
          _header(),
          if (_loading)
            const SliverFillRemaining(
                hasScrollBody: false, child: AppLoadingState())
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(
                  message: 'Punktshop konnte nicht geladen werden',
                  onRetry: _load),
            )
          else if (_rewards.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.card_giftcard_rounded,
                title: 'Noch keine Prämien',
                message:
                    'Dieser Partner hat aktuell keine Prämien im Punktshop.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
              sliver: SliverList.builder(
                itemCount: _rewards.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) return const _ShopInfoBanner();
                  return _ShopRewardCard(reward: _rewards[i - 1]);
                },
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _header() {
    final tt = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.mintGradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Punktshop',
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        widget.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopInfoBanner extends StatelessWidget {
  const _ShopInfoBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.greenLine),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: AppColors.green, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Jede Prämie kostet nur 0,01 € plus deine gesammelten Punkte. '
              'Einlösen kannst du direkt im Laden.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopRewardCard extends StatelessWidget {
  const _ShopRewardCard({required this.reward});

  final PointsRewardModel reward;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RewardThumb(imageUrl: reward.imageUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title.isNotEmpty ? reward.title : 'Prämie',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (reward.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    reward.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      height: 1.35,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _PricePill(requiredPoints: reward.requiredPoints),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardThumb extends StatelessWidget {
  const _RewardThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (imageUrl.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.mintSoft,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: const Icon(Icons.card_giftcard_rounded,
            color: AppColors.green, size: 26),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: SizedBox(
        width: 64,
        height: 64,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: cs.secondaryContainer),
          errorWidget: (_, _, _) => Container(
            color: AppColors.mintSoft,
            child: const Icon(Icons.card_giftcard_rounded,
                color: AppColors.green, size: 24),
          ),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.requiredPoints});

  final int requiredPoints;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.greenLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, size: 15, color: AppColors.green),
          const SizedBox(width: 5),
          Text(
            '$requiredPoints Punkte + 0,01 €',
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.greenDeep,
            ),
          ),
        ],
      ),
    );
  }
}
