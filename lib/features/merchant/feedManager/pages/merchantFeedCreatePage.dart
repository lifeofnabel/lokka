import 'package:cached_network_image/cached_network_image.dart';
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
import '../../shared/widgets/merchantUiComponents.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../providers/merchantFeedCreateProvider.dart';
import '../services/feedAiSuggestionService.dart';
import '../services/merchantFeedCreateService.dart';

class MerchantFeedCreatePage extends StatelessWidget {
  const MerchantFeedCreatePage({super.key});

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
      )..loadAiUsage(),
      child: const _MerchantFeedCreateView(),
    );
  }
}

class _MerchantFeedCreateView extends StatefulWidget {
  const _MerchantFeedCreateView();

  @override
  State<_MerchantFeedCreateView> createState() => _MerchantFeedCreateViewState();
}

class _MerchantFeedCreateViewState extends State<_MerchantFeedCreateView> {
  final title = TextEditingController();
  final subtitle = TextEditingController();
  final description = TextEditingController();
  final aiInput = TextEditingController();
  final ctaLabel = TextEditingController();
  final minAmount = TextEditingController();
  final oldPrice = TextEditingController();
  final newPrice = TextEditingController();

  int step = 0;
  String type = 'offer';
  bool hasButton = false;
  bool isVisible = true;
  DateTime? startsAt;
  DateTime? endsAt;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      title,
      subtitle,
      description,
      ctaLabel,
      minAmount,
      oldPrice,
      newPrice,
    ]) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    title.dispose();
    subtitle.dispose();
    description.dispose();
    aiInput.dispose();
    ctaLabel.dispose();
    minAmount.dispose();
    oldPrice.dispose();
    newPrice.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

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
      title: texts.text('merchant.feedCreate.title'),
      subtitle: texts.text('merchant.feedCreate.subtitle'),
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
          _PostPreview(
            type: type,
            title: title.text,
            subtitle: subtitle.text,
            description: description.text,
            imageUrl: provider.imageUrl,
            ctaLabel: hasButton ? ctaLabel.text : '',
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
          selected: type,
          onSelected: (value) => setState(() => type = value),
        ),
      1 => _BasicStep(
          title: title,
          subtitle: subtitle,
          description: description,
          aiInput: aiInput,
          aiUsesToday: provider.aiUsesToday,
          isSuggesting: provider.isSuggesting,
          imageUrl: provider.imageUrl,
          onUpload: provider.uploadImage,
          onAi: () => _applyAiSuggestion(provider),
        ),
      2 => _RulesStep(
          hasButton: hasButton,
          ctaLabel: ctaLabel,
          minAmount: minAmount,
          oldPrice: oldPrice,
          newPrice: newPrice,
          onButtonChanged: (value) => setState(() => hasButton = value),
        ),
      3 => _ScheduleStep(
          startsAt: startsAt,
          endsAt: endsAt,
          onStart: () => _pickDate(isStart: true),
          onEnd: () => _pickDate(isStart: false),
          onClearEnd: () => setState(() => endsAt = null),
        ),
      4 => _VisibilityStep(
          isVisible: isVisible,
          onChanged: (value) => setState(() => isVisible = value),
        ),
      _ => _ConfirmStep(
          type: type,
          title: title.text,
          subtitle: subtitle.text,
          description: description.text,
          imageUrl: provider.imageUrl,
          isVisible: isVisible,
          startsAt: startsAt,
          endsAt: endsAt,
          hasButton: hasButton,
          ctaLabel: ctaLabel.text,
        ),
    };
  }

  Future<void> _applyAiSuggestion(MerchantFeedCreateProvider provider) async {
    final suggestion = await provider.suggestPost(type: type, input: aiInput.text);
    if (suggestion == null) return;
    if (!mounted) return;
    setState(() {
      if (_actionTypes.any((option) => option.key == suggestion.type)) {
        type = suggestion.type;
      }
      title.text = suggestion.title;
      subtitle.text = suggestion.subtitle;
      description.text = suggestion.description;
      if (suggestion.ctaLabel.trim().isNotEmpty) {
        hasButton = true;
        ctaLabel.text = suggestion.ctaLabel;
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startsAt ?? now : endsAt ?? startsAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        startsAt = picked;
      } else {
        endsAt = picked;
      }
    });
  }

  Future<void> _publish(
    BuildContext context,
    MerchantFeedCreateProvider provider,
    LanguageService texts,
  ) async {
    final ok = await provider.createPost(
      type: type,
      title: title.text,
      subtitle: subtitle.text,
      description: description.text,
      requiredMessage: texts.text('merchant.feedCreate.required'),
      ctaLabel: hasButton ? ctaLabel.text : '',
      ctaType: hasButton ? 'primary' : '',
      rules: {
        'minAmount': _parseNumber(minAmount.text),
        'oldPrice': _parseNumber(oldPrice.text),
        'newPrice': _parseNumber(newPrice.text),
      }..removeWhere((_, value) => value == null),
      startsAt: startsAt,
      endsAt: endsAt,
      isPrivate: !isVisible,
    );
    if (ok && context.mounted) context.go('/merchant/feed/manage');
  }
}

