import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../catalog/models/merchantItemData.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/pointsSystemModel.dart';
import '../providers/merchantPointsProvider.dart';
import '../services/merchantPointsService.dart';
import '../widgets/pointsRuleCard.dart';

class MerchantPointsPage extends StatelessWidget {
  const MerchantPointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantPointsProvider(
        service: MerchantPointsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _MerchantPointsView(),
    );
  }
}

class _MerchantPointsView extends StatefulWidget {
  const _MerchantPointsView();

  @override
  State<_MerchantPointsView> createState() => _MerchantPointsViewState();
}

class _MerchantPointsViewState extends State<_MerchantPointsView> {
  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantPointsProvider>();

    final system = provider.systems.isNotEmpty
        ? (provider.activeSystem ?? provider.systems.first)
        : null;
    final mode = system?.programMode ?? PointsProgramMode.monthlyRewards;

    final visibleRewards = provider.rewards
        .where((reward) => !reward.isArchivedReward)
        .toList()
      ..sort((a, b) => a.requiredPoints.compareTo(b.requiredPoints));
    // Belohnungen nach Typ trennen (#32): Geschenke (custom/discount) gehören in
    // den Monatsmodus, Shop-Artikel (item) in den Shop-Modus – sonst vermischen
    // sich Geschenke-Leiter und Shop-Grid.
    final giftRewards = visibleRewards
        .where((r) => r.rewardType != PointsRewardType.item)
        .toList();
    final shopRewards = visibleRewards
        .where((r) => r.rewardType == PointsRewardType.item)
        .toList();
    final modeRewards =
        mode == PointsProgramMode.monthlyRewards ? giftRewards : shopRewards;

