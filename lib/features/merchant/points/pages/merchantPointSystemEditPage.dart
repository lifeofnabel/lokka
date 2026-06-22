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
  String _programMode = PointsProgramMode.monthlyRewards;
  String _originalProgramMode = PointsProgramMode.monthlyRewards;
  int _monthlyResetDay = 1;
  int _transitionDays = 14;
  // Lokaler Doppel-Submit-Schutz: deckt auch das Zeitfenster ab, in dem ein
  // Bestätigungs-Sheet offen ist (provider.isSaving ist dann noch false).
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _pointsPerEuro.dispose();
    super.dispose();
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
    final saving = provider.isSaving || _busy;

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
          // Live-Preview an die Controller gekoppelt – nur die Vorschau baut bei
          // jedem Tastendruck neu, nicht die ganze Editor-Seite.
          AnimatedBuilder(
            animation: Listenable.merge([_title, _pointsPerEuro]),
            builder: (context, _) => _Preview(
              title: _title.text,
              programMode: _programMode,
              pointsPerEuro: _parseNumber(_pointsPerEuro.text) ?? 1,
            ),
          ),
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
            maxLength: AppLimits.pointsTitleMaxLength,
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _pointsPerEuro,
            label: texts.text('merchant.points.field.pointsPerEuro'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_DecimalInputFormatter()],
          ),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(
            controller: _description,
            label: texts.text('common.description'),
            maxLines: 3,
            maxLength: AppLimits.pointsDescriptionMaxLength,
          ),
          const SizedBox(height: AppSpacing.lg),
          MerchantPrimaryButton(
            label: system.isLive ? texts.text('common.save') : texts.text('merchant.points.saveDraft'),
            icon: Icons.save_rounded,
            isLoading: saving,
            onPressed: () => _save(context, provider, system),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Aktivieren ist die untergeordnete Sekundäraktion (eine klare
          // Primäraktion pro Screen): dezenter Sekundär-Button statt zweitem
          // Vollbreiten-Block.
          MerchantSecondaryButton(
            label: texts.text('merchant.points.activate'),
            icon: Icons.rocket_launch_rounded,
            onPressed: saving ? null : () => _publish(context, provider, system),
          ),
        ],
      ),
    );
  }

  void _hydrate(PointsSystemModel system) {
    final key = system.id.isEmpty ? 'new' : system.id;
    if (_hydratedId == key) return;
    _hydratedId = key;
    // Reine State-Felder dürfen sofort, sie lösen keinen Controller-Notify aus.
    _programMode = system.programMode;
    _originalProgramMode = system.programMode;
    _monthlyResetDay = system.monthlyResetDay.clamp(1, 31).toInt();
    // Controller-Inhalte erst nach dem Frame setzen (kein Schreiben in build),
    // und nur, wenn sie sich tatsächlich unterscheiden (keine Cursorsprünge).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setIfChanged(_title, system.title);
      _setIfChanged(_description, system.description);
      _setIfChanged(_pointsPerEuro, _formatNumber(system.pointsPerEuro));
    });
  }

  bool _modeChanged(PointsSystemModel system) {
    return system.id.isNotEmpty && _originalProgramMode != _programMode;
  }

  PointsSystemModel _systemFromForm(
    MerchantPointsProvider provider,
    PointsSystemModel existing, {
    String? forcedStatus,
  }) {
    // Bestehenden Status erhalten (paused/archived gehen nicht verloren); nur
    // beim bewussten Aktivieren wird forcedStatus=active gesetzt.
    final status = forcedStatus ?? existing.status;
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
      existingParticipantsCanContinue: existing.existingParticipantsCanContinue,
      // transitionEndsAt nur bei echtem Modus-Wechsel setzen; wenn der Modus
      // wieder dem Original entspricht (A->B->A), explizit auf null zurück.
      transitionEndsAt: _modeChanged(existing)
          ? DateTime.now().add(Duration(days: _transitionDays))
          : (_programMode == existing.programMode ? null : existing.transitionEndsAt),
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
    if (_busy) return;
    final texts = context.read<LanguageService>();
    if (!_validate(context)) return;
    setState(() => _busy = true);
    try {
      if (_modeChanged(existing)) {
        final accepted = await _confirmModeSwitch(context);
        if (accepted != true || !context.mounted) return;
      }
      final draft = _systemFromForm(provider, existing);
      final id = await provider.saveSystem(draft);
      if (!context.mounted || id == null) return;
      // Gespeicherten Datensatz mit id übernehmen, statt die Seite neu zu
      // mounten – lokaler UI-State (Modus, Slider) bleibt erhalten.
      provider.adoptSystem(draft.copyWith(id: id));
      _hydratedId = id;
      _originalProgramMode = _programMode;
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
    PointsSystemModel existing,
  ) async {
    if (_busy) return;
    if (!_validate(context)) return;
    setState(() => _busy = true);
    try {
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validate(BuildContext context) {
    final texts = context.read<LanguageService>();
    final points = _parseNumber(_pointsPerEuro.text) ?? 0;
    String? message;
    if (_title.text.trim().isEmpty) {
      message = texts.text('merchant.points.error.systemTitle');
    } else if (_title.text.trim().length > AppLimits.pointsTitleMaxLength) {
      message = texts.text('merchant.points.error.titleTooLong');
    } else if (points <= 0) {
      message = texts.text('merchant.points.error.pointsPerEuro');
    } else if (points > AppLimits.pointsPerEuroMax) {
      message = texts.text('merchant.points.error.pointsPerEuroMax');
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

class _Preview extends StatelessWidget {
  const _Preview({
    required this.title,
    required this.programMode,
    required this.pointsPerEuro,
  });

  final String title;
  final String programMode;
  final num pointsPerEuro;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                  title.trim().isEmpty
                      ? texts.text('merchant.points.defaultSystem')
                      : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_modeLabel(texts, programMode)} / ${_formatNumber(pointsPerEuro)} ${texts.text('merchant.points.pointsPerEuro')}',
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
    return Semantics(
      selected: selected,
      button: true,
      label: title,
      child: InkWell(
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
                  // Info-Tooltip bleibt unabhängig vom Selektionszustand
                  // erreichbar; bei Auswahl zusätzlich der Haken davor.
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle_rounded,
                          size: 18, color: MerchantPremiumColors.gold),
                    ),
                  Tooltip(
                    message: tooltip,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 8),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: MerchantPremiumColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
            ],
          ),
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
                Flexible(
                  child: Text(
                    texts.text('merchant.points.monthlyResetDay'),
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: texts.text('merchant.points.monthlyResetDayTip'),
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 8),
                  child: const Icon(Icons.info_outline_rounded, size: 18, color: MerchantPremiumColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // DS-konformes Dropdown (wie _ItemDropdown), Touch-Target >=48dp,
          // Label mit Einheit ("Tag X").
          SizedBox(
            width: 132,
            child: DropdownButtonFormField<int>(
              initialValue: value,
              isDense: false,
              dropdownColor: MerchantPremiumColors.surfaceAlt,
              iconEnabledColor: MerchantPremiumColors.muted,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w600,
              ),
              decoration: merchantPremiumInputDecoration(
                label: texts.text('merchant.points.monthlyResetDay'),
              ),
              items: List.generate(
                31,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text(
                    texts.text('merchant.points.resetDayOption')
                        .replaceAll('{day}', '${index + 1}'),
                  ),
                ),
              ),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            texts.text('merchant.points.modeSwitchWarningMessage'),
            style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
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
  return showMerchantConfirmSheet(
    context: context,
    title: texts.text('merchant.points.activateSystemTitle'),
    message: texts.text('merchant.points.activateSystemMessage'),
    confirmLabel: texts.text('merchant.points.activate'),
    cancelLabel: texts.text('common.cancel'),
    confirmIcon: Icons.rocket_launch_rounded,
  );
}

Future<bool?> _confirmModeSwitch(BuildContext context) {
  final texts = context.read<LanguageService>();
  return showMerchantConfirmSheet(
    context: context,
    title: texts.text('merchant.points.modeSwitchConfirmTitle'),
    message: texts.text('merchant.points.modeSwitchConfirmMessage'),
    confirmLabel: texts.text('merchant.points.modeSwitchConfirm'),
    cancelLabel: texts.text('common.cancel'),
    confirmIcon: Icons.check_rounded,
    warn: true,
  );
}

num? _parseNumber(String value) {
  final clean = value.trim().replaceAll(',', '.');
  if (clean.isEmpty) return null;
  // Mehrfach-Trennzeichen (z. B. "1.2.3") liefern hier null statt eines stillen
  // Fallbacks – die Validierung greift dann.
  return num.tryParse(clean);
}

/// Zeige Zahlen mit Komma als Dezimaltrennzeichen (deutsche Konvention) und
/// ohne überflüssige ".0"-Endung.
String _formatNumber(num value) {
  final text = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  return text.replaceAll('.', ',');
}

String _modeLabel(LanguageService texts, String mode) {
  return mode == PointsProgramMode.pointsShopRewards
      ? texts.text('merchant.points.mode.pointsShopRewards')
      : texts.text('merchant.points.mode.monthlyRewards');
}

/// Lässt nur Dezimalzahlen mit einem Trennzeichen (Komma oder Punkt) und max.
/// 2 Nachkommastellen zu – verhindert Mehrfach-Trennzeichen und Buchstaben.
class _DecimalInputFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d{0,6}([.,]\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty || _pattern.hasMatch(newValue.text)) return newValue;
    return oldValue;
  }
}
