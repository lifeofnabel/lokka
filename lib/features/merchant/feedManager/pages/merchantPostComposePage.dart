import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/feed/feedPostTypeStyle.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/localCacheService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../data/feedTemplates.dart';
import '../models/feedCatalogItem.dart';
import '../providers/merchantFeedCreateProvider.dart';
import '../services/feedAiSuggestionService.dart';
import '../services/merchantFeedCreateService.dart';
import '../utils/feedFormatters.dart';
import '../widgets/merchantFeedPostPreview.dart';
import '../widgets/squareImageCropSheet.dart';
import 'merchantFeedCreatePage.dart' show showCatalogItemPickerDialog;

/// Instagram-simple "Beitrag erstellen": a template chooser (2 groups) → one
/// easy fill screen (big image, title, tap-to-fill suggestions, the few fields
/// the template needs; everything advanced tucked under one toggle) → a quick
/// review. Built to be understandable for people with little social-media
/// experience.
class MerchantPostComposePage extends StatelessWidget {
  const MerchantPostComposePage({super.key, this.initialType});

  final String? initialType;

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
      child: _ComposeView(initialType: initialType),
    );
  }
}

/// Opens the template chooser as a bottom sheet, then routes to the fill screen
/// for the picked template. Call from the dashboard "Beitrag erstellen" button.
Future<void> showPostTemplateChooser(BuildContext context) async {
  final texts = context.read<LanguageService>();
  final type = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.baseElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => _TemplateChooserSheet(texts: texts),
  );
  if (type == null || !context.mounted) return;
  context.go('/merchant/feed/create?type=$type');
}

class _ComposeView extends StatefulWidget {
  const _ComposeView({this.initialType});
  final String? initialType;

  @override
  State<_ComposeView> createState() => _ComposeViewState();
}

