import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../catalog/models/merchantItemData.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/stampCardModel.dart';
import '../providers/merchantStampsProvider.dart';
import '../services/merchantStampsService.dart';
import '../widgets/merchantStampCard.dart';

class MerchantStampEditPage extends StatelessWidget {
  const MerchantStampEditPage({super.key, this.stampCardId});

  final String? stampCardId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantStampsProvider(
        service: MerchantStampsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(editId: stampCardId),
      child: _MerchantStampEditView(stampCardId: stampCardId),
    );
  }
}

class _MerchantStampEditView extends StatefulWidget {
  const _MerchantStampEditView({this.stampCardId});

  final String? stampCardId;

  @override
  State<_MerchantStampEditView> createState() => _MerchantStampEditViewState();
}

class _MerchantStampEditViewState extends State<_MerchantStampEditView> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _description = TextEditingController();
  final _minimumAmount = TextEditingController();
  final _conditionText = TextEditingController();
  final _rewardTitle = TextEditingController();
  final _rewardDescription = TextEditingController();
  final _stampContent = TextEditingController();

  String? _hydratedId;
  bool _isHydrating = false;
  bool _showAdvancedDesign = false;
  int _requiredStamps = 10;
  String _conditionType = StampConditionType.visit;
  String _requiredItemId = '';
  String _requiredItemName = '';
  String _rewardType = StampRewardType.custom;
  String _rewardItemId = '';
  String _rewardItemName = '';
  String _backgroundColor = '#171A18';
  String _gradientColor = '#45C9A4';
  bool _gradientEnabled = false;
  String _accentColor = '#9CE8CF';
  String _textColor = '#FEFFFC';
  String _styleName = 'noir';
  String _stampShape = 'circle';
  String _stampIconType = 'icon';
  String _stampIconValue = 'star';
  String _imageUrl = '';
  String _imagePlacement = 'side';

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _title,
      _subtitle,
      _description,
      _minimumAmount,
      _conditionText,
      _rewardTitle,
      _rewardDescription,
      _stampContent,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _description.dispose();
    _minimumAmount.dispose();
    _conditionText.dispose();
    _rewardTitle.dispose();
    _rewardDescription.dispose();
    _stampContent.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (!_isHydrating && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantStampsProvider>();

    if (provider.isLoading) {
      return MerchantToolScaffold(
        title: texts.text('merchant.stamps.editTitle'),
        subtitle: texts.text('merchant.stamps.editSubtitle'),
        backPath: '/merchant/stamps',
        child: const MerchantLoadingCards(count: 5),
      );
    }

    if (provider.error != null && provider.editingCard == null) {
      return MerchantToolScaffold(
        title: texts.text('merchant.stamps.editTitle'),
        subtitle: texts.text('merchant.stamps.editSubtitle'),
        backPath: '/merchant/stamps',
        child: MerchantErrorState(
          message: provider.error!,
          onRetry: () => provider.load(editId: widget.stampCardId),
        ),
      );
    }

    final card = provider.editingCard ?? StampCardModel.empty(merchantId: provider.merchantId);
    _hydrate(card);

    return MerchantToolScaffold(
      title: widget.stampCardId == null ? texts.text('merchant.stamps.create') : texts.text('merchant.stamps.editTitle'),
      subtitle: texts.text('merchant.stamps.editSubtitle'),
      backPath: '/merchant/stamps',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.stamps.editTooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.error != null) ...[
            MerchantErrorState(
              message: provider.error!,
              onRetry: provider.clearError,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _SectionCard(
            title: texts.text('merchant.stamps.section.name'),
            tooltip: texts.text('merchant.stamps.section.nameTip'),
            child: Column(
              children: [
                MerchantTextField(
                  controller: _title,
                  label: texts.text('merchant.stamps.field.title'),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(
                  controller: _subtitle,
                  label: texts.text('merchant.stamps.field.subtitle'),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(
                  controller: _description,
                  label: texts.text('common.description'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          _SectionCard(
            title: texts.text('merchant.stamps.section.condition'),
            tooltip: texts.text('merchant.stamps.section.conditionTip'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChipWrap(
                  options: [
                    _ChipOption(StampConditionType.visit, texts.text('merchant.stamps.condition.visit')),
                    _ChipOption(StampConditionType.minimumAmount, texts.text('merchant.stamps.condition.minimumAmount')),
                    _ChipOption(StampConditionType.item, texts.text('merchant.stamps.condition.item')),
                    _ChipOption(StampConditionType.custom, texts.text('merchant.stamps.condition.custom')),
                  ],
                  selected: _conditionType,
                  onSelected: (value) => setState(() => _conditionType = value),
                ),
                if (_conditionType == StampConditionType.minimumAmount) ...[
                  const SizedBox(height: AppSpacing.md),
                  MerchantTextField(
                    controller: _minimumAmount,
                    label: texts.text('merchant.stamps.field.minimumAmount'),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (_conditionType == StampConditionType.item) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ItemDropdown(
                    label: texts.text('merchant.stamps.field.requiredItem'),
                    items: provider.items,
                    value: _requiredItemId,
                    onChanged: (item) => setState(() {
                      _requiredItemId = item?.id ?? '';
                      _requiredItemName = item?.name ?? '';
                    }),
                  ),
                ],
                if (_conditionType == StampConditionType.custom) ...[
                  const SizedBox(height: AppSpacing.md),
                  MerchantTextField(
                    controller: _conditionText,
                    label: texts.text('merchant.stamps.field.conditionText'),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          _SectionCard(
            title: texts.text('merchant.stamps.section.stamps'),
            tooltip: texts.text('merchant.stamps.section.stampsTip'),
            child: _ChipWrap(
              options: [
                ...[5, 8, 10, 12, 15].map((count) => _ChipOption(count.toString(), count.toString())),
                _ChipOption('custom', texts.text('merchant.stamps.custom')),
              ],
              selected: [5, 8, 10, 12, 15].contains(_requiredStamps) ? _requiredStamps.toString() : 'custom',
              onSelected: (value) async {
                if (value != 'custom') {
                  setState(() => _requiredStamps = int.parse(value));
                  return;
                }
                final custom = await _askCustomStampCount(context, _requiredStamps);
                if (custom != null) setState(() => _requiredStamps = custom);
              },
            ),
          ),
          _SectionCard(
            title: texts.text('merchant.stamps.section.reward'),
            tooltip: texts.text('merchant.stamps.section.rewardTip'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChipWrap(
                  options: [
                    _ChipOption(StampRewardType.custom, texts.text('merchant.stamps.reward.custom')),
                    _ChipOption(StampRewardType.item, texts.text('merchant.stamps.reward.item')),
                  ],
                  selected: _rewardType,
                  onSelected: (value) => setState(() => _rewardType = value),
                ),
                if (_rewardType == StampRewardType.item) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ItemDropdown(
                    label: texts.text('merchant.stamps.field.rewardItem'),
                    items: provider.items,
                    value: _rewardItemId,
                    onChanged: (item) => setState(() {
                      _rewardItemId = item?.id ?? '';
                      _rewardItemName = item?.name ?? '';
                      if (item != null && _rewardTitle.text.trim().isEmpty) {
                        _rewardTitle.text = item.name;
                      }
                    }),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(
                  controller: _rewardTitle,
                  label: texts.text('merchant.stamps.field.rewardTitle'),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(
                  controller: _rewardDescription,
                  label: texts.text('merchant.stamps.field.rewardDescription'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          _SectionCard(
            title: texts.text('merchant.stamps.section.design'),
            tooltip: texts.text('merchant.stamps.section.designTip'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StyleSelector(
                  selected: _styleName,
                  onSelected: _setStyle,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAdvancedDesign = !_showAdvancedDesign),
                  icon: Icon(_showAdvancedDesign ? Icons.expand_less_rounded : Icons.tune_rounded),
                  label: Text(texts.text('merchant.stamps.advancedDesign')),
                ),
                if (_showAdvancedDesign) ...[
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    value: _gradientEnabled,
                    onChanged: (value) => setState(() => _gradientEnabled = value),
                    title: Text(texts.text('merchant.stamps.gradient')),
                    contentPadding: EdgeInsets.zero,
                  ),
                  _ColorSelector(
                    title: texts.text('merchant.stamps.backgroundColor'),
                    selected: _backgroundColor,
                    colors: const ['#171A18', '#E9FAF3', '#FFF5E6', '#301824', '#1F3A52', '#F5F6F2'],
                    onSelected: (value) => setState(() => _backgroundColor = value),
                  ),
                  if (_gradientEnabled)
                    _ColorSelector(
                      title: texts.text('merchant.stamps.gradientColor'),
                      selected: _gradientColor,
                      colors: const ['#45C9A4', '#9CE8CF', '#FFD6E7', '#CFE4FF', '#FFF1A5', '#FFB36C'],
                      onSelected: (value) => setState(() => _gradientColor = value),
                    ),
                  _ColorSelector(
                    title: texts.text('merchant.stamps.accentColor'),
                    selected: _accentColor,
                    colors: const ['#9CE8CF', '#171A18', '#FEFFFC', '#FFD6E7', '#FFF1A5', '#CFE4FF'],
                    onSelected: (value) => setState(() => _accentColor = value),
                  ),
                  _ColorSelector(
                    title: texts.text('merchant.stamps.textColor'),
                    selected: _textColor,
                    colors: const ['#FEFFFC', '#171A18', '#4A4A4A', '#FFF5E6'],
                    onSelected: (value) => setState(() => _textColor = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ChipWrap(
                    options: [
                      _ChipOption('circle', texts.text('merchant.stamps.shape.circle')),
                      _ChipOption('square', texts.text('merchant.stamps.shape.square')),
                      _ChipOption('softSquare', texts.text('merchant.stamps.shape.softSquare')),
                      _ChipOption('diamond', texts.text('merchant.stamps.shape.diamond')),
                    ],
                    selected: _stampShape,
                    onSelected: (value) => setState(() => _stampShape = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ChipWrap(
                    options: [
                      _ChipOption('icon', texts.text('merchant.stamps.content.icon')),
                      _ChipOption('char', texts.text('merchant.stamps.content.char')),
                    ],
                    selected: _stampIconType,
                    onSelected: (value) => setState(() => _stampIconType = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_stampIconType == 'icon')
                    _ChipWrap(
                      options: [
                        _ChipOption('star', texts.text('merchant.stamps.icon.star')),
                        _ChipOption('gift', texts.text('merchant.stamps.icon.gift')),
                        _ChipOption('coffee', texts.text('merchant.stamps.icon.coffee')),
                        _ChipOption('food', texts.text('merchant.stamps.icon.food')),
                        _ChipOption('heart', texts.text('merchant.stamps.icon.heart')),
                        _ChipOption('local', texts.text('merchant.stamps.icon.local')),
                      ],
                      selected: _stampIconValue,
                      onSelected: (value) => setState(() => _stampIconValue = value),
                    )
                  else
                    MerchantTextField(
                      controller: _stampContent,
                      label: texts.text('merchant.stamps.field.stampContent'),
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_imageUrl.isEmpty)
                  _ChipWrap(
                    options: [
                      _ChipOption('side', texts.text('merchant.stamps.image.side')),
                      _ChipOption('top', texts.text('merchant.stamps.image.top')),
                      _ChipOption('background', texts.text('merchant.stamps.image.background')),
                    ],
                    selected: _imagePlacement,
                    onSelected: (value) => setState(() => _imagePlacement = value),
                  )
                else
                  _LockedImagePlacement(
                    label: texts.text('merchant.stamps.imageLocked')
                        .replaceAll('{placement}', texts.text('merchant.stamps.image.$_imagePlacement')),
                    onRemove: () => setState(() => _imageUrl = ''),
                  ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: provider.isSaving
                      ? null
                      : () async {
                          final uploaded = await provider.uploadImage(
                            type: _uploadTypeForPlacement(_imagePlacement),
                          );
                          if (uploaded != null && uploaded.isNotEmpty) {
                            setState(() => _imageUrl = uploaded);
                          }
                        },
                  icon: const Icon(Icons.image_rounded),
                  label: Text(
                    _imageUrl.isEmpty ? texts.text('common.uploadImage') : texts.text('common.replaceImage'),
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: texts.text('merchant.stamps.section.preview'),
            tooltip: texts.text('merchant.stamps.section.previewTip'),
            child: MerchantStampPreview(card: _cardFromForm(provider, card)),
          ),
          _SectionCard(
            title: texts.text('merchant.stamps.section.publish'),
            tooltip: texts.text('merchant.stamps.section.publishTip'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  texts.text('merchant.stamps.publishInfo'),
                  style: const TextStyle(
                    color: AppColors.gray700,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantPrimaryButton(
                  label: texts.text('merchant.stamps.saveDraft'),
                  icon: Icons.save_rounded,
                  isLoading: provider.isSaving,
                  onPressed: () => _saveDraft(context, provider, card),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: provider.isSaving ? null : () => _publish(context, provider, card),
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: Text(texts.text('merchant.stamps.publish')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _hydrate(StampCardModel card) {
    final key = card.id.isEmpty ? 'new' : card.id;
    if (_hydratedId == key) return;
    _isHydrating = true;
    _hydratedId = key;
    _title.text = card.title;
    _subtitle.text = card.subtitle;
    _description.text = card.description;
    _minimumAmount.text = card.minimumAmount?.toString().replaceAll('.', ',') ?? '';
    _conditionText.text = card.conditionText;
    _rewardTitle.text = card.rewardTitle;
    _rewardDescription.text = card.rewardDescription;
    _stampContent.text = card.stampIconType == 'char' ? card.stampIconValue : '';
    _requiredStamps = card.requiredStamps;
    _conditionType = card.conditionType;
    _requiredItemId = card.requiredItemId;
    _requiredItemName = card.requiredItemName;
    _rewardType = card.rewardType;
    _rewardItemId = card.rewardItemId;
    _rewardItemName = card.rewardItemName;
    _backgroundColor = card.backgroundColor;
    _gradientColor = card.gradientColor;
    _gradientEnabled = card.gradientEnabled;
    _accentColor = card.accentColor;
    _textColor = card.textColor;
    _styleName = card.styleName;
    _stampShape = card.stampShape;
    _stampIconType = card.stampIconType;
    _stampIconValue = card.stampIconValue;
    _imageUrl = card.imageUrl;
    _imagePlacement = card.imagePlacement;
    _isHydrating = false;
  }

  StampCardModel _cardFromForm(
    MerchantStampsProvider provider,
    StampCardModel existing, {
    String? forcedStatus,
  }) {
    final status = forcedStatus ??
        (existing.status == StampCardStatus.active ? StampCardStatus.active : StampCardStatus.draft);
    final conditionItem = _findItem(provider.items, _requiredItemId);
    final rewardItem = _findItem(provider.items, _rewardItemId);
    return StampCardModel(
      id: existing.id,
      merchantId: provider.merchantId,
      title: _title.text,
      subtitle: _subtitle.text,
      description: _description.text,
      requiredStamps: _requiredStamps,
      conditionType: _conditionType,
      minimumAmount: _parseAmount(_minimumAmount.text),
      requiredItemId: _conditionType == StampConditionType.item ? conditionItem?.id ?? '' : '',
      requiredItemName: _conditionType == StampConditionType.item ? conditionItem?.name ?? _requiredItemName : '',
      conditionText: _conditionText.text,
      rewardType: _rewardType,
      rewardItemId: _rewardType == StampRewardType.item ? rewardItem?.id ?? '' : '',
      rewardItemName: _rewardType == StampRewardType.item ? rewardItem?.name ?? _rewardItemName : '',
      rewardTitle: _rewardTitle.text,
      rewardDescription: _rewardDescription.text,
      backgroundColor: _backgroundColor,
      gradientColor: _gradientColor,
      gradientEnabled: _gradientEnabled,
      accentColor: _accentColor,
      textColor: _textColor,
      styleName: _styleName,
      stampShape: _stampShape,
      stampIconType: _stampIconType,
      stampIconValue: _stampIconType == 'char'
          ? (_stampContent.text.trim().isEmpty ? '*' : _stampContent.text.trim())
          : _stampIconValue,
      imageUrl: _imageUrl,
      imagePlacement: _imagePlacement,
      claimLimits: const {'perUser': null, 'perDay': null},
      creditCostPerWeek: 2,
      status: status,
      isActive: status == StampCardStatus.active,
      isArchived: status == StampCardStatus.archived,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
      publishedAt: existing.publishedAt,
      activatedAt: existing.activatedAt,
      pausedAt: existing.pausedAt,
      archivedAt: existing.archivedAt,
    );
  }

  Future<void> _saveDraft(
    BuildContext context,
    MerchantStampsProvider provider,
    StampCardModel existing,
  ) async {
    final texts = context.read<LanguageService>();
    if (!_validate(context, provider)) return;
    final id = await provider.saveCard(_cardFromForm(provider, existing));
    if (!context.mounted || id == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texts.text('merchant.stamps.saved'))),
    );
    context.pushReplacement('/merchant/stamps/edit/$id');
  }

  Future<void> _publish(
    BuildContext context,
    MerchantStampsProvider provider,
    StampCardModel existing,
  ) async {
    if (!_validate(context, provider)) return;
    final accepted = await _showPublishSheet(context);
    if (accepted != true || !context.mounted) return;
    final id = await provider.publishCard(
      _cardFromForm(provider, existing, forcedStatus: StampCardStatus.active),
    );
    if (!context.mounted || id == null) return;
    context.go('/merchant/stamps');
  }

  bool _validate(BuildContext context, MerchantStampsProvider provider) {
    final texts = context.read<LanguageService>();
    String? message;
    if (_title.text.trim().isEmpty) {
      message = texts.text('merchant.stamps.error.title');
    } else if (_rewardTitle.text.trim().isEmpty) {
      message = texts.text('merchant.stamps.error.reward');
    } else if (_conditionType == StampConditionType.minimumAmount && _parseAmount(_minimumAmount.text) == null) {
      message = texts.text('merchant.stamps.error.minimumAmount');
    } else if (_conditionType == StampConditionType.item && _findItem(provider.items, _requiredItemId) == null) {
      message = texts.text('merchant.stamps.error.item');
    } else if (_rewardType == StampRewardType.item && _findItem(provider.items, _rewardItemId) == null) {
      message = texts.text('merchant.stamps.error.rewardItem');
    }
    if (message == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }

  void _setStyle(_StyleOption option) {
    setState(() {
      _styleName = option.key;
      _backgroundColor = option.background;
      _gradientColor = option.gradient;
      _accentColor = option.accent;
      _textColor = option.text;
      _gradientEnabled = option.gradientEnabled;
    });
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.tooltip,
    required this.child,
  });

  final String title;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              MerchantInfoTooltip(message: tooltip),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
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
              selectedColor: AppColors.black,
              labelStyle: TextStyle(
                color: selected == option.value ? AppColors.white : AppColors.black,
                fontWeight: FontWeight.w800,
              ),
              side: const BorderSide(color: AppColors.border),
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
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          texts.text('merchant.stamps.noItems'),
          style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w700),
        ),
      );
    }
    final selected = items.any((item) => item.id == value) ? value : items.first.id;
    return DropdownButtonFormField<String>(
      value: selected,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item.id,
              child: Text(item.name),
            ),
          )
          .toList(),
      onChanged: (id) {
        for (final item in items) {
          if (item.id == id) {
            onChanged(item);
            return;
          }
        }
        onChanged(null);
      },
    );
  }
}

class _StyleOption {
  const _StyleOption({
    required this.key,
    required this.background,
    required this.gradient,
    required this.gradientEnabled,
    required this.accent,
    required this.text,
  });

  final String key;
  final String background;
  final String gradient;
  final bool gradientEnabled;
  final String accent;
  final String text;
}

const _styleOptions = [
  _StyleOption(key: 'noir', background: '#171A18', gradient: '#45C9A4', gradientEnabled: false, accent: '#9CE8CF', text: '#FEFFFC'),
  _StyleOption(key: 'mint', background: '#E9FAF3', gradient: '#9CE8CF', gradientEnabled: true, accent: '#171A18', text: '#171A18'),
  _StyleOption(key: 'cream', background: '#FFF5E6', gradient: '#FFF1A5', gradientEnabled: true, accent: '#45C9A4', text: '#171A18'),
  _StyleOption(key: 'berry', background: '#301824', gradient: '#6F284A', gradientEnabled: true, accent: '#FFD6E7', text: '#FEFFFC'),
];

class _StyleSelector extends StatelessWidget {
  const _StyleSelector({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<_StyleOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _styleOptions
          .map(
            (option) => InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onSelected(option),
              child: Container(
                width: 118,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _color(option.background),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected == option.key ? AppColors.black : AppColors.border,
                    width: selected == option.key ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _color(option.accent),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      texts.text('merchant.stamps.style.${option.key}'),
                      style: TextStyle(
                        color: _color(option.text),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Color _color(String hex) {
    final clean = hex.replaceAll('#', '');
    final parsed = int.tryParse('FF$clean', radix: 16);
    return parsed == null ? AppColors.black : Color(parsed);
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({
    required this.title,
    required this.selected,
    required this.colors,
    required this.onSelected,
  });

  final String title;
  final String selected;
  final List<String> colors;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: colors.map((hex) {
              final selectedColor = selected.toUpperCase() == hex.toUpperCase();
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onSelected(hex),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _color(hex),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selectedColor ? AppColors.black : AppColors.border,
                      width: selectedColor ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _color(String hex) {
    final clean = hex.replaceAll('#', '');
    final parsed = int.tryParse('FF$clean', radix: 16);
    return parsed == null ? AppColors.black : Color(parsed);
  }
}

class _LockedImagePlacement extends StatelessWidget {
  const _LockedImagePlacement({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: onRemove,
            child: Text(texts.text('merchant.stamps.removeImage')),
          ),
        ],
      ),
    );
  }
}

UploadImageType _uploadTypeForPlacement(String placement) {
  return switch (placement) {
    'top' => UploadImageType.stampCardTop,
    'background' => UploadImageType.stampCardBackground,
    _ => UploadImageType.stampCardSide,
  };
}

Future<int?> _askCustomStampCount(BuildContext context, int current) async {
  final texts = context.read<LanguageService>();
  final controller = TextEditingController(text: current.toString());
  final result = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(sheetContext).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texts.text('merchant.stamps.customCount'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: controller,
            label: texts.text('merchant.stamps.field.requiredStamps'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantPrimaryButton(
            label: texts.text('common.save'),
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.of(sheetContext).pop(value == null ? null : value.clamp(2, 30).toInt());
            },
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

Future<bool?> _showPublishSheet(BuildContext context) {
  final texts = context.read<LanguageService>();
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
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
              texts.text('merchant.stamps.publishTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text('merchant.stamps.publishMessage'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gray700,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            MerchantPrimaryButton(
              label: texts.text('merchant.stamps.publish'),
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

num? _parseAmount(String value) {
  final clean = value.trim().replaceAll(',', '.');
  if (clean.isEmpty) return null;
  return num.tryParse(clean);
}

MerchantItemData? _findItem(List<MerchantItemData> items, String id) {
  if (items.isEmpty) return null;
  for (final item in items) {
    if (item.id == id) return item;
  }
  return items.first;
}
