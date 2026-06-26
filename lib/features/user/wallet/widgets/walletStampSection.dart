import 'package:flutter/material.dart';

import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/merchant/stamps/models/stampCardModel.dart';
import 'package:lokka/features/stamps/services/stampFunctionsService.dart';
import 'package:lokka/features/stamps/widgets/stampCardVisual.dart';
import 'package:lokka/features/user/wallet/models/earnedRewardModel.dart';
import 'package:lokka/features/user/wallet/models/stampProgressModel.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';

/// The "Stempeln" content for one store: swipe between the store's (up to 3)
/// stamp cards with a `1/3` pager, see real progress (filled vs remaining via
/// the shared [StampCardVisual]), remove your own stamps, claim a full card and
/// see earned rewards.
///
/// The cards appear automatically because you follow the store — no "add" step.
/// Progress fills in when the merchant scans your QR. Remove/claim go through the
/// server-authored callables (the client never writes loyalty state).
class WalletStampSection extends StatefulWidget {
  const WalletStampSection({
    super.key,
    required this.service,
    required this.merchantId,
    required this.cards,
  });

  final UserWalletService service;
  final String merchantId;
  final List<StampCardModel> cards;

  @override
  State<WalletStampSection> createState() => _WalletStampSectionState();
}

class _WalletStampSectionState extends State<WalletStampSection> {
  final _fn = StampFunctionsService();
  late final PageController _ctrl;
  final Set<String> _busy = {};
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.96);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StampProgressModel>>(
      stream: widget.service.stampProgressByMerchantStream(widget.merchantId),
      builder: (context, snapshot) {
        final byCard = <String, StampProgressModel>{
          for (final p in snapshot.data ?? const <StampProgressModel>[])
            p.stampCardId: p,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 410,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: widget.cards.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) {
                  final card = widget.cards[i];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i < widget.cards.length - 1 ? 10 : 0,
                    ),
                    child: SingleChildScrollView(
                      child: _StampCardPanel(
                        card: card,
                        progress: byCard[card.id],
                        busy: _busy.contains(card.id),
                        onRemove: () => _remove(card),
                        onClaim: () => _claim(card),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.cards.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              _Pager(count: widget.cards.length, index: _page),
            ],
            _EarnedRewards(
              service: widget.service,
              merchantId: widget.merchantId,
            ),
          ],
        );
      },
    );
  }

  Future<void> _run(String cardId, Future<void> Function() action) async {
    if (_busy.contains(cardId)) return;
    setState(() => _busy.add(cardId));
    try {
      await action();
    } catch (e) {
      if (mounted) _toast(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy.remove(cardId));
    }
  }

  Future<void> _remove(StampCardModel card) => _run(card.id, () async {
        await _fn.userRemoveStamp(
            merchantId: widget.merchantId, cardId: card.id);
        if (mounted) _toast('Stempel entfernt');
      });

  Future<void> _claim(StampCardModel card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Belohnung einlösen'),
        content: const Text(
          'Deine Karte ist voll. Löse die Belohnung ein – sie wandert dann in '
          '„Verdiente Belohnungen" und die Karte startet neu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Einlösen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(card.id, () async {
      await _fn.claimReward(merchantId: widget.merchantId, cardId: card.id);
      if (mounted) _toast('Belohnung gesichert! 🎉');
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    // Server not reachable / functions not deployed yet.
    if (s.contains('unavailable') ||
        s.contains('not-found') ||
        s.contains('not_found') ||
        s.contains('internal')) {
      return 'Server gerade nicht erreichbar. Bitte später erneut versuchen.';
    }
    if (s.contains('card-full')) return 'Die Karte ist bereits voll.';
    if (s.contains('not-completed')) return 'Die Karte ist noch nicht voll.';
    if (s.contains('login') || s.contains('unauthenticated')) {
      return 'Bitte melde dich an.';
    }
    return 'Hat nicht geklappt. Bitte versuche es erneut.';
  }
}

/// One card page: the shared visual with real progress + the meta line + the
/// context-appropriate action (remove / claim / hint).
class _StampCardPanel extends StatelessWidget {
  const _StampCardPanel({
    required this.card,
    required this.progress,
    required this.busy,
    required this.onRemove,
    required this.onClaim,
  });

  final StampCardModel card;
  final StampProgressModel? progress;
  final bool busy;
  final VoidCallback onRemove;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final max = card.maxStamps;
    final current = progress?.currentStamps ?? 0;
    final completed = current >= max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StampCardVisual(card: card, filledStamps: current),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                '$current / $max Stempel',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (completed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Voll',
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _actions(context, completed: completed, current: current),
      ],
    );
  }

  Widget _actions(BuildContext context,
      {required bool completed, required int current}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (busy) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    // Never been stamped: nothing to remove — gentle hint instead.
    if (current == 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Lass dir an der Kasse mit deinem QR Stempel geben.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (completed)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onClaim,
              icon: const Icon(Icons.redeem_rounded),
              label: const Text('Belohnung einlösen'),
            ),
          ),
        if (completed) const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onRemove, // current > 0 here → safe, clamps at 0 server-side
            icon: const Icon(Icons.remove_rounded),
            label: const Text('Stempel entfernen'),
          ),
        ),
      ],
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(count, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: index == i ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: index == i ? cs.primary : cs.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
        const SizedBox(width: 10),
        Text(
          '${index + 1}/$count',
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EarnedRewards extends StatelessWidget {
  const _EarnedRewards({required this.service, required this.merchantId});

  final UserWalletService service;
  final String merchantId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return StreamBuilder<List<EarnedRewardModel>>(
      stream: service.earnedRewardsByMerchantStream(merchantId),
      builder: (context, snapshot) {
        final rewards = snapshot.data ?? const <EarnedRewardModel>[];
        if (rewards.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Verdiente Belohnungen',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...rewards.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.mintSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.greenLine),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.card_giftcard_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.label.isEmpty ? 'Belohnung' : r.label,
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (r.cardTitle.isNotEmpty)
                            Text(
                              r.cardTitle,
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Bereit',
                        style: tt.labelSmall?.copyWith(
                          color: AppColors.greenDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Zeig die Belohnung an der Kasse – das Personal löst sie ein.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}