    return MerchantToolScaffold(
      title: texts.text('merchant.points.title'),
      subtitle: texts.text('merchant.points.subtitle'),
      trailing:
          MerchantInfoTooltip(message: texts.text('merchant.points.tooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.isLoading)
            const MerchantLoadingCards(count: 5)
          else if (provider.error != null &&
              provider.systems.isEmpty &&
              provider.rewards.isEmpty)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else ...[
            // ── 1 · Status auf einen Blick ──────────────────────────────────
            _StatusHero(
              system: system,
              activeRewards: modeRewards.where((r) => r.isLive).length,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── 2 · DIE GROSSE ENTSCHEIDUNG: Welches System? ────────────────
            _BigDecisionSection(
              selected: mode,
              hasSystem: system != null,
              onChoose: (next) => _onChooseMode(context, provider, system, next),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── 3 · Grundeinstellungen ──────────────────────────────────────
            _SectionLabel(
              title:
                  _t(texts, 'merchant.points.basicsTitle', 'Grundeinstellungen'),
              hint: mode == PointsProgramMode.monthlyRewards
                  ? _t(texts, 'merchant.points.basicsHintMonthly',
                      'Wie viele Punkte deine Kunden sammeln und wann der Monat neu startet.')
                  : _t(texts, 'merchant.points.basicsHintShop',
                      'Wie viele Punkte deine Kunden pro Euro sammeln.'),
            ),
            const SizedBox(height: AppSpacing.md),
            _BasicsCard(
              system: system,
              mode: mode,
              onEditPoints: () =>
                  _editPointsPerEuro(context, provider, system, mode),
              onEditResetDay: () =>
                  _editResetDay(context, provider, system, mode),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── 4 · Inhalte je nach System ──────────────────────────────────
            if (mode == PointsProgramMode.monthlyRewards)
              _MonthlySection(
                rewards: giftRewards,
                onEditReward: (reward) => context
                    .push('/merchant/points/rewards/edit/${reward.id}'),
                onAddReward: () =>
                    context.push('/merchant/points/rewards/edit'),
              )
            else
              _ShopSection(
                rewards: shopRewards,
                onEditReward: (reward) =>
                    _editShopPrice(context, provider, reward),
                onAddArticle: () => _importArticle(context, provider, system),
              ),
          ],
        ],
      ),
    );
  }

  // ── Aktionen ───────────────────────────────────────────────────────────

  Future<void> _onChooseMode(
    BuildContext context,
    MerchantPointsProvider provider,
    PointsSystemModel? system,
    String next,
  ) async {
    final current = system?.programMode ?? PointsProgramMode.monthlyRewards;
    if (system != null && current == next) return;

    // Wechsel bei bestehendem System: nachfragen (Schutz).
    if (system != null && system.id.isNotEmpty && current != next) {
      final ok = await _confirmModeSwitch(context);
      if (ok != true || !context.mounted) return;
    }

    final base = system ?? PointsSystemModel.empty(merchantId: provider.merchantId);
    await provider.saveSystem(base.copyWith(programMode: next));
  }

  Future<void> _editPointsPerEuro(
    BuildContext context,
    MerchantPointsProvider provider,
    PointsSystemModel? system,
    String mode,
  ) async {
    final texts = context.read<LanguageService>();
    final base =
        system ?? PointsSystemModel.empty(merchantId: provider.merchantId);
    final value = await _numberSheet(
      context,
      title: _t(texts, 'merchant.points.field.pointsPerEuro',
          'Punkte pro Euro'),
      hint: _t(texts, 'merchant.points.basicsHintShop',
          'Wie viele Punkte deine Kunden pro Euro sammeln.'),
      initial: base.pointsPerEuro.toString().replaceAll('.0', ''),
    );
    if (value == null || !context.mounted) return;
    final parsed = num.tryParse(value.replaceAll(',', '.')) ?? base.pointsPerEuro;
    await provider.saveSystem(
      base.copyWith(programMode: mode, pointsPerEuro: parsed <= 0 ? 1 : parsed),
    );
  }

  Future<void> _editResetDay(
    BuildContext context,
    MerchantPointsProvider provider,
    PointsSystemModel? system,
    String mode,
  ) async {
    final base =
        system ?? PointsSystemModel.empty(merchantId: provider.merchantId);
    final value = await _resetDaySheet(context, base.monthlyResetDay);
    if (value == null || !context.mounted) return;
    await provider.saveSystem(
      base.copyWith(programMode: mode, monthlyResetDay: value),
    );
  }

  Future<void> _importArticle(
    BuildContext context,
    MerchantPointsProvider provider,
    PointsSystemModel? system,
  ) async {
    final item = await _pickArticleSheet(context, provider.items);
    if (item == null || !context.mounted) return;
    final suggested = _suggestedPoints(system, item);
    final points = await _numberSheet(
      context,
      title: _t(context.read<LanguageService>(),
          'merchant.points.shop.priceTitle', 'Preis in Punkten'),
      hint: _t(context.read<LanguageService>(), 'merchant.points.shop.priceHint',
          'Wie viele Punkte kostet dieser Artikel im Punkteshop?'),
      initial: suggested.toString(),
      integerOnly: true,
    );
    if (points == null || !context.mounted) return;
    final parsed = int.tryParse(points.trim()) ?? suggested;
    final reward = PointsRewardModel.empty(merchantId: provider.merchantId)
        .copyWith(
      title: item.name,
      description: item.description,
      rewardType: PointsRewardType.item,
      requiredPoints: parsed <= 0 ? 1 : parsed,
      rewardItemId: item.id,
      rewardItemName: item.name,
      imageUrl: item.imageUrl,
    );
    await provider.publishReward(reward);
  }

  Future<void> _editShopPrice(
    BuildContext context,
    MerchantPointsProvider provider,
    PointsRewardModel reward,
  ) async {
    final texts = context.read<LanguageService>();
    final action = await _shopArticleActionSheet(context, reward);
    if (action == null || !context.mounted) return;
    if (action == _ShopAction.remove) {
      await provider.archiveReward(reward.id);
      return;
    }
    final points = await _numberSheet(
      context,
      title:
          _t(texts, 'merchant.points.shop.priceTitle', 'Preis in Punkten'),
      hint: _t(texts, 'merchant.points.shop.priceHint',
          'Wie viele Punkte kostet dieser Artikel im Punkteshop?'),
      initial: reward.requiredPoints.toString(),
      integerOnly: true,
    );
    if (points == null || !context.mounted) return;
    final parsed = int.tryParse(points.trim()) ?? reward.requiredPoints;
    await provider.saveReward(
      reward.copyWith(requiredPoints: parsed <= 0 ? 1 : parsed),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  STATUS HERO
// ════════════════════════════════════════════════════════════════════════

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.system, required this.activeRewards});

  final PointsSystemModel? system;
  final int activeRewards;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final isLive = system?.isLive ?? false;
    final hasSystem = system != null;

    final statusLabel = !hasSystem
        ? _t(texts, 'merchant.points.heroStateNone', 'Noch nicht eingerichtet')
        : isLive
            ? texts.text('merchant.points.status.active').toUpperCase()
            : _statusLabel(texts, system!.status).toUpperCase();

    final accent =
        isLive ? MerchantPremiumColors.gold : MerchantPremiumColors.muted;

    return MerchantPremiumCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MerchantPremiumColors.goldSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MerchantPremiumColors.gold.withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(Icons.stars_rounded,
                color: MerchantPremiumColors.gold, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  !hasSystem
                      ? _t(texts, 'merchant.points.heroTitleNone',
                          'Punkteprogramm starten')
                      : (system!.title.trim().isEmpty
                          ? texts.text('merchant.points.defaultSystem')
                          : system!.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                if (hasSystem) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$activeRewards ${_t(texts, 'merchant.points.heroActiveRewards', 'Aktive Belohnungen')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  DIE GROSSE ENTSCHEIDUNG
// ════════════════════════════════════════════════════════════════════════

class _BigDecisionSection extends StatelessWidget {
  const _BigDecisionSection({
    required this.selected,
    required this.hasSystem,
    required this.onChoose,
  });

  final String selected;
  final bool hasSystem;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          title: _t(texts, 'merchant.points.decisionTitle',
              'Welches System möchtest du?'),
          hint: _t(texts, 'merchant.points.decisionHint',
              'Wähle eine von zwei Möglichkeiten. Du kannst später wechseln.'),
        ),
        const SizedBox(height: AppSpacing.md),
        _BigOptionCard(
          title: _t(texts, 'merchant.points.mode.monthlyRewards',
              'Monatliche Geschenke'),
          description: _t(
            texts,
            'merchant.points.decisionMonthlyDesc',
            'Kunden sammeln den ganzen Monat Punkte und bekommen feste Geschenke, je mehr Punkte – desto größer das Geschenk.',
          ),
          icon: Icons.calendar_month_rounded,
          selected: selected == PointsProgramMode.monthlyRewards,
          onTap: () => onChoose(PointsProgramMode.monthlyRewards),
        ),
        const SizedBox(height: AppSpacing.sm),
        _BigOptionCard(
          title: _t(texts, 'merchant.points.mode.pointsShopRewards',
              'Punkteshop'),
          description: _t(
            texts,
            'merchant.points.decisionShopDesc',
            'Kunden lösen ihre Punkte jederzeit gegen Artikel aus deinem kleinen Punkteshop ein.',
          ),
          icon: Icons.shopping_bag_rounded,
          selected: selected == PointsProgramMode.pointsShopRewards,
          onTap: () => onChoose(PointsProgramMode.pointsShopRewards),
        ),
      ],
    );
  }
}

class _BigOptionCard extends StatelessWidget {
  const _BigOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? MerchantPremiumColors.goldSoft
                : MerchantPremiumColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: selected
                  ? MerchantPremiumColors.gold
                  : MerchantPremiumColors.line,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected ? null : MerchantPremiumShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? MerchantPremiumColors.gold
                      : MerchantPremiumColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? MerchantPremiumColors.gold
                        : MerchantPremiumColors.line,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: selected
                      ? MerchantPremiumColors.base
                      : MerchantPremiumColors.ink,
                ),
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MerchantPremiumColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 24,
                          color: selected
                              ? MerchantPremiumColors.gold
                              : MerchantPremiumColors.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  GRUNDEINSTELLUNGEN
// ════════════════════════════════════════════════════════════════════════

class _BasicsCard extends StatelessWidget {
  const _BasicsCard({
    required this.system,
    required this.mode,
    required this.onEditPoints,
    required this.onEditResetDay,
  });

  final PointsSystemModel? system;
  final String mode;
  final VoidCallback onEditPoints;
  final VoidCallback onEditResetDay;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final pointsPerEuro =
        (system?.pointsPerEuro ?? 1).toString().replaceAll('.0', '');
    final resetDay = system?.monthlyResetDay ?? 1;
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(6),
      radius: 28,
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.toll_rounded,
            label: _t(texts, 'merchant.points.field.pointsPerEuro',
                'Punkte pro Euro'),
            value:
                '$pointsPerEuro ${_t(texts, 'merchant.points.points', 'Punkte')}',
            onTap: onEditPoints,
          ),
          if (mode == PointsProgramMode.monthlyRewards) ...[
            const _SettingDivider(),
            _SettingRow(
              icon: Icons.event_repeat_rounded,
              label: _t(texts, 'merchant.points.monthlyResetDay',
                  'Monatlicher Neustart'),
              value: _t(texts, 'merchant.points.resetDayValue',
                      'Am {day}. des Monats')
                  .replaceAll('{day}', '$resetDay'),
              onTap: onEditResetDay,
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.goldSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MerchantPremiumColors.gold.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(icon,
                    size: 22, color: MerchantPremiumColors.gold),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded,
                  size: 19, color: MerchantPremiumColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingDivider extends StatelessWidget {
  const _SettingDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 14,
      endIndent: 14,
      color: MerchantPremiumColors.line,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  MONATLICHE GESCHENKE: Skala + Grid
// ════════════════════════════════════════════════════════════════════════

class _MonthlySection extends StatelessWidget {
  const _MonthlySection({
    required this.rewards,
    required this.onEditReward,
    required this.onAddReward,
  });

  final List<PointsRewardModel> rewards;
  final ValueChanged<PointsRewardModel> onEditReward;
  final VoidCallback onAddReward;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          title: _t(texts, 'merchant.points.giftsTitle', 'Deine Geschenke'),
          hint: _t(texts, 'merchant.points.giftsHint',
              'Lege fest, welches Geschenk es bei wie vielen Punkten gibt.'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (rewards.isEmpty)
          _EmptyGiftsCard(onAdd: onAddReward)
        else ...[
          _GiftLadder(rewards: rewards, onTap: onEditReward),
          const SizedBox(height: AppSpacing.md),
          _RewardGrid(
            rewards: rewards,
            onTap: onEditReward,
            onAdd: onAddReward,
          ),
        ],
      ],
    );
  }
}

/// Vertikale Geschenk-Leiter (aufsteigend nach Punkten) mit Pfeil-Verbindern.
class _GiftLadder extends StatelessWidget {
  const _GiftLadder({required this.rewards, required this.onTap});

  final List<PointsRewardModel> rewards;
  final ValueChanged<PointsRewardModel> onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.stairs_rounded,
                  size: 20, color: MerchantPremiumColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(texts, 'merchant.points.ladderTitle',
                      'So wachsen die Geschenke'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < rewards.length; i++) ...[
            if (i > 0) const _LadderConnector(),
            _LadderStep(
              reward: rewards[i],
              step: i + 1,
              onTap: () => onTap(rewards[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _LadderConnector extends StatelessWidget {
  const _LadderConnector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 22),
      child: SizedBox(
        height: 22,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_up_rounded,
                size: 20, color: MerchantPremiumColors.gold),
          ],
        ),
      ),
    );
  }
}

class _LadderStep extends StatelessWidget {
  const _LadderStep({
    required this.reward,
    required this.step,
    required this.onTap,
  });

  final PointsRewardModel reward;
  final int step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: reward.isLive
                ? MerchantPremiumColors.goldSoft
                : MerchantPremiumColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: reward.isLive
                  ? MerchantPremiumColors.gold.withValues(alpha: 0.45)
                  : MerchantPremiumColors.line,
            ),
          ),
          child: Row(
            children: [
              PointsRewardPreview(reward: reward, size: 46),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title.trim().isEmpty
                          ? texts.text('merchant.points.rewardUntitled')
                          : reward.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${reward.requiredPoints} ${_t(texts, 'merchant.points.points', 'Punkte')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: MerchantPremiumColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  REWARD GRID (Geschenke als Karten, 2 pro Reihe)
// ════════════════════════════════════════════════════════════════════════

class _RewardGrid extends StatelessWidget {
  const _RewardGrid({
    required this.rewards,
    required this.onTap,
    required this.onAdd,
  });

  final List<PointsRewardModel> rewards;
  final ValueChanged<PointsRewardModel> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.sm;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final reward in rewards)
              SizedBox(
                width: width,
                child: _GiftCard(reward: reward, onTap: () => onTap(reward)),
              ),
            SizedBox(
              width: width,
              child: _AddCard(
                label: _t(texts, 'merchant.points.addGift',
                    'Geschenk hinzufügen'),
                onTap: onAdd,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.reward, required this.onTap});

  final PointsRewardModel reward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MerchantPremiumColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: reward.isLive
                  ? MerchantPremiumColors.gold.withValues(alpha: 0.40)
                  : MerchantPremiumColors.line,
              width: reward.isLive ? 1.4 : 1,
            ),
            boxShadow: MerchantPremiumShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: PointsRewardPreview(
                  reward: reward,
                  size: double.infinity,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                reward.title.trim().isEmpty
                    ? texts.text('merchant.points.rewardUntitled')
                    : reward.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${reward.requiredPoints} ${_t(texts, 'merchant.points.points', 'Punkte')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MerchantPremiumColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (!reward.isLive)
                    Text(
                      _statusLabel(texts, reward.status),
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  PUNKTESHOP: Mini-Shop-Grid + Import
// ════════════════════════════════════════════════════════════════════════

class _ShopSection extends StatelessWidget {
  const _ShopSection({
    required this.rewards,
    required this.onEditReward,
    required this.onAddArticle,
  });

  final List<PointsRewardModel> rewards;
  final ValueChanged<PointsRewardModel> onEditReward;
  final VoidCallback onAddArticle;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(
          title: _t(texts, 'merchant.points.shopTitle', 'Dein Punkteshop'),
          hint: _t(texts, 'merchant.points.shopHint',
              'Artikel, die deine Kunden mit Punkten kaufen können.'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (rewards.isEmpty)
          _EmptyShopCard(onAdd: onAddArticle)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = AppSpacing.sm;
              final width = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final reward in rewards)
                    SizedBox(
                      width: width,
                      child: _GiftCard(
                        reward: reward,
                        onTap: () => onEditReward(reward),
                      ),
                    ),
                  SizedBox(
                    width: width,
                    child: _AddCard(
                      label: _t(texts, 'merchant.points.shop.addArticle',
                          'Artikel hinzufügen'),
                      onTap: onAddArticle,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Gemeinsame kleine Bausteine
// ════════════════════════════════════════════════════════════════════════

class _AddCard extends StatelessWidget {
  const _AddCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MerchantPremiumColors.glass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: MerchantPremiumColors.gold.withValues(alpha: 0.40),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.goldSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: MerchantPremiumColors.gold.withValues(alpha: 0.30),
                  ),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 28, color: MerchantPremiumColors.gold),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyGiftsCard extends StatelessWidget {
  const _EmptyGiftsCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return _EmptyContentCard(
      icon: Icons.card_giftcard_rounded,
      title: _t(texts, 'merchant.points.giftsEmptyTitle',
          'Noch keine Geschenke'),
      message: _t(texts, 'merchant.points.giftsEmptyMessage',
          'Lege dein erstes Geschenk an, das Kunden mit Punkten bekommen.'),
      actionLabel:
          _t(texts, 'merchant.points.addGift', 'Geschenk hinzufügen'),
      onAction: onAdd,
    );
  }
}

class _EmptyShopCard extends StatelessWidget {
  const _EmptyShopCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return _EmptyContentCard(
      icon: Icons.shopping_bag_rounded,
      title:
          _t(texts, 'merchant.points.shopEmptyTitle', 'Noch keine Artikel'),
      message: _t(texts, 'merchant.points.shopEmptyMessage',
          'Füge Artikel aus deiner Speisekarte hinzu, die Kunden mit Punkten kaufen können.'),
      actionLabel: _t(texts, 'merchant.points.shop.addArticle',
          'Artikel hinzufügen'),
      onAction: onAdd,
    );
  }
}

class _EmptyContentCard extends StatelessWidget {
  const _EmptyContentCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MerchantPremiumColors.goldSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MerchantPremiumColors.gold.withValues(alpha: 0.24),
              ),
            ),
            child: Icon(icon, size: 26, color: MerchantPremiumColors.gold),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: MerchantPremiumColors.gold,
              foregroundColor: MerchantPremiumColors.base,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: MerchantPremiumColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          hint,
          style: const TextStyle(
            color: MerchantPremiumColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  BOTTOM SHEETS
// ════════════════════════════════════════════════════════════════════════

Future<String?> _numberSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required String initial,
  bool integerOnly = false,
}) {
  final texts = context.read<LanguageService>();
  final controller = TextEditingController(text: initial);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MerchantPremiumColors.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: integerOnly
                    ? TextInputType.number
                    : const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: integerOnly
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                decoration: merchantPremiumInputDecoration(label: title),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: MerchantPremiumColors.gold,
                  foregroundColor: MerchantPremiumColors.base,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: Text(texts.text('common.save')),
              ),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(texts.text('common.cancel')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<int?> _resetDaySheet(BuildContext context, int current) {
  final texts = context.read<LanguageService>();
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t(texts, 'merchant.points.monthlyResetDay',
                  'Monatlicher Neustart'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _t(texts, 'merchant.points.monthlyResetDayTip',
                  'An diesem Tag im Monat starten die Punkte neu.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: List.generate(31, (index) {
                  final day = index + 1;
                  final selected = day == current;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(day),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? MerchantPremiumColors.gold
                              : MerchantPremiumColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? MerchantPremiumColors.gold
                                : MerchantPremiumColors.line,
                          ),
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: selected
                                ? MerchantPremiumColors.base
                                : MerchantPremiumColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<MerchantItemData?> _pickArticleSheet(
  BuildContext context,
  List<MerchantItemData> items,
) {
  final texts = context.read<LanguageService>();
  return showModalBottomSheet<MerchantItemData>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t(texts, 'merchant.points.shop.pickTitle',
                  'Artikel auswählen'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _t(texts, 'merchant.points.shop.pickHint',
                  'Wähle einen Artikel aus deiner Speisekarte.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  texts.text('merchant.points.noItems'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ArticlePickRow(
                      item: item,
                      onTap: () => Navigator.of(sheetContext).pop(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ArticlePickRow extends StatelessWidget {
  const _ArticlePickRow({required this.item, required this.onTap});

  final MerchantItemData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: MerchantPremiumColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MerchantPremiumColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MerchantPremiumColors.line),
                ),
                child: item.imageUrl.isEmpty
                    ? const Icon(Icons.restaurant_rounded,
                        color: MerchantPremiumColors.muted)
                    : Image.network(item.imageUrl, fit: BoxFit.cover),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: MerchantPremiumColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ShopAction { editPrice, remove }

Future<_ShopAction?> _shopArticleActionSheet(
  BuildContext context,
  PointsRewardModel reward,
) {
  final texts = context.read<LanguageService>();
  return showModalBottomSheet<_ShopAction>(
    context: context,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              reward.title.trim().isEmpty
                  ? texts.text('merchant.points.rewardUntitled')
                  : reward.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_ShopAction.editPrice),
              icon: const Icon(Icons.toll_rounded),
              label: Text(_t(texts, 'merchant.points.shop.editPrice',
                  'Punktepreis ändern')),
              style: FilledButton.styleFrom(
                backgroundColor: MerchantPremiumColors.gold,
                foregroundColor: MerchantPremiumColors.base,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_ShopAction.remove),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: MerchantPremiumColors.danger),
              label: Text(
                _t(texts, 'merchant.points.shop.remove',
                    'Aus Punkteshop entfernen'),
                style: const TextStyle(color: MerchantPremiumColors.danger),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                side: BorderSide(
                    color: MerchantPremiumColors.danger
                        .withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text(texts.text('common.cancel')),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool?> _confirmModeSwitch(BuildContext context) {
  final texts = context.read<LanguageService>();
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.warningSoft,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 38, color: MerchantPremiumColors.warning),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text('merchant.points.modeSwitchConfirmTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text('merchant.points.modeSwitchConfirmMessage'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              icon: const Icon(Icons.check_rounded),
              label: Text(texts.text('merchant.points.modeSwitchConfirm')),
              style: FilledButton.styleFrom(
                backgroundColor: MerchantPremiumColors.gold,
                foregroundColor: MerchantPremiumColors.base,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: Text(texts.text('common.cancel')),
            ),
          ],
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════
//  Helfer
// ════════════════════════════════════════════════════════════════════════

int _suggestedPoints(PointsSystemModel? system, MerchantItemData item) {
  final pointsPerEuro = system?.pointsPerEuro ?? 1;
  final points = (item.price * pointsPerEuro).round();
  return points <= 0 ? 1 : points;
}

/// Übersetzt [key]; fällt auf [fallback] zurück, wenn der Key fehlt
/// (LanguageService liefert bei fehlendem Key den Key selbst zurück).
String _t(LanguageService texts, String key, String fallback) {
  final value = texts.text(key);
  return value == key ? fallback : value;
}

String _statusLabel(LanguageService texts, String status) {
  return switch (status) {
    PointsStatus.active => texts.text('merchant.points.status.active'),
    PointsStatus.paused => texts.text('merchant.points.status.paused'),
    PointsStatus.archived => texts.text('merchant.points.status.archived'),
    _ => texts.text('merchant.points.status.draft'),
  };
}
