import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/merchant/stamps/models/stampCardModel.dart';
import 'package:lokka/features/stamps/services/stampFunctionsService.dart';
import 'package:lokka/features/stamps/widgets/stampCardVisual.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/partners/pages/userPartnerStampsPage.dart';
import 'package:lokka/features/user/shared/widgets/quickActionBar.dart';
import 'package:lokka/features/user/wallet/models/earnedRewardModel.dart';
import 'package:lokka/features/user/wallet/models/stampProgressModel.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';
import 'package:lokka/features/user/wallet/utils/cityShorten.dart';
import 'package:lokka/features/user/wallet/utils/walletCode.dart';

/// Opens the store's cards as an Apple-Wallet-style stack that **grows** out of
/// the tapped card (scale + fade), instead of pushing a separate page.
void openWalletCardStack(BuildContext context, WalletCardModel card, String uid) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 210),
      pageBuilder: (context, animation, secondaryAnimation) =>
          WalletCardExpanded(card: card, uid: uid),
      transitionsBuilder: (context, anim, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// The expanded store view: a vertically swipeable stack of cards belonging to
/// ONE store — the store card (with QR + quick actions), one card per ADDED
/// stamp card, and one card per points system (only when the merchant offers it
/// and the user follows). Cards slightly overlap so you can swipe up/down.
class WalletCardExpanded extends StatefulWidget {
  const WalletCardExpanded({super.key, required this.card, required this.uid});

  final WalletCardModel card;
  final String uid;

  @override
  State<WalletCardExpanded> createState() => _WalletCardExpandedState();
}

class _WalletCardExpandedState extends State<WalletCardExpanded> {
  late final UserWalletService _service;
  final _fn = StampFunctionsService();
  final _ctrl = PageController(viewportFraction: 0.88);
  final Set<String> _busy = {};

  PublicMerchantUserModel? _merchant;
  List<StampCardModel> _activeCards = const [];
  bool _pointsEnabled = false;
  bool _loading = true;
  int _page = 0;

  String get _mid => widget.card.merchantId;
  String get _qrData =>
      'lokka://wallet/${widget.uid}/$_mid/${widget.card.walletCode}';

  @override
  void initState() {
    super.initState();
    _service = UserWalletService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
    _ctrl.addListener(() {
      final p = _ctrl.page?.round() ?? 0;
      if (p != _page) setState(() => _page = p);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final merchant = await _service.loadMerchant(_mid);
      final cards = await _service.loadActiveStampCards(_mid);
      final points = await _service.loadPointsEnabled(_mid);
      if (!mounted) return;
      setState(() {
        _merchant = merchant;
        _activeCards = cards;
        _pointsEnabled = points;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : StreamBuilder<WalletCardModel?>(
                      stream: _service.walletCardStream(_mid),
                      initialData: widget.card,
                      builder: (context, walletSnap) {
                        final added =
                            (walletSnap.data ?? widget.card).addedStampCardIds.toSet();
                        return StreamBuilder<List<StampProgressModel>>(
                          stream: _service.stampProgressByMerchantStream(_mid),
                          builder: (context, progSnap) {
                            final progress = <String, StampProgressModel>{
                              for (final p
                                  in progSnap.data ?? const <StampProgressModel>[])
                                p.stampCardId: p,
                            };
                            return _stack(added, progress);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    // Minimal: a centred grab handle + a single close button. The store identity
    // lives on the card itself — no duplicated name, no text bleeding over the dim.
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, 2),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stack(Set<String> added, Map<String, StampProgressModel> progress) {
    final addedCards =
        _activeCards.where((c) => added.contains(c.id)).toList();

    final panes = <Widget>[
      _Pane(child: _StorePane(
        card: widget.card,
        merchant: _merchant,
        qrData: _qrData,
        actions: _quickActions(),
        onEnlarge: _openFullscreen,
      )),
      for (final c in addedCards)
        _Pane(
          child: _StampPane(
            service: _service,
            merchantId: _mid,
            card: c,
            progress: progress[c.id],
            busy: _busy.contains(c.id),
            onRemoveCard: () => _removeCard(c),
            onClaim: () => _claim(c),
          ),
        ),
      if (addedCards.isEmpty)
        _Pane(child: _HintPane(onVisit: _openMerchantStamps)),
      if (_pointsEnabled) const _Pane(child: _PointsPane()),
    ];

    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _ctrl,
            children: panes,
          ),
        ),
        // Position dots — easy to grasp there are more cards to swipe.
        if (panes.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < panes.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _page == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: _page == i ? 0.95 : 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Stamp mutations (server-authored) ──────────────────────────────────────
  Future<void> _run(String cardId, Future<void> Function() action) async {
    if (_busy.contains(cardId)) return;
    setState(() => _busy.add(cardId));
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy.remove(cardId));
    }
  }

  /// Removes the whole card from the wallet — asks first. Collected stamps stay
  /// server-side, so re-adding the card later restores them.
  Future<void> _removeCard(StampCardModel card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Karte entfernen?'),
        content: const Text(
          'Diese Stempelkarte wird aus deiner Wallet entfernt. Deine '
          'gesammelten Stempel bleiben erhalten, falls du sie später wieder '
          'hinzufügst.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Entfernen')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(card.id, () async {
      await _service.removeStampCardFromWallet(_mid, card.id);
      if (mounted) _snack('Karte entfernt');
    });
  }

  Future<void> _claim(StampCardModel card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Belohnung einlösen'),
        content: const Text(
          'Deine Karte ist voll. Löse die Belohnung ein – sie wandert in '
          '„Verdiente Belohnungen" und die Karte startet neu.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Einlösen')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(card.id, () async {
      await _fn.claimReward(merchantId: _mid, cardId: card.id);
      if (mounted) _snack('Belohnung gesichert! 🎉');
    });
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('unavailable') ||
        s.contains('not-found') ||
        s.contains('not_found') ||
        s.contains('internal')) {
      return 'Server gerade nicht erreichbar. Bitte später erneut versuchen.';
    }
    if (s.contains('card-full')) return 'Die Karte ist bereits voll.';
    if (s.contains('not-completed')) return 'Die Karte ist noch nicht voll.';
    return 'Hat nicht geklappt. Bitte versuche es erneut.';
  }

  // ── Quick actions ──────────────────────────────────────────────────────────
  List<QuickAction> _quickActions() {
    final m = _merchant;
    final hasRoute = m != null && (m.address.isNotEmpty || m.hasCoordinates);
    final hasHours = m != null && (m.openingHours?.isNotEmpty ?? false);
    final hasPhone = m != null && m.phone.trim().isNotEmpty;
    final hasSocial = m != null && m.socialLinks.isNotEmpty;
    return [
      QuickAction(
          icon: Icons.near_me_rounded,
          label: 'Route',
          enabled: hasRoute,
          onTap: hasRoute ? _openRoute : null),
      QuickAction(
          icon: Icons.schedule_rounded,
          label: 'Zeiten',
          enabled: hasHours,
          onTap: hasHours ? _openHours : null),
      QuickAction(
          icon: Icons.call_rounded,
          label: 'Anrufen',
          enabled: hasPhone,
          onTap: hasPhone ? _call : null),
      QuickAction(
          icon: Icons.alternate_email_rounded,
          label: 'Social',
          enabled: hasSocial,
          onTap: hasSocial ? _openSocial : null),
    ];
  }

  Future<void> _openRoute() async {
    final m = _merchant;
    if (m == null) return;
    final query = m.hasCoordinates
        ? '${m.lat},${m.lng}'
        : Uri.encodeComponent(
            m.fullAddress.isNotEmpty ? m.fullAddress : m.address);
    await _launch(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
        external: true,
        fail: 'Karten-App konnte nicht geöffnet werden');
  }

  Future<void> _call() async {
    final phone = _merchant?.phone.trim() ?? '';
    if (phone.isEmpty) return;
    await _launch(Uri.parse('tel:$phone'), external: false, fail: 'Anruf nicht möglich');
  }

  Future<void> _launch(Uri uri,
      {required bool external, required String fail}) async {
    try {
      await launchUrl(uri,
          mode: external
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault);
    } catch (_) {
      _snack(fail);
    }
  }

  void _openHours() {
    final hours = _merchant?.openingHours ?? const <String, dynamic>{};
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBg,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: _HoursSheet(hours: Map<String, dynamic>.from(hours)),
      ),
    );
  }

  void _openSocial() {
    final links = _merchant?.socialLinks ?? const <String, String>{};
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBg,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: _SocialSheet(
          links: links,
          onOpen: (url) {
            var u = url.trim();
            if (u.isEmpty) return;
            if (!u.startsWith('http')) u = 'https://$u';
            final uri = Uri.tryParse(u);
            if (uri != null) {
              _launch(uri,
                  external: true, fail: 'Link konnte nicht geöffnet werden');
            }
          },
        ),
      ),
    );
  }

  void _openMerchantStamps() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPartnerStampsPage(
          merchantId: _mid,
          shopName: widget.card.merchantName,
          merchant: _merchant,
        ),
      ),
    );
  }

  void _openFullscreen() {
    final pretty = WalletCode.pretty(widget.card.walletCode);
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      barrierLabel: 'QR',
      pageBuilder: (ctx, animation, secondaryAnimation) {
        final w = MediaQuery.of(ctx).size.width;
        final qrSize = (w * 0.62).clamp(200.0, 300.0);
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: QrImageView(
                        data: _qrData, version: QrVersions.auto, size: qrSize),
                  ),
                  const SizedBox(height: 16),
                  Text(pretty,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      )),
                  const SizedBox(height: 8),
                  Text('Zum Schließen tippen',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// A single card in the vertical stack — rounded surface with a soft shadow and
/// internal scroll so tall content fits the peeking viewport.
class _Pane extends StatelessWidget {
  const _Pane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Card sizes to its content and floats vertically centred (Apple-Wallet
    // feel) — no dead space below. Scrolls only when content exceeds the height.
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBg,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Store pane ────────────────────────────────────────────────────────────────
class _StorePane extends StatelessWidget {
  const _StorePane({
    required this.card,
    required this.merchant,
    required this.qrData,
    required this.actions,
    required this.onEnlarge,
  });

  final WalletCardModel card;
  final PublicMerchantUserModel? merchant;
  final String qrData;
  final List<QuickAction> actions;
  final VoidCallback onEnlarge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final logo = (merchant?.logoUrl.isNotEmpty ?? false)
        ? merchant!.logoUrl
        : card.merchantLogoUrl;
    final name = card.merchantName.isEmpty ? 'Partner' : card.merchantName;
    final city = card.merchantCity.trim();
    final category = (merchant?.shopType.trim().isNotEmpty ?? false)
        ? merchant!.shopType.trim()
        : card.merchantShopType.trim();
    // Shorten long Hessen cities (e.g. "Frankfurt am Main" → "FFM") so the meta
    // line doesn't get truncated.
    final metaCity = city.length > 14 ? HessenCity.shorten(city) : city;
    final meta = [category, metaCity].where((s) => s.isNotEmpty).join('  ·  ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Clean identity row — logo + name + one line of meta. No cover noise.
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: logo.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: logo,
                      fit: BoxFit.cover,
                      memCacheWidth: 140,
                      errorWidget: (context, url, error) => const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.green, size: 22),
                    )
                  : const Icon(Icons.storefront_rounded,
                      color: AppColors.green, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        // Hero QR — white, rounded, soft shadow (no thin technical border).
        GestureDetector(
          onTap: onEnlarge,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: QrImageView(
                data: qrData, version: QrVersions.auto, size: 196),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: onEnlarge,
          icon: const Icon(Icons.fullscreen_rounded, size: 18),
          label: const Text('Vergrößern'),
          style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        _CodeChip(pretty: WalletCode.pretty(card.walletCode)),
        const SizedBox(height: AppSpacing.xl),
        QuickActionBar(actions: actions),
      ],
    );
  }
}

// ── Stamp pane (one per added card) ──────────────────────────────────────────
class _StampPane extends StatelessWidget {
  const _StampPane({
    required this.service,
    required this.merchantId,
    required this.card,
    required this.progress,
    required this.busy,
    required this.onRemoveCard,
    required this.onClaim,
  });

  final UserWalletService service;
  final String merchantId;
  final StampCardModel card;
  final StampProgressModel? progress;
  final bool busy;
  final VoidCallback onRemoveCard;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final max = card.maxStamps;
    final current = progress?.currentStamps ?? 0;
    final completed = current >= max;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StampCardVisual(card: card, filledStamps: current),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text('$current / $max Stempel',
                  style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700, color: cs.onSurface)),
            ),
            if (completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('Voll',
                    style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSecondaryContainer)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (busy)
          const SizedBox(
            height: 48,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          )
        else if (current == 0)
          Row(
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
          )
        else if (completed)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onClaim,
              icon: const Icon(Icons.redeem_rounded),
              label: const Text('Belohnung einlösen'),
            ),
          ),
        // This card's earned rewards.
        StreamBuilder<List<EarnedRewardModel>>(
          stream: service.earnedRewardsByMerchantStream(merchantId),
          builder: (context, snap) {
            final rewards = (snap.data ?? const <EarnedRewardModel>[])
                .where((r) => r.cardId == card.id)
                .toList();
            if (rewards.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text('Verdiente Belohnungen',
                    style:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                for (final r in rewards)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.mintSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.greenLine),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded,
                            color: AppColors.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(r.label.isEmpty ? 'Belohnung' : r.label,
                              style: tt.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        Text('Bereit',
                            style: tt.labelSmall?.copyWith(
                                color: AppColors.greenDeep,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        // Quiet footer: remove the whole card from the wallet (asks first).
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton.icon(
            onPressed: busy ? null : onRemoveCard,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Karte entfernen'),
            style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ── Hint pane (nothing added yet) ────────────────────────────────────────────
class _HintPane extends StatelessWidget {
  const _HintPane({required this.onVisit});

  final VoidCallback onVisit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.add_card_rounded, size: 44, color: cs.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Text('Noch keine Stempelkarte hinzugefügt',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Besuche die Seite dieses Partners und schau, welche Stempelkarten du '
          'hinzufügen kannst. Danach erscheinen sie hier.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: onVisit,
          icon: const Icon(Icons.storefront_rounded, size: 18),
          label: const Text('Zur Partner-Seite'),
        ),
      ],
    );
  }
}

// ── Points pane (reserved placeholder) ───────────────────────────────────────
class _PointsPane extends StatelessWidget {
  const _PointsPane();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.stars_rounded,
                  color: cs.onSecondaryContainer, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('Punktesystem',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('Bald verfügbar',
                  style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onTertiaryContainer)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        IgnorePointer(
          child: Opacity(
            opacity: 0.5,
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Sammeln')),
                  ButtonSegment(value: 1, label: Text('Einlösen')),
                ],
                selected: const {0},
                showSelectedIcon: false,
                onSelectionChanged: (_) {},
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Hier sammelst du bald Punkte bei diesem Partner und löst sie gegen '
          'Belohnungen ein. Wir bauen das gerade.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.pretty});

  final String pretty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceGray,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () {
          Clipboard.setData(ClipboardData(text: pretty));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code kopiert'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pretty.isEmpty ? '—' : pretty,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.copy_rounded, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoursSheet extends StatelessWidget {
  const _HoursSheet({required this.hours});

  final Map<String, dynamic> hours;

  static const _days = [
    ('monday', 'Montag'),
    ('tuesday', 'Dienstag'),
    ('wednesday', 'Mittwoch'),
    ('thursday', 'Donnerstag'),
    ('friday', 'Freitag'),
    ('saturday', 'Samstag'),
    ('sunday', 'Sonntag'),
  ];

  String _format(dynamic value) {
    if (value is Map) {
      if (value['closed'] == true) return 'Geschlossen';
      final open = value['open']?.toString();
      final close = value['close']?.toString();
      if (open != null && close != null) return '$open – $close';
      final slots = value['slots'];
      if (slots is List && slots.isNotEmpty) {
        return slots
            .whereType<Map>()
            .map((s) => '${s['open']} – ${s['close']}')
            .join(', ');
      }
    }
    return 'Geschlossen';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final todayIdx = DateTime.now().weekday - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Öffnungszeiten',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < _days.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Text(_days[i].$2,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight:
                          i == todayIdx ? FontWeight.w700 : FontWeight.w500,
                      color: i == todayIdx ? cs.primary : cs.onSurface,
                    )),
                const Spacer(),
                Text(_format(hours[_days[i].$1]),
                    style: tt.bodyMedium?.copyWith(
                      color: i == todayIdx ? cs.primary : cs.onSurfaceVariant,
                      fontWeight:
                          i == todayIdx ? FontWeight.w700 : FontWeight.w500,
                    )),
              ],
            ),
          ),
      ],
    );
  }
}

class _SocialSheet extends StatelessWidget {
  const _SocialSheet({required this.links, required this.onOpen});

  final Map<String, String> links;
  final void Function(String url) onOpen;

  static const _meta = <(String, String, IconData)>[
    ('website', 'Website', Icons.language_rounded),
    ('instagram', 'Instagram', Icons.camera_alt_rounded),
    ('tiktok', 'TikTok', Icons.music_note_rounded),
    ('facebook', 'Facebook', Icons.facebook),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Social Media',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        for (final (key, label, icon) in _meta)
          if ((links[key] ?? '').isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.onSecondaryContainer, size: 20),
              ),
              title: Text(label,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () {
                Navigator.pop(context);
                onOpen(links[key]!);
              },
            ),
      ],
    );
  }
}
