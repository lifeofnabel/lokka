import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../../core/widgets/swipeHint.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/stampCardModel.dart';
import '../providers/merchantStampsProvider.dart';
import '../services/merchantStampsService.dart';
import '../widgets/merchantStampCard.dart';
import '../../../stamps/services/stampFunctionsService.dart';
import '../../../stamps/widgets/stickSetupFlow.dart';

class MerchantStampsPage extends StatelessWidget {
  const MerchantStampsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantStampsProvider(
        service: MerchantStampsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _MerchantStampsView(),
    );
  }
}

class _MerchantStampsView extends StatefulWidget {
  const _MerchantStampsView();

  @override
  State<_MerchantStampsView> createState() => _MerchantStampsViewState();
}

class _MerchantStampsViewState extends State<_MerchantStampsView> {
  // Index of the card visible in the pager — the fixed action panel below
  // always acts on THIS card, so it never requires swiping to find a button.
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantStampsProvider>();
    final cards = provider.cards;
    final clampedIndex = cards.isEmpty ? 0 : _index.clamp(0, cards.length - 1);
    final current = cards.isEmpty ? null : cards[clampedIndex];

    return MerchantToolScaffold(
      title: texts.text('merchant.stamps.title'),
      subtitle: texts.text('merchant.stamps.subtitle'),
      backPath: '/merchant/dashboard',
      trailing:
          MerchantInfoTooltip(message: texts.text('merchant.stamps.tooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantPrimaryButton(
            label: 'Neue Stempelkarte',
            icon: Icons.add_rounded,
            isLoading: provider.isSaving,
            onPressed: () => _create(context, provider),
          ),
          const SizedBox(height: 8),
          Text(
            '${provider.activeCount} von ${MerchantStampsProvider.maxActiveCards} Karten',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: provider.atCap
                  ? MerchantPremiumColors.danger
                  : MerchantPremiumColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards(count: 2)
          else if (provider.error != null && provider.cards.isEmpty)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else if (provider.cards.isEmpty)
            MerchantEmptyState(
              title: texts.text('merchant.stamps.emptyTitle'),
              message: texts.text('merchant.stamps.emptyMessage'),
              actionLabel: texts.text('merchant.stamps.create'),
              onAction: () => context.push('/merchant/stamps/edit'),
            )
          else ...[
            _StampCarousel(
              cards: cards,
              index: clampedIndex,
              onIndexChanged: (i) => setState(() => _index = i),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Fest außerhalb der swipebaren Karte — immer an derselben Stelle,
            // wirkt auf die gerade sichtbare Karte. Kein Swipen nötig.
            if (current != null)
              _ActionPanel(
                card: current,
                isSaving: provider.isSaving,
                onPublish: () => _publish(context, provider, current),
                onLimit: () => _setLimit(context, provider, current),
                onStick: () => startStickSetup(
                  context,
                  card: current,
                  functions: StampFunctionsService(),
                  onChanged: provider.load,
                ),
                onEdit: () => context.push('/merchant/stamps/edit/${current.id}'),
                onPause: () => _confirmAction(
                  context,
                  titleKey: 'merchant.stamps.pauseTitle',
                  messageKey: 'merchant.stamps.pauseMessage',
                  confirmKey: 'merchant.stamps.pause',
                  onConfirm: () => provider.pauseCard(current.id),
                ),
                onDelete: () => _confirmAction(
                  context,
                  titleKey: 'merchant.stamps.deleteTitle',
                  messageKey: 'merchant.stamps.deleteMessage',
                  confirmKey: 'common.delete',
                  isDanger: true,
                  onConfirm: () => provider.deleteDraftCard(current.id),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _create(BuildContext context, MerchantStampsProvider provider) {
    final texts = context.read<LanguageService>();
    if (provider.atCap) {
      _showCapReached(context, texts);
      return;
    }
    context.push('/merchant/stamps/edit');
  }

  Future<void> _publish(BuildContext context, MerchantStampsProvider provider,
      StampCardModel card) async {
    await _confirmAction(
      context,
      titleKey: 'merchant.stamps.publishTitle',
      message: kStampPublishMessage,
      confirmKey: 'merchant.stamps.publish',
      onConfirm: () async {
        await provider.publishCard(card);
      },
    );
  }

  Future<void> _setLimit(BuildContext context, MerchantStampsProvider provider,
      StampCardModel card) async {
    final result = await showMerchantBottomSheet<_LimitResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LimitSheet(
        cooldownSeconds: _cooldownOf(card),
        maxDistribution: card.maxDistribution,
        distributedCount: card.distributedCount,
      ),
    );
    if (result == null || !context.mounted) return;
    await provider.setLimits(
      card,
      cooldownSeconds: result.cooldownSeconds,
      maxDistribution: result.maxDistribution,
    );
  }

  int _cooldownOf(StampCardModel card) {
    final raw = card.claimLimits['cooldownSeconds'];
    if (raw is num) return raw.round();
    return int.tryParse('${raw ?? ''}') ?? 120;
  }
}

/// Fixe Aktionsleiste UNTER der swipebaren Karte (nicht Teil davon) — schönes,
/// eigenes Panel, immer sichtbar, wirkt auf die gerade angezeigte Karte.
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.card,
    required this.isSaving,
    required this.onPublish,
    required this.onLimit,
    required this.onStick,
    required this.onEdit,
    required this.onPause,
    required this.onDelete,
  });

  final StampCardModel card;
  final bool isSaving;
  final VoidCallback onPublish;
  final VoidCallback onLimit;
  final VoidCallback onStick;
  final VoidCallback onEdit;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hauptknopf: Stift verbinden (live) bzw. veröffentlichen ─────
          if (card.isLive)
            MerchantPrimaryButton(
              label: 'Stempelstift verbinden',
              icon: Icons.nfc_rounded,
              isLoading: isSaving,
              onPressed: onStick,
            )
          else
            MerchantPrimaryButton(
              label: texts.text('merchant.stamps.publish'),
              icon: Icons.rocket_launch_rounded,
              isLoading: isSaving,
              onPressed: onPublish,
            ),
          const SizedBox(height: AppSpacing.sm),

          // ── Limit setzen (Wartezeit + verfügbare Anzahl) ────────────────
          MerchantSecondaryButton(
            label: 'Limit setzen',
            icon: Icons.timer_outlined,
            onPressed: onLimit,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Bearbeiten · Pausieren · Löschen (nebeneinander) ──────────
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  label: texts.text('common.edit'),
                  icon: Icons.edit_rounded,
                  onTap: onEdit,
                ),
              ),
              if (card.isLive) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _CardAction(
                    label: texts.text('merchant.stamps.pause'),
                    icon: Icons.pause_rounded,
                    onTap: onPause,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  label: texts.text('common.delete'),
                  icon: Icons.delete_outline_rounded,
                  isDanger: true,
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color =
        isDanger ? MerchantPremiumColors.danger : MerchantPremiumColors.ink;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color: isDanger
              ? MerchantPremiumColors.danger.withValues(alpha: 0.5)
              : MerchantPremiumColors.line,
        ),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// „Limit setzen": zwei unabhängige, serverseitig durchgesetzte Grenzen in
/// einem Sheet — Wartezeit zwischen zwei Stempeln UND (neu) wie viele
/// Stempelkarten insgesamt verteilt werden sollen, mit Live-Zähler.
class _LimitResult {
  const _LimitResult(this.cooldownSeconds, this.maxDistribution);
  final int cooldownSeconds;
  final int? maxDistribution;
}

class _LimitSheet extends StatefulWidget {
  const _LimitSheet({
    required this.cooldownSeconds,
    required this.maxDistribution,
    required this.distributedCount,
  });

  final int cooldownSeconds;
  final int? maxDistribution;
  final int distributedCount;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  static const _cooldownOptions = [
    (0, 'Keine', 'Jeder Tipp zählt sofort'),
    (60, '1 Minute', 'Frühestens jede Minute'),
    (120, '2 Minuten', 'Empfohlen'),
    (300, '5 Minuten', 'Extra sicher'),
  ];

  static const _distributionPresets = [25, 50, 100];

  late int _cooldown = widget.cooldownSeconds;
  late int? _maxDistribution = widget.maxDistribution;
  late bool _customOpen = widget.maxDistribution != null &&
      !_distributionPresets.contains(widget.maxDistribution);
  late int _customValue =
      widget.maxDistribution ?? (widget.distributedCount > 0 ? widget.distributedCount : 25);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Limit setzen',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Zeitliches Limit ─────────────────────────────────────────
          const Text(
            'Wie lange muss ein Gast bis zum nächsten Stempel warten?',
            style: TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Schützt vor doppeltem Stempeln.',
            style: TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final option in _cooldownOptions) ...[
            _LimitOption(
              title: option.$2,
              subtitle: option.$3,
              selected: _cooldown == option.$1,
              onTap: () => setState(() => _cooldown = option.$1),
            ),
            const SizedBox(height: 8),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: MerchantPremiumColors.line),
          ),

          // ── Verfügbare Anzahl ────────────────────────────────────────
          const Text(
            'Wie viele Stempelkarten möchtest du verteilen?',
            style: TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Z. B. nur die ersten Gäste bekommen diese Karte.',
            style: TextStyle(
              color: MerchantPremiumColors.muted,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: MerchantPremiumColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MerchantPremiumColors.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded,
                    size: 18, color: MerchantPremiumColors.muted),
                const SizedBox(width: 8),
                Text(
                  '${widget.distributedCount} bisher hinzugefügt',
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _LimitOption(
            title: 'Unbegrenzt',
            subtitle: 'Jeder Gast kann die Karte bekommen',
            selected: _maxDistribution == null,
            onTap: () => setState(() {
              _maxDistribution = null;
              _customOpen = false;
            }),
          ),
          const SizedBox(height: 8),
          for (final n in _distributionPresets) ...[
            _LimitOption(
              title: '$n Karten',
              subtitle: 'Danach ist Schluss',
              selected: _maxDistribution == n,
              onTap: () => setState(() {
                _maxDistribution = n;
                _customOpen = false;
              }),
            ),
            const SizedBox(height: 8),
          ],
          _LimitOption(
            title: _customOpen ? '$_customValue Karten' : 'Eigene Zahl',
            subtitle: 'Selbst festlegen',
            selected: _customOpen,
            onTap: () => setState(() {
              _customOpen = true;
              _maxDistribution = _customValue;
            }),
          ),
          if (_customOpen) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  onTap: _customValue > 1
                      ? () => setState(() {
                            _customValue--;
                            _maxDistribution = _customValue;
                          })
                      : null,
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    '$_customValue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  onTap: () => setState(() {
                    _customValue++;
                    _maxDistribution = _customValue;
                  }),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          MerchantPrimaryButton(
            label: 'Speichern',
            onPressed: () => Navigator.of(context)
                .pop(_LimitResult(_cooldown, _maxDistribution)),
          ),
        ],
      ),
    );
  }
}

