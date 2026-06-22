import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/localCacheService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../../core/widgets/appImage.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../shared/widgets/merchantUiComponents.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/feedCatalogItem.dart';
import '../utils/feedFormatters.dart';
import '../providers/merchantFeedCreateProvider.dart';
import '../services/feedAiSuggestionService.dart';
import '../services/merchantFeedCreateService.dart';
import '../widgets/merchantFeedPostPreview.dart';
import '../widgets/squareImageCropSheet.dart';

enum FeedCreateKind { post, action }

class MerchantFeedCreatePage extends StatelessWidget {
  const MerchantFeedCreatePage({
    super.key,
    this.kind = FeedCreateKind.post,
  });

  final FeedCreateKind kind;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantFeedCreateProvider(
        service: MerchantFeedCreateService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
          aiSuggestionService: const FeedAiSuggestionService(),
        ),
        uploadService: context.read<UploadService>(),
        cacheService: context.read<LocalCacheService>(),
      )..load(),
      child: _MerchantFeedCreateView(kind: kind),
    );
  }
}

class _MerchantFeedCreateView extends StatefulWidget {
  const _MerchantFeedCreateView({required this.kind});

  final FeedCreateKind kind;

  @override
  State<_MerchantFeedCreateView> createState() => _MerchantFeedCreateViewState();
}

class _MerchantFeedCreateViewState extends State<_MerchantFeedCreateView> {
  final title = TextEditingController();
  final subtitle = TextEditingController();
  final description = TextEditingController();
  final ctaLabel = TextEditingController();
  final oldPrice = TextEditingController();
  final newPrice = TextEditingController();
  final externalUrl = TextEditingController();
  final linkedPostId = TextEditingController();

  int step = 0;
  late String type;
  bool hasButton = false;
  bool showPrice = false;
  bool isVisible = true;
  bool useCatalogItems = false;
  String ctaLinkType = 'none';
  String targetAudience = 'all';

  // ── Zeitsteuerung über 3 Schalter (Google-Home-Stil) ────────────────────
  // (a) Startzeit festlegen: aus = ab sofort, an = startDate wählen.
  bool useCustomStart = false;
  DateTime? startDate;
  // (b) Enddatum festlegen: aus = unbegrenzt, an = endDate wählen.
  bool useEndDate = false;
  DateTime? endDate;
  // (c) Später posten (planen): aus = sofort posten, an = scheduledAt wählen.
  bool schedulePost = false;
  DateTime? scheduledAt;

  List<FeedCatalogItem> selectedCatalogItems = const [];

  /// Auflösung der 3 Schalter auf den vom Publish-Flow erwarteten `startsAt`.
  /// "Später posten" hat Vorrang (setzt einen Zukunftsstart), sonst greift die
  /// frei gewählte Startzeit, sonst null (= ab sofort).
  DateTime? get _resolvedStartsAt {
    if (schedulePost && scheduledAt != null) return scheduledAt;
    if (useCustomStart && startDate != null) return startDate;
    return null;
  }

  DateTime? get _resolvedEndsAt => useEndDate ? endDate : null;

  @override
  void initState() {
    super.initState();
    type = _isAction ? 'offer' : 'news';
    for (final controller in [
      title,
      subtitle,
      description,
      ctaLabel,
      oldPrice,
      newPrice,
      externalUrl,
      linkedPostId,
    ]) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    title.dispose();
    subtitle.dispose();
    description.dispose();
    ctaLabel.dispose();
    oldPrice.dispose();
    newPrice.dispose();
    externalUrl.dispose();
    linkedPostId.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _isAction => widget.kind == FeedCreateKind.action;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantFeedCreateProvider>();
    final texts = context.watch<LanguageService>();
    final stepKeys = [
      'merchant.feedCreate.step.type',
      'merchant.feedCreate.step.basic',
      'merchant.feedCreate.step.rules',
      'merchant.feedCreate.step.schedule',
      'merchant.feedCreate.step.visibility',
      'merchant.feedCreate.step.preview',
    ];

    return MerchantToolScaffold(
      title: texts.text(_isAction ? 'merchant.feedCreate.actionTitle' : 'merchant.feedCreate.title'),
      subtitle: texts.text(_isAction ? 'merchant.feedCreate.actionSubtitle' : 'merchant.feedCreate.subtitle'),
      backPath: '/merchant/dashboard',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.feedCreate.tooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.error != null) ...[
            MerchantErrorState(
              message: texts.text(provider.error!),
              onRetry: provider.clearError,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _StepPills(
            step: step,
            labels: stepKeys.map(texts.text).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          _PreviewLauncher(
            onTap: () => _showPreviewDialog(context, provider),
          ),
          const SizedBox(height: AppSpacing.md),
          _stepContent(context, provider, texts),
          const SizedBox(height: AppSpacing.lg),
          _NavigationRow(
            step: step,
            isLast: step == 5,
            isSaving: provider.isSaving,
            onBack: step == 0 ? null : () => setState(() => step--),
            onNext: () => step == 5 ? _publish(context, provider, texts) : setState(() => step++),
          ),
        ],
      ),
    );
  }

