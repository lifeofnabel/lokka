import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/pointsSystemModel.dart';
import '../providers/merchantPointsProvider.dart';
import '../services/merchantPointsService.dart';

class MerchantPointSystemEditPage extends StatelessWidget {
  const MerchantPointSystemEditPage({super.key, this.systemId});

  final String? systemId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantPointsProvider(
        service: MerchantPointsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(systemId: systemId ?? ''),
      child: _PointSystemEditView(systemId: systemId),
    );
  }
}

class _PointSystemEditView extends StatefulWidget {
  const _PointSystemEditView({this.systemId});

  final String? systemId;

  @override
  State<_PointSystemEditView> createState() => _PointSystemEditViewState();
}

class _PointSystemEditViewState extends State<_PointSystemEditView> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _pointsPerEuro = TextEditingController();
  String? _hydratedId;
  bool _isHydrating = false;
  String _programMode = PointsProgramMode.monthlyRewards;
  String _originalProgramMode = PointsProgramMode.monthlyRewards;
  int _monthlyResetDay = 1;
  int _transitionDays = 14;

  @override
  void initState() {
    super.initState();
    for (final controller in [_title, _description, _pointsPerEuro]) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _pointsPerEuro.dispose();
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
        title: texts.text('merchant.points.systemEditTitle'),
        subtitle: texts.text('merchant.points.systemEditSubtitle'),
        backPath: '/merchant/points',
        child: const MerchantLoadingCards(count: 4),
      );
    }

    final system = provider.editingSystem ??
        PointsSystemModel.empty(merchantId: provider.merchantId);
    _hydrate(system);

    return MerchantToolScaffold(
      title: texts.text('merchant.points.systemEditTitle'),
      subtitle: texts.text('merchant.points.systemEditSubtitle'),
      backPath: '/merchant/points',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.points.systemEditTip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.error != null) ...[
            MerchantErrorState(message: provider.error!, onRetry: provider.clearError),
            const SizedBox(height: AppSpacing.md),
          ],
          _Preview(system: _systemFromForm(provider, system)),
          const SizedBox(height: AppSpacing.md),
          _ModePicker(
            selected: _programMode,
            onSelected: (value) => setState(() => _programMode = value),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_programMode == PointsProgramMode.monthlyRewards) ...[
            _ResetDayPicker(
              value: _monthlyResetDay,
              onChanged: (value) => setState(() => _monthlyResetDay = value),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_modeChanged(system)) ...[
            _SwitchWarning(
              transitionDays: _transitionDays,
              onChanged: (value) => setState(() => _transitionDays = value),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          MerchantTextField(
            controller: _title,
            label: texts.text('merchant.points.field.systemTitle'),
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _pointsPerEuro,
            label: texts.text('merchant.points.field.pointsPerEuro'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _description,
            label: texts.text('common.description'),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),
          MerchantPrimaryButton(
            label: system.isLive ? texts.text('common.save') : texts.text('merchant.points.saveDraft'),
            icon: Icons.save_rounded,
            isLoading: provider.isSaving,
            onPressed: () => _save(context, provider, system),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: provider.isSaving ? null : () => _publish(context, provider, system),
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

  void _hydrate(PointsSystemModel system) {
    final key = system.id.isEmpty ? 'new' : system.id;
    if (_hydratedId == key) return;
    _isHydrating = true;
    _hydratedId = key;
    _title.text = system.title;
    _description.text = system.description;
    _pointsPerEuro.text = system.pointsPerEuro.toString().replaceAll('.', ',');
    _programMode = system.programMode;
    _originalProgramMode = system.programMode;
    _monthlyResetDay = system.monthlyResetDay.clamp(1, 31).toInt();
    _isHydrating = false;
  }

  bool _modeChanged(PointsSystemModel system) {
    return system.id.isNotEmpty && _originalProgramMode != _programMode;
  }

  PointsSystemModel _systemFromForm(
    MerchantPointsProvider provider,
    PointsSystemModel existing, {
    String? forcedStatus,
  }) {
    final status = forcedStatus ??
        (existing.status == PointsStatus.active ? PointsStatus.active : PointsStatus.draft);
    return PointsSystemModel(
      id: existing.id,
      merchantId: provider.merchantId,
      title: _title.text,
      description: _description.text,
      programMode: _programMode,
      monthlyResetDay: _monthlyResetDay,
      pointsPerEuro: _parseNumber(_pointsPerEuro.text) ?? 1,
      status: status,
      isActive: status == PointsStatus.active,
      isArchived: status == PointsStatus.archived,
      existingParticipantsCanContinue: true,
      transitionEndsAt: _modeChanged(existing)
          ? DateTime.now().add(Duration(days: _transitionDays))
          : existing.transitionEndsAt,
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
    PointsSystemModel existing,
  ) async {
    final texts = context.read<LanguageService>();
    if (!_validate(context)) return;
    if (_modeChanged(existing)) {
      final accepted = await _confirmModeSwitch(context);
      if (accepted != true || !context.mounted) return;
    }
    final id = await provider.saveSystem(_systemFromForm(provider, existing));
    if (!context.mounted || id == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texts.text('merchant.points.saved'))),
    );
    context.pushReplacement('/merchant/points/system/edit/$id');
  }

  Future<void> _publish(
    BuildContext context,
    MerchantPointsProvider provider,
    PointsSystemModel existing,
  ) async {
    if (!_validate(context)) return;
    final accepted = await _confirmPublish(context);
    if (accepted != true || !context.mounted) return;
    if (_modeChanged(existing)) {
      final modeAccepted = await _confirmModeSwitch(context);
      if (modeAccepted != true || !context.mounted) return;
    }
    final id = await provider.publishSystem(
      _systemFromForm(provider, existing, forcedStatus: PointsStatus.active),
    );
    if (!context.mounted || id == null) return;
    context.go('/merchant/points');
  }

  bool _validate(BuildContext context) {
    final texts = context.read<LanguageService>();
    String? message;
    if (_title.text.trim().isEmpty) {
      message = texts.text('merchant.points.error.systemTitle');
    } else if ((_parseNumber(_pointsPerEuro.text) ?? 0) <= 0) {
      message = texts.text('merchant.points.error.pointsPerEuro');
    }
    if (message == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.system});

  final PointsSystemModel system;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
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
                Text(
                  system.title.trim().isEmpty
                      ? texts.text('merchant.points.defaultSystem')
                      : system.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_modeLabel(texts, system.programMode)} / ${system.pointsPerEuro} ${texts.text('merchant.points.pointsPerEuro')}',
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

class _ModePicker extends StatelessWidget {
  const _ModePicker({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Row(
      children: [
        Expanded(
          child: _ModeCard(
            title: texts.text('merchant.points.mode.monthlyRewards'),
            tooltip: texts.text('merchant.points.mode.monthlyRewardsTip'),
            icon: Icons.calendar_month_rounded,
            selected: selected == PointsProgramMode.monthlyRewards,
            onTap: () => onSelected(PointsProgramMode.monthlyRewards),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ModeCard(
            title: texts.text('merchant.points.mode.pointsShopRewards'),
            tooltip: texts.text('merchant.points.mode.pointsShopRewardsTip'),
            icon: Icons.shopping_bag_rounded,
            selected: selected == PointsProgramMode.pointsShopRewards,
            onTap: () => onSelected(PointsProgramMode.pointsShopRewards),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? MerchantPremiumColors.goldSoft
              : MerchantPremiumColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? MerchantPremiumColors.gold
                : MerchantPremiumColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: selected
                        ? MerchantPremiumColors.gold
                        : MerchantPremiumColors.ink),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: MerchantPremiumColors.gold)
                else
                  Tooltip(
                    message: tooltip,
                    child: const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: MerchantPremiumColors.muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetDayPicker extends StatelessWidget {
  const _ResetDayPicker({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  texts.text('merchant.points.monthlyResetDay'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: texts.text('merchant.points.monthlyResetDayTip'),
                  child: const Icon(Icons.info_outline_rounded, size: 18, color: MerchantPremiumColors.muted),
                ),
              ],
            ),
          ),
          DropdownButton<int>(
            value: value,
            dropdownColor: MerchantPremiumColors.surfaceAlt,
            iconEnabledColor: MerchantPremiumColors.muted,
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w800,
            ),
            underline: const SizedBox.shrink(),
            items: List.generate(
              31,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text((index + 1).toString()),
              ),
            ),
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _SwitchWarning extends StatelessWidget {
  const _SwitchWarning({
    required this.transitionDays,
    required this.onChanged,
  });

  final int transitionDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.warningSoft,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: MerchantPremiumColors.warning.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: MerchantPremiumColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  texts.text('merchant.points.modeSwitchWarningTitle'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            texts.text('merchant.points.modeSwitchWarningMessage'),
            style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            children: [7, 14, 21, 28]
                .map(
                  (days) => ChoiceChip(
                    label: Text(texts.text('merchant.points.deadlineDays').replaceAll('{days}', '$days')),
                    selected: transitionDays == days,
                    onSelected: (_) => onChanged(days),
                  ),
                )
                .toList(),
          ),
        ],
      ),
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
              texts.text('merchant.points.activateSystemTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text('merchant.points.activateSystemMessage'),
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
            const Icon(Icons.warning_amber_rounded, size: 38, color: MerchantPremiumColors.warning),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text('merchant.points.modeSwitchConfirmTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
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
            MerchantPrimaryButton(
              label: texts.text('merchant.points.modeSwitchConfirm'),
              icon: Icons.check_rounded,
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

num? _parseNumber(String value) {
  final clean = value.trim().replaceAll(',', '.');
  if (clean.isEmpty) return null;
  return num.tryParse(clean);
}

String _modeLabel(LanguageService texts, String mode) {
  return mode == PointsProgramMode.pointsShopRewards
      ? texts.text('merchant.points.mode.pointsShopRewards')
      : texts.text('merchant.points.mode.monthlyRewards');
}