class _TypeStep extends StatelessWidget {
  const _TypeStep({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.type'),
      tooltip: texts.text('merchant.feedCreate.step.typeTip'),
      child: MerchantDashboardGrid(
        children: _actionTypes
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
    required this.aiInput,
    required this.aiUsesToday,
    required this.isSuggesting,
    required this.imageUrl,
    required this.onUpload,
    required this.onAi,
  });

  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController description;
  final TextEditingController aiInput;
  final int aiUsesToday;
  final bool isSuggesting;
  final String imageUrl;
  final VoidCallback onUpload;
  final VoidCallback onAi;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      children: [
        MerchantFormSection(
          title: texts.text('merchant.feedCreate.aiTitle'),
          tooltip: texts.text('merchant.feedCreate.aiTip'),
          child: Column(
            children: [
              MerchantTextField(
                controller: aiInput,
                label: texts.text('merchant.feedCreate.aiInput'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              MerchantPrimaryButton(
                label: texts
                    .text('merchant.feedCreate.aiButton')
                    .replaceAll('{count}', (5 - aiUsesToday).clamp(0, 5).toString()),
                icon: Icons.auto_awesome_rounded,
                isLoading: isSuggesting,
                onPressed: aiUsesToday >= 5 ? null : onAi,
              ),
            ],
          ),
        ),
        MerchantFormSection(
          title: texts.text('merchant.feedCreate.step.basic'),
          tooltip: texts.text('merchant.feedCreate.step.basicTip'),
          child: Column(
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
              const SizedBox(height: AppSpacing.md),
              _ImagePickerCard(imageUrl: imageUrl, onTap: onUpload),
            ],
          ),
        ),
      ],
    );
  }
}

class _RulesStep extends StatelessWidget {
  const _RulesStep({
    required this.hasButton,
    required this.ctaLabel,
    required this.minAmount,
    required this.oldPrice,
    required this.newPrice,
    required this.onButtonChanged,
  });

  final bool hasButton;
  final TextEditingController ctaLabel;
  final TextEditingController minAmount;
  final TextEditingController oldPrice;
  final TextEditingController newPrice;
  final ValueChanged<bool> onButtonChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.rules'),
      tooltip: texts.text('merchant.feedCreate.step.rulesTip'),
      child: Column(
        children: [
          MerchantTextField(
            controller: minAmount,
            label: texts.text('merchant.feedCreate.minAmount'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            value: hasButton,
            onChanged: onButtonChanged,
            title: Text(texts.text('merchant.feedCreate.hasButton')),
            subtitle: Text(texts.text('merchant.feedCreate.hasButtonTip')),
            contentPadding: EdgeInsets.zero,
          ),
          if (hasButton) ...[
            const SizedBox(height: AppSpacing.sm),
            MerchantTextField(
              controller: ctaLabel,
              label: texts.text('merchant.feedCreate.ctaLabel'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({
    required this.startsAt,
    required this.endsAt,
    required this.onStart,
    required this.onEnd,
    required this.onClearEnd,
  });

  final DateTime? startsAt;
  final DateTime? endsAt;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onClearEnd;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.schedule'),
      tooltip: texts.text('merchant.feedCreate.step.scheduleTip'),
      child: Column(
        children: [
          _DateLine(
            title: texts.text('merchant.feedCreate.startsAt'),
            value: _dateText(texts, startsAt),
            onTap: onStart,
          ),
          const SizedBox(height: AppSpacing.sm),
          _DateLine(
            title: texts.text('merchant.feedCreate.endsAt'),
            value: _dateText(texts, endsAt),
            onTap: onEnd,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onClearEnd,
            child: Text(texts.text('merchant.feedCreate.noEndDate')),
          ),
        ],
      ),
    );
  }
}

class _VisibilityStep extends StatelessWidget {
  const _VisibilityStep({
    required this.isVisible,
    required this.onChanged,
  });

  final bool isVisible;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantFormSection(
      title: texts.text('merchant.feedCreate.step.visibility'),
      tooltip: texts.text('merchant.feedCreate.step.visibilityTip'),
      child: SwitchListTile(
        value: isVisible,
        onChanged: onChanged,
        title: Text(texts.text('merchant.feedCreate.publicVisible')),
        subtitle: Text(texts.text('merchant.feedCreate.publicVisibleTip')),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    required this.isVisible,
    required this.startsAt,
    required this.endsAt,
    required this.hasButton,
    required this.ctaLabel,
  });

  final String type;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final bool isVisible;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool hasButton;
  final String ctaLabel;

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
          _SummaryRow(label: texts.text('merchant.feedCreate.startsAt'), value: _dateText(texts, startsAt)),
          _SummaryRow(label: texts.text('merchant.feedCreate.endsAt'), value: _dateText(texts, endsAt)),
          if (hasButton) _SummaryRow(label: texts.text('merchant.feedCreate.ctaLabel'), value: ctaLabel),
        ],
      ),
    );
  }
}