class _ComposeViewState extends State<_ComposeView> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _description = TextEditingController();
  final _oldPrice = TextEditingController();
  final _newPrice = TextEditingController();
  final _percent = TextEditingController();
  final _ctaLabel = TextEditingController();
  final _externalUrl = TextEditingController();

  String? _type;
  bool _review = false; // false = fill, true = prüfen
  bool _advancedOpen = false;

  // advanced
  bool _hasButton = false;
  String _ctaLinkType = 'profile';
  bool _isVisible = true;
  String _audience = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedCategory = '';
  List<FeedCatalogItem> _selectedItems = const [];

  @override
  void initState() {
    super.initState();
    final t = widget.initialType?.trim();
    _type = (t == null || t.isEmpty) ? null : t;
    for (final c in [_title, _subtitle, _description, _oldPrice, _newPrice, _percent, _ctaLabel]) {
      c.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _subtitle, _description, _oldPrice, _newPrice, _percent, _ctaLabel, _externalUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  FeedTemplate get _template =>
      feedTemplateForType(_type ?? '') ?? kFeedTemplates.first;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantFeedCreateProvider>();

    // No template yet → inline chooser (fallback for direct /create links).
    if (_type == null) {
      return MerchantToolScaffold(
        title: texts.text('merchant.compose.title'),
        subtitle: texts.text('merchant.compose.subtitle'),
        backPath: '/merchant/dashboard',
        child: _TemplateChooser(
          texts: texts,
          onPick: (t) => setState(() => _type = t),
        ),
      );
    }

    return MerchantToolScaffold(
      title: feedPostTypeLabel(texts, _type!),
      subtitle: texts.text(_review ? 'merchant.compose.reviewSubtitle' : 'merchant.compose.fillSubtitle'),
      backPath: '/merchant/feed/manage',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.error != null) ...[
            MerchantErrorState(message: texts.text(provider.error!), onRetry: provider.clearError),
            const SizedBox(height: AppSpacing.md),
          ],
          _StepDots(review: _review),
          const SizedBox(height: AppSpacing.md),
          if (_review) _reviewBody(context, provider, texts) else _fillBody(context, provider, texts),
          const SizedBox(height: AppSpacing.lg),
          _navRow(context, provider, texts),
        ],
      ),
    );
  }

  // ── Step 1: fill ────────────────────────────────────────────────────────────
  Widget _fillBody(BuildContext context, MerchantFeedCreateProvider provider, LanguageService texts) {
    final tpl = _template;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeedTypeBadge(type: _type!),
        const SizedBox(height: AppSpacing.md),
        // Image — always required, big and first (Instagram feel).
        _ImageCard(imageUrl: provider.imageUrl, onTap: () => _pickImage(context, provider)),
        const SizedBox(height: AppSpacing.md),
        MerchantTextField(controller: _title, label: texts.text('merchant.compose.titleLabel')),
        const SizedBox(height: AppSpacing.sm),
        MerchantTextField(controller: _subtitle, label: texts.text('merchant.compose.subtitleLabel')),
        if (tpl.subtitleSuggestions.isNotEmpty)
          _Suggestions(
            label: texts.text('merchant.compose.suggestionsLabel'),
            values: tpl.subtitleSuggestions.map(_applyCategory).toList(),
            onPick: (v) => _setText(_subtitle, v),
          ),
        const SizedBox(height: AppSpacing.sm),
        MerchantTextField(controller: _description, label: texts.text('merchant.compose.descriptionLabel'), maxLines: 4),
        if (tpl.descriptionSuggestions.isNotEmpty)
          _Suggestions(
            label: texts.text('merchant.compose.suggestionsLabel'),
            values: tpl.descriptionSuggestions.map(_applyCategory).toList(),
            onPick: (v) => _setText(_description, v),
          ),
        const SizedBox(height: AppSpacing.md),
        // Inline template-specific fields (kept minimal).
        ..._templateFields(context, provider, texts, tpl),
        const SizedBox(height: AppSpacing.sm),
        _AdvancedSection(
          open: _advancedOpen,
          onToggle: (v) => setState(() => _advancedOpen = v),
          child: _advancedContent(context, provider, texts, tpl),
        ),
      ],
    );
  }

  List<Widget> _templateFields(BuildContext context, MerchantFeedCreateProvider provider, LanguageService texts, FeedTemplate tpl) {
    final out = <Widget>[];
    if (tpl.needsCategory) {
      final cats = provider.catalogItems
          .map((i) => i.categoryName.trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      out.add(_FieldLabel(texts.text('merchant.compose.categoryLabel')));
      out.add(_Suggestions(
        label: '',
        values: cats.isEmpty ? [texts.text('merchant.compose.noCategories')] : cats,
        selected: _selectedCategory,
        onPick: cats.isEmpty ? null : (v) => setState(() => _selectedCategory = v),
      ));
      out.add(const SizedBox(height: AppSpacing.sm));
    }
    if (tpl.needsPercent) {
      out.add(MerchantTextField(
        controller: _percent,
        label: texts.text('merchant.compose.percentLabel'),
        keyboardType: TextInputType.number,
      ));
      out.add(const SizedBox(height: AppSpacing.sm));
    }
    if (tpl.needsPrice) {
      out.add(Row(children: [
        Expanded(child: MerchantTextField(controller: _oldPrice, label: texts.text('merchant.feedCreate.oldPrice'), keyboardType: TextInputType.number)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: MerchantTextField(controller: _newPrice, label: texts.text('merchant.feedCreate.newPrice'), keyboardType: TextInputType.number)),
      ]));
      out.add(const SizedBox(height: AppSpacing.sm));
    }
    if (tpl.needsTimeWindow) {
      out.add(OutlinedButton.icon(
        onPressed: () => _pickTimeWindow(context, texts),
        icon: const Icon(Icons.schedule_rounded),
        label: Text(texts.text('merchant.compose.pickTimeWindow')),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
      ));
      out.add(const SizedBox(height: AppSpacing.sm));
    }
    return out;
  }

  Widget _advancedContent(BuildContext context, MerchantFeedCreateProvider provider, LanguageService texts, FeedTemplate tpl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AI improve
        TextButton.icon(
          onPressed: provider.canCorrect && !provider.isCorrecting ? () => _aiImprove(context, provider) : null,
          icon: provider.isCorrecting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: MerchantPremiumColors.gold))
              : const Icon(Icons.auto_fix_high_rounded, size: 18),
          label: Text(provider.canCorrect
              ? texts.text('merchant.compose.aiImprove')
              : '${provider.aiCorrectionsToday}/${MerchantFeedCreateProvider.aiCorrectionLimit}'),
          style: TextButton.styleFrom(foregroundColor: MerchantPremiumColors.gold, alignment: Alignment.centerLeft),
        ),
        // Catalog link (action templates only)
        if (tpl.isAction) ...[
          OutlinedButton.icon(
            onPressed: provider.catalogItems.isEmpty ? null : () => _linkCatalog(context, provider),
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: Text(_selectedItems.isEmpty
                ? texts.text('merchant.compose.linkMenu')
                : '${_selectedItems.length} ${texts.text('merchant.compose.linkedCount')}'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        // CTA button
        SwitchListTile(
          value: _hasButton,
          onChanged: (v) => setState(() => _hasButton = v),
          title: Text(texts.text('merchant.compose.addButton')),
          contentPadding: EdgeInsets.zero,
        ),
        if (_hasButton) ...[
          MerchantTextField(controller: _ctaLabel, label: texts.text('merchant.feedManage.ctaLabel')),
          const SizedBox(height: AppSpacing.sm),
          _CtaTargetPicker(
            selected: _ctaLinkType,
            onSelected: (v) => setState(() => _ctaLinkType = v),
          ),
          if (_ctaLinkType == 'url') ...[
            const SizedBox(height: AppSpacing.sm),
            MerchantTextField(controller: _externalUrl, label: texts.text('merchant.feedManage.ctaUrl'), keyboardType: TextInputType.url),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
        // Schedule
        _DateRow(
          label: texts.text('merchant.feedCreate.startsAt'),
          value: _startDate,
          fallback: texts.text('merchant.feedCreate.time.startOff'),
          onPick: () async {
            final d = await _pickDateTime(_startDate);
            if (d != null) setState(() => _startDate = d);
          },
          onClear: _startDate == null ? null : () => setState(() => _startDate = null),
        ),
        _DateRow(
          label: texts.text('merchant.feedCreate.endsAt'),
          value: _endDate,
          fallback: texts.text('merchant.feedCreate.time.endOff'),
          onPick: () async {
            final d = await _pickDateTime(_endDate ?? _startDate);
            if (d != null) setState(() => _endDate = d);
          },
          onClear: _endDate == null ? null : () => setState(() => _endDate = null),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Audience + visibility
        SwitchListTile(
          value: _audience == 'regulars',
          onChanged: (v) => setState(() => _audience = v ? 'regulars' : 'all'),
          title: Text(texts.text('merchant.compose.regularsOnly')),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          value: _isVisible,
          onChanged: (v) => setState(() => _isVisible = v),
          title: Text(texts.text('merchant.feedCreate.publicVisible')),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // ── Step 2: review ──────────────────────────────────────────────────────────
  Widget _reviewBody(BuildContext context, MerchantFeedCreateProvider provider, LanguageService texts) {
    final showPrice = _template.needsPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeedTypeBadge(type: _type!),
        const SizedBox(height: AppSpacing.md),
        MerchantFeedPostPreview(
          type: _type!,
          merchantName: provider.merchantName,
          merchantLogoUrl: provider.merchantLogoUrl,
          merchantCity: provider.merchantCity,
          merchantShopType: provider.merchantShopType,
          ratingText: provider.merchantRatingText,
          title: _title.text,
          subtitle: _subtitle.text,
          imageUrl: provider.imageUrl,
          oldPrice: showPrice ? _oldPrice.text : '',
          newPrice: showPrice ? _newPrice.text : '',
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewRow(label: texts.text('merchant.compose.visibilityLabel'), value: _isVisible ? texts.text('common.public') : texts.text('common.private')),
        _ReviewRow(label: texts.text('merchant.compose.audienceLabel'), value: texts.text(_audience == 'regulars' ? 'merchant.compose.regularsShort' : 'merchant.compose.allShort')),
        _ReviewRow(label: texts.text('merchant.feedCreate.startsAt'), value: _startDate == null ? texts.text('merchant.feedCreate.time.startOff') : _fmtDate(_startDate!)),
        if (_endDate != null) _ReviewRow(label: texts.text('merchant.feedCreate.endsAt'), value: _fmtDate(_endDate!)),
        if (_hasButton) _ReviewRow(label: texts.text('merchant.feedManage.ctaLabel'), value: _ctaLabel.text),
      ],
    );
  }

  Widget _navRow(BuildContext context, MerchantFeedCreateProvider provider, LanguageService texts) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: provider.isSaving
                ? null
                : () => _review ? setState(() => _review = false) : _backToChooser(),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
            child: Text(texts.text('common.back')),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MerchantPrimaryButton(
            label: _review ? texts.text('merchant.feedCreate.publish') : texts.text('auth.continue'),
            icon: _review ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
            isLoading: provider.isSaving,
            onPressed: () => _review ? _publish(context, provider, texts) : _toReview(context, provider, texts),
          ),
        ),
      ],
    );
  }

  // ── actions ────────────────────────────────────────────────────────────────
  void _backToChooser() {
    if (widget.initialType != null && widget.initialType!.isNotEmpty) {
      context.go('/merchant/feed/manage');
    } else {
      setState(() => _type = null);
    }
  }

  void _setText(TextEditingController c, String v) {
    c.text = v;
    c.selection = TextSelection.collapsed(offset: v.length);
  }

  String _applyCategory(String s) => s.replaceAll('{cat}', _selectedCategory.isEmpty ? '…' : _selectedCategory);

  Future<void> _pickImage(BuildContext context, MerchantFeedCreateProvider provider) async {
    final file = await provider.pickFeedImage();
    if (file == null || !context.mounted) return;
    final cropped = await showSquareImageCropSheet(context: context, imageBytes: file.bytes);
    if (cropped == null) return;
    await provider.uploadCroppedFeedImage(bytes: cropped, fileName: file.fileName);
  }

  Future<void> _aiImprove(BuildContext context, MerchantFeedCreateProvider provider) async {
    final texts = context.read<LanguageService>();
    final messenger = ScaffoldMessenger.of(context);
    final corrected = await provider.correctFields(
      type: _type!,
      title: _title.text,
      subtitle: _subtitle.text,
      description: _description.text,
    );
    if (!mounted) return;
    if (corrected == null) {
      messenger.showSnackBar(SnackBar(content: Text(texts.text('merchant.feedCreate.aiCorrect.failed'))));
      provider.clearAiHint();
      return;
    }
    setState(() {
      if (corrected.title.trim().isNotEmpty) _title.text = corrected.title;
      if (corrected.subtitle.trim().isNotEmpty) _subtitle.text = corrected.subtitle;
      if (corrected.description.trim().isNotEmpty) _description.text = corrected.description;
    });
    messenger.showSnackBar(SnackBar(content: Text(texts.text('merchant.feedCreate.aiCorrect.done'))));
  }

  Future<void> _linkCatalog(BuildContext context, MerchantFeedCreateProvider provider) async {
    final selected = await showCatalogItemPickerDialog(
      context: context,
      items: provider.catalogItems,
      initialSelection: _selectedItems,
      type: _type!,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedItems = selected;
      // Pull the first linked image in if the merchant hasn't picked one yet.
      final firstImg = selected.map((i) => i.imageUrl).firstWhere((u) => u.trim().isNotEmpty, orElse: () => '');
      if (provider.imageUrl.isEmpty && firstImg.isNotEmpty) provider.useCatalogImage(firstImg);
    });
  }

  Future<void> _pickTimeWindow(BuildContext context, LanguageService texts) async {
    final from = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 17, minute: 0));
    if (from == null || !context.mounted) return;
    final to = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 19, minute: 0));
    if (to == null || !mounted) return;
    String two(int v) => v.toString().padLeft(2, '0');
    setState(() => _setText(_subtitle, '${two(from.hour)}:${two(from.minute)}–${two(to.hour)}:${two(to.minute)} Uhr'));
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final base = initial ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    return DateTime(picked.year, picked.month, picked.day, time?.hour ?? 9, time?.minute ?? 0);
  }

  void _toReview(BuildContext context, MerchantFeedCreateProvider provider, LanguageService texts) {
    if (provider.imageUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texts.text('merchant.compose.imageRequired'))));
      return;
    }
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texts.text('merchant.compose.titleRequired'))));
      return;
    }
    if (_hasButton && _ctaLabel.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texts.text('merchant.feedManage.error.ctaLabel'))));
      return;
    }
    setState(() => _review = true);
  }

  Future<void> _publish(BuildContext context, MerchantFeedCreateProvider provider, LanguageService texts) async {
    final tpl = _template;
    final hasButton = _hasButton && _ctaLabel.text.trim().isNotEmpty;
    final rules = <String, dynamic>{
      if (tpl.needsPrice) 'oldPrice': feedParseNumber(_oldPrice.text),
      if (tpl.needsPrice) 'newPrice': feedParseNumber(_newPrice.text),
      if (tpl.needsPrice) 'discountPercent': feedDiscountPercent(_oldPrice.text, _newPrice.text),
      if (tpl.needsPercent) 'discountPercent': int.tryParse(_percent.text.trim()),
      if (tpl.needsCategory && _selectedCategory.isNotEmpty) 'category': _selectedCategory,
      if (_selectedItems.isNotEmpty) 'linkedItemIds': _selectedItems.map((i) => i.id).toList(),
      if (_selectedItems.isNotEmpty) 'linkedItems': _selectedItems.map((i) => i.toRuleMap()).toList(),
    }..removeWhere((_, v) => v == null);

    final ok = await provider.createPost(
      type: _type!,
      title: _title.text,
      subtitle: _subtitle.text,
      description: _description.text,
      requiredMessage: texts.text('merchant.compose.imageRequired'),
      ctaLabel: hasButton ? _ctaLabel.text : '',
      ctaType: hasButton ? 'primary' : '',
      ctaLinkType: hasButton ? _ctaLinkType : '',
      ctaTargetId: '',
      ctaUrl: hasButton && _ctaLinkType == 'url' ? _externalUrl.text : '',
      targetAudience: _audience,
      rules: rules,
      startsAt: _startDate,
      endsAt: _endDate,
      isPrivate: !_isVisible,
    );
    if (ok && context.mounted) context.go('/merchant/feed/manage');
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

// ── Chooser ───────────────────────────────────────────────────────────────────

class _TemplateChooserSheet extends StatelessWidget {
  const _TemplateChooserSheet({required this.texts});
  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: SingleChildScrollView(
          child: _TemplateChooser(
            texts: texts,
            onPick: (t) => Navigator.of(context).pop(t),
          ),
        ),
      ),
    );
  }
}

