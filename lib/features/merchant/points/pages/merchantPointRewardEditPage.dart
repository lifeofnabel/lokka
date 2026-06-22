import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/appLimits.dart';
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
  String _rewardType = PointsRewardType.custom;
  String _rewardItemId = '';
  String _imageUrl = '';
  // true, solange die Pflichtpunkte nur den geladenen/Default-Wert tragen und
  // nicht vom Nutzer bewusst geändert wurden. Steuert das Auto-Befüllen bei
  // Item-Auswahl ohne Magic-String-Vergleich.
  bool _requiredPointsPristine = true;
  // Quelle des aktuellen Bildes: true = aus einem Item übernommen (wird beim
  // Typ-/Item-Wechsel aufgeräumt), false = manuell hochgeladen (bleibt).
  bool _imageFromItem = false;
  // Beim Speichern eines gelöschten Katalog-Items als Fallback verwendeter,
  // zuvor persistierter Item-Name (kein eigenes UI-State-Feld nötig).
  String _persistedItemName = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Tippen in den Pflichtpunkten gilt als bewusste Eingabe.
    _requiredPoints.addListener(_onRequiredPointsChanged);
  }

  @override
  void dispose() {
    _requiredPoints.removeListener(_onRequiredPointsChanged);
    _title.dispose();
    _description.dispose();
    _requiredPoints.dispose();
    _discountText.dispose();
    super.dispose();
  }

  void _onRequiredPointsChanged() => _requiredPointsPristine = false;

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
    final saving = provider.isSaving || _busy;

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
          // Live-Preview + Skala nur an die relevanten Controller (Titel,
          // Pflichtpunkte) gekoppelt – nicht die ganze Seite pro Tastendruck.
          AnimatedBuilder(
            animation: Listenable.merge([_title, _requiredPoints]),
            builder: (context, _) {
              final preview = _rewardFromForm(provider, reward);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PreviewShell(reward: preview),
                  const SizedBox(height: AppSpacing.md),
                  _RewardScaleMini(rewards: _scaleRewards(provider, reward, preview)),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _ChipWrap(
            options: [
              _ChipOption(PointsRewardType.custom, texts.text('merchant.points.reward.custom')),
              _ChipOption(PointsRewardType.item, texts.text('merchant.points.reward.item')),
              _ChipOption(PointsRewardType.discount, texts.text('merchant.points.reward.discount')),
            ],
            selected: _rewardType,
            onSelected: (value) => setState(() {
              _rewardType = value;
              // Vom Item übernommenes Bild beim Wegwechseln aufräumen; manuell
              // hochgeladene Bilder bleiben erhalten.
              if (value != PointsRewardType.item && _imageFromItem) {
                _imageUrl = '';
                _imageFromItem = false;
              }
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _title,
            label: texts.text('merchant.points.field.rewardTitle'),
            maxLength: AppLimits.pointsTitleMaxLength,
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _requiredPoints,
            label: texts.text('merchant.points.field.requiredPoints'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
          ),
          if (_rewardType == PointsRewardType.item) ...[
            const SizedBox(height: AppSpacing.md),
            _ItemDropdown(
              label: texts.text('merchant.points.field.rewardItem'),
              items: provider.items,
              value: _rewardItemId,
              onCreateItem: () => context.go('/merchant/tools/items'),
              onChanged: (item) => setState(() {
                _rewardItemId = item?.id ?? '';
                _persistedItemName = item?.name ?? _persistedItemName;
                if (item != null && _title.text.trim().isEmpty) {
                  _title.text = item.name;
                }
                if (item != null && _requiredPointsPristine) {
                  _requiredPoints.text = _suggestedPoints(provider, item).toString();
                  _requiredPointsPristine = true; // Auto-Wert bleibt änderbar.
                }
                if (item != null && (_imageUrl.trim().isEmpty || _imageFromItem)) {
                  _imageUrl = item.imageUrl;
                  _imageFromItem = item.imageUrl.isNotEmpty;
                }
              }),
            ),
          ],
          if (_rewardType == PointsRewardType.discount) ...[
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(
              controller: _discountText,
              label: texts.text('merchant.points.field.discountText'),
              maxLength: AppLimits.pointsDiscountMaxLength,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _description,
            label: texts.text('common.description'),
            maxLines: 3,
            maxLength: AppLimits.pointsDescriptionMaxLength,
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantSecondaryButton(
            label: _imageUrl.isEmpty
                ? texts.text('common.uploadImage')
                : texts.text('common.replaceImage'),
            icon: Icons.image_rounded,
            onPressed: saving
                ? null
                : () async {
                    final uploaded = await provider.uploadRewardImage();
                    if (uploaded != null && uploaded.isNotEmpty) {
                      setState(() {
                        _imageUrl = uploaded;
                        _imageFromItem = false; // bewusst manuell hochgeladen.
                      });
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.lg),
          MerchantPrimaryButton(
            label: reward.isLive ? texts.text('common.save') : texts.text('merchant.points.saveDraft'),
            icon: Icons.save_rounded,
            isLoading: saving,
            onPressed: () => _save(context, provider, reward),
          ),
          const SizedBox(height: AppSpacing.sm),
          MerchantSecondaryButton(
            label: texts.text('merchant.points.activate'),
            icon: Icons.rocket_launch_rounded,
            onPressed: saving ? null : () => _publish(context, provider, reward),
          ),
        ],
      ),
    );
  }

  void _hydrate(PointsRewardModel reward) {
    final key = reward.id.isEmpty ? 'new' : reward.id;
    if (_hydratedId == key) return;
    _hydratedId = key;
    // Reine State-Felder dürfen sofort.
    _rewardType = reward.rewardType;
    _rewardItemId = reward.rewardItemId;
    _persistedItemName = reward.rewardItemName;
    _imageUrl = reward.imageUrl;
    // Bestehendes Item-Reward mit Bild: als „aus Item" werten, damit ein
    // Typwechsel es aufräumt; ohne Item gilt das Bild als manuell.
    _imageFromItem = reward.rewardType == PointsRewardType.item &&
        reward.imageUrl.isNotEmpty &&
        reward.rewardItemId.isNotEmpty;
    // Controller-Inhalte erst nach dem Frame setzen (kein Schreiben in build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setIfChanged(_title, reward.title);
      _setIfChanged(_description, reward.description);
      _setIfChanged(_requiredPoints, reward.requiredPoints.toString());
      _setIfChanged(_discountText, reward.discountText);
      // Geladene/Default-Punkte gelten als unberührt, bis der Nutzer tippt –
      // nach dem (listener-auslösenden) Schreiben zurücksetzen.
      _requiredPointsPristine = true;
    });
  }

  PointsRewardModel _rewardFromForm(
    MerchantPointsProvider provider,
    PointsRewardModel existing, {
    String? forcedStatus,
  }) {
    // Bestehenden Status erhalten (paused/archived bleiben), nur beim bewussten
    // Aktivieren wird forcedStatus=active gesetzt.
    final status = forcedStatus ?? existing.status;
    final isItem = _rewardType == PointsRewardType.item;
    final item = _findItem(provider.items, _rewardItemId);
    // Name aus dem aufgelösten Item; Fallback ist der zuvor persistierte Name
    // (deckt ein zwischenzeitlich gelöschtes Katalog-Item ab).
    final itemName = isItem ? (item?.name ?? _persistedItemName) : '';
    return PointsRewardModel(
      id: existing.id,
      merchantId: provider.merchantId,
      title: _title.text,
      description: _description.text,
      rewardType: _rewardType,
      requiredPoints:
          int.tryParse(_requiredPoints.text.trim()) ?? PointsRewardModel.defaultRequiredPoints,
      rewardItemId: isItem ? item?.id ?? '' : '',
      rewardItemName: itemName,
      discountText: _rewardType == PointsRewardType.discount ? _discountText.text : '',
      // Bild für Nicht-Item-Typen nur halten, wenn es nicht aus einem Item kam.
      imageUrl: (!isItem && _imageFromItem) ? '' : _imageUrl,
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
    if (_busy) return;
    final texts = context.read<LanguageService>();
    if (!_validate(context, provider)) return;
    setState(() => _busy = true);
    try {
      final draft = _rewardFromForm(provider, existing);
      final id = await provider.saveReward(draft);
      if (!context.mounted || id == null) return;
      // Gespeicherten Datensatz mit id übernehmen, statt die Seite neu zu
      // mounten – lokaler UI-State bleibt erhalten.
      provider.adoptReward(draft.copyWith(id: id));
      _hydratedId = id;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texts.text('merchant.points.saved'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish(
    BuildContext context,
    MerchantPointsProvider provider,
    PointsRewardModel existing,
  ) async {
    if (_busy) return;
    if (!_validate(context, provider)) return;
    setState(() => _busy = true);
    try {
      final accepted = await _confirmPublish(context);
      if (accepted != true || !context.mounted) return;
      final id = await provider.publishReward(
        _rewardFromForm(provider, existing, forcedStatus: PointsStatus.active),
      );
      if (!context.mounted || id == null) return;
      context.go('/merchant/points');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validate(BuildContext context, MerchantPointsProvider provider) {
    final texts = context.read<LanguageService>();
    final points = int.tryParse(_requiredPoints.text.trim()) ?? 0;
    String? message;
    if (_title.text.trim().isEmpty) {
      message = texts.text('merchant.points.error.rewardTitle');
    } else if (_title.text.trim().length > AppLimits.pointsTitleMaxLength) {
      message = texts.text('merchant.points.error.titleTooLong');
    } else if (points <= 0) {
      message = texts.text('merchant.points.error.requiredPoints');
    } else if (points > AppLimits.pointsRequiredPointsMax) {
      message = texts.text('merchant.points.error.requiredPointsMax');
    } else if (_rewardType == PointsRewardType.item && _findItem(provider.items, _rewardItemId) == null) {
      message = texts.text('merchant.points.error.rewardItem');
    } else if (_rewardType == PointsRewardType.discount && _discountText.text.trim().isEmpty) {
      message = texts.text('merchant.points.error.discountText');
    } else if (_rewardType == PointsRewardType.discount &&
        _discountText.text.trim().length > AppLimits.pointsDiscountMaxLength) {
      message = texts.text('merchant.points.error.discountTooLong');
    } else if (_description.text.trim().length > AppLimits.pointsDescriptionMaxLength) {
      message = texts.text('merchant.points.error.descriptionTooLong');
    }
    if (message == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}

void _setIfChanged(TextEditingController controller, String value) {
  if (controller.text != value) controller.text = value;
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Tooltip(
                message: texts.text('merchant.points.rewardScaleTip'),
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 8),
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
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Container(
                        width: 126,
                        padding: const EdgeInsets.all(AppSpacing.sm + 2),
                        decoration: BoxDecoration(
                          color: MerchantPremiumColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: MerchantPremiumColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PointsRewardPreview(reward: reward),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              reward.title.trim().isEmpty
                                  ? texts.text('merchant.points.rewardUntitled')
                                  : reward.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MerchantPremiumColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs / 2),
                            Text(
                              '${reward.requiredPoints} ${texts.text('merchant.points.points')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MerchantPremiumColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  '${reward.requiredPoints} ${texts.text('merchant.points.points')}',
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w600,
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
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
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
                fontWeight: FontWeight.w700,
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
    required this.onCreateItem,
  });

  final String label;
  final List<MerchantItemData> items;
  final String value;
  final ValueChanged<MerchantItemData?> onChanged;
  final VoidCallback onCreateItem;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    if (items.isEmpty) {
      // Leere Item-Liste: keine wählbare Eingabe – stattdessen Hinweis + CTA
      // zur Artikel-Anlage, statt den Nutzer in einer toten Auswahl zu lassen.
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              texts.text('merchant.points.noItems'),
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            MerchantSecondaryButton(
              label: texts.text('merchant.points.noItemsCreate'),
              icon: Icons.add_rounded,
              onPressed: onCreateItem,
            ),
          ],
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
          fontWeight: FontWeight.w600,
        ),
      ),
      dropdownColor: MerchantPremiumColors.surfaceAlt,
      style: const TextStyle(
        color: MerchantPremiumColors.ink,
        fontWeight: FontWeight.w700,
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
  return showMerchantConfirmSheet(
    context: context,
    title: texts.text('merchant.points.activateRewardTitle'),
    message: texts.text('merchant.points.activateRewardMessage'),
    confirmLabel: texts.text('merchant.points.activate'),
    cancelLabel: texts.text('common.cancel'),
    confirmIcon: Icons.rocket_launch_rounded,
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