  Widget _stepContent(
    BuildContext context,
    MerchantFeedCreateProvider provider,
    LanguageService texts,
  ) {
    return switch (step) {
      0 => _TypeStep(
          kind: widget.kind,
          selected: type,
          onSelected: (value) => setState(() {
            type = value;
            if (!_typeSupportsCatalogItems(value)) {
              useCatalogItems = false;
              selectedCatalogItems = const [];
            }
          }),
        ),
      1 => _BasicStep(
          title: title,
          subtitle: subtitle,
          description: description,
          canCorrect: provider.canCorrect,
          correctionsToday: provider.aiCorrectionsToday,
          correctionLimit: MerchantFeedCreateProvider.aiCorrectionLimit,
          isCorrecting: provider.isCorrecting,
          imageUrl: provider.imageUrl,
          onUpload: () => _pickCropAndUpload(context, provider),
          onCorrect: () => _applyAiCorrection(context, provider),
        ),
      2 => _RulesStep(
          isAction: _isAction,
          type: type,
          hasButton: hasButton,
          showPrice: showPrice,
          useCatalogItems: useCatalogItems,
          catalogItems: provider.catalogItems,
          selectedItems: selectedCatalogItems,
          ctaLabel: ctaLabel,
          oldPrice: oldPrice,
          newPrice: newPrice,
          ctaLinkType: ctaLinkType,
          externalUrl: externalUrl,
          linkedPostId: linkedPostId,
          onButtonChanged: (value) => setState(() => hasButton = value),
          onPriceChanged: (value) => setState(() => showPrice = value),
          onCatalogItemsChanged: (value) => setState(() {
            useCatalogItems = value;
            if (!value) selectedCatalogItems = const [];
          }),
          onSelectCatalogItems: () => _selectCatalogItems(provider),
          onApplyCatalogItems: () => _applyCatalogItems(provider),
          onUseCatalogImage: () => _confirmUseCatalogImage(provider),
          onCtaLabelPreset: (value) => setState(() {
            hasButton = true;
            ctaLabel.text = value;
          }),
          onLinkTypeChanged: (value) => setState(() {
            hasButton = value != 'none';
            ctaLinkType = value;
          }),
        ),
      3 => _ScheduleStep(
          useCustomStart: useCustomStart,
          startDate: startDate,
          useEndDate: useEndDate,
          endDate: endDate,
          schedulePost: schedulePost,
          scheduledAt: scheduledAt,
          onToggleCustomStart: (value) async {
            if (!value) {
              setState(() {
                useCustomStart = false;
                startDate = null;
              });
              return;
            }
            final picked = await _pickDateTime(initial: startDate);
            if (picked == null) return;
            setState(() {
              useCustomStart = true;
              startDate = picked;
            });
          },
          onEditStart: () async {
            final picked = await _pickDateTime(initial: startDate);
            if (picked == null) return;
            setState(() {
              useCustomStart = true;
              startDate = picked;
            });
          },
          onToggleEndDate: (value) async {
            if (!value) {
              setState(() {
                useEndDate = false;
                endDate = null;
              });
              return;
            }
            final picked = await _pickDateTime(initial: endDate ?? startDate);
            if (picked == null) return;
            setState(() {
              useEndDate = true;
              endDate = picked;
            });
          },
          onEditEnd: () async {
            final picked = await _pickDateTime(initial: endDate ?? startDate);
            if (picked == null) return;
            setState(() {
              useEndDate = true;
              endDate = picked;
            });
          },
          onToggleSchedule: (value) async {
            if (!value) {
              setState(() {
                schedulePost = false;
                scheduledAt = null;
              });
              return;
            }
            final picked = await _pickDateTime(initial: scheduledAt, firstDate: DateTime.now());
            if (picked == null) return;
            setState(() {
              schedulePost = true;
              scheduledAt = picked;
            });
          },
          onEditSchedule: () async {
            final picked = await _pickDateTime(initial: scheduledAt, firstDate: DateTime.now());
            if (picked == null) return;
            setState(() {
              schedulePost = true;
              scheduledAt = picked;
            });
          },
        ),
      4 => _VisibilityStep(
          isVisible: isVisible,
          targetAudience: targetAudience,
          onChanged: (value) => setState(() => isVisible = value),
          onAudienceChanged: (value) => setState(() => targetAudience = value),
        ),
      _ => _ConfirmStep(
          type: type,
          isVisible: isVisible,
          selectedItems: selectedCatalogItems,
          startsAt: _resolvedStartsAt,
          endsAt: _resolvedEndsAt,
          isScheduled: schedulePost &&
              scheduledAt != null &&
              scheduledAt!.isAfter(DateTime.now()),
          hasButton: hasButton,
          ctaLabel: ctaLabel.text,
          ctaLinkType: ctaLinkType,
          targetAudience: targetAudience,
          showPrice: showPrice,
          oldPrice: oldPrice.text,
          newPrice: newPrice.text,
        ),
    };
  }

