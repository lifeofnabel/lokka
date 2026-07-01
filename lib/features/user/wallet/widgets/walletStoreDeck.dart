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
import 'package:lokka/features/merchant/stamps/models/stampCardModel.dart';
import 'package:lokka/features/stamps/services/stampFunctionsService.dart';
import 'package:lokka/features/stamps/widgets/stampCardVisual.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';
import 'package:lokka/features/user/partners/pages/userPartnerStampsPage.dart';
import 'package:lokka/features/user/wallet/models/earnedRewardModel.dart';
import 'package:lokka/features/user/wallet/models/stampProgressModel.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';
import 'package:lokka/features/user/wallet/services/walletStoreWarmupCache.dart';
import 'package:lokka/features/user/wallet/theme/walletDesignTokens.dart';
import 'package:lokka/features/user/wallet/utils/cityShorten.dart';
import 'package:lokka/features/user/wallet/utils/walletCode.dart';
import 'package:lokka/features/user/wallet/widgets/walletEmptyLoyaltyCard.dart';
import 'package:lokka/features/user/wallet/widgets/walletMerchantActionRow.dart';
import 'package:lokka/features/user/wallet/widgets/walletMerchantSheets.dart';

/// One store's vertical "peek deck": the main store card fills the whole
/// available height; the top edge of the NEXT card (a stamp card, points, or
/// the empty-loyalty hint) peeks in below it. Swiping up brings the next card
/// fully into view — covering the previous one — while the card after THAT
/// begins to peek. Built on a [PageView] with `viewportFraction < 1`, which
/// gives exactly this "current fills the view, next peeks below" behaviour for
/// free, with no custom animation code.
class WalletStoreDeck extends StatefulWidget {
  const WalletStoreDeck({super.key, required this.card, required this.uid});

  final WalletCardModel card;
  final String uid;

  @override
  State<WalletStoreDeck> createState() => _WalletStoreDeckState();
}

class _WalletStoreDeckState extends State<WalletStoreDeck> {
  late final UserWalletService _service;
  final _fn = StampFunctionsService();
  PageController? _deckCtrl;
  final Set<String> _busy = {};