class _TemplateChooser extends StatelessWidget {
  const _TemplateChooser({required this.texts, required this.onPick});
  final LanguageService texts;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          texts.text('merchant.compose.chooseTitle'),
          style: const TextStyle(color: MerchantPremiumColors.ink, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.md),
        _GroupLabel(texts.text('merchant.compose.groupGeneral')),
        const SizedBox(height: AppSpacing.sm),
        _TemplateGrid(group: FeedTemplateGroup.general, texts: texts, onPick: onPick),
        const SizedBox(height: AppSpacing.lg),
        _GroupLabel(texts.text('merchant.compose.groupAction')),
        const SizedBox(height: AppSpacing.sm),
        _TemplateGrid(group: FeedTemplateGroup.action, texts: texts, onPick: onPick),
      ],
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({required this.group, required this.texts, required this.onPick});
  final FeedTemplateGroup group;
  final LanguageService texts;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final items = feedTemplatesIn(group);
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final cols = c.maxWidth >= 560 ? 3 : 2;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: items.map((t) {
          final style = feedPostTypeStyle(t.type);
          return SizedBox(
            width: w,
            child: InkWell(
              onTap: () => onPick(t.type),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MerchantPremiumColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: style.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                      child: Icon(style.icon, color: style.color, size: 22),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      feedPostTypeLabel(texts, t.type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

// ── Small pieces ──────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.4),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900)),
      );
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.label, required this.values, required this.onPick, this.selected});
  final String label;
  final List<String> values;
  final ValueChanged<String>? onPick;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(label, style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((v) {
              final isSel = selected != null && selected == v;
              return ActionChip(
                label: Text(v, overflow: TextOverflow.ellipsis),
                onPressed: onPick == null ? null : () => onPick!(v),
                backgroundColor: isSel ? MerchantPremiumColors.ink : MerchantPremiumColors.surfaceAlt,
                side: BorderSide(color: isSel ? MerchantPremiumColors.gold : MerchantPremiumColors.line),
                labelStyle: TextStyle(color: isSel ? Colors.white : MerchantPremiumColors.ink, fontWeight: FontWeight.w800),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.imageUrl, required this.onTap});
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: MerchantPremiumColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: MerchantPremiumColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_rounded, size: 40, color: MerchantPremiumColors.ink),
                    const SizedBox(height: AppSpacing.sm),
                    Text(texts.text('merchant.compose.addImage'), style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(texts.text('merchant.compose.imageHint'), style: const TextStyle(color: MerchantPremiumColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                )
              : Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        Text(texts.text('merchant.compose.changeImage'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                      ]),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({required this.open, required this.onToggle, required this.child});
  final bool open;
  final ValueChanged<bool> onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: EdgeInsets.zero,
      color: MerchantPremiumColors.surfaceAlt,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: open,
          onExpansionChanged: onToggle,
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          leading: const Icon(Icons.tune_rounded, color: MerchantPremiumColors.ink),
          title: Text(texts.text('merchant.compose.advanced'), style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900)),
          subtitle: Text(texts.text('merchant.compose.advancedHint'), style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
          iconColor: MerchantPremiumColors.ink,
          collapsedIconColor: MerchantPremiumColors.muted,
          children: [child],
        ),
      ),
    );
  }
}

