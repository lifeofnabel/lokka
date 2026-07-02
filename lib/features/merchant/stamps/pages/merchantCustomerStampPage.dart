import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../../core/widgets/appPillSwitch.dart' show kAppMaxWidth;
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../../stamps/services/stampFunctionsService.dart';
import '../../../user/wallet/utils/walletCode.dart';

/// Reached after the merchant scans a customer's wallet QR. Shows that customer's
/// stamp cards (this merchant), lets staff add stamps (+1 default, long-press for
/// a bigger order) and mark earned rewards as used. Speed-first: big targets,
/// minimal taps, readable across the counter.
class MerchantCustomerStampPage extends StatefulWidget {
  const MerchantCustomerStampPage({
    super.key,
    required this.customerUid,
    required this.merchantId,
    this.functions,
  });

  final String customerUid;
  final String merchantId;
  final StampFunctionsService? functions;

  @override
  State<MerchantCustomerStampPage> createState() =>
      _MerchantCustomerStampPageState();
}

class _MerchantCustomerStampPageState extends State<MerchantCustomerStampPage> {
  late final StampFunctionsService _fn =
      widget.functions ?? StampFunctionsService();

  MerchantCustomerView? _view;
  bool _loading = true;
  String? _error;
  String? _busyCardId; // a stamp/redeem op is in flight for this card/reward

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final view = await _fn.merchantLoadCustomer(widget.customerUid);
      if (!mounted) return;
      setState(() {
        _view = view;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final code = stampErrorCode(e);
      setState(() {
        _error = context.read<LanguageService>().text(stampErrorKey(e)) +
            (code.isEmpty ? '' : '  ($code)');
        _loading = false;
      });
    }
  }

  Future<void> _stamp(String cardId, int delta) async {
    if (_busyCardId != null) return;
    final texts = context.read<LanguageService>();
    setState(() => _busyCardId = cardId);
    try {
      final res =
          await _fn.merchantStampCustomer(customerUid: widget.customerUid, cardId: cardId, delta: delta);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      _toast(res.completed
          ? texts.text('merchant.stampScan.cardFull')
          : texts.text('merchant.stampScan.stamped').replaceFirst('{n}', '${res.added}'));
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(texts.text(stampErrorKey(e)), error: true);
    } finally {
      if (mounted) setState(() => _busyCardId = null);
    }
  }

