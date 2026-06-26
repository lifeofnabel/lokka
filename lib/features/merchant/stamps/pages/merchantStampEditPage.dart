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
import '../../shared/widgets/merchantUiComponents.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/stampCardModel.dart';
import '../providers/merchantStampsProvider.dart';
import '../services/merchantStampsService.dart';
import '../widgets/merchantStampCard.dart';
import '../widgets/stampBuilderExtras.dart';

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

  static const int _stepCount = 6;

  int _step = 0;
  String? _hydratedId;
  bool _isHydrating = false;
  MerchantStampsProvider? _stampsProvider;
  bool _showAdvancedDesign = false;
  int _requiredStamps = 10;
  // Dead time between two stamps for the same customer (seconds). 0 = none, for
  // shops that hand out several stamps per purchase. Stored in claimLimits.
  int _cooldownSeconds = 120;
  String _conditionType = StampConditionType.visit;
  String _requiredItemId = '';
  String _requiredItemName = '';
  String _rewardType = StampRewardType.custom;
  String _rewardItemId = '';
  String _rewardItemName = '';
  // Optional intermediate reward milestones (atStamp < requiredStamps). Empty =
  // simple single-reward card. The final reward is always the main reward fields.
  List<StampRewardTier> _rewardTiers = [];
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
    // Hydration NICHT in build() (#45): einmalig, sobald der Provider die Karte
    // geladen hat – kein State-Mutieren während des Builds.
    _stampsProvider = context.read<MerchantStampsProvider>()
      ..addListener(_hydrateFromProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromProvider());
  }

  @override
  void dispose() {
    _stampsProvider?.removeListener(_hydrateFromProvider);
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

  // Hydriert Controller/Felder aus dem geladenen Provider-Stand (#45) – einmal
  // pro Karte (danach via _hydratedId idempotent); Rebuild nach frischer
  // Hydration, damit die befüllten Felder erscheinen.
  void _hydrateFromProvider() {
    final provider = _stampsProvider;
    if (!mounted || provider == null || provider.isLoading) return;
    final card = provider.editingCard ??
        StampCardModel.empty(merchantId: provider.merchantId);
    if (_hydrate(card) && mounted) setState(() {});
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

    return MerchantToolScaffold(
      title: widget.stampCardId == null
          ? texts.text('merchant.stamps.create')
          : texts.text('merchant.stamps.editTitle'),
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
          _StepDots(step: _step, total: _stepCount, labels: _stepLabels),
          const SizedBox(height: AppSpacing.md),
          // Vorschau-Popout ganz oben: öffnet eine Live-Vorschau der Karte.
          _PreviewLauncher(
            onTap: () => _showPreviewDialog(context, provider, card),
          ),
          const SizedBox(height: AppSpacing.md),
          _stepContent(context, provider, texts, card),
          const SizedBox(height: AppSpacing.sm),
          _NavigationRow(
            step: _step,
            isLast: _step == _stepCount - 1,
            isSaving: provider.isSaving,
            onBack: _step == 0 ? null : () => setState(() => _step--),
            onNext: _step == _stepCount - 1
                ? () => _publish(context, provider, card)
                : () => setState(() => _step++),
          ),
        ],
      ),
    );
  }

  List<String> get _stepLabels => const [
        'merchant.stamps.section.name',
        'merchant.stamps.section.condition',
        'merchant.stamps.section.stamps',
        'merchant.stamps.section.reward',
        'merchant.stamps.section.design',
        'merchant.stamps.section.publish',
      ];

  Widget _stepContent(
    BuildContext context,
    MerchantStampsProvider provider,
    LanguageService texts,
    StampCardModel card,
  ) {
    return switch (_step) {
      0 => _NameStep(
          title: _title,
          subtitle: _subtitle,
          description: _description,
        ),
      1 => _ConditionStep(
          conditionType: _conditionType,
          minimumAmount: _minimumAmount,
          conditionText: _conditionText,
          items: provider.items,
          requiredItemId: _requiredItemId,
          onConditionType: (value) => setState(() => _conditionType = value),
          onItem: (item) => setState(() {
            _requiredItemId = item?.id ?? '';
            _requiredItemName = item?.name ?? '';
          }),
        ),
      2 => _StampsStep(
          requiredStamps: _requiredStamps,
          cooldownSeconds: _cooldownSeconds,
          onCount: (value) => setState(() => _requiredStamps = value),
          onCustom: () async {
            final custom = await _askCustomStampCount(context, _requiredStamps);
            if (custom != null) setState(() => _requiredStamps = custom);
          },
          onCooldown: (value) => setState(() => _cooldownSeconds = value),
        ),
      3 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RewardStep(
              rewardType: _rewardType,
              items: provider.items,
              rewardItemId: _rewardItemId,
              rewardTitle: _rewardTitle,
              rewardDescription: _rewardDescription,
              onRewardType: (value) => setState(() => _rewardType = value),
              onItem: (item) => setState(() {
                _rewardItemId = item?.id ?? '';
                _rewardItemName = item?.name ?? '';
                if (item != null && _rewardTitle.text.trim().isEmpty) {
                  _rewardTitle.text = item.name;
                }
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            StampTieredRewardsEditor(
              tiers: _rewardTiers,
              maxStamps: _requiredStamps,
              onAdd: _addRewardTier,
              onRemove: (i) => setState(() => _rewardTiers.removeAt(i)),
            ),
          ],
        ),
      4 => _DesignStep(
          styleName: _styleName,
          showAdvanced: _showAdvancedDesign,
          gradientEnabled: _gradientEnabled,
          backgroundColor: _backgroundColor,
          gradientColor: _gradientColor,
          accentColor: _accentColor,
          textColor: _textColor,
          stampShape: _stampShape,
          stampIconType: _stampIconType,
          stampIconValue: _stampIconValue,
          stampContent: _stampContent,
          imageUrl: _imageUrl,
          imagePlacement: _imagePlacement,
          isSaving: provider.isSaving,
          onStyle: _setStyle,
          onToggleAdvanced: () => setState(() => _showAdvancedDesign = !_showAdvancedDesign),
          onGradient: (value) => setState(() => _gradientEnabled = value),
          onBackgroundColor: (value) => setState(() => _backgroundColor = value),
          onGradientColor: (value) => setState(() => _gradientColor = value),
          onAccentColor: (value) => setState(() => _accentColor = value),
          onTextColor: (value) => setState(() => _textColor = value),
          onShape: (value) => setState(() => _stampShape = value),
          onIconType: (value) => setState(() => _stampIconType = value),
          onIconValue: (value) => setState(() => _stampIconValue = value),
          onPlacement: (value) => setState(() => _imagePlacement = value),
          onRemoveImage: () => setState(() => _imageUrl = ''),
          onUpload: () async {
            final uploaded = await provider.uploadImage(
              type: _uploadTypeForPlacement(_imagePlacement),
            );
            if (uploaded != null && uploaded.isNotEmpty) {
              setState(() => _imageUrl = uploaded);
            }
          },
        ),
      _ => _PublishStep(card: _cardFromForm(provider, card)),
    };
  }

  Future<void> _showPreviewDialog(
    BuildContext context,
    MerchantStampsProvider provider,
    StampCardModel existing,
  ) async {
    final texts = context.read<LanguageService>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: MerchantPremiumCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            radius: 34,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        texts.text('merchant.stamps.section.preview'),
                        style: const TextStyle(
                          color: MerchantPremiumColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded, color: MerchantPremiumColors.ink),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                StampPreviewBody(card: _cardFromForm(provider, existing)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hydrate(StampCardModel card) {
    final key = card.id.isEmpty ? 'new' : card.id;
    if (_hydratedId == key) return false;
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
    final rawCooldown = card.claimLimits['cooldownSeconds'];
    _cooldownSeconds = rawCooldown is num
        ? rawCooldown.round()
        : int.tryParse('${rawCooldown ?? ''}') ?? 120;
    _conditionType = card.conditionType;
    _requiredItemId = card.requiredItemId;
    _requiredItemName = card.requiredItemName;
    _rewardType = card.rewardType;
    _rewardItemId = card.rewardItemId;
    _rewardItemName = card.rewardItemName;
    // Keep only intermediate tiers; the top tier maps to the main reward fields.
    _rewardTiers = card.rewardTiers
        .where((t) => t.atStamp < card.requiredStamps)
        .toList();
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
    return true;
  }

  StampCardModel _cardFromForm(
    MerchantStampsProvider provider,
    StampCardModel existing, {
    String? forcedStatus,
  }) {
    // Bestehenden Status erhalten (#46): nur _publish erzwingt 'active'. Vorher
    // wurde paused/archived beim Entwurf-Speichern still zu 'draft'. Neue Karten
    // sind via StampCardModel.empty() ohnehin 'draft'.
    final status = forcedStatus ?? existing.status;
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
      rewardTiers: _buildRewardTiers(rewardItem),
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
      claimLimits: {...existing.claimLimits, 'cooldownSeconds': _cooldownSeconds},
      // Preserve the prepared share link + stick binding across edits.
      staticToken: existing.staticToken,
      boundStickId: existing.boundStickId,
      stickType: existing.stickType,
      stickVerifiedAt: existing.stickVerifiedAt,
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

  /// Combines the optional intermediate tiers with the final (main) reward into
  /// one ordered list. Empty intermediate tiers → empty list (legacy single
  /// reward path, kept for back-compat).
  List<StampRewardTier> _buildRewardTiers(MerchantItemData? rewardItem) {
    final extra = _rewardTiers
        .where((t) => t.atStamp > 0 && t.atStamp < _requiredStamps)
        .toList();
    if (extra.isEmpty) return const [];
    final main = StampRewardTier(
      atStamp: _requiredStamps,
      type: _rewardType,
      label: _rewardTitle.text.trim(),
      itemId: _rewardType == StampRewardType.item ? rewardItem?.id ?? '' : '',
      itemName: _rewardType == StampRewardType.item
          ? rewardItem?.name ?? _rewardItemName
          : '',
    );
    return [...extra, main]..sort((a, b) => a.atStamp.compareTo(b.atStamp));
  }

  Future<void> _addRewardTier() async {
    final tier = await showStampTierDialog(context, maxStamps: _requiredStamps);
    if (tier != null) setState(() => _rewardTiers.add(tier));
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
    int? jumpTo;
    if (_title.text.trim().isEmpty) {
      message = texts.text('merchant.stamps.error.title');
      jumpTo = 0;
    } else if (_conditionType == StampConditionType.minimumAmount && _parseAmount(_minimumAmount.text) == null) {
      message = texts.text('merchant.stamps.error.minimumAmount');
      jumpTo = 1;
    } else if (_conditionType == StampConditionType.item && _findItem(provider.items, _requiredItemId) == null) {
      message = texts.text('merchant.stamps.error.item');
      jumpTo = 1;
    } else if (_rewardTitle.text.trim().isEmpty) {
      message = texts.text('merchant.stamps.error.reward');
      jumpTo = 3;
    } else if (_rewardType == StampRewardType.item && _findItem(provider.items, _rewardItemId) == null) {
      message = texts.text('merchant.stamps.error.rewardItem');
      jumpTo = 3;
    }
    if (message == null) return true;
    if (jumpTo != null && jumpTo != _step) setState(() => _step = jumpTo!);
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

// ─── Survey steps ──────────────────────────────────────────────────────────

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController description;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.stamps.section.name'),
      tooltip: texts.text('merchant.stamps.section.nameTip'),
      child: Column(
        children: [
          MerchantTextField(controller: title, label: texts.text('merchant.stamps.field.title')),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(controller: subtitle, label: texts.text('merchant.stamps.field.subtitle')),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: description,
            label: texts.text('common.description'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _ConditionStep extends StatelessWidget {
  const _ConditionStep({
    required this.conditionType,
    required this.minimumAmount,
    required this.conditionText,
    required this.items,
    required this.requiredItemId,
    required this.onConditionType,
    required this.onItem,
  });

  final String conditionType;
  final TextEditingController minimumAmount;
  final TextEditingController conditionText;
  final List<MerchantItemData> items;
  final String requiredItemId;
  final ValueChanged<String> onConditionType;
  final ValueChanged<MerchantItemData?> onItem;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
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
            selected: conditionType,
            onSelected: onConditionType,
          ),
          if (conditionType == StampConditionType.minimumAmount) ...[
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(
              controller: minimumAmount,
              label: texts.text('merchant.stamps.field.minimumAmount'),
              keyboardType: TextInputType.number,
            ),
          ],
          if (conditionType == StampConditionType.item) ...[
            const SizedBox(height: AppSpacing.md),
            _ItemDropdown(
              label: texts.text('merchant.stamps.field.requiredItem'),
              items: items,
              value: requiredItemId,
              onChanged: onItem,
            ),
          ],
          if (conditionType == StampConditionType.custom) ...[
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(
              controller: conditionText,
              label: texts.text('merchant.stamps.field.conditionText'),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}

class _StampsStep extends StatelessWidget {
  const _StampsStep({
    required this.requiredStamps,
    required this.cooldownSeconds,
    required this.onCount,
    required this.onCustom,
    required this.onCooldown,
  });

  final int requiredStamps;
  final int cooldownSeconds;
  final ValueChanged<int> onCount;
  final VoidCallback onCustom;
  final ValueChanged<int> onCooldown;

  static const _cooldownPresets = [0, 60, 120, 300];

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    const presets = [5, 8, 10, 12, 15];
    // Snap an arbitrary stored value to the nearest preset for selection display.
    final selectedCooldown = _cooldownPresets.contains(cooldownSeconds)
        ? cooldownSeconds
        : (cooldownSeconds <= 0
            ? 0
            : _cooldownPresets.reduce((a, b) =>
                (cooldownSeconds - a).abs() <= (cooldownSeconds - b).abs() ? a : b));
    return MerchantFormSection(
      title: texts.text('merchant.stamps.section.stamps'),
      tooltip: texts.text('merchant.stamps.section.stampsTip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipWrap(
            options: [
              ...presets.map((count) => _ChipOption(count.toString(), count.toString())),
              _ChipOption('custom', texts.text('merchant.stamps.custom')),
            ],
            selected: presets.contains(requiredStamps) ? requiredStamps.toString() : 'custom',
            onSelected: (value) {
              if (value == 'custom') {
                onCustom();
              } else {
                onCount(int.parse(value));
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            texts.text('merchant.stamps.cooldownTitle'),
            style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            texts.text('merchant.stamps.cooldownHint'),
            style: const TextStyle(
                color: MerchantPremiumColors.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChipWrap(
            options: [
              _ChipOption('0', texts.text('merchant.stamps.cooldown.none')),
              _ChipOption('60', texts.text('merchant.stamps.cooldown.1min')),
              _ChipOption('120', texts.text('merchant.stamps.cooldown.2min')),
              _ChipOption('300', texts.text('merchant.stamps.cooldown.5min')),
            ],
            selected: selectedCooldown.toString(),
            onSelected: (value) => onCooldown(int.parse(value)),
          ),
        ],
      ),
    );
  }
}

class _RewardStep extends StatelessWidget {
  const _RewardStep({
    required this.rewardType,
    required this.items,
    required this.rewardItemId,
    required this.rewardTitle,
    required this.rewardDescription,
    required this.onRewardType,
    required this.onItem,
  });

  final String rewardType;
  final List<MerchantItemData> items;
  final String rewardItemId;
  final TextEditingController rewardTitle;
  final TextEditingController rewardDescription;
  final ValueChanged<String> onRewardType;
  final ValueChanged<MerchantItemData?> onItem;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
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
            selected: rewardType,
            onSelected: onRewardType,
          ),
          if (rewardType == StampRewardType.item) ...[
            const SizedBox(height: AppSpacing.md),
            _ItemDropdown(
              label: texts.text('merchant.stamps.field.rewardItem'),
              items: items,
              value: rewardItemId,
              onChanged: onItem,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(controller: rewardTitle, label: texts.text('merchant.stamps.field.rewardTitle')),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: rewardDescription,
            label: texts.text('merchant.stamps.field.rewardDescription'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _DesignStep extends StatelessWidget {
  const _DesignStep({
    required this.styleName,
    required this.showAdvanced,
    required this.gradientEnabled,
    required this.backgroundColor,
    required this.gradientColor,
    required this.accentColor,
    required this.textColor,
    required this.stampShape,
    required this.stampIconType,
    required this.stampIconValue,
    required this.stampContent,
    required this.imageUrl,
    required this.imagePlacement,
    required this.isSaving,
    required this.onStyle,
    required this.onToggleAdvanced,
    required this.onGradient,
    required this.onBackgroundColor,
    required this.onGradientColor,
    required this.onAccentColor,
    required this.onTextColor,
    required this.onShape,
    required this.onIconType,
    required this.onIconValue,
    required this.onPlacement,
    required this.onRemoveImage,
    required this.onUpload,
  });

  final String styleName;
  final bool showAdvanced;
  final bool gradientEnabled;
  final String backgroundColor;
  final String gradientColor;
  final String accentColor;
  final String textColor;
  final String stampShape;
  final String stampIconType;
  final String stampIconValue;
  final TextEditingController stampContent;
  final String imageUrl;
  final String imagePlacement;
  final bool isSaving;
  final ValueChanged<_StyleOption> onStyle;
  final VoidCallback onToggleAdvanced;
  final ValueChanged<bool> onGradient;
  final ValueChanged<String> onBackgroundColor;
  final ValueChanged<String> onGradientColor;
  final ValueChanged<String> onAccentColor;
  final ValueChanged<String> onTextColor;
  final ValueChanged<String> onShape;
  final ValueChanged<String> onIconType;
  final ValueChanged<String> onIconValue;
  final ValueChanged<String> onPlacement;
  final VoidCallback onRemoveImage;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.stamps.section.design'),
      tooltip: texts.text('merchant.stamps.section.designTip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texts.text('merchant.stamps.templatesTitle'),
            style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StyleSelector(selected: styleName, onSelected: onStyle),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onToggleAdvanced,
            icon: Icon(showAdvanced ? Icons.expand_less_rounded : Icons.tune_rounded),
            label: Text(texts.text('merchant.stamps.advancedDesign')),
            style: OutlinedButton.styleFrom(
              foregroundColor: MerchantPremiumColors.ink,
              side: const BorderSide(color: MerchantPremiumColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
          if (showAdvanced) ...[
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              value: gradientEnabled,
              onChanged: onGradient,
              title: Text(
                texts.text('merchant.stamps.gradient'),
                style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w800),
              ),
              activeThumbColor: MerchantPremiumColors.gold,
              contentPadding: EdgeInsets.zero,
            ),
            _ColorSelector(
              title: texts.text('merchant.stamps.backgroundColor'),
              selected: backgroundColor,
              colors: const ['#171A18', '#E9FAF3', '#FFF5E6', '#301824', '#1F3A52', '#F5F6F2'],
              onSelected: onBackgroundColor,
            ),
            if (gradientEnabled)
              _ColorSelector(
                title: texts.text('merchant.stamps.gradientColor'),
                selected: gradientColor,
                colors: const ['#45C9A4', '#9CE8CF', '#FFD6E7', '#CFE4FF', '#FFF1A5', '#FFB36C'],
                onSelected: onGradientColor,
              ),
            _ColorSelector(
              title: texts.text('merchant.stamps.accentColor'),
              selected: accentColor,
              colors: const ['#9CE8CF', '#171A18', '#FEFFFC', '#FFD6E7', '#FFF1A5', '#CFE4FF'],
              onSelected: onAccentColor,
            ),
            _ColorSelector(
              title: texts.text('merchant.stamps.textColor'),
              selected: textColor,
              colors: const ['#FEFFFC', '#171A18', '#4A4A4A', '#FFF5E6'],
              onSelected: onTextColor,
            ),
            const SizedBox(height: AppSpacing.md),
            _ChipWrap(
              options: [
                _ChipOption('circle', texts.text('merchant.stamps.shape.circle')),
                _ChipOption('square', texts.text('merchant.stamps.shape.square')),
                _ChipOption('softSquare', texts.text('merchant.stamps.shape.softSquare')),
                _ChipOption('diamond', texts.text('merchant.stamps.shape.diamond')),
              ],
              selected: stampShape,
              onSelected: onShape,
            ),
            const SizedBox(height: AppSpacing.md),
            _ChipWrap(
              options: [
                _ChipOption('icon', texts.text('merchant.stamps.content.icon')),
                _ChipOption('char', texts.text('merchant.stamps.content.char')),
              ],
              selected: stampIconType,
              onSelected: onIconType,
            ),
            const SizedBox(height: AppSpacing.md),
            if (stampIconType == 'icon')
              _ChipWrap(
                options: [
                  _ChipOption('star', texts.text('merchant.stamps.icon.star')),
                  _ChipOption('gift', texts.text('merchant.stamps.icon.gift')),
                  _ChipOption('coffee', texts.text('merchant.stamps.icon.coffee')),
                  _ChipOption('food', texts.text('merchant.stamps.icon.food')),
                  _ChipOption('heart', texts.text('merchant.stamps.icon.heart')),
                  _ChipOption('local', texts.text('merchant.stamps.icon.local')),
                ],
                selected: stampIconValue,
                onSelected: onIconValue,
              )
            else
              MerchantTextField(
                controller: stampContent,
                label: texts.text('merchant.stamps.field.stampContent'),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (imageUrl.isEmpty)
            _ChipWrap(
              options: [
                _ChipOption('side', texts.text('merchant.stamps.image.side')),
                _ChipOption('top', texts.text('merchant.stamps.image.top')),
                _ChipOption('background', texts.text('merchant.stamps.image.background')),
              ],
              selected: imagePlacement,
              onSelected: onPlacement,
            )
          else
            _LockedImagePlacement(
              label: texts
                  .text('merchant.stamps.imageLocked')
                  .replaceAll('{placement}', texts.text('merchant.stamps.image.$imagePlacement')),
              onRemove: onRemoveImage,
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: isSaving ? null : onUpload,
            icon: const Icon(Icons.image_rounded),
            label: Text(
              imageUrl.isEmpty ? texts.text('common.uploadImage') : texts.text('common.replaceImage'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: MerchantPremiumColors.ink,
              side: const BorderSide(color: MerchantPremiumColors.line),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishStep extends StatelessWidget {
  const _PublishStep({required this.card});

  final StampCardModel card;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.stamps.section.publish'),
      tooltip: texts.text('merchant.stamps.section.publishTip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantStampPreview(card: card),
        ],
      ),
    );
  }
}

// ─── Navigation & step indicator ───────────────────────────────────────────

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.total, required this.labels});

  final int step;
  final int total;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: MerchantPremiumColors.surfaceAlt,
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texts
                .text('merchant.stamps.stepIndicator')
                .replaceAll('{current}', '${step + 1}')
                .replaceAll('{total}', '$total'),
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texts.text(labels[step]),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(total, (index) {
              final active = index <= step;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: active ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PreviewLauncher extends StatelessWidget {
  const _PreviewLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: 24,
      onTap: onTap,
      child: Row(
        children: [
          const MerchantPremiumIconBox(icon: Icons.visibility_rounded, size: 44),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texts.text('merchant.stamps.previewLauncher'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  texts.text('merchant.stamps.previewLauncherHint'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.open_in_full_rounded, color: MerchantPremiumColors.ink, size: 20),
        ],
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.step,
    required this.isLast,
    required this.isSaving,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final bool isLast;
  final bool isSaving;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Row(
      children: [
        if (onBack != null) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isSaving ? null : onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(texts.text('common.back')),
              style: OutlinedButton.styleFrom(
                foregroundColor: MerchantPremiumColors.ink,
                minimumSize: const Size.fromHeight(56),
                side: const BorderSide(color: MerchantPremiumColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          flex: onBack == null ? 1 : 2,
          child: MerchantPrimaryButton(
            label: isLast ? texts.text('merchant.stamps.publish') : texts.text('common.next'),
            icon: isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
            isLoading: isSaving,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

// ─── Shared form widgets ───────────────────────────────────────────────────

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
              selectedColor: MerchantPremiumColors.gold,
              backgroundColor: MerchantPremiumColors.surface,
              labelStyle: TextStyle(
                color: selected == option.value
                    ? MerchantPremiumColors.base
                    : MerchantPremiumColors.ink,
                fontWeight: FontWeight.w800,
              ),
              side: const BorderSide(color: MerchantPremiumColors.line),
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
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: Text(
          texts.text('merchant.stamps.noItems'),
          style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w700),
        ),
      );
    }
    final selected = items.any((item) => item.id == value) ? value : items.first.id;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      dropdownColor: MerchantPremiumColors.surface,
      iconEnabledColor: MerchantPremiumColors.ink,
      style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w800),
      decoration: merchantPremiumInputDecoration(label: label),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item.id,
              child: Text(
                item.name,
                style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w800),
              ),
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

// Three ready-made design templates. Tapping one sets all colours at once;
// the advanced section below lets the merchant fine-tune from there.
const _styleOptions = [
  _StyleOption(key: 'noir', background: '#171A18', gradient: '#45C9A4', gradientEnabled: true, accent: '#9CE8CF', text: '#FEFFFC'),
  _StyleOption(key: 'cream', background: '#FFF5E6', gradient: '#FFD9A0', gradientEnabled: true, accent: '#45C9A4', text: '#171A18'),
  _StyleOption(key: 'berry', background: '#2A1430', gradient: '#6F284A', gradientEnabled: true, accent: '#FFD6E7', text: '#FEFFFC'),
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
    return Row(
      children: [
        for (var i = 0; i < _styleOptions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _tile(texts, _styleOptions[i])),
        ],
      ],
    );
  }

  Widget _tile(LanguageService texts, _StyleOption option) {
    final isSelected = selected == option.key;
    final bg = _color(option.background);
    final accent = _color(option.accent);
    final fg = _color(option.text);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => onSelected(option),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          gradient: option.gradientEnabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bg, _color(option.gradient)],
                )
              : null,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    texts.text('merchant.stamps.style.${option.key}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: MerchantPremiumColors.gold, size: 18),
              ],
            ),
            const Spacer(),
            // Mini stamp row → a real preview of the look.
            Row(
              children: List.generate(
                3,
                (_) => Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: fg.withValues(alpha: 0.18)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _color(String hex) {
    final clean = hex.replaceAll('#', '');
    final parsed = int.tryParse('FF$clean', radix: 16);
    return parsed == null ? MerchantPremiumColors.base : Color(parsed);
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
          Text(
            title,
            style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900),
          ),
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
                      color: selectedColor ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
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
    return parsed == null ? MerchantPremiumColors.base : Color(parsed);
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
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 19, color: MerchantPremiumColors.ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w800),
            ),
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
    backgroundColor: MerchantPremiumColors.surface,
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
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: controller,
            label: texts.text('merchant.stamps.field.requiredStamps'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Min/Max sichtbar kommunizieren statt still zu clampen (#69).
          Text(
            texts.text('merchant.stamps.customCountHint'),
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantPrimaryButton(
            label: texts.text('common.save'),
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null) {
                Navigator.of(sheetContext).pop();
                return;
              }
              final clamped = value.clamp(2, 30).toInt();
              // Bei Bereichsüberschreitung Feedback geben, nicht still anpassen.
              if (clamped != value) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text(texts.text('merchant.stamps.customCountClamped'))),
                );
              }
              Navigator.of(sheetContext).pop(clamped);
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
              texts.text('merchant.stamps.publishTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text('merchant.stamps.publishMessage'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
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

const String kStampPublishConfirmMessage =
    'Nach der Bestätigung wird die Karte sofort für deine Kundinnen und Kunden aktiv.';

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