  Future<void> _applyAiCorrection(
    BuildContext context,
    MerchantFeedCreateProvider provider,
  ) async {
    final texts = context.read<LanguageService>();
    final messenger = ScaffoldMessenger.of(context);
    final corrected = await provider.correctFields(
      type: type,
      title: title.text,
      subtitle: subtitle.text,
      description: description.text,
    );
    if (!mounted) return;
    if (corrected == null) {
      // Graceful: dezenter Hinweis, Felder bleiben unverändert.
      final hint = provider.aiHint;
      if (hint != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(_correctHintText(texts, hint))),
        );
        provider.clearAiHint();
      }
      return;
    }
    setState(() {
      // Nur die drei Basisfelder ersetzen – Inhalt bleibt, nur korrigiert.
      title.text = corrected.title.trim().isEmpty ? title.text : corrected.title;
      subtitle.text =
          corrected.subtitle.trim().isEmpty ? subtitle.text : corrected.subtitle;
      description.text = corrected.description.trim().isEmpty
          ? description.text
          : corrected.description;
    });
    messenger.showSnackBar(
      SnackBar(content: Text(_correctHintText(texts, 'merchant.feedCreate.aiCorrect.done'))),
    );
  }

  Future<void> _pickCropAndUpload(
    BuildContext context,
    MerchantFeedCreateProvider provider,
  ) async {
    final file = await provider.pickFeedImage();
    if (file == null || !context.mounted) return;
    final cropped = await showSquareImageCropSheet(
      context: context,
      imageBytes: file.bytes,
    );
    if (cropped == null) return;
    await provider.uploadCroppedFeedImage(
      bytes: cropped,
      fileName: file.fileName,
    );
  }

  Future<void> _selectCatalogItems(MerchantFeedCreateProvider provider) async {
    final selected = await showCatalogItemPickerDialog(
      context: context,
      items: provider.catalogItems,
      initialSelection: selectedCatalogItems,
      type: type,
    );
    if (selected == null || !mounted) return;
    setState(() {
      selectedCatalogItems = selected;
      useCatalogItems = selectedCatalogItems.isNotEmpty;
    });
  }

  Future<void> _applyCatalogItems(MerchantFeedCreateProvider provider) async {
    if (selectedCatalogItems.isEmpty) return;
    final texts = context.read<LanguageService>();
    final shouldOverwrite = title.text.trim().isNotEmpty ||
        subtitle.text.trim().isNotEmpty ||
        description.text.trim().isNotEmpty ||
        oldPrice.text.trim().isNotEmpty ||
        newPrice.text.trim().isNotEmpty;
    final confirmed = !shouldOverwrite ||
        await _confirmDialog(
          context,
          title: texts.text('merchant.feedCreate.items.applyTitle'),
          message: texts.text('merchant.feedCreate.items.applyMessage'),
          confirmLabel: texts.text('merchant.feedCreate.items.apply'),
        );
    if (!confirmed || !mounted) return;

    final first = selectedCatalogItems.first;
    setState(() {
      title.text = _catalogTitle(texts, type, selectedCatalogItems);
      subtitle.text = _catalogSubtitle(texts, selectedCatalogItems);
      description.text = _catalogDescription(selectedCatalogItems);
      if (_isAction && first.price > 0) {
        showPrice = true;
        newPrice.text = _priceInput(first.price);
        if (first.originalPrice != null && first.originalPrice! > first.price) {
          oldPrice.text = _priceInput(first.originalPrice!);
        }
      }
    });
  }

  Future<void> _confirmUseCatalogImage(MerchantFeedCreateProvider provider) async {
    final image = _firstCatalogImage(selectedCatalogItems);
    if (image.isEmpty) return;
    final texts = context.read<LanguageService>();
    final confirmed = await _confirmDialog(
      context,
      title: texts.text('merchant.feedCreate.items.imageTitle'),
      message: texts.text('merchant.feedCreate.items.imageMessage'),
      confirmLabel: texts.text('merchant.feedCreate.items.imageUse'),
    );
    if (!confirmed) return;
    provider.useCatalogImage(image);
  }

  Future<void> _showPreviewDialog(
    BuildContext context,
    MerchantFeedCreateProvider provider,
  ) async {
    final texts = context.read<LanguageService>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
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
                        texts.text('merchant.feedCreate.previewDialogTitle'),
                        style: const TextStyle(
                          color: MerchantPremiumColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(
                  child: SingleChildScrollView(
                    child: MerchantFeedPostPreview(
                      type: type,
                      merchantName: provider.merchantName,
                      merchantLogoUrl: provider.merchantLogoUrl,
                      merchantCity: provider.merchantCity,
                      merchantShopType: provider.merchantShopType,
                      ratingText: provider.merchantRatingText,
                      title: title.text,
                      subtitle: subtitle.text,
                      imageUrl: provider.imageUrl,
                      oldPrice: showPrice ? oldPrice.text : '',
                      newPrice: showPrice ? newPrice.text : '',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Datum + Uhrzeit wählen. Liefert null bei Abbruch (Schalter bleibt dann
  /// in seinem vorherigen Zustand – der Aufrufer entscheidet).
  Future<DateTime?> _pickDateTime({DateTime? initial, DateTime? firstDate}) async {
    final now = DateTime.now();
    final base = initial ?? now;
    final lowerBound = firstDate ?? DateTime(now.year - 1);
    final initialDate = base.isBefore(lowerBound) ? lowerBound : base;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: lowerBound,
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    return DateTime(
      picked.year,
      picked.month,
      picked.day,
      time?.hour ?? 9,
      time?.minute ?? 0,
    );
  }

  Future<void> _publish(
    BuildContext context,
    MerchantFeedCreateProvider provider,
    LanguageService texts,
  ) async {
    if (hasButton && ctaLabel.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texts.text('merchant.feedCreate.error.ctaLabel'))),
      );
      return;
    }
    if (hasButton && ctaLinkType == 'external' && externalUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texts.text('merchant.feedCreate.error.externalUrl'))),
      );
      return;
    }
    // Geplante Zeit muss in der Zukunft liegen, sonst würde der Service sofort
    // posten, obwohl „Später posten" an ist (#15).
    if (schedulePost &&
        scheduledAt != null &&
        !scheduledAt!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texts.text('merchant.feedCreate.error.scheduleInPast'))),
      );
      return;
    }
    final ok = await provider.createPost(
      type: type,
      title: title.text,
      subtitle: subtitle.text,
      description: description.text,
      requiredMessage: texts.text('merchant.feedCreate.required'),
      ctaLabel: hasButton ? ctaLabel.text : '',
      ctaType: hasButton ? 'primary' : '',
      ctaLinkType: hasButton ? ctaLinkType : '',
      ctaTargetId: _ctaTargetId(),
      ctaUrl: ctaLinkType == 'external' ? externalUrl.text : '',
      targetAudience: targetAudience,
      rules: {
        if (_isAction && showPrice) 'oldPrice': feedParseNumber(oldPrice.text),
        if (_isAction && showPrice) 'newPrice': feedParseNumber(newPrice.text),
        if (_isAction && showPrice) 'discountPercent': feedDiscountPercent(oldPrice.text, newPrice.text),
        if (useCatalogItems && selectedCatalogItems.isNotEmpty) 'itemSource': 'catalog',
        if (useCatalogItems && selectedCatalogItems.isNotEmpty) 'linkedItemIds': selectedCatalogItems.map((item) => item.id).toList(),
        if (useCatalogItems && selectedCatalogItems.isNotEmpty) 'linkedItems': selectedCatalogItems.map((item) => item.toRuleMap()).toList(),
      }..removeWhere((_, value) => value == null),
      startsAt: _resolvedStartsAt,
      endsAt: _resolvedEndsAt,
      isPrivate: !isVisible,
    );
    if (ok && context.mounted) context.go('/merchant/feed/manage');
  }

  String _ctaTargetId() {
    return switch (ctaLinkType) {
      'shop' => 'shop',
      'catalog' => 'catalog',
      'feedPost' => linkedPostId.text,
      _ => '',
    };
  }
}

class _TypeStep extends StatelessWidget {
  const _TypeStep({
    required this.kind,
    required this.selected,
    required this.onSelected,
  });

