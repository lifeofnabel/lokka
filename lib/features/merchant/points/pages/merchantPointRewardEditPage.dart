import 'package:flutter/material.dart';
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

class MerchantPointRewardEditPage extends StatelessWidget {
  const MerchantPointRewardEditPage({super.key, this.rewardId});

  final String? rewardId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantPointsProvider(
        service: MerchantPointsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(rewardId: rewardId ?? ''),
      child: _PointRewardEditView(rewardId: rewardId),
    );
  }
}

class _PointRewardEditView extends StatefulWidget {
  const _PointRewardEditView({this.rewardId});

  final String? rewardId;

  @override
  State<_PointRewardEditView> createState() => _PointRewardEditViewState();
}

class _PointRewardEditViewState extends State<_PointRewardEditView> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _requiredPoints = TextEditingController();
  final _discountText = TextEditingController();
  String? _hydratedId;
  bool _isHydrating = false;
  String _rewardType = PointsRewardType.custom;
  String _rewardItemId = '';
  String _rewardItemName = '';
  String _imageUrl = '';

  @override
  void initState() {
    super.initState();
    for (final controller in [_title, _description, _requiredPoints, _discountText]) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _requiredPoints.dispose();
    _discountText.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!_isHydrating && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantPointsProvider>();

    if (provider.isLoading) {
      return MerchantToolScaffold(
        title: texts.text('merchant.points.rewardEditTitle'),
        subtitle: texts.text('merchant.points.rewardEditSubtitle'),
        backPath: '/merchant/points',
        child: const MerchantLoadingCards(count: 4),
      );
    }

    final reward = provider.editingReward ??
        PointsRewardModel.empty(merchantId: provider.merchantId);
    _hydrate(reward);
    final preview = _rewardFromForm(provider, reward);

    return MerchantToolScaffold(
      title: texts.text('merchant.points.rewardEditTitle'),
      subtitle: texts.text('merchant.points.rewardEditSubtitle'),
      backPath: '/merchant/points',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.points.rewardEditTip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.error != null) ...[
            MerchantErrorState(message: provider.error!, onRetry: provider.clearError),
            const SizedBox(height: AppSpacing.md),
          ],
          _PreviewShell(reward: preview),
          const SizedBox(height: AppSpacing.md),
          _RewardScaleMini(rewards: _scaleRewards(provider, reward, preview)),
          const SizedBox(height: AppSpacing.md),
          _ChipWrap(
            options: [
              _ChipOption(PointsRewardType.custom, texts.text('merchant.points.reward.custom')),
              _ChipOption(PointsRewardType.item, texts.text('merchant.points.reward.item')),
              _ChipOption(PointsRewardType.discount, texts.text('merchant.points.reward.discount')),
            ],
            selected: _rewardType,
            onSelected: (value) => setState(() => _rewardType = value),
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _title,
            label: texts.text('merchant.points.field.rewardTitle'),
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _requiredPoints,
            label: texts.text('merchant.points.field.requiredPoints'),
            keyboardType: TextInputType.number,
          ),
          if (_rewardType == PointsRewardType.item) ...[
            const SizedBox(height: AppSpacing.md),
            _ItemDropdown(
              label: texts.text('merchant.points.field.rewardItem'),
              items: provider.items,
              value: _rewardItemId,
              onChanged: (item) => setState(() {
                _rewardItemId = item?.id ?? '';
                _rewardItemName = item?.name ?? '';
                if (item != null && _title.text.trim().isEmpty) {
                  _title.text = item.name;
                }
                if (item != null && (_requiredPoints.text.trim().isEmpty || _requiredPoints.text.trim() == '100')) {
                  _requiredPoints.text = _suggestedPoints(provider, item).toString();
                }
                if (item != null && _imageUrl.trim().isEmpty) {
                  _imageUrl = item.imageUrl;
                }
              }),
            ),
          ],
          if (_rewardType == PointsRewardType.discount) ...[
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(
              controller: _discountText,
              label: texts.text('merchant.points.field.discountText'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _description,
            label: texts.text('common.description'),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: provider.isSaving
                ? null
                : () async {
                    final uploaded = await provider.uploadRewardImage();
                    if (uploaded != null && uploaded.isNotEmpty) {
                      setState(() => _imageUrl = uploaded);
                    }
                  },
            icon: const Icon(Icons.image_rounded),
            label: Text(_imageUrl.isEmpty ? texts.text('common.uploadImage') : texts.text('common.replaceImage')),
          ),
          const SizedBox(height: AppSpacing.lg),
          MerchantPrimaryButton(
            label: reward.isLive ? texts.text('common.save') : texts.text('merchant.points.saveDraft'),
            icon: Icons.save_rounded,
            isLoading: provider.isSaving,
            onPressed: () => _save(context, provider, reward),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: provider.isSaving ? null : () => _publish(context, provider, reward),
            icon: const Icon(Icons.rocket_launch_rounded),
            label: Text(texts.text('merchant.points.activate')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ],
      ),
    );
  }

  void _hydrate(PointsRewardModel reward) {
    final key = reward.id.isEmpty ? 'new' : reward.id;
    if (_hydratedId == key) return;
    _isHydrating = true;
    _hydratedId = key;
    _title.text = reward.title;
    _description.text = reward.description;
    _requiredPoints.text = reward.requiredPoints.toString();
    _discountText.text = reward.discountText;
    _rewardType = reward.rewardType;
    _rewardItemId = reward.rewardItemId;
    _rewardItemName = reward.rewardItemName;
    _imageUrl = reward.imageUrl;
    _isHydrating = false;
  }

  PointsRewardModel _rewardFromForm(
    MerchantPointsProvider provider,
    PointsRewardModel existing, {
    String? forcedStatus,
  }) {
    final status = forcedStatus ??
        (existing.status == PointsStatus.active ? PointsStatus.active : PointsStatus.draft);
    final item = _findItem(provider.items, _rewardItemId);
    return PointsRewardModel(
      id: existing.id,
      merchantId: provider.merchantId,
      title: _title.text,
      description: _description.text,
      rewardType: _rewardType,
      requiredPoints: int.tryParse(_requiredPoints.text.trim()) ?? 100,
      rewardItemId: _rewardType == PointsRewardType.item ? item?.id ?? '' : '',
      rewardItemName: _rewardType == PointsRewardType.item ? item?.name ?? _rewardItemName : '',
      discountText: _rewardType == PointsRewardType.discount ? _discountText.text : '',
      imageUrl: _imageUrl,
      status: status,
      isActive: status == PointsStatus.active,
      isArchived: status == PointsStatus.archived,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
      publishedAt: existing.publishedAt,
      activatedAt: existing.activatedAt,
      pausedAt: existing.pausedAt,
      archivedAt: existing.archivedAt,
    );
  }

  Future<void> _save(
    BuildContext context,
    MerchantPointsProvider provider,
    PointsRewardModel existing,
  ) async {
    final texts = context.read<LanguageService>();
    if (!_validate(context, provider)) return;
    final id = await provider.saveReward(_rewardFromForm(provider, existing));
    if (!context.mounted || id == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texts.text('merchant.points.saved'))),
    );
    context.pushReplacement('/merchant/points/rewards/edit/$id');
  }

  Future<void> _publish(
    BuildContext context,
    MerchantPointsProvider provider,
    PointsRewardModel existing,
  ) async {
    if (!_validate(context, provider)) return;
    final accepted = await _confirmPublish(context);
    if (accepted != true || !context.mounted) return;
    final id = await provider.publishReward(
      _rewardFromForm(provider, existing, forcedStatus: PointsStatus.active),
    );
    if (!context.mounted || id == null) return;
    context.go('/merchant/points');
  }

  bool _validate(BuildContext context, MerchantPointsProvider provider) {
    final texts = context.read<LanguageService>();
    String? message;
    if (_title.text.trim().isEmpty) {
      message = texts.text('merchant.points.error.rewardTitle');
    } else if ((int.tryParse(_requiredPoints.text.trim()) ?? 0) <= 0) {
      message = texts.text('merchant.points.error.requiredPoints');
    } else if (_rewardType == PointsRewardType.item && _findItem(provider.items, _rewardItemId) == null) {
      message = texts.text('merchant.points.error.rewardItem');
    } else if (_rewardType == PointsRewardType.discount && _discountText.text.trim().isEmpty) {
      message = texts.text('merchant.points.error.discountText');
    }
    if (message == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}

List<PointsRewardModel> _scaleRewards(
  MerchantPointsProvider provider,
  PointsRewardModel editing,
  PointsRewardModel preview,
) {
  final rewards = provider.rewards
      .where((reward) => reward.id != editing.id && !reward.isArchived)
      .toList();
  rewards.add(preview);
  rewards.sort((a, b) => a.requiredPoints.compareTo(b.requiredPoints));
  return rewards;
}

class _RewardScaleMini extends StatelessWidget {
  const _RewardScaleMini({required this.rewards});

  final List<PointsRewardModel> rewards;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  texts.text('merchant.points.rewardScale'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Tooltip(
                message: texts.text('merchant.points.rewardScaleTip'),
                child: const Icon(Icons.info_outline_rounded,
                    size: 18, color: MerchantPremiumColors.muted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: rewards
                  .map(
                    (reward) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 126,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MerchantPremiumColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: MerchantPremiumColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PointsRewardPreview(reward: reward),
                            const SizedBox(height: 8),
                            Text(
                              reward.title.trim().isEmpty
                                  ? texts.text('merchant.points.rewardUntitled')
                                  : reward.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MerchantPremiumColors.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${reward.requiredPoints} ${texts.text('merchant.points.points')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MerchantPremiumColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewShell extends StatelessWidget {
  const _PreviewShell({required this.reward});

  final PointsRewardModel reward;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: 28,
      child: Row(
        children: [
          PointsRewardPreview(reward: reward),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title.trim().isEmpty
                      ? texts.text('merchant.points.rewardUntitled')
                      : reward.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${reward.requiredPoints} ${texts.text('merchant.points.points')}',
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w800,
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

class _ChipOption {
  const _ChipOption(this.value, this.label);

  final String value;
  final String label;
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<_ChipOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (option) => ChoiceChip(
              label: Text(option.label),
              selected: selected == option.value,
              onSelected: (_) => onSelected(option.value),
              backgroundColor: MerchantPremiumColors.surfaceAlt,
              selectedColor: MerchantPremiumColors.gold,
              labelStyle: TextStyle(
                color: selected == option.value
                    ? MerchantPremiumColors.base
                    : MerchantPremiumColors.ink,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide(
                color: selected == option.value
                    ? MerchantPremiumColors.gold
                    : MerchantPremiumColors.line,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ItemDropdown extends StatelessWidget {
  const _ItemDropdown({
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<MerchantItemData> items;
  final String value;
  final ValueChanged<MerchantItemData?> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: Text(
          texts.text('merchant.points.noItems'),
          style: const TextStyle(
            color: MerchantPremiumColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    // Keine stille Vorauswahl (#31): nur ein echt gewähltes Item anzeigen, sonst
    // Hint „Artikel wählen" – erzwingt eine bewusste Auswahl (Validierung greift).
    final hasSelection = items.any((item) => item.id == value);
    return DropdownButtonFormField<String>(
      initialValue: hasSelection ? value : null,
      hint: Text(
        texts.text('merchant.points.selectItem'),
        style: const TextStyle(
          color: MerchantPremiumColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
      dropdownColor: MerchantPremiumColors.surfaceAlt,
      style: const TextStyle(
        color: MerchantPremiumColors.ink,
        fontWeight: FontWeight.w800,
      ),
      iconEnabledColor: MerchantPremiumColors.muted,
      decoration: merchantPremiumInputDecoration(label: label),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item.id,
              child: Text(
                item.name,
                style: const TextStyle(color: MerchantPremiumColors.ink),
              ),
            ),
          )
          .toList(),
      onChanged: (id) => onChanged(_findItem(items, id ?? '')),
    );
  }
}

Future<bool?> _confirmPublish(BuildContext context) {
  final texts = context.read<LanguageService>();
  return showModalBottomSheet<bool>(
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
              texts.text('merchant.points.activateRewardTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nach der Bestätigung wird die Belohnung für deine Kunden sichtbar.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            MerchantPrimaryButton(
              label: texts.text('merchant.points.activate'),
              icon: Icons.rocket_launch_rounded,
              onPressed: () => Navigator.of(sheetContext).pop(true),
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

MerchantItemData? _findItem(List<MerchantItemData> items, String id) {
  for (final item in items) {
    if (item.id == id) return item;
  }
  // Kein items.first-Fallback (#30): bei fehlender/ungültiger Auswahl null, damit
  // die Validierung greift und kein Artikel still als Belohnung gespeichert wird.
  return null;
}

int _suggestedPoints(MerchantPointsProvider provider, MerchantItemData item) {
  final pointsPerEuro = provider.activeSystem?.pointsPerEuro ?? 1;
  final points = (item.price * pointsPerEuro).round();
  return points <= 0 ? 1 : points;
}
