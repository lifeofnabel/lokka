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

class _MerchantStampsView extends StatelessWidget {
  const _MerchantStampsView();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantStampsProvider>();

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
          else
            _StampCarousel(
              cards: provider.cards,
              onEdit: (card) => context.push('/merchant/stamps/edit/${card.id}'),
              onPublish: (card) => _publish(context, provider, card),
              onLimit: (card) => _setLimit(context, provider, card),
              onStick: (card) => startStickSetup(
                context,
                card: card,
                functions: StampFunctionsService(),
                onChanged: provider.load,
              ),
              onPause: (card) => _confirmAction(
                context,
                titleKey: 'merchant.stamps.pauseTitle',
                messageKey: 'merchant.stamps.pauseMessage',
                confirmKey: 'merchant.stamps.pause',
                onConfirm: () => provider.pauseCard(card.id),
              ),
              onDelete: (card) => _confirmAction(
                context,
                titleKey: 'merchant.stamps.deleteTitle',
                messageKey: 'merchant.stamps.deleteMessage',
                confirmKey: 'common.delete',
                isDanger: true,
                onConfirm: () => provider.deleteDraftCard(card.id),
              ),
            ),
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
    final seconds = await showMerchantBottomSheet<int>(
      context: context,
      builder: (_) => _LimitSheet(current: _cooldownOf(card)),
    );
    if (seconds == null || !context.mounted) return;
    await provider.setCooldown(card, seconds);
  }

  int _cooldownOf(StampCardModel card) {
    final raw = card.claimLimits['cooldownSeconds'];
    if (raw is num) return raw.round();
    return int.tryParse('${raw ?? ''}') ?? 120;
  }
}

/// „Limit setzen": schnelle Wahl der Wartezeit zwischen zwei Stempeln desselben
/// Gastes (das einzige serverseitig erzwungene Limit). Große, gut tappbare
/// Kacheln, ein Speichern-Knopf.
class _LimitSheet extends StatefulWidget {
  const _LimitSheet({required this.current});

  final int current;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  static const _options = [
    (0, 'Keine', 'Jeder Tipp zählt sofort'),
    (60, '1 Minute', 'Frühestens jede Minute'),
    (120, '2 Minuten', 'Empfohlen'),
    (300, '5 Minuten', 'Extra sicher'),
  ];

  late int _value = widget.current;

  @override
  Widget build(BuildContext context) {
    // Falls ein alter, ungewöhnlicher Wert gespeichert ist: als eigene Option zeigen.
    final hasPreset = _options.any((o) => o.$1 == _value);
    return Column(
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
        const SizedBox(height: 6),
        const Text(
          'Wie lange muss ein Gast bis zum nächsten Stempel warten? '
          'Das schützt vor doppeltem Stempeln.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MerchantPremiumColors.muted,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final option in _options) ...[
          _LimitOption(
            title: option.$2,
            subtitle: option.$3,
            selected: _value == option.$1,
            onTap: () => setState(() => _value = option.$1),
          ),
          const SizedBox(height: 8),
        ],
        if (!hasPreset)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LimitOption(
              title: '${_value ~/ 60} Minuten',
              subtitle: 'Aktuell gespeichert',
              selected: true,
              onTap: () {},
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        MerchantPrimaryButton(
          label: 'Speichern',
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
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

/// Lokale, kostenlose Hinweistexte (kein Credit-/Preis-Bezug mehr).
const String kStampPublishMessage =
    'Nach der Bestätigung wird die Karte sofort für deine Kundinnen und Kunden aktiv.';

/// Swipeable one-card-per-screen carousel with a 1/n pager.
class _StampCarousel extends StatefulWidget {
  const _StampCarousel({
    required this.cards,
    required this.onEdit,
    required this.onPublish,
    required this.onLimit,
    required this.onStick,
    required this.onPause,
    required this.onDelete,
  });

  final List<StampCardModel> cards;
  final void Function(StampCardModel) onEdit;
  final void Function(StampCardModel) onPublish;
  final void Function(StampCardModel) onLimit;
  final void Function(StampCardModel) onStick;
  final void Function(StampCardModel) onPause;
  final void Function(StampCardModel) onDelete;

  @override
  State<_StampCarousel> createState() => _StampCarouselState();
}

class _StampCarouselState extends State<_StampCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clamp the index if the list shrank (e.g. after delete).
    if (_index >= widget.cards.length) {
      _index = widget.cards.length - 1;
    }
    return Column(
      children: [
        SizedBox(
          height: 540,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.cards.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final card = widget.cards[i];
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: MerchantStampCard(
                  card: card,
                  onEdit: () => widget.onEdit(card),
                  onPublish: () => widget.onPublish(card),
                  onLimit: () => widget.onLimit(card),
                  onStick: () => widget.onStick(card),
                  onPause: () => widget.onPause(card),
                  onDelete: () => widget.onDelete(card),
                ),
              );
            },
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
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? MerchantPremiumColors.gold
                        : MerchantPremiumColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          '${_index + 1}/${widget.cards.length}',
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