  final FeedCreateKind kind;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.type'),
      tooltip: texts.text('merchant.feedCreate.step.typeTip'),
      child: MerchantDashboardGrid(
        children: _typeOptions(kind)
            .map(
              (option) => MerchantActionCard(
                title: texts.text(option.titleKey),
                subtitle: texts.text(option.subtitleKey),
                icon: option.icon,
                isDark: selected == option.key,
                onTap: () => onSelected(option.key),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BasicStep extends StatelessWidget {
  const _BasicStep({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.canCorrect,
    required this.correctionsToday,
    required this.correctionLimit,
    required this.isCorrecting,
    required this.imageUrl,
    required this.onUpload,
    required this.onCorrect,
  });

  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController description;
  final bool canCorrect;
  final int correctionsToday;
  final int correctionLimit;
  final bool isCorrecting;
  final String imageUrl;
  final VoidCallback onUpload;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.basic'),
      tooltip: texts.text('merchant.feedCreate.step.basicTip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantTextField(controller: title, label: texts.text('merchant.feedCreate.postTitle')),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(controller: subtitle, label: texts.text('merchant.feedCreate.postSubtitle')),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: description,
            label: texts.text('merchant.feedCreate.description'),
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Dezente, unaufdringliche KI-Korrektur direkt neben den Feldern.
          _AiCorrectAction(
            canCorrect: canCorrect,
            isCorrecting: isCorrecting,
            correctionsToday: correctionsToday,
            correctionLimit: correctionLimit,
            onCorrect: onCorrect,
          ),
          const SizedBox(height: AppSpacing.md),
          _ImagePickerCard(imageUrl: imageUrl, onTap: onUpload),
        ],
      ),
    );
  }
}

/// Kleiner, unaufdringlicher „KI verbessern"-Button unter den Basisfeldern.
/// Kein großes Panel – nur eine dezente Zeile (Google-Home-Ruhe).
class _AiCorrectAction extends StatelessWidget {
  const _AiCorrectAction({
    required this.canCorrect,
    required this.isCorrecting,
    required this.correctionsToday,
    required this.correctionLimit,
    required this.onCorrect,
  });