class _CtaTargetPicker extends StatelessWidget {
  const _CtaTargetPicker({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    const options = ['profile', 'url', 'stampCard'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((v) => ChoiceChip(
        label: Text(texts.text('merchant.feedManage.cta.$v')),
        selected: selected == v,
        selectedColor: MerchantPremiumColors.ink,
        backgroundColor: MerchantPremiumColors.surface,
        side: BorderSide(color: selected == v ? MerchantPremiumColors.gold : MerchantPremiumColors.line),
        labelStyle: TextStyle(color: selected == v ? Colors.white : MerchantPremiumColors.ink, fontWeight: FontWeight.w900),
        onSelected: (_) => onSelected(v),
      )).toList(),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.value, required this.fallback, required this.onPick, required this.onClear});
  final String label;
  final DateTime? value;
  final String fallback;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    final text = value == null ? fallback : '${two(value!.day)}.${two(value!.month)}.${value!.year} ${two(value!.hour)}:${two(value!.minute)}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onPick,
      leading: const Icon(Icons.calendar_month_rounded, color: MerchantPremiumColors.ink),
      title: Text(label, style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900)),
      subtitle: Text(text, style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w700)),
      trailing: onClear == null ? null : IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded, color: MerchantPremiumColors.muted)),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: MerchantPremiumColors.muted))),
          Flexible(child: Text(value.trim().isEmpty ? '–' : value, textAlign: TextAlign.right, style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900))),
        ]),
      );
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.review});
  final bool review;
  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Row(children: [
      _dot(texts.text('merchant.compose.stepFill'), !review, true),
      const SizedBox(width: 8),
      _dot(texts.text('merchant.compose.stepReview'), review, false),
    ]);
  }

  Widget _dot(String label, bool active, bool first) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? MerchantPremiumColors.surface : MerchantPremiumColors.baseSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? MerchantPremiumColors.gold : Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text('${first ? '1' : '2'}  $label', style: TextStyle(color: active ? MerchantPremiumColors.ink : MerchantPremiumColors.mutedLight, fontWeight: FontWeight.w900, fontSize: 12)),
        ),
      );
}