class _LimitOption extends StatelessWidget {
  const _LimitOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? MerchantPremiumColors.goldSoft
                : MerchantPremiumColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? MerchantPremiumColors.gold
                  : MerchantPremiumColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected
                            ? MerchantPremiumColors.mint
                            : MerchantPremiumColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? MerchantPremiumColors.gold
                    : MerchantPremiumColors.muted,
              ),
            ],
          ),
        ),
      ),
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
          width: 52,
          height: 52,
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
            size: 24,
            color: enabled
                ? MerchantPremiumColors.ink
                : MerchantPremiumColors.muted,
          ),
        ),
      ),
    );
  }
}

/// Lokale, kostenlose Hinweistexte (kein Credit-/Preis-Bezug mehr).
const String kStampPublishMessage =
    'Nach der Bestätigung wird die Karte sofort für deine Kundinnen und Kunden aktiv.';

/// Swipeable one-card-per-screen preview with a 1/n pager. Rein visuell — die
/// Aktionsleiste liegt fest AUSSERHALB (siehe `_ActionPanel`).
class _StampCarousel extends StatefulWidget {
  const _StampCarousel({
    required this.cards,
    required this.index,
    required this.onIndexChanged,
  });

  final List<StampCardModel> cards;
  final int index;
  final void Function(int) onIndexChanged;