  PublicMerchantUserModel? _merchant;
  List<StampCardModel> _activeCards = const [];
  bool _pointsEnabled = false;
  bool _loading = true;

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
    _load();
  }

  Future<void> _load() async {
    try {
      // Cache-first (siehe WalletStoreWarmupCache): war diese Karte schon
      // sichtbar oder von der Nachbarkarte vorab geladen, ist das hier sofort
      // fertig statt 3 sequenzielle Reads blockierend zu warten.
      final entry = await WalletStoreWarmupCache.warm(_mid, service: _service);
      if (!mounted) return;
      setState(() {
        _merchant = entry.merchant;
        _activeCards = entry.activeCards;
        _pointsEnabled = entry.pointsEnabled;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _deckCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<WalletCardModel?>(
      stream: _service.walletCardStream(_mid),
      initialData: widget.card,
      builder: (context, walletSnap) {
        final added =
            (walletSnap.data ?? widget.card).addedStampCardIds.toSet();
        return StreamBuilder<List<StampProgressModel>>(
          stream: _service.stampProgressByMerchantStream(_mid),
          builder: (context, progSnap) {
            final progress = <String, StampProgressModel>{
              for (final p in progSnap.data ?? const <StampProgressModel>[])
                p.stampCardId: p,
            };
            return _deck(added, progress);
          },
        );
      },
    );
  }

  Widget _deck(Set<String> added, Map<String, StampProgressModel> progress) {
    final addedCards = _activeCards.where((c) => added.contains(c.id)).toList();

    final pages = <Widget>[
      _MainStoreCard(
        card: widget.card,
        merchant: _merchant,
        qrData: _qrData,
        actions: _quickActions(),
        onEnlarge: _openFullscreen,
        onOpenMerchant: _openMerchantProfile,
      ),
      if (addedCards.isEmpty)
        _DeckPage(
          child: Center(
            child: EmptyLoyaltyCard(
              merchantName: widget.card.merchantName,
              offersProgramme: _activeCards.isNotEmpty,
              onVisitProfile: _openMerchantStamps,
            ),
          ),
        )
      else
        for (final c in addedCards)
          _DeckPage(
            child: _StampFullCard(
              card: c,
              progress: progress[c.id],
              busy: _busy.contains(c.id),
              onRemoveCard: () => _removeCard(c),
              onClaim: () => _claim(c),
              earnedRewards: _service.earnedRewardsByMerchantStream(_mid),
            ),
          ),
      if (_pointsEnabled)
        const _DeckPage(child: _PointsFullCard()),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        const peek = 58.0;
        final vf = h <= peek ? 1.0 : ((h - peek) / h).clamp(0.5, 1.0);
        _deckCtrl ??= PageController(viewportFraction: vf);
        return PageView.builder(
          controller: _deckCtrl,
          scrollDirection: Axis.vertical,
          physics: const _DeckPhysics(),
          itemCount: pages.length,
          itemBuilder: (context, i) => pages[i],
        );
      },
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
  List<MerchantAction> _quickActions() {
    final m = _merchant;
    final hasRoute = m != null && (m.address.isNotEmpty || m.hasCoordinates);
    final hasHours = m != null && (m.openingHours?.isNotEmpty ?? false);
    final hasPhone = m != null && m.phone.trim().isNotEmpty;
    final hasSocial = m != null && m.socialLinks.isNotEmpty;
    return [
      if (hasRoute)
        MerchantAction(
            icon: Icons.near_me_rounded, label: 'Route', onTap: _openRoute),
      if (hasHours)
        MerchantAction(
            icon: Icons.schedule_rounded, label: 'Zeiten', onTap: _openHours),
      if (hasPhone)
        MerchantAction(
            icon: Icons.call_rounded, label: 'Anrufen', onTap: _call),
      if (hasSocial)
        MerchantAction(
            icon: Icons.public_rounded, label: 'Social', onTap: _openSocial),
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
    await _launch(Uri.parse('tel:$phone'),
        external: false, fail: 'Anruf nicht möglich');
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

  void _openHours() =>
      showHoursSheet(context, _merchant?.openingHours ?? const {});

  void _openSocial() {
    showSocialSheet(context, _merchant?.socialLinks ?? const {}, (url) {
      var u = url.trim();
      if (u.isEmpty) return;
      if (!u.startsWith('http')) u = 'https://$u';
      final uri = Uri.tryParse(u);
      if (uri != null) {
        _launch(uri, external: true, fail: 'Link konnte nicht geöffnet werden');
      }
    });
  }

  /// Tapping the merchant's photo or name opens their public profile.
  void _openMerchantProfile() {
    final m = _merchant;
    if (m == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserPartnerDetailPage(merchant: m)),
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
    final name = widget.card.merchantName;
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      barrierLabel: 'QR',
      pageBuilder: (ctx, animation, secondaryAnimation) {
        final w = MediaQuery.of(ctx).size.width;
        final qrSize = (w * 0.6).clamp(190.0, 280.0);
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (name.isNotEmpty) ...[
                    Text(name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 18),
                  ],
                  // One combined card: QR on top, code chip integrated below —
                  // reads as a single "pass", not two disconnected elements.
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                            data: _qrData, version: QrVersions.auto, size: qrSize),
                        const SizedBox(height: 16),
                        _FullscreenCodeChip(pretty: pretty),
                      ],
                    ),
                  ),
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

/// A touch snappier spring than the default so the deck settles cleanly on
/// one card instead of overshooting into the next peek.
class _DeckPhysics extends PageScrollPhysics {
  const _DeckPhysics({super.parent});

  @override
  _DeckPhysics applyTo(ScrollPhysics? ancestor) =>
      _DeckPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.5, stiffness: 130, damping: 20);
}

/// Shared rounded/shadowed shell for every non-main deck page, with internal
/// scrolling so content NEVER overflows a slot, however tall or short the
/// device viewport is (this is what fixes the previous overflow bug).
class _DeckPage extends StatelessWidget {
  const _DeckPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          WalletTokens.md, 0, WalletTokens.md, WalletTokens.sm),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(WalletTokens.cardRadius),
          boxShadow: WalletTokens.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(WalletTokens.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: c.maxHeight - WalletTokens.lg * 2),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main store card — the cover photo is fully, prominently visible; a bottom
//  "ticket shelf" holds the QR, code and quick actions with guaranteed contrast.
// ─────────────────────────────────────────────────────────────────────────────
class _MainStoreCard extends StatelessWidget {
  const _MainStoreCard({
    required this.card,
    required this.merchant,
    required this.qrData,
    required this.actions,
    required this.onEnlarge,
    required this.onOpenMerchant,
  });

  final WalletCardModel card;
  final PublicMerchantUserModel? merchant;
  final String qrData;
  final List<MerchantAction> actions;
  final VoidCallback onEnlarge;
  final VoidCallback onOpenMerchant;

  /// Same fixed height the merchant's own profile page uses for its cover
  /// hero — matching this exactly (same height, same BoxFit.cover) means the
  /// visible crop of the photo here is identical to what the merchant set.
  static const _coverHeight = 220.0;
  static const _logoSize = 92.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cover = (merchant?.coverUrl.isNotEmpty ?? false)
        ? merchant!.coverUrl
        : card.merchantCoverUrl;
    final logo = (merchant?.logoUrl.isNotEmpty ?? false)
        ? merchant!.logoUrl
        : card.merchantLogoUrl;
    final name = card.merchantName.isEmpty ? 'Partner' : card.merchantName;
    final city = card.merchantCity.trim();
    final metaCity = city.length > 14 ? HessenCity.shorten(city) : city;
    final category = (merchant?.shopType.trim().isNotEmpty ?? false)
        ? merchant!.shopType.trim()
        : card.merchantShopType.trim();
    final meta = [category, metaCity].where((s) => s.isNotEmpty).join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          WalletTokens.md, 0, WalletTokens.md, WalletTokens.sm),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(WalletTokens.cardRadius),
          boxShadow: WalletTokens.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover — same height/fit as the merchant's own profile hero, so
            // the crop matches exactly what they set there. The logo overlaps
            // its bottom edge, mirroring that same layout.
            SizedBox(
              height: _coverHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned.fill(
                    child: cover.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            memCacheWidth: 900,
                            errorWidget: (context, url, error) =>
                                const _CoverFallback(),
                          )
                        : const _CoverFallback(),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.18),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.22),
                          ],
                          stops: const [0, 0.4, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -_logoSize / 2,
                    child: GestureDetector(
                      onTap: onOpenMerchant,
                      child: Container(
                        width: _logoSize,
                        height: _logoSize,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: logo.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: logo,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 200,
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.storefront_rounded,
                                          color: cs.onSurfaceVariant, size: 30),
                                )
                              : Icon(Icons.storefront_rounded,
                                  color: cs.onSurfaceVariant, size: 30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _logoSize / 2 + WalletTokens.sm),
            GestureDetector(
              onTap: onOpenMerchant,
              child: Column(
                children: [
                  Text(name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: WalletTokens.wHeavy)),
                  if (meta.isNotEmpty)
                    Text(meta,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: WalletTokens.wSemibold)),
                ],
              ),
            ),
            const SizedBox(height: WalletTokens.md),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: WalletTokens.lg),
              child: _PerforatedDivider(),
            ),
            // QR + code + actions fill the rest — centred if there's extra
            // room, scrollable if the device is short (never overflows).
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(WalletTokens.lg,
                        WalletTokens.md, WalletTokens.lg, WalletTokens.lg),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: onEnlarge,
                              child: Container(
                                padding: const EdgeInsets.all(WalletTokens.md),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(
                                      WalletTokens.qrRadius),
                                ),
                                child: QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: (MediaQuery.sizeOf(context).width *
                                          0.34)
                                      .clamp(120.0, 160.0),
                                ),
                              ),
                            ),
                            const SizedBox(height: WalletTokens.sm),
                            _CodeChip(pretty: WalletCode.pretty(card.walletCode)),
                            if (actions.isNotEmpty) ...[
                              const SizedBox(height: WalletTokens.md),
                              MerchantActionRow(actions: actions),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E4034), Color(0xFF12835F)],
        ),
      ),
    );
  }
}