class _PostPreview extends StatelessWidget {
  const _PostPreview({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    required this.ctaLabel,
  });

  final String type;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 170,
            color: AppColors.gray50,
            child: imageUrl.isEmpty
                ? const Icon(Icons.image_rounded, size: 38, color: AppColors.gray500)
                : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MerchantStatusChip(label: texts.text('feed.type.$type'), status: 'dark'),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title.trim().isEmpty ? texts.text('merchant.feedCreate.previewTitle') : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.02),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle.trim().isEmpty ? texts.text('merchant.feedCreate.previewSubtitle') : subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w800),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.gray700, height: 1.35),
                  ),
                ],
                if (ctaLabel.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: AppColors.black,
                      disabledForegroundColor: AppColors.white,
                    ),
                    child: Text(ctaLabel),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded, size: 38),
                  const SizedBox(height: AppSpacing.sm),
                  Text(texts.text('merchant.feedCreate.image'), style: const TextStyle(fontWeight: FontWeight.w900)),
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
                color: selected ? AppColors.black : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? AppColors.black : AppColors.border),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: selected ? AppColors.white : AppColors.black,
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
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: AppColors.gray700)),
                ],
              ),
            ),
            const Icon(Icons.calendar_month_rounded),
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
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.gray700))),
          Text(value.trim().isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w900)),
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

const _actionTypes = [
  _ActionTypeOption(key: 'offer', titleKey: 'feed.type.offer', subtitleKey: 'merchant.feedCreate.type.offerTip', icon: Icons.local_offer_rounded),
  _ActionTypeOption(key: 'news', titleKey: 'feed.type.news', subtitleKey: 'merchant.feedCreate.type.newsTip', icon: Icons.article_rounded),
  _ActionTypeOption(key: 'newProduct', titleKey: 'feed.type.newProduct', subtitleKey: 'merchant.feedCreate.type.newProductTip', icon: Icons.fiber_new_rounded),
  _ActionTypeOption(key: 'happyHour', titleKey: 'feed.type.happyHour', subtitleKey: 'merchant.feedCreate.type.happyHourTip', icon: Icons.schedule_rounded),
  _ActionTypeOption(key: 'quickSell', titleKey: 'feed.type.quickSell', subtitleKey: 'merchant.feedCreate.type.quickSellTip', icon: Icons.flash_on_rounded),
  _ActionTypeOption(key: 'info', titleKey: 'feed.type.info', subtitleKey: 'merchant.feedCreate.type.infoTip', icon: Icons.info_rounded),
];

String _dateText(LanguageService texts, DateTime? date) {
  if (date == null) return texts.text('merchant.feedCreate.noDate');
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

num? _parseNumber(String value) {
  final clean = value.trim().replaceAll(',', '.');
  if (clean.isEmpty) return null;
  return num.tryParse(clean);
}
