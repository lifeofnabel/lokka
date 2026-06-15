import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/couponModel.dart';
import '../providers/merchantCouponsProvider.dart';
import '../services/merchantCouponsService.dart';

class MerchantCouponEditPage extends StatelessWidget {
  const MerchantCouponEditPage({super.key, this.couponId});

  final String? couponId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantCouponsProvider(
        service: MerchantCouponsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(editId: couponId),
      child: _MerchantCouponEditView(couponId: couponId),
    );
  }
}

class _MerchantCouponEditView extends StatefulWidget {
  const _MerchantCouponEditView({this.couponId});

  final String? couponId;

  @override
  State<_MerchantCouponEditView> createState() => _MerchantCouponEditViewState();
}

class _MerchantCouponEditViewState extends State<_MerchantCouponEditView> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _description = TextEditingController();
  final _valueText = TextEditingController();
  final _codePrefix = TextEditingController(text: 'LK');
  final _codeCount = TextEditingController(text: '20');

  String? _hydratedId;
  bool _isHydrating = false;
  String _type = CouponType.percent;
  int _maxUsesPerCode = 1;
  String _imageUrl = '';
  List<String> _codes = [];
  Map<String, String> _codeStatuses = {};

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _title,
      _subtitle,
      _description,
      _valueText,
      _codePrefix,
      _codeCount,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _description.dispose();
    _valueText.dispose();
    _codePrefix.dispose();
    _codeCount.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (!_isHydrating && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantCouponsProvider>();

    if (provider.isLoading) {
      return MerchantToolScaffold(
        title: texts.text('merchant.coupons.editTitle'),
        subtitle: texts.text('merchant.coupons.editSubtitle'),
        backPath: '/merchant/coupons',
        child: const MerchantLoadingCards(count: 5),
      );
    }

    if (provider.error != null && provider.editingCoupon == null) {
      return MerchantToolScaffold(
        title: texts.text('merchant.coupons.editTitle'),
        subtitle: texts.text('merchant.coupons.editSubtitle'),
        backPath: '/merchant/coupons',
        child: MerchantErrorState(
          message: provider.error!,
          onRetry: () => provider.load(editId: widget.couponId),
        ),
      );
    }

    final coupon = provider.editingCoupon ?? CouponModel.empty(merchantId: provider.merchantId);
    _hydrate(coupon);

    return MerchantToolScaffold(
      title: widget.couponId == null
          ? texts.text('merchant.coupons.create')
          : texts.text('merchant.coupons.editTitle'),
      subtitle: texts.text('merchant.coupons.editSubtitle'),
      backPath: '/merchant/coupons',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.coupons.editTooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.error != null) ...[
            MerchantErrorState(message: provider.error!, onRetry: provider.clearError),
            const SizedBox(height: AppSpacing.md),
          ],
          _CouponPreview(coupon: _couponFromForm(provider, coupon)),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: texts.text('merchant.coupons.section.base'),
            tooltip: texts.text('merchant.coupons.section.baseTip'),
            child: Column(
              children: [
                MerchantTextField(
                  controller: _title,
                  label: texts.text('merchant.coupons.field.title'),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(
                  controller: _subtitle,
                  label: texts.text('merchant.coupons.field.subtitle'),
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
            title: texts.text('merchant.coupons.section.value'),
            tooltip: texts.text('merchant.coupons.section.valueTip'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChipWrap(
                  options: [
                    _ChipOption(CouponType.percent, texts.text('merchant.coupons.type.percent')),
                    _ChipOption(CouponType.fixed, texts.text('merchant.coupons.type.fixed')),
                    _ChipOption(CouponType.freeItem, texts.text('merchant.coupons.type.freeItem')),
                    _ChipOption(CouponType.custom, texts.text('merchant.coupons.type.custom')),
                  ],
                  selected: _type,
                  onSelected: (value) => setState(() => _type = value),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(
                  controller: _valueText,
                  label: texts.text('merchant.coupons.field.valueText'),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: texts.text('merchant.coupons.section.codes'),
            tooltip: texts.text('merchant.coupons.section.codesTip'),
            child: Column(
              children: [
                MerchantTextField(
                  controller: _codePrefix,
                  label: texts.text('merchant.coupons.field.codePrefix'),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(
                  controller: _codeCount,
                  label: texts.text('merchant.coupons.field.codeCount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                _ChipWrap(
                  options: [
                    _ChipOption('1', texts.text('merchant.coupons.oncePerCode')),
                    _ChipOption('99', texts.text('merchant.coupons.multiUse')),
                  ],
                  selected: _maxUsesPerCode == 1 ? '1' : '99',
                  onSelected: (value) => setState(() => _maxUsesPerCode = value == '1' ? 1 : 99),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _generateCodes(provider),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: Text(texts.text('merchant.coupons.generateCodes')),
                ),
                if (_codes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await _openCodesSheet(
                        context: context,
                        codes: _codes,
                        statuses: _codeStatuses,
                      );
                      if (updated != null) {
                        setState(() => _codeStatuses = updated);
                      }
                    },
                    icon: const Icon(Icons.list_alt_rounded),
                    label: Text(texts.text('merchant.coupons.viewCodes')),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_codes.length} ${texts.text('merchant.coupons.codes')}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _codes.take(12).map((code) => _CodePill(code: code)).toList(),
                  ),
                ],
              ],
            ),
          ),
          _SectionCard(
            title: texts.text('merchant.coupons.section.image'),
            tooltip: texts.text('merchant.coupons.section.imageTip'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    child: Image.network(
                      _imageUrl,
                      height: 170,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                OutlinedButton.icon(
                  onPressed: provider.isSaving
                      ? null
                      : () async {
                          final uploaded = await provider.uploadImage();
                          if (uploaded != null && uploaded.isNotEmpty) {
                            setState(() => _imageUrl = uploaded);
                          }
                        },
                  icon: const Icon(Icons.image_rounded),
                  label: Text(
                    _imageUrl.isEmpty
                        ? texts.text('common.uploadImage')
                        : texts.text('common.replaceImage'),
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: texts.text('merchant.coupons.section.publish'),
            tooltip: texts.text('merchant.coupons.section.publishTip'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  texts.text('merchant.coupons.section.publishTip'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantPrimaryButton(
                  label: texts.text('merchant.coupons.saveDraft'),
                  icon: Icons.save_rounded,
                  isLoading: provider.isSaving,
                  onPressed: () => _saveDraft(context, provider, coupon),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: provider.isSaving ? null : () => _publish(context, provider, coupon),
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: Text(texts.text('merchant.coupons.publish')),
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

  void _hydrate(CouponModel coupon) {
    if (_hydratedId == coupon.id) return;
    _isHydrating = true;
    _hydratedId = coupon.id;
    _title.text = coupon.title;
    _subtitle.text = coupon.subtitle;
    _description.text = coupon.description;
    _valueText.text = coupon.valueText;
    _codePrefix.text = coupon.codePrefix.isEmpty ? 'LK' : coupon.codePrefix;
    _codeCount.text = coupon.codes.isEmpty ? '20' : coupon.codes.length.toString();
    _type = coupon.type;
    _maxUsesPerCode = coupon.maxUsesPerCode;
    _imageUrl = coupon.imageUrl;
    _codes = [...coupon.codes];
    _codeStatuses = _normalizedStatuses(_codes, coupon.codeStatuses);
    _isHydrating = false;
  }

  CouponModel _couponFromForm(MerchantCouponsProvider provider, CouponModel existing, {String? forcedStatus}) {
    final status = forcedStatus ?? (existing.status == CouponStatus.active ? CouponStatus.active : CouponStatus.draft);
    return CouponModel(
      id: existing.id,
      merchantId: provider.merchantId,
      title: _title.text,
      subtitle: _subtitle.text,
      description: _description.text,
      type: _type,
      valueText: _valueText.text,
      codePrefix: _codePrefix.text,
      codes: _codes,
      codeStatuses: _normalizedStatuses(_codes, _codeStatuses),
      maxUsesPerCode: _maxUsesPerCode,
      imageUrl: _imageUrl,
      status: status,
      isActive: status == CouponStatus.active,
      isArchived: status == CouponStatus.archived,
      isPrivate: false,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
      publishedAt: existing.publishedAt,
      activatedAt: existing.activatedAt,
      pausedAt: existing.pausedAt,
      archivedAt: existing.archivedAt,
    );
  }

  void _generateCodes(MerchantCouponsProvider provider) {
    final count = (int.tryParse(_codeCount.text.trim()) ?? 20).clamp(1, 100).toInt();
    _codeCount.text = count.toString();
    final generated = provider.generateCodes(
      prefix: _codePrefix.text,
      count: count,
      existing: _codes,
    );
    setState(() {
      _codes = generated;
      _codeStatuses = _normalizedStatuses(generated, _codeStatuses);
    });
  }

  Future<void> _saveDraft(
    BuildContext context,
    MerchantCouponsProvider provider,
    CouponModel existing,
  ) async {
    final texts = context.read<LanguageService>();
    if (!_validate(context)) return;
    if (_codes.isEmpty) _generateCodes(provider);
    final id = await provider.saveCoupon(_couponFromForm(provider, existing));
    if (!context.mounted || id == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texts.text('merchant.coupons.saved'))),
    );
    context.pushReplacement('/merchant/coupons/edit/$id');
  }

  Future<void> _publish(
    BuildContext context,
    MerchantCouponsProvider provider,
    CouponModel existing,
  ) async {
    if (!_validate(context)) return;
    if (_codes.isEmpty) _generateCodes(provider);
    final accepted = await _showPublishSheet(context);
    if (accepted != true || !context.mounted) return;
    final id = await provider.publishCoupon(
      _couponFromForm(provider, existing, forcedStatus: CouponStatus.active),
    );
    if (!context.mounted || id == null) return;
    context.go('/merchant/coupons');
  }

  bool _validate(BuildContext context) {
    final texts = context.read<LanguageService>();
    String? message;
    if (_title.text.trim().isEmpty) {
      message = texts.text('merchant.coupons.error.title');
    } else if (_valueText.text.trim().isEmpty) {
      message = texts.text('merchant.coupons.error.value');
    }
    if (message == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}

class _CouponPreview extends StatelessWidget {
  const _CouponPreview({required this.coupon});

  final CouponModel coupon;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.baseElevated,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          if (coupon.imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.network(
                coupon.imageUrl,
                width: 86,
                height: 86,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.title.isEmpty ? texts.text('merchant.coupons.previewTitle') : coupon.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  coupon.valueText.isEmpty ? texts.text('merchant.coupons.previewValue') : coupon.valueText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        color: MerchantPremiumColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: MerchantPremiumColors.line),
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
              selectedColor: MerchantPremiumColors.gold,
              backgroundColor: MerchantPremiumColors.surfaceAlt,
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

class _CodePill extends StatelessWidget {
  const _CodePill({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Text(code, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

Future<Map<String, String>?> _openCodesSheet({
  required BuildContext context,
  required List<String> codes,
  required Map<String, String> statuses,
}) {
  final initial = _normalizedStatuses(codes, statuses);
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => _CodesSheet(
      codes: codes,
      statuses: initial,
    ),
  );
}

class _CodesSheet extends StatefulWidget {
  const _CodesSheet({
    required this.codes,
    required this.statuses,
  });

  final List<String> codes;
  final Map<String, String> statuses;

  @override
  State<_CodesSheet> createState() => _CodesSheetState();
}

class _CodesSheetState extends State<_CodesSheet> {
  late Map<String, String> statuses;

  @override
  void initState() {
    super.initState();
    statuses = {...widget.statuses};
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              texts.text('merchant.coupons.codesTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text('merchant.coupons.codesTip'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.codes.length,
                itemBuilder: (context, index) {
                  final code = widget.codes[index];
                  return _CodeStatusRow(
                    code: code,
                    status: statuses[code] ?? CouponCodeStatus.available,
                    onChanged: (status) => setState(() => statuses[code] = status),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            MerchantPrimaryButton(
              label: texts.text('common.save'),
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(statuses),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeStatusRow extends StatelessWidget {
  const _CodeStatusRow({
    required this.code,
    required this.status,
    required this.onChanged,
  });

  final String code;
  final String status;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(code, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChoice(
                label: texts.text('merchant.coupons.code.available'),
                selected: status == CouponCodeStatus.available,
                onTap: () => onChanged(CouponCodeStatus.available),
              ),
              _StatusChoice(
                label: texts.text('merchant.coupons.code.used'),
                selected: status == CouponCodeStatus.used,
                onTap: () => onChanged(CouponCodeStatus.used),
              ),
              _StatusChoice(
                label: texts.text('merchant.coupons.code.blocked'),
                selected: status == CouponCodeStatus.blocked,
                onTap: () => onChanged(CouponCodeStatus.blocked),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: MerchantPremiumColors.gold,
      backgroundColor: MerchantPremiumColors.surfaceWarm,
      labelStyle: TextStyle(
        color: selected ? MerchantPremiumColors.base : MerchantPremiumColors.ink,
        fontWeight: FontWeight.w900,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class CouponCodeStatus {
  const CouponCodeStatus._();

  static const available = 'available';
  static const used = 'used';
  static const blocked = 'blocked';
}

Map<String, String> _normalizedStatuses(
  List<String> codes,
  Map<String, String> statuses,
) {
  final result = <String, String>{};
  for (final code in codes) {
    final status = statuses[code];
    result[code] = switch (status) {
      CouponCodeStatus.used => CouponCodeStatus.used,
      CouponCodeStatus.blocked => CouponCodeStatus.blocked,
      _ => CouponCodeStatus.available,
    };
  }
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
              texts.text('merchant.coupons.publishTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text('merchant.coupons.publishMessage'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            MerchantPrimaryButton(
              label: texts.text('merchant.coupons.publish'),
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
