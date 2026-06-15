import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/merchant/points/models/pointsSystemModel.dart';
import 'package:lokka/features/user/partners/pages/userPartnerPointsShopPage.dart';
import 'package:lokka/features/user/partners/services/userLoyaltyService.dart';

/// Punkteprogramm eines Partners (read-only User-Sicht).
///
/// Zeigt die Regeln der aktiven Punktesysteme. Monatliche Programme rendern
/// ihre Geschenke als vertikale Leiter (aufsteigend nach Punkten),
/// Punktshop-Programme verlinken auf [UserPartnerPointsShopPage].
class UserPartnerPointsPage extends StatefulWidget {
  const UserPartnerPointsPage({
    super.key,
    required this.merchantId,
    required this.shopName,
  });

  final String merchantId;
  final String shopName;

  @override
  State<UserPartnerPointsPage> createState() => _UserPartnerPointsPageState();
}

class _UserPartnerPointsPageState extends State<UserPartnerPointsPage> {
  late final UserLoyaltyService _service;
  List<PointsSystemModel> _systems = [];
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
      final systemsFuture = _service.fetchPointsSystems(widget.merchantId);
      final rewardsFuture = _service.fetchPointsRewards(widget.merchantId);
      final systems = await systemsFuture;
      final rewards = await rewardsFuture;
      if (mounted) {
        setState(() {
          _systems = systems;
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

  void _openPointsShop() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserPartnerPointsShopPage(
          merchantId: widget.merchantId,
          shopName: widget.shopName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.greenTint,
      body: CustomScrollView(
        slivers: [
          _header(),
          if (_loading)
            const SliverFillRemaining(
                hasScrollBody: false, child: AppLoadingState())
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(
                  message: 'Punkteprogramm konnte nicht geladen werden',
                  onRetry: _load),
            )
          else if (_systems.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.stars_rounded,
                title: 'Noch kein Punkteprogramm',
                message:
                    'Dieser Partner hat aktuell kein aktives Punkteprogramm.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
              sliver: SliverList(
                delegate: SliverChildListDelegate(_sections()),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _sections() {
    final monthly = _systems
        .where((s) => s.programMode != PointsProgramMode.pointsShopRewards)
        .toList();
    final shop = _systems
        .where((s) => s.programMode == PointsProgramMode.pointsShopRewards)
        .toList();

    return [
      for (final system in monthly) ...[
        _RulesCard(system: system),
        const SizedBox(height: AppSpacing.md),
        if (_rewards.isEmpty)
          const _NoGiftsHint()
        else
          _RewardLadder(rewards: _rewards),
        const SizedBox(height: AppSpacing.lg),
      ],
      for (final system in shop) ...[
        _RulesCard(system: system),
        const SizedBox(height: AppSpacing.md),
        _PointsShopTeaser(onOpenShop: _openPointsShop),
        const SizedBox(height: AppSpacing.lg),
      ],
    ];
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
                        'Punkteprogramm',
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

String _formatPointsPerEuro(num pointsPerEuro) {
  final isWhole = pointsPerEuro == pointsPerEuro.roundToDouble();
  final value = isWhole
      ? pointsPerEuro.toInt().toString()
      : pointsPerEuro.toString().replaceAll('.', ',');
  final unit = pointsPerEuro == 1 ? 'Punkt' : 'Punkte';
  return '$value $unit pro Euro';
}

/// Regeln eines Punktesystems: Titel, Beschreibung und Eckdaten-Chips.
class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.system});

  final PointsSystemModel system;

  bool get _isMonthly =>
      system.programMode != PointsProgramMode.pointsShopRewards;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.mintGradientSoft,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(
                  _isMonthly
                      ? Icons.calendar_month_rounded
                      : Icons.shopping_bag_rounded,
                  color: AppColors.greenDeep,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system.title.isNotEmpty ? system.title : 'Lokka Punkte',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isMonthly ? 'Monatliches Programm' : 'Punktshop',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (system.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              system.description,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _RuleChip(
                icon: Icons.stars_rounded,
                label: _formatPointsPerEuro(system.pointsPerEuro),
              ),
              if (_isMonthly)
                _RuleChip(
                  icon: Icons.restart_alt_rounded,
                  label:
                      'Neustart am ${system.monthlyResetDay}. jedes Monats',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.greenLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.green),
          const SizedBox(width: 5),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.greenDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoGiftsHint extends StatelessWidget {
  const _NoGiftsHint();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded,
              color: AppColors.green, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Der Partner hat noch keine Geschenke hinterlegt.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertikale Geschenke-Leiter: aufsteigend nach Punkten, mit Pfeil-Konnektoren.
class _RewardLadder extends StatelessWidget {
  const _RewardLadder({required this.rewards});

  final List<PointsRewardModel> rewards;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
          child: Text(
            'Deine Geschenke-Leiter',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        for (var i = 0; i < rewards.length; i++) ...[
          if (i > 0) const _LadderConnector(),
          _LadderStep(reward: rewards[i]),
        ],
      ],
    );
  }
}

class _LadderConnector extends StatelessWidget {
  const _LadderConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Column(
        children: [
          Container(width: 2, height: 8, color: AppColors.greenLine),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.green),
          Container(width: 2, height: 8, color: AppColors.greenLine),
        ],
      ),
    );
  }
}

class _LadderStep extends StatelessWidget {
  const _LadderStep({required this.reward});

  final PointsRewardModel reward;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppColors.mintGradientSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBg, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mintStrong.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.card_giftcard_rounded,
                  size: 14, color: AppColors.greenDeep),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                _LadderThumb(imageUrl: reward.imageUrl),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.title.isNotEmpty ? reward.title : 'Geschenk',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'bei ${reward.requiredPoints} Punkten',
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LadderThumb extends StatelessWidget {
  const _LadderThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (imageUrl.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.mintSoft,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: const Icon(Icons.redeem_rounded,
            color: AppColors.green, size: 22),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: SizedBox(
        width: 48,
        height: 48,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: cs.secondaryContainer),
          errorWidget: (_, _, _) => Container(
            color: AppColors.mintSoft,
            child: const Icon(Icons.redeem_rounded,
                color: AppColors.green, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Hinweis-Karte für Punktshop-Programme mit Link in den Shop.
class _PointsShopTeaser extends StatelessWidget {
  const _PointsShopTeaser({required this.onOpenShop});

  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.greenLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dieser Laden hat einen Punktshop',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.greenDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tausche deine gesammelten Punkte gegen Prämien — '
            'jede Prämie kostet nur 0,01 € plus Punkte.',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onOpenShop,
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: const Text('Punktshop ansehen'),
          ),
        ],
      ),
    );
  }
}