  final bool canCorrect;
  final bool isCorrecting;
  final int correctionsToday;
  final int correctionLimit;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final disabled = !canCorrect || isCorrecting;
    final remaining = (correctionLimit - correctionsToday).clamp(0, correctionLimit);
    final label = canCorrect
        ? _t(texts, 'merchant.feedCreate.aiCorrect.action', 'KI verbessern')
        : _t(texts, 'merchant.feedCreate.aiCorrect.limit',
            '$correctionsToday/$correctionLimit heute genutzt');
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: disabled ? null : onCorrect,
            icon: isCorrecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MerchantPremiumColors.gold,
                    ),
                  )
                : const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: Text(label),
            style: TextButton.styleFrom(
              foregroundColor:
                  canCorrect ? MerchantPremiumColors.gold : MerchantPremiumColors.muted,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (canCorrect)
            Text(
              '$remaining/$correctionLimit',
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _RulesStep extends StatelessWidget {
  const _RulesStep({
    required this.isAction,
    required this.type,
    required this.hasButton,
    required this.showPrice,
    required this.useCatalogItems,
    required this.catalogItems,
    required this.selectedItems,
    required this.ctaLabel,
    required this.oldPrice,
    required this.newPrice,
    required this.ctaLinkType,
    required this.externalUrl,
    required this.linkedPostId,
    required this.onButtonChanged,
    required this.onPriceChanged,
    required this.onCatalogItemsChanged,
    required this.onSelectCatalogItems,
    required this.onApplyCatalogItems,
    required this.onUseCatalogImage,
    required this.onCtaLabelPreset,
    required this.onLinkTypeChanged,
  });

  final bool isAction;
  final String type;
  final bool hasButton;
  final bool showPrice;
  final bool useCatalogItems;
  final List<FeedCatalogItem> catalogItems;
  final List<FeedCatalogItem> selectedItems;
  final TextEditingController ctaLabel;
  final TextEditingController oldPrice;
  final TextEditingController newPrice;
  final String ctaLinkType;
  final TextEditingController externalUrl;
  final TextEditingController linkedPostId;
  final ValueChanged<bool> onButtonChanged;
  final ValueChanged<bool> onPriceChanged;
  final ValueChanged<bool> onCatalogItemsChanged;
  final VoidCallback onSelectCatalogItems;
  final VoidCallback onApplyCatalogItems;
  final VoidCallback onUseCatalogImage;
  final ValueChanged<String> onCtaLabelPreset;
  final ValueChanged<String> onLinkTypeChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.rules'),
      tooltip: texts.text('merchant.feedCreate.step.rulesTip'),
      child: Column(
        children: [
          if (isAction) ...[
            if (_typeSupportsCatalogItems(type)) ...[
              SwitchListTile(
                value: useCatalogItems,
                onChanged: onCatalogItemsChanged,
                title: Text(texts.text('merchant.feedCreate.items.useCatalog')),
                subtitle: Text(texts.text('merchant.feedCreate.items.useCatalogTip')),
                contentPadding: EdgeInsets.zero,
              ),
              if (useCatalogItems) ...[
                const SizedBox(height: AppSpacing.sm),
                _CatalogItemLinkCard(
                  type: type,
                  catalogItems: catalogItems,
                  selectedItems: selectedItems,
                  onSelect: onSelectCatalogItems,
                  onApply: onApplyCatalogItems,
                  onUseImage: onUseCatalogImage,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
            SwitchListTile(
              value: showPrice,
              onChanged: onPriceChanged,
              title: Text(texts.text('merchant.feedCreate.showPrice')),
              subtitle: Text(texts.text('merchant.feedCreate.showPriceTip')),
              contentPadding: EdgeInsets.zero,
            ),
            if (showPrice) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: MerchantTextField(
                      controller: oldPrice,
                      label: texts.text('merchant.feedCreate.oldPrice'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MerchantTextField(
                      controller: newPrice,
                      label: texts.text('merchant.feedCreate.newPrice'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (!isAction)
            MerchantPremiumCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: MerchantPremiumColors.surfaceAlt,
              child: Row(
                children: [
                  const MerchantPremiumIconBox(icon: Icons.info_outline_rounded, size: 42),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      texts.text('merchant.feedCreate.postRulesHint'),
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!isAction) const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            value: hasButton,
            onChanged: onButtonChanged,
            title: Text(texts.text('merchant.feedCreate.hasButton')),
            subtitle: Text(texts.text('merchant.feedCreate.hasButtonTip')),
            contentPadding: EdgeInsets.zero,
          ),
          if (hasButton) ...[
            const SizedBox(height: AppSpacing.sm),
            _PresetChips(
              values: _ctaPresets.map((key) => texts.text(key)).toList(),
              onSelected: onCtaLabelPreset,
            ),
            const SizedBox(height: AppSpacing.sm),
            MerchantTextField(
              controller: ctaLabel,
              label: texts.text('merchant.feedCreate.ctaLabel'),
            ),
            const SizedBox(height: AppSpacing.md),
            _LinkTypePicker(
              selected: ctaLinkType,
              onSelected: onLinkTypeChanged,
            ),
            if (ctaLinkType == 'external') ...[
              const SizedBox(height: AppSpacing.sm),
              MerchantTextField(
                controller: externalUrl,
                label: texts.text('merchant.feedCreate.externalUrl'),
                keyboardType: TextInputType.url,
              ),
            ],
            if (ctaLinkType == 'feedPost') ...[
              const SizedBox(height: AppSpacing.sm),
              MerchantTextField(
                controller: linkedPostId,
                label: texts.text('merchant.feedCreate.linkedPostId'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CatalogItemLinkCard extends StatelessWidget {
  const _CatalogItemLinkCard({
    required this.type,
    required this.catalogItems,
    required this.selectedItems,
    required this.onSelect,
    required this.onApply,
    required this.onUseImage,
  });

  final String type;
  final List<FeedCatalogItem> catalogItems;
  final List<FeedCatalogItem> selectedItems;
  final VoidCallback onSelect;
  final VoidCallback onApply;
  final VoidCallback onUseImage;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final target = _catalogItemTargetCount(type);
    final imageAvailable = _firstCatalogImage(selectedItems).isNotEmpty;
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: MerchantPremiumColors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MerchantPremiumIconBox(icon: Icons.restaurant_menu_rounded, size: 44),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  selectedItems.isEmpty
                      ? texts.text('merchant.feedCreate.items.emptySelection')
                      : _selectedCatalogSummary(selectedItems),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              if (target != null)
                MerchantPremiumPill(
                  label: '${selectedItems.length}/$target',
                  background: MerchantPremiumColors.goldSoft,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantPrimaryButton(
            label: catalogItems.isEmpty
                ? texts.text('merchant.feedCreate.items.none')
                : texts.text('merchant.feedCreate.items.select'),
            icon: Icons.add_rounded,
            onPressed: catalogItems.isEmpty ? null : onSelect,
          ),
          if (selectedItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.content_paste_go_rounded),
              label: Text(texts.text('merchant.feedCreate.items.apply')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
            if (imageAvailable) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: onUseImage,
                icon: const Icon(Icons.image_rounded),
                label: Text(texts.text('merchant.feedCreate.items.imageUse')),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

Future<List<FeedCatalogItem>?> showCatalogItemPickerDialog({
  required BuildContext context,
  required List<FeedCatalogItem> items,
  required List<FeedCatalogItem> initialSelection,
  required String type,
}) {
  final texts = context.read<LanguageService>();
  final target = _catalogItemTargetCount(type);
  final categories = items
      .map((item) => item.categoryName.trim())
      .where((category) => category.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  var selected = List<FeedCatalogItem>.from(initialSelection);
  var query = '';
  String? category;

  return showDialog<List<FeedCatalogItem>>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = items.where((item) {
            final search = '${item.displayName} ${item.categoryName} ${item.description}'.toLowerCase();
            final queryMatch = query.trim().isEmpty || search.contains(query.trim().toLowerCase());
            final categoryMatch = category == null || item.categoryName == category;
            return queryMatch && categoryMatch;
          }).toList();
          final selectionReady = selected.isNotEmpty && (target == null || selected.length == target);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
              child: MerchantPremiumCard(
                radius: 34,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            texts.text('merchant.feedCreate.items.dialogTitle'),
                            style: const TextStyle(
                              color: MerchantPremiumColors.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        MerchantPremiumPill(
                          label: target == null ? '${selected.length}' : '${selected.length}/$target',
                          background: MerchantPremiumColors.goldSoft,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      onChanged: (value) => setDialogState(() => query = value),
                      decoration: merchantPremiumInputDecoration(
                        label: texts.text('merchant.feedCreate.items.search'),
                      ),
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(texts.text('common.all')),
                                selected: category == null,
                                onSelected: (_) => setDialogState(() => category = null),
                              ),
                            ),
                            ...categories.map(
                              (value) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(value),
                                  selected: category == value,
                                  onSelected: (_) => setDialogState(() => category = value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                texts.text('merchant.feedCreate.items.noResults'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: MerchantPremiumColors.muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final count = selected.where((selectedItem) => selectedItem.id == item.id).length;
                                final canAdd = target == null || selected.length < target;
                                return _CatalogPickerRow(
                                  item: item,
                                  count: count,
                                  canAdd: canAdd,
                                  onAdd: () => setDialogState(() => selected = [...selected, item]),
                                  onRemove: count == 0
                                      ? null
                                      : () => setDialogState(() {
                                            final next = List<FeedCatalogItem>.from(selected);
                                            final removeIndex = next.indexWhere((selectedItem) => selectedItem.id == item.id);
                                            if (removeIndex >= 0) next.removeAt(removeIndex);
                                            selected = next;
                                          }),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(texts.text('common.cancel')),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: MerchantPrimaryButton(
                            label: texts.text('common.apply'),
                            icon: Icons.check_rounded,
                            onPressed: selectionReady ? () => Navigator.of(dialogContext).pop(selected) : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _CatalogPickerRow extends StatelessWidget {
  const _CatalogPickerRow({
    required this.item,
    required this.count,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  final FeedCatalogItem item;
  final int count;
  final bool canAdd;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final price = _priceInput(item.price);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 52,
              height: 52,
              child: item.imageUrl.isEmpty
                  ? const ColoredBox(
                      color: MerchantPremiumColors.goldSoft,
                      child: Icon(Icons.restaurant_rounded, color: MerchantPremiumColors.ink),
                    )
                  : AppImage(
                      imageUrl: item.imageUrl,
                      errorWidget: const ColoredBox(
                        color: MerchantPremiumColors.goldSoft,
                        child: Icon(Icons.restaurant_rounded, color: MerchantPremiumColors.ink),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (item.categoryName.isNotEmpty) item.categoryName,
                    if (price.isNotEmpty) '$price ${texts.text('common.euro')}',
                  ].join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (item.isPrivate)
                      MerchantPremiumPill(
                        label: texts.text('common.private'),
                        background: MerchantPremiumColors.warningSoft,
                        foreground: MerchantPremiumColors.warning,
                      ),
                    if (!item.isAvailable)
                      MerchantPremiumPill(
                        label: texts.text('merchant.feedCreate.items.unavailable'),
                        background: MerchantPremiumColors.dangerSoft,
                        foreground: MerchantPremiumColors.danger,
                      ),
                    if (!item.isActive)
                      MerchantPremiumPill(
                        label: texts.text('merchant.feedCreate.items.inactive'),
                        background: MerchantPremiumColors.surface,
                        foreground: MerchantPremiumColors.muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          Text(
            count.toString(),
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            onPressed: canAdd ? onAdd : null,
            icon: const Icon(Icons.add_circle_rounded),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({
    required this.useCustomStart,
    required this.startDate,
    required this.useEndDate,
    required this.endDate,
    required this.schedulePost,
    required this.scheduledAt,
    required this.onToggleCustomStart,
    required this.onEditStart,
    required this.onToggleEndDate,
    required this.onEditEnd,
    required this.onToggleSchedule,
    required this.onEditSchedule,
  });

  final bool useCustomStart;
  final DateTime? startDate;
  final bool useEndDate;
  final DateTime? endDate;
  final bool schedulePost;
  final DateTime? scheduledAt;
  final ValueChanged<bool> onToggleCustomStart;
  final VoidCallback onEditStart;
  final ValueChanged<bool> onToggleEndDate;
  final VoidCallback onEditEnd;
  final ValueChanged<bool> onToggleSchedule;
  final VoidCallback onEditSchedule;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.schedule'),
      tooltip: texts.text('merchant.feedCreate.step.scheduleTip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // (a) Startzeit festlegen.
          _ScheduleSwitchTile(
            icon: Icons.play_circle_outline_rounded,
            title: _t(texts, 'merchant.feedCreate.time.startTitle', 'Startzeit festlegen'),
            offHint: _t(texts, 'merchant.feedCreate.time.startOff', 'Ab sofort sichtbar'),
            value: useCustomStart,
            onChanged: onToggleCustomStart,
            detail: useCustomStart
                ? _DateLine(
                    title: texts.text('merchant.feedCreate.startsAt'),
                    value: _dateText(texts, startDate),
                    onTap: onEditStart,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          // (b) Enddatum festlegen.
          _ScheduleSwitchTile(
            icon: Icons.event_busy_rounded,
            title: _t(texts, 'merchant.feedCreate.time.endTitle', 'Enddatum festlegen'),
            offHint: _t(texts, 'merchant.feedCreate.time.endOff', 'Läuft unbegrenzt'),
            value: useEndDate,
            onChanged: onToggleEndDate,
            detail: useEndDate
                ? _DateLine(
                    title: texts.text('merchant.feedCreate.endsAt'),
                    value: _dateText(texts, endDate),
                    onTap: onEditEnd,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          // (c) Später posten (planen).
          _ScheduleSwitchTile(
            icon: Icons.schedule_send_rounded,
            title: _t(texts, 'merchant.feedCreate.time.scheduleTitle', 'Später posten (planen)'),
            offHint: _t(texts, 'merchant.feedCreate.time.scheduleOff', 'Sofort posten'),
            value: schedulePost,
            onChanged: onToggleSchedule,
            detail: schedulePost
                ? _DateLine(
                    title: _t(texts, 'merchant.feedCreate.time.scheduleAt', 'Geplant für'),
                    value: _dateText(texts, scheduledAt),
                    onTap: onEditSchedule,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// Ruhige Google-Home-Switch-Karte: großer Titel, weicher Hinweis im Aus-Zustand,
/// optionaler Detail-Block (Datum) wenn an.
class _ScheduleSwitchTile extends StatelessWidget {
  const _ScheduleSwitchTile({
    required this.icon,
    required this.title,
    required this.offHint,
    required this.value,
    required this.onChanged,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String offHint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: MerchantPremiumColors.surfaceAlt,
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MerchantPremiumIconBox(icon: icon, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (!value) ...[
                      const SizedBox(height: 3),
                      Text(
                        offHint,
                        style: const TextStyle(
                          color: MerchantPremiumColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: MerchantPremiumColors.gold,
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.md),
            detail!,
          ],
        ],
      ),
    );
  }
}

class _PresetChips extends StatelessWidget {
  const _PresetChips({
    required this.values,
    required this.onSelected,
  });

  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => ActionChip(
              label: Text(value),
              onPressed: () => onSelected(value),
              backgroundColor: MerchantPremiumColors.surfaceAlt,
              side: const BorderSide(color: MerchantPremiumColors.line),
              labelStyle: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LinkTypePicker extends StatelessWidget {
  const _LinkTypePicker({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return _SegmentWrap(
      options: const ['none', 'external', 'shop', 'catalog', 'feedPost'],
      selected: selected,
      label: (value) => texts.text('merchant.feedCreate.link.$value'),
      onSelected: onSelected,
    );
  }
}

class _AudiencePicker extends StatelessWidget {
  const _AudiencePicker({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return _SegmentWrap(
      options: const ['all', 'regulars'],
      selected: selected,
      label: (value) => texts.text('merchant.feedCreate.audience.$value'),
      onSelected: onSelected,
    );
  }
}

class _SegmentWrap extends StatelessWidget {
  const _SegmentWrap({
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final String Function(String) label;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (value) => ChoiceChip(
              label: Text(label(value)),
              selected: selected == value,
              onSelected: (_) => onSelected(value),
              selectedColor: MerchantPremiumColors.ink,
              backgroundColor: MerchantPremiumColors.surfaceAlt,
              labelStyle: TextStyle(
                color: selected == value ? Colors.white : MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
              ),
              side: const BorderSide(color: MerchantPremiumColors.line),
            ),
          )
          .toList(),
    );
  }
}

class _VisibilityStep extends StatelessWidget {
  const _VisibilityStep({
    required this.isVisible,
    required this.targetAudience,
    required this.onChanged,
    required this.onAudienceChanged,
  });

  final bool isVisible;
  final String targetAudience;
  final ValueChanged<bool> onChanged;
  final ValueChanged<String> onAudienceChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.visibility'),
      tooltip: texts.text('merchant.feedCreate.step.visibilityTip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AudiencePicker(
            selected: targetAudience,
            onSelected: onAudienceChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            value: isVisible,
            onChanged: onChanged,
            title: Text(texts.text('merchant.feedCreate.publicVisible')),
            subtitle: Text(texts.text('merchant.feedCreate.publicVisibleTip')),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.type,
    required this.isVisible,
    required this.selectedItems,
    required this.startsAt,
    required this.endsAt,
    required this.isScheduled,
    required this.hasButton,
    required this.ctaLabel,
    required this.ctaLinkType,
    required this.targetAudience,
    required this.showPrice,
    required this.oldPrice,
    required this.newPrice,
  });

  final String type;
  final bool isVisible;
  final List<FeedCatalogItem> selectedItems;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isScheduled;
  final bool hasButton;
  final String ctaLabel;
  final String ctaLinkType;
  final String targetAudience;
  final bool showPrice;
  final String oldPrice;
  final String newPrice;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.preview'),
      tooltip: texts.text('merchant.feedCreate.step.previewTip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(label: texts.text('merchant.feedCreate.type'), value: texts.text('feed.type.$type')),
          _SummaryRow(label: texts.text('merchant.feedCreate.visibility'), value: isVisible ? texts.text('common.public') : texts.text('common.private')),
          if (selectedItems.isNotEmpty) _SummaryRow(label: texts.text('merchant.feedCreate.items.select'), value: _selectedCatalogSummary(selectedItems)),
          _SummaryRow(label: texts.text('merchant.feedCreate.targetAudience'), value: texts.text('merchant.feedCreate.audience.$targetAudience')),
          _SummaryRow(
            label: texts.text('merchant.feedCreate.startsAt'),
            value: startsAt == null
                ? _t(texts, 'merchant.feedCreate.time.startOff', 'Ab sofort sichtbar')
                : _dateText(texts, startsAt),
          ),
          if (isScheduled)
            _SummaryRow(
              label: _t(texts, 'merchant.feedCreate.time.scheduleAt', 'Geplant für'),
              value: _dateText(texts, startsAt),
            ),
          _SummaryRow(
            label: texts.text('merchant.feedCreate.endsAt'),
            value: endsAt == null
                ? _t(texts, 'merchant.feedCreate.time.endOff', 'Läuft unbegrenzt')
                : _dateText(texts, endsAt),
          ),
          if (showPrice) _SummaryRow(label: texts.text('merchant.feedCreate.oldPrice'), value: oldPrice),
          if (showPrice) _SummaryRow(label: texts.text('merchant.feedCreate.newPrice'), value: newPrice),
          if (hasButton) _SummaryRow(label: texts.text('merchant.feedCreate.ctaLabel'), value: ctaLabel),
          if (hasButton) _SummaryRow(label: texts.text('merchant.feedCreate.linkType'), value: texts.text('merchant.feedCreate.link.$ctaLinkType')),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: MerchantPremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: AppRadius.large,
        child: Row(
          children: [
            const MerchantPremiumIconBox(icon: Icons.visibility_rounded, size: 44),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                texts.text('merchant.feedCreate.previewOpen'),
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.open_in_full_rounded, color: MerchantPremiumColors.ink, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.imageUrl,
    required this.onTap,
  });

  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded, size: 38, color: MerchantPremiumColors.ink),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    texts.text('merchant.feedCreate.image'),
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              )
            : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
      ),
    );
  }
}

class _StepPills extends StatelessWidget {
  const _StepPills({
    required this.step,
    required this.labels,
  });

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == step;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? MerchantPremiumColors.surface : MerchantPremiumColors.baseSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? MerchantPremiumColors.gold : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: selected ? MerchantPremiumColors.ink : MerchantPremiumColors.mutedLight,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }),
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
        Expanded(
          child: OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Text(texts.text('common.back')),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MerchantPrimaryButton(
            label: isLast ? texts.text('merchant.feedCreate.publish') : texts.text('auth.continue'),
            icon: isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
            isLoading: isSaving,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

class _DateLine extends StatelessWidget {
  const _DateLine({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: MerchantPremiumColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.calendar_month_rounded, color: MerchantPremiumColors.ink),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: MerchantPremiumColors.muted))),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ActionTypeOption {
  const _ActionTypeOption({
    required this.key,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
  });

  final String key;
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
}

List<_ActionTypeOption> _typeOptions(FeedCreateKind kind) {
  return switch (kind) {
    FeedCreateKind.action => _actionTypes,
    FeedCreateKind.post => _postTypes,
  };
}

const _postTypes = [
  _ActionTypeOption(key: 'news', titleKey: 'feed.type.news', subtitleKey: 'merchant.feedCreate.type.newsTip', icon: Icons.article_rounded),
  _ActionTypeOption(key: 'newProduct', titleKey: 'feed.type.newProduct', subtitleKey: 'merchant.feedCreate.type.newProductTip', icon: Icons.fiber_new_rounded),
  _ActionTypeOption(key: 'info', titleKey: 'feed.type.info', subtitleKey: 'merchant.feedCreate.type.infoTip', icon: Icons.info_rounded),
  _ActionTypeOption(key: 'communityEvent', titleKey: 'feed.type.communityEvent', subtitleKey: 'merchant.feedCreate.type.communityEventTip', icon: Icons.celebration_rounded),
  _ActionTypeOption(key: 'hiring', titleKey: 'feed.type.hiring', subtitleKey: 'merchant.feedCreate.type.hiringTip', icon: Icons.group_add_rounded),
];

const _actionTypes = [
  _ActionTypeOption(key: 'offer', titleKey: 'feed.type.offer', subtitleKey: 'merchant.feedCreate.type.offerTip', icon: Icons.local_offer_rounded),
  _ActionTypeOption(key: 'categoryDiscountPercent', titleKey: 'feed.type.categoryDiscountPercent', subtitleKey: 'merchant.feedCreate.type.categoryDiscountPercentTip', icon: Icons.percent_rounded),
  _ActionTypeOption(key: 'happyHour', titleKey: 'feed.type.happyHour', subtitleKey: 'merchant.feedCreate.type.happyHourTip', icon: Icons.schedule_rounded),
  _ActionTypeOption(key: 'onePlusOneFree', titleKey: 'feed.type.onePlusOneFree', subtitleKey: 'merchant.feedCreate.type.onePlusOneFreeTip', icon: Icons.exposure_plus_1_rounded),
  _ActionTypeOption(key: 'twoPlusOneFree', titleKey: 'feed.type.twoPlusOneFree', subtitleKey: 'merchant.feedCreate.type.twoPlusOneFreeTip', icon: Icons.filter_3_rounded),
  _ActionTypeOption(key: 'rescueMe', titleKey: 'feed.type.rescueMe', subtitleKey: 'merchant.feedCreate.type.rescueMeTip', icon: Icons.volunteer_activism_rounded),
];

const _ctaPresets = [
  'merchant.feedCreate.cta.more',
  'merchant.feedCreate.cta.secure',
  'merchant.feedCreate.cta.menu',
  'merchant.feedCreate.cta.order',
  'merchant.feedCreate.cta.ask',
  'merchant.feedCreate.cta.shop',
];

/// Übersetzt [key]; fällt auf [fallback] zurück, falls der Key fehlt
/// (LanguageService.text liefert bei fehlendem Key den Key selbst zurück).
String _t(LanguageService texts, String key, String fallback) {
  final value = texts.text(key);
  return value == key ? fallback : value;
}

/// Deutsche Hinweistexte für die KI-Korrektur (Fallback eingebaut, falls die
/// Keys noch nicht im LanguageService liegen).
String _correctHintText(LanguageService texts, String key) {
  const fallbacks = {
    'merchant.feedCreate.aiCorrect.done': 'Texte verbessert.',
    'merchant.feedCreate.aiCorrect.failed':
        'KI gerade nicht erreichbar. Deine Texte bleiben unverändert.',
    'merchant.feedCreate.aiCorrect.empty':
        'Bitte zuerst Titel, Untertitel oder Beschreibung ausfüllen.',
    'merchant.feedCreate.aiCorrect.limit': '2/2 heute genutzt.',
  };
  return _t(texts, key, fallbacks[key] ?? key);
}

String _dateText(LanguageService texts, DateTime? date) {
  if (date == null) return texts.text('merchant.feedCreate.noDate');
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.${date.year} $hour:$minute';
}

bool _typeSupportsCatalogItems(String type) {
  return {
    'offer',
    'categoryDiscountPercent',
    'onePlusOneFree',
    'twoPlusOneFree',
    'quickSell',
    'rescueMe',
  }.contains(type);
}

int? _catalogItemTargetCount(String type) {
  return switch (type) {
    'onePlusOneFree' => 2,
    'twoPlusOneFree' => 3,
    _ => null,
  };
}

String _selectedCatalogSummary(List<FeedCatalogItem> items) {
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final item in items) {
    counts[item.id] = (counts[item.id] ?? 0) + 1;
    names[item.id] = item.displayName;
  }
  return counts.entries
      .map((entry) {
        final name = names[entry.key] ?? '';
        return entry.value > 1 ? '${entry.value}x $name' : name;
      })
      .where((value) => value.trim().isNotEmpty)
      .join(', ');
}

String _firstCatalogImage(List<FeedCatalogItem> items) {
  for (final item in items) {
    if (item.imageUrl.trim().isNotEmpty) return item.imageUrl.trim();
  }
  return '';
}

String _catalogTitle(
  LanguageService texts,
  String type,
  List<FeedCatalogItem> items,
) {
  final summary = _selectedCatalogSummary(items);
  if (summary.isEmpty) return '';
  return switch (type) {
    'onePlusOneFree' => texts.text('merchant.feedCreate.items.titleOnePlusOne').replaceAll('{items}', summary),
    'twoPlusOneFree' => texts.text('merchant.feedCreate.items.titleTwoPlusOne').replaceAll('{items}', summary),
    'categoryDiscountPercent' => texts.text('merchant.feedCreate.items.titleDiscount').replaceAll('{items}', summary),
    'rescueMe' || 'quickSell' => texts.text('merchant.feedCreate.items.titleRescue').replaceAll('{items}', summary),
    _ => texts.text('merchant.feedCreate.items.titleOffer').replaceAll('{items}', summary),
  };
}

String _catalogSubtitle(LanguageService texts, List<FeedCatalogItem> items) {
  final categories = items
      .map((item) => item.categoryName.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .take(2)
      .join(', ');
  return categories.isEmpty ? texts.text('merchant.feedCreate.items.catalogSubtitle') : categories;
}

String _catalogDescription(List<FeedCatalogItem> items) {
  return items
      .map((item) => item.description.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .join('\n');
}

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final texts = context.read<LanguageService>();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: MerchantPremiumColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(texts.text('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: MerchantPremiumColors.coral),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

String _priceInput(num value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 2).replaceAll('.', ',');
}