/// A row of small dots — a light echo of a boarding pass's perforated tear
/// line, between the photo and the ticket shelf below it.
class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: CustomPaint(painter: _DotsPainter(color: cs.outlineVariant)),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 10.0;
    const r = 1.6;
    var x = gap / 2;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, size.height / 2), r, paint);
      x += gap;
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// The code chip used inside the fullscreen QR card. Fixed light styling (not
/// theme-driven): this always sits on the hardcoded-white QR card — a
/// scannability requirement, independent of light/dark mode — so its own
/// colours must stay legible on white regardless of the active theme.
class _FullscreenCodeChip extends StatelessWidget {
  const _FullscreenCodeChip({required this.pretty});

  final String pretty;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(WalletTokens.chipRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(WalletTokens.chipRadius),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pretty.isEmpty ? '—' : pretty,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 17,
                    fontWeight: WalletTokens.wBold,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  )),
              const SizedBox(width: 8),
              const Icon(Icons.copy_rounded, size: 15, color: Colors.black45),
            ],
          ),
        ),
      ),
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
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(WalletTokens.chipRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(WalletTokens.chipRadius),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pretty.isEmpty ? '—' : pretty,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: WalletTokens.wBold,
                    letterSpacing: 1.5,
                    fontFamily: 'monospace',
                  )),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stamp card — one FULL page per added stamp card, well spaced: header,