  @override
  State<_StampCarousel> createState() => _StampCarouselState();
}

class _StampCarouselState extends State<_StampCarousel> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.cards.length,
                onPageChanged: widget.onIndexChanged,
                itemBuilder: (context, i) =>
                    MerchantStampCard(card: widget.cards[i]),
              ),
              if (widget.index < widget.cards.length - 1)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 8,
                  child: Center(
                    child: SwipeHint(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
                ),
              if (widget.index > 0)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 8,
                  child: Center(
                    child: SwipeHint(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (widget.cards.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.cards.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == widget.index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == widget.index
                        ? MerchantPremiumColors.gold
                        : MerchantPremiumColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          '${widget.index + 1}/${widget.cards.length}',
          style: const TextStyle(
            color: MerchantPremiumColors.muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

void _showCapReached(BuildContext context, LanguageService texts) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_rounded,
                color: MerchantPremiumColors.gold, size: 40),
            const SizedBox(height: 12),
            Text(
              texts.text('merchant.stamps.capReachedTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              texts.text('merchant.stamps.capReachedBody'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: MerchantPremiumColors.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.35),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(ctx).maybePop(),
              style: FilledButton.styleFrom(
                backgroundColor: MerchantPremiumColors.ink,
                foregroundColor: MerchantPremiumColors.base,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(texts.text('common.ok')),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmAction(
  BuildContext context, {
  required String titleKey,
  String? messageKey,
  String? message,
  required String confirmKey,
  required Future<void> Function() onConfirm,
  bool isDanger = false,
}) async {
  final texts = context.read<LanguageService>();
  final resolvedMessage =
      message ?? (messageKey != null ? texts.text(messageKey) : '');
  final accepted = await showModalBottomSheet<bool>(
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
              texts.text(titleKey),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              resolvedMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: isDanger
                    ? MerchantPremiumColors.danger
                    : MerchantPremiumColors.ink,
                foregroundColor:
                    isDanger ? Colors.white : MerchantPremiumColors.base,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(texts.text(confirmKey)),
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

  if (accepted != true || !context.mounted) return;
  await onConfirm();
}
