import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../stamps/widgets/stampCardVisual.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/stampCardModel.dart';
import '../providers/merchantStampsProvider.dart';
import '../services/merchantStampsService.dart';

/// Stempelkarte erstellen/bearbeiten — EIN Bildschirm, 4 Fragen.
///
/// Bewusst radikal vereinfacht (für ältere Menschen und Leute mit wenig Zeit):
/// Name · Wie viele Stempel · Belohnung · Aussehen. Alles andere bekommt
/// sinnvolle Standardwerte und versteckt sich unter „Mehr". Live-Vorschau oben,
/// ein großer „Veröffentlichen"-Knopf unten.
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
  final _reward = TextEditingController();

  MerchantStampsProvider? _provider;
  String? _hydratedId;
  bool _hydrating = false;

  int _stamps = 10;
  int _lookIndex = 0;
  // Wartezeit zwischen zwei Stempeln desselben Gastes (Sekunden). Schützt vor
  // doppeltem Stempeln; in claimLimits gespeichert.
  int _cooldownSeconds = 120;
  String _imageUrl = '';
  bool _showMore = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onFieldChange);
    _reward.addListener(_onFieldChange);
    _provider = context.read<MerchantStampsProvider>()..addListener(_hydrate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  @override
  void dispose() {
    _provider?.removeListener(_hydrate);
    _title.dispose();
    _reward.dispose();
    super.dispose();
  }

  void _onFieldChange() {
    if (!_hydrating && mounted) setState(() {});
  }

  /// Befüllt die Felder einmalig aus der geladenen Karte (idempotent via
  /// _hydratedId). Vorhandene Karten werden auf das nächstliegende „Aussehen"
  /// abgebildet — die Detail-Farbwahl entfällt in der neuen, einfachen Strecke.
  void _hydrate() {
    final provider = _provider;
    if (!mounted || provider == null || provider.isLoading) return;
    final card = provider.editingCard ??
        StampCardModel.empty(merchantId: provider.merchantId);
    final key = card.id.isEmpty ? 'new' : card.id;
    if (_hydratedId == key) return;
    _hydrating = true;
    _hydratedId = key;
    _title.text = card.title;
    _reward.text =
        card.rewardTitle.isNotEmpty ? card.rewardTitle : card.rewardItemName;
    _stamps = card.requiredStamps;
    _lookIndex = _lookIndexFor(card.styleName);
    final cooldown = card.claimLimits['cooldownSeconds'];
    _cooldownSeconds = cooldown is num
        ? cooldown.round()
        : int.tryParse('${cooldown ?? ''}') ?? 120;
    _imageUrl = card.imageUrl;
    _hydrating = false;
    if (mounted) setState(() {});
  }

  int _lookIndexFor(String styleName) {
    final i = _kLooks.indexWhere((l) => l.key == styleName);
    return i < 0 ? 0 : i;
  }

  /// Baut die Karte aus den wenigen Eingaben + Standardwerten. `copyWith` erhält
  /// staticToken / Stift-Bindung / Zeitstempel der bestehenden Karte.
  StampCardModel _compose(StampCardModel base, {String? status}) {
    final look = _kLooks[_lookIndex.clamp(0, _kLooks.length - 1)];
    final next = status ?? base.status;
    return base.copyWith(
      merchantId: _provider?.merchantId ?? base.merchantId,
      title: _title.text.trim(),
      requiredStamps: _stamps,
      conditionType: StampConditionType.visit,
      requiredItemId: '',
      requiredItemName: '',
      conditionText: '',
      rewardType: StampRewardType.custom,
      rewardItemId: '',
      rewardItemName: '',
      rewardTitle: _reward.text.trim(),
      rewardDescription: '',
      rewardTiers: const [],
      backgroundColor: look.bg,
      gradientColor: look.gradient,
      gradientEnabled: look.gradientEnabled,
      accentColor: look.accent,
      textColor: look.text,
      styleName: look.key,
      stampShape: look.shape,
      stampIconType: 'icon',
      stampIconValue: look.icon,
      imageUrl: _imageUrl,
      imagePlacement: 'side',
      claimLimits: {...base.claimLimits, 'cooldownSeconds': _cooldownSeconds},
      status: next,
      isActive: next == StampCardStatus.active,
      isArchived: next == StampCardStatus.archived,
    );
  }

  Future<void> _pickCustomCount() async {
    final picked = await showMerchantBottomSheet<int>(
      context: context,
      builder: (sheetContext) => _CustomCountSheet(initial: _stamps),
    );
    if (picked != null && mounted) setState(() => _stamps = picked);
  }

  Future<void> _publish(MerchantStampsProvider provider, StampCardModel base) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_title.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Bitte gib der Karte einen Namen.'),
      ));
      return;
    }
    if (_reward.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Bitte schreibe, was es geschenkt gibt.'),
      ));
      return;
    }
    final isLive = base.isLive;
    final accepted = await showMerchantConfirmSheet(
      context: context,
      title: isLive ? 'Änderungen speichern?' : 'Karte veröffentlichen?',
      message: isLive
          ? 'Die Karte wird für deine Gäste aktualisiert.'
          : 'Die Karte ist danach sofort für deine Gäste sichtbar.',
      confirmLabel: isLive ? 'Speichern' : 'Veröffentlichen',
      cancelLabel: 'Abbrechen',
      confirmIcon: isLive ? Icons.check_rounded : Icons.rocket_launch_rounded,
    );
    if (accepted != true || !mounted) return;
    final id = await provider.publishCard(
      _compose(base, status: StampCardStatus.active),
    );
    if (!mounted || id == null) return;
    context.go('/merchant/stamps');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantStampsProvider>();
    final isEdit = widget.stampCardId != null;
    const title = 'Stempelkarte';
    const subtitle = 'In einer Minute fertig.';

    if (provider.isLoading) {
      return const MerchantToolScaffold(
        title: title,
        subtitle: subtitle,
        backPath: '/merchant/stamps',
        child: MerchantLoadingCards(count: 4),
      );
    }
    if (provider.error != null && provider.editingCard == null) {
      return MerchantToolScaffold(
        title: title,
        subtitle: subtitle,
        backPath: '/merchant/stamps',
        child: MerchantErrorState(
          message: provider.error!,
          onRetry: () => provider.load(editId: widget.stampCardId),
        ),
      );
    }

    final base = provider.editingCard ??
        StampCardModel.empty(merchantId: provider.merchantId);
    final preview = _compose(base);
    final isLive = base.isLive;

    return MerchantToolScaffold(
      title: isEdit ? 'Karte bearbeiten' : 'Neue Stempelkarte',
      subtitle: subtitle,
      backPath: '/merchant/stamps',
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

          // ── Live-Vorschau ──────────────────────────────────────────────
          StampCardVisual(card: preview),
          const SizedBox(height: AppSpacing.lg),

          // 1 · Name
          _Field(
            step: '1',
            label: 'Wie heißt die Karte?',
            child: MerchantTextField(
              controller: _title,
              label: 'Name',
              hint: 'z. B. Kaffee-Karte',
            ),
          ),

          // 2 · Anzahl
          _Field(
            step: '2',
            label: 'Wie viele Stempel braucht man?',
            helper: 'So oft kommen Gäste, bis es die Belohnung gibt.',
            child: _CountPicker(
              value: _stamps,
              onChanged: (value) => setState(() => _stamps = value),
              onCustom: _pickCustomCount,
            ),
          ),

          // 3 · Belohnung
          _Field(
            step: '3',
            label: 'Was gibt es geschenkt?',
            child: MerchantTextField(
              controller: _reward,
              label: 'Belohnung',
              hint: 'z. B. 1 Gratis-Kaffee',
            ),
          ),

          // 4 · Aussehen
          _Field(
            step: '4',
            label: 'Welches Aussehen?',
            child: _LookPicker(
              index: _lookIndex,
              onChanged: (value) => setState(() => _lookIndex = value),
            ),
          ),

          // Optional: Mehr Einstellungen
          _MoreSettings(
            expanded: _showMore,
            onToggle: () => setState(() => _showMore = !_showMore),
            cooldownSeconds: _cooldownSeconds,
            onCooldown: (value) => setState(() => _cooldownSeconds = value),
            imageUrl: _imageUrl,
            busy: provider.isSaving,
            onAddImage: () async {
              final url = await provider.uploadImage(
                type: UploadImageType.stampCardSide,
              );
              if (url != null && url.isNotEmpty && mounted) {
                setState(() => _imageUrl = url);
              }
            },
            onRemoveImage: () => setState(() => _imageUrl = ''),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Ein großer Knopf ───────────────────────────────────────────
          MerchantPrimaryButton(
            label: isLive ? 'Speichern' : 'Veröffentlichen',
            icon: isLive ? Icons.check_rounded : Icons.rocket_launch_rounded,
            isLoading: provider.isSaving,
            onPressed: () => _publish(provider, base),
          ),
          const SizedBox(height: 10),
          Text(
            isLive
                ? 'Deine Gäste sehen die Änderung sofort.'
                : 'Danach ist die Karte sofort für deine Gäste da.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bausteine ───────────────────────────────────────────────────────────────

/// Eine nummerierte Frage: große Überschrift + optionaler Hilfstext + Eingabe.
class _Field extends StatelessWidget {
  const _Field({
    required this.step,
    required this.label,
    required this.child,
    this.helper,
  });

  final String step;
  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.goldSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: MerchantPremiumColors.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    color: MerchantPremiumColors.mint,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    if (helper != null && helper!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        helper!,
                        style: const TextStyle(
                          color: MerchantPremiumColors.muted,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Große Auswahl der Stempel-Anzahl: vier Voreinstellungen + „Andere".
class _CountPicker extends StatelessWidget {
  const _CountPicker({
    required this.value,
    required this.onChanged,
    required this.onCustom,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onCustom;

  static const _presets = [5, 8, 10, 12];

  @override
  Widget build(BuildContext context) {
    final isCustom = !_presets.contains(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < _presets.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _BigTile(
                  selected: value == _presets[i],
                  onTap: () => onChanged(_presets[i]),
                  child: Text(
                    '${_presets[i]}',
                    style: TextStyle(
                      color: value == _presets[i]
                          ? MerchantPremiumColors.mint
                          : MerchantPremiumColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _BigTile(
          selected: isCustom,
          height: 52,
          onTap: onCustom,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 19,
                color: isCustom
                    ? MerchantPremiumColors.mint
                    : MerchantPremiumColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                isCustom ? 'Andere Anzahl: $value' : 'Andere Anzahl',
                style: TextStyle(
                  color: isCustom
                      ? MerchantPremiumColors.mint
                      : MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Großer, gut tappbarer Auswahlkachel-Baustein (mind. 56–64 px).
class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.selected,
    required this.onTap,
    required this.child,
    this.height = 64,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? MerchantPremiumColors.goldSoft
                : MerchantPremiumColors.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? MerchantPremiumColors.gold
                  : MerchantPremiumColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Auswahl-Sheet für eine eigene Stempel-Anzahl (großer +/− Schrittzähler).
class _CustomCountSheet extends StatefulWidget {
  const _CustomCountSheet({required this.initial});

  final int initial;

  @override
  State<_CustomCountSheet> createState() => _CustomCountSheetState();
}

class _CustomCountSheetState extends State<_CustomCountSheet> {
  late int _value = widget.initial.clamp(2, 30);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Eigene Anzahl',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MerchantPremiumColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              onTap: _value > 2 ? () => setState(() => _value--) : null,
            ),
            SizedBox(
              width: 110,
              child: Text(
                '$_value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              onTap: _value < 30 ? () => setState(() => _value++) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        MerchantPrimaryButton(
          label: 'Übernehmen',
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MerchantPremiumColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: enabled
                  ? MerchantPremiumColors.gold
                  : MerchantPremiumColors.line,
            ),
          ),
          child: Icon(
            icon,
            size: 28,
            color: enabled
                ? MerchantPremiumColors.ink
                : MerchantPremiumColors.muted,
          ),
        ),
      ),
    );
  }
}

/// Vier fertige „Aussehen"-Vorlagen als Swatch-Kacheln.
class _LookPicker extends StatelessWidget {
  const _LookPicker({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _kLooks.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _LookSwatch(
              look: _kLooks[i],
              selected: index == i,
              onTap: () => onChanged(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _LookSwatch extends StatelessWidget {
  const _LookSwatch({
    required this.look,
    required this.selected,
    required this.onTap,
  });

  final _StampLook look;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: MerchantPremiumColors.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? MerchantPremiumColors.gold
                  : MerchantPremiumColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _hex(look.bg),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Icon(
                  _lookIcon(look.icon),
                  color: _hex(look.accent),
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                look.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? MerchantPremiumColors.mint
                      : MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optionaler, eingeklappter Bereich: Wartezeit + Bild. Standard = zu.
class _MoreSettings extends StatelessWidget {
  const _MoreSettings({
    required this.expanded,
    required this.onToggle,
    required this.cooldownSeconds,
    required this.onCooldown,
    required this.imageUrl,
    required this.busy,
    required this.onAddImage,
    required this.onRemoveImage,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final int cooldownSeconds;
  final ValueChanged<int> onCooldown;
  final String imageUrl;
  final bool busy;
  final VoidCallback onAddImage;
  final VoidCallback onRemoveImage;

  static const _cooldownOptions = [
    (0, 'Keine'),
    (60, '1 Min'),
    (120, '2 Min'),
    (300, '5 Min'),
  ];

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded,
                      color: MerchantPremiumColors.muted, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Mehr (nicht nötig)',
                      style: TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: MerchantPremiumColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Wartezeit zwischen zwei Stempeln',
              style: TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Schützt davor, dass aus Versehen doppelt gestempelt wird.',
              style: TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _cooldownOptions)
                  ChoiceChip(
                    selected: cooldownSeconds == option.$1,
                    onSelected: (_) => onCooldown(option.$1),
                    label: Text(option.$2),
                    labelStyle: TextStyle(
                      color: cooldownSeconds == option.$1
                          ? MerchantPremiumColors.base
                          : MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                    selectedColor: MerchantPremiumColors.gold,
                    backgroundColor: MerchantPremiumColors.surface,
                    side: const BorderSide(color: MerchantPremiumColors.line),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Bild (optional)',
              style: TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (imageUrl.isEmpty)
              MerchantSecondaryButton(
                label: 'Bild hinzufügen',
                icon: Icons.add_photo_alternate_rounded,
                onPressed: busy ? null : onAddImage,
              )
            else
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MerchantSecondaryButton(
                      label: 'Bild entfernen',
                      icon: Icons.delete_outline_rounded,
                      onPressed: busy ? null : onRemoveImage,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ─── „Aussehen"-Vorlagen ─────────────────────────────────────────────────────

class _StampLook {
  const _StampLook({
    required this.key,
    required this.label,
    required this.bg,
    required this.gradient,
    required this.gradientEnabled,
    required this.accent,
    required this.text,
    required this.shape,
    required this.icon,
  });

  final String key;
  final String label;
  final String bg;
  final String gradient;
  final bool gradientEnabled;
  final String accent;
  final String text;
  final String shape;
  final String icon;
}

const List<_StampLook> _kLooks = [
  _StampLook(
    key: 'noir',
    label: 'Klassisch',
    bg: '#171A18',
    gradient: '#45C9A4',
    gradientEnabled: false,
    accent: '#9CE8CF',
    text: '#FEFFFC',
    shape: 'circle',
    icon: 'star',
  ),
  _StampLook(
    key: 'cream',
    label: 'Kaffee',
    bg: '#3A2A1C',
    gradient: '#E6B980',
    gradientEnabled: false,
    accent: '#E6B980',
    text: '#FFF3E6',
    shape: 'circle',
    icon: 'coffee',
  ),
  _StampLook(
    key: 'berry',
    label: 'Beere',
    bg: '#2A1430',
    gradient: '#E59ED6',
    gradientEnabled: false,
    accent: '#E59ED6',
    text: '#FFF0FB',
    shape: 'softSquare',
    icon: 'heart',
  ),
  _StampLook(
    key: 'fresh',
    label: 'Frisch',
    bg: '#10342A',
    gradient: '#2FB389',
    gradientEnabled: true,
    accent: '#BFF3DF',
    text: '#FFFFFF',
    shape: 'circle',
    icon: 'food',
  ),
];

IconData _lookIcon(String value) {
  return switch (value) {
    'coffee' => Icons.local_cafe_rounded,
    'food' => Icons.fastfood_rounded,
    'gift' => Icons.card_giftcard_rounded,
    'heart' => Icons.favorite_rounded,
    'local' => Icons.storefront_rounded,
    _ => Icons.star_rounded,
  };
}

Color _hex(String value) {
  final clean = value.replaceAll('#', '');
  if (clean.length != 6) return MerchantPremiumColors.surfaceAlt;
  final parsed = int.tryParse('FF$clean', radix: 16);
  return parsed == null ? MerchantPremiumColors.surfaceAlt : Color(parsed);
}