  Future<void> _redeem(ScanReward reward) async {
    if (_busyCardId != null) return;
    final texts = context.read<LanguageService>();
    final ok = await _confirm(
      texts.text('merchant.stampScan.redeemTitle'),
      texts.text('merchant.stampScan.redeemBody').replaceFirst('{reward}', reward.label),
      texts.text('merchant.stampScan.redeemConfirm'),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyCardId = reward.id);
    try {
      await _fn.merchantRedeemReward(customerUid: widget.customerUid, rewardId: reward.id);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      _toast(texts.text('merchant.stampScan.redeemed'));
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(texts.text(stampErrorKey(e)), error: true);
    } finally {
      if (mounted) setState(() => _busyCardId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final view = _view;
    return Scaffold(
      backgroundColor: MerchantPremiumColors.base,
      appBar: AppBar(
        backgroundColor: MerchantPremiumColors.base,
        foregroundColor: MerchantPremiumColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
            (view?.customerName.trim().isNotEmpty ?? false)
                ? view!.customerName.trim()
                : texts.text('merchant.stampScan.customerFallback'),
            style: const TextStyle(
                color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        // Handy-Breite wie der Rest des Merchant-Bereichs (kein
        // MerchantToolScaffold hier wegen des dynamischen Kunden-Titels).
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kAppMaxWidth),
            child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: MerchantPremiumColors.gold))
            : _error != null
                ? _ErrorBox(message: _error!, onRetry: _load)
                : view == null
                    ? const SizedBox.shrink()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: MerchantPremiumColors.gold,
                        backgroundColor: MerchantPremiumColors.surface,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          children: [
                            _CustomerHeader(view: view),
                            if (view.rewards.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _SectionLabel(
                                  text: texts.text('merchant.stampScan.rewardsLabel')),
                              const SizedBox(height: AppSpacing.sm),
                              ...view.rewards.map((r) => _RewardRow(
                                    reward: r,
                                    busy: _busyCardId == r.id,
                                    onRedeem: () => _redeem(r),
                                  )),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            _SectionLabel(
                                text: texts.text('merchant.stampScan.cardsLabel')),
                            const SizedBox(height: AppSpacing.sm),
                            if (view.cards.isEmpty)
                              _EmptyCards(texts: texts)
                            else
                              ...view.cards.map((c) {
                                final p = view.progress[c.id];
                                return _CardRow(
                                  card: c,
                                  current: p?.currentStamps ?? 0,
                                  busy: _busyCardId == c.id,
                                  onStampOne: () => _stamp(c.id, 1),
                                  onStampMany: () => _askMany(c),
                                );
                              }),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Future<void> _askMany(ScanCard card) async {
    final texts = context.read<LanguageService>();
    final n = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: MerchantPremiumColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                texts.text('merchant.stampScan.manyTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [2, 3, 4, 5, 10]
                    .map((v) => SizedBox(
                          width: 64,
                          height: 56,
                          child: FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(v),
                            style: FilledButton.styleFrom(
                              backgroundColor: MerchantPremiumColors.surfaceAlt,
                              foregroundColor: MerchantPremiumColors.ink,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text('+$v',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 18)),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (n != null) await _stamp(card.id, n);
  }

  Future<bool?> _confirm(String title, String body, String confirm) {
    final texts = context.read<LanguageService>();
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: MerchantPremiumColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.sm),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.35)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: MerchantPremiumColors.gold,
                  foregroundColor: MerchantPremiumColors.base,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(confirm),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(texts.text('common.cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          error ? MerchantPremiumColors.danger : MerchantPremiumColors.surfaceAlt,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

String _initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '🙂';
  return parts.take(2).map((w) => w[0].toUpperCase()).join();
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.view});
  final MerchantCustomerView view;

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final name = view.customerName.trim();
    final meta = <String>[
      if (view.postalCode.trim().isNotEmpty) 'PLZ ${view.postalCode.trim()}',
      if (view.followedAt != null)
        '${texts.text('merchant.stampScan.followsSince')} ${_date(view.followedAt!)}',
    ];
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: name, photoUrl: view.photoUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        name.isEmpty
                            ? texts.text('merchant.stampScan.customerFallback')
                            : name,
                        style: const TextStyle(
                            color: MerchantPremiumColors.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                    if (view.walletCode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(WalletCode.pretty(view.walletCode),
                          style: const TextStyle(
                              color: MerchantPremiumColors.muted,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(meta.join('  ·  '),
                style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
          if (view.interests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  view.interests.take(6).map((i) => _MetaChip(label: i)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl});
  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 28,
      backgroundColor: MerchantPremiumColors.gold,
      child: Text(_initialsOf(name),
          style: const TextStyle(
              color: MerchantPremiumColors.base,
              fontWeight: FontWeight.w900,
              fontSize: 18)),
    );
    if (photoUrl.trim().isEmpty) return fallback;
    return ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          memCacheWidth: 160,
          errorWidget: (context, url, error) => fallback,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Text(label,
          style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.current,
    required this.busy,
    required this.onStampOne,
    required this.onStampMany,
  });

  final ScanCard card;
  final int current;
  final bool busy;
  final VoidCallback onStampOne;
  final VoidCallback onStampMany;

  @override
  Widget build(BuildContext context) {
    final full = current >= card.maxStamps && card.maxStamps > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MerchantPremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: 22,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.title,
                      style: const TextStyle(
                          color: MerchantPremiumColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('$current / ${card.maxStamps}',
                      style: const TextStyle(
                          color: MerchantPremiumColors.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Big +1 target; long-press for a bigger order (+N).
            GestureDetector(
              onLongPress: full || busy ? null : onStampMany,
              child: SizedBox(
                width: 84,
                height: 64,
                child: FilledButton(
                  onPressed: full || busy ? null : onStampOne,
                  style: FilledButton.styleFrom(
                    backgroundColor: full
                        ? MerchantPremiumColors.surfaceAlt
                        : MerchantPremiumColors.gold,
                    foregroundColor: MerchantPremiumColors.base,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MerchantPremiumColors.base))
                      : Text(full ? '✓' : '+1',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 22)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.reward,
    required this.busy,
    required this.onRedeem,
  });

  final ScanReward reward;
  final bool busy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MerchantPremiumColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded,
                color: MerchantPremiumColors.gold, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(reward.label,
                  style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: busy ? null : onRedeem,
              style: FilledButton.styleFrom(
                backgroundColor: MerchantPremiumColors.ink,
                foregroundColor: MerchantPremiumColors.base,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: MerchantPremiumColors.base))
                  : Text(context.read<LanguageService>()
                      .text('merchant.stampScan.markUsed')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: MerchantPremiumColors.muted,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.4));
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.texts});
  final LanguageService texts;
  @override
  Widget build(BuildContext context) => MerchantPremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        radius: 22,
        child: Column(
          children: [
            const Icon(Icons.loyalty_outlined,
                color: MerchantPremiumColors.muted, size: 36),
            const SizedBox(height: 10),
            Text(texts.text('merchant.stampScan.noCards'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final texts = context.read<LanguageService>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: MerchantPremiumColors.danger, size: 40),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: MerchantPremiumColors.gold,
                foregroundColor: MerchantPremiumColors.base,
              ),
              child: Text(texts.text('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}