//  visual, progress, action, and this card's own earned rewards.
// ─────────────────────────────────────────────────────────────────────────────
class _StampFullCard extends StatelessWidget {
  const _StampFullCard({
    required this.card,
    required this.progress,
    required this.busy,
    required this.onRemoveCard,
    required this.onClaim,
    required this.earnedRewards,
  });

  final StampCardModel card;
  final StampProgressModel? progress;
  final bool busy;
  final VoidCallback onRemoveCard;
  final VoidCallback onClaim;
  final Stream<List<EarnedRewardModel>> earnedRewards;

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
        // Header — meaningful even when only this card's top edge is peeking.
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.loyalty_rounded,
                  size: 18, color: cs.onSecondaryContainer),
            ),
            const SizedBox(width: WalletTokens.sm),
            Expanded(
              child: Text('Stempelkarte',
                  style: tt.titleSmall?.copyWith(fontWeight: WalletTokens.wBold)),
            ),
            IconButton(
              onPressed: busy ? null : onRemoveCard,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: WalletTokens.md),
        StampCardVisual(card: card, filledStamps: current),
        const SizedBox(height: WalletTokens.md),
        Row(
          children: [
            Expanded(
              child: Text('$current / $max Stempel',
                  style: tt.titleSmall?.copyWith(
                      fontWeight: WalletTokens.wBold, color: cs.onSurface)),
            ),
            if (completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('Voll',
                    style: tt.labelSmall?.copyWith(
                        fontWeight: WalletTokens.wBold,
                        color: cs.onSecondaryContainer)),
              ),
          ],
        ),
        const SizedBox(height: WalletTokens.md),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          )
        else if (current == 0)
          Text('Stempel an der Kasse per QR erhalten.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
        else if (completed)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onClaim,
              icon: const Icon(Icons.redeem_rounded, size: 18),
              label: const Text('Belohnung einlösen'),
            ),
          ),
        StreamBuilder<List<EarnedRewardModel>>(
          stream: earnedRewards,
          builder: (context, snap) {
            final rewards = (snap.data ?? const <EarnedRewardModel>[])
                .where((r) => r.cardId == card.id)
                .toList();
            if (rewards.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: WalletTokens.lg),
                Text('Verdiente Belohnungen',
                    style: tt.titleSmall?.copyWith(fontWeight: WalletTokens.wBold)),
                const SizedBox(height: WalletTokens.sm),
                for (final r in rewards)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(WalletTokens.md),
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
                                  ?.copyWith(fontWeight: WalletTokens.wBold)),
                        ),
                        Text('Bereit',
                            style: tt.labelSmall?.copyWith(
                                color: AppColors.greenDeep,
                                fontWeight: WalletTokens.wHeavy)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Points — reserved placeholder, full page.
// ─────────────────────────────────────────────────────────────────────────────
class _PointsFullCard extends StatelessWidget {
  const _PointsFullCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(width: WalletTokens.sm),
            Expanded(
              child: Text('Punktesystem',
                  style: tt.titleMedium?.copyWith(fontWeight: WalletTokens.wBold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('Bald verfügbar',
                  style: tt.labelSmall?.copyWith(
                      fontWeight: WalletTokens.wHeavy,
                      color: cs.onTertiaryContainer)),
            ),
          ],
        ),
        const SizedBox(height: WalletTokens.lg),
        Text(
          'Hier sammelst du bald Punkte bei diesem Partner und löst sie gegen '
          'Belohnungen ein. Wir bauen das gerade.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }
}
