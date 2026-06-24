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

class _MerchantStampsView extends StatefulWidget {
  const _MerchantStampsView();

  @override
  State<_MerchantStampsView> createState() => _MerchantStampsViewState();
}

class _MerchantStampsViewState extends State<_MerchantStampsView> {
  // Index of the card visible in the pager — the stick setup targets THIS card.
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantStampsProvider>();
    final cards = provider.cards;
    final clamped = cards.isEmpty ? 0 : _index.clamp(0, cards.length - 1);
    final targetCard = cards.isEmpty ? null : cards[clamped];

    return MerchantToolScaffold(
      title: texts.text('merchant.stamps.title'),
      subtitle: texts.text('merchant.stamps.subtitle'),
      backPath: '/merchant/dashboard',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.stamps.tooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopActions(
            provider: provider,
            texts: texts,
            onCreate: () => _create(context, provider),
            // Setup always targets the currently visible pager card.
            onSetup: targetCard == null
                ? null
                : () => startStickSetup(
                      context,
                      card: targetCard,
                      functions: StampFunctionsService(),
                      onChanged: provider.load,
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
              onIndexChanged: (i) => setState(() => _index = i),
              onEdit: (card) => context.push('/merchant/stamps/edit/${card.id}'),
              onPublish: (card) => _publishCapped(context, provider, card),
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

  Future<void> _publishCapped(
      BuildContext context, MerchantStampsProvider provider, StampCardModel card) async {
    // Publishing a draft does not increase the non-archived count (a draft
    // already counts), so the cap only blocks NEW cards/duplicates, not publish.
    await _publish(context, card);
  }

  Future<void> _publish(BuildContext context, StampCardModel card) async {
    final provider = context.read<MerchantStampsProvider>();
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
}

/// Lokale, kostenlose Hinweistexte (kein Credit-/Preis-Bezug mehr).
const String kStampPublishMessage =
    'Nach der Bestätigung wird die Karte sofort für deine Kundinnen und Kunden aktiv.';

/// Top of the manage screen: the 3-card cap indicator, plus the two actions —
/// create a card and set up the stamp stick for the visible card.
class _TopActions extends StatelessWidget {
  const _TopActions({
    required this.provider,
    required this.texts,
    required this.onCreate,
    required this.onSetup,
  });

  final MerchantStampsProvider provider;
  final LanguageService texts;
  final VoidCallback onCreate;

  /// Null when there is no card to bind a stick to (disables the button).
  final VoidCallback? onSetup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 3/3 cap — always visible, never hidden.
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: provider.atCap
                  ? MerchantPremiumColors.danger.withValues(alpha: 0.14)
                  : MerchantPremiumColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: provider.atCap
                    ? MerchantPremiumColors.danger.withValues(alpha: 0.5)
                    : MerchantPremiumColors.line,
              ),
            ),
            child: Text(
              texts
                  .text('merchant.stamps.cap')
                  .replaceFirst('{n}', '${provider.activeCount}')
                  .replaceFirst('{max}', '${MerchantStampsProvider.maxActiveCards}'),
              style: TextStyle(
                color: provider.atCap
                    ? MerchantPremiumColors.danger
                    : MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        MerchantPrimaryButton(
          label: texts.text('merchant.stamps.create'),
          icon: Icons.add_rounded,
          isLoading: provider.isSaving,
          onPressed: onCreate,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Single full-width action: set up the stick for the visible card.
        _SecondaryButton(
          label: texts.text('merchant.stick.setup'),
          icon: Icons.nfc_rounded,
          onTap: onSetup,
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: MerchantPremiumColors.ink,
        side: const BorderSide(color: MerchantPremiumColors.line),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Swipeable one-card-per-screen carousel with a 1/n pager.
class _StampCarousel extends StatefulWidget {
  const _StampCarousel({
    required this.cards,
    required this.onEdit,
    required this.onPublish,
    required this.onPause,
    required this.onDelete,
    required this.onIndexChanged,
  });

  final List<StampCardModel> cards;
  final void Function(StampCardModel) onEdit;
  final void Function(StampCardModel) onPublish;
  final void Function(StampCardModel) onPause;
  final void Function(StampCardModel) onDelete;
  final void Function(int) onIndexChanged;

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
    // Clamp the index if the list shrank (e.g. after archive/delete).
    if (_index >= widget.cards.length) {
      _index = widget.cards.length - 1;
    }
    return Column(
      children: [
        SizedBox(
          height: 560,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.cards.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onIndexChanged(i);
            },
            itemBuilder: (context, i) {
              final card = widget.cards[i];
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: MerchantStampCard(
                  card: card,
                  onEdit: () => widget.onEdit(card),
                  onPublish: () => widget.onPublish(card),
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
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
  final resolvedMessage = message ?? (messageKey != null ? texts.text(messageKey) : '');
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
                backgroundColor: isDanger ? MerchantPremiumColors.danger : MerchantPremiumColors.ink,
                foregroundColor: isDanger ? Colors.white : MerchantPremiumColors.base,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
