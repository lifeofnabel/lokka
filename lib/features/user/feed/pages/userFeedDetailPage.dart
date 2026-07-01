import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lokka/core/services/externalLinkService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/widgets/responsiveContentWidth.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/utils/shareUtils.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';
import 'package:lokka/features/user/feed/widgets/reviewsSheet.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';
import 'package:lokka/features/user/partners/services/merchantWarmupCache.dart';
import 'package:lokka/features/user/reviews/widgets/ratingSection.dart';
import 'package:lokka/features/user/shared/widgets/quickActionBar.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';

/// Beitrag-Detail („post-detail") — User-Bereich, helles Material 3.
///
/// Aufbau (oben → unten), gem. Release-Vorgabe:
/// 1. Bild-Hero (zentriert; Back/Zoom floating — KEIN Titel-Overlay mehr)
/// 2. Titel + Untertitel (unter dem Bild, über der Beschreibung)
/// 3. Like · Kommentar · Teilen (konsistent mit dem Feed)
/// 4. Deal-Block (Preise/Rabatt/Gültigkeit)
/// 5. Beschreibung
/// 6. CTA-Button
/// 7. QuickActionBar: Route starten · Anrufen · Social (grau wenn Daten fehlen)
/// 8. Händler-Zeile (→ Partnerseite)
/// 9. RatingSection (Ø + Rezensionen, eine pro Nutzer)
class UserFeedDetailPage extends StatefulWidget {
  const UserFeedDetailPage({
    super.key,
    required this.post,
    required this.feedService,
  });

  final FeedPostModel post;
  final UserFeedService feedService;

  @override
  State<UserFeedDetailPage> createState() => _UserFeedDetailPageState();
}

class _UserFeedDetailPageState extends State<UserFeedDetailPage> {
  /// Erster Like-Status vom Server — Basis für die optimistische Zähler-Anzeige.
  bool? _likedBaseline;

  /// Händler für die QuickActionBar (Route/Anrufen/Social). Wird nachgeladen.
  PublicMerchantUserModel? _merchant;

  FeedPostModel get _post => widget.post;
  UserFeedService get _service => widget.feedService;

  @override
  void initState() {
    super.initState();
    _trackView();
    _loadMerchant();
    _warmMerchantProfile();
  }

  /// Stößt das Vorab-Laden der Partner-Profilseite an (Wallet-Status, eigene
  /// Beiträge, Treue-Verfügbarkeit) – die wahrscheinlichsten nächsten Schritte
  /// von hier sind "zurück" oder "Profil ansehen", also lohnt es sich, dessen
  /// Daten schon zu holen, während der Nutzer noch diesen Beitrag liest.
  void _warmMerchantProfile() {
    if (_post.merchantId.isEmpty) return;
    unawaited(MerchantWarmupCache.warm(
      _post.merchantId,
      firestoreService: _service.firestoreService,
      walletService: UserWalletService(
        firestoreService: _service.firestoreService,
        authService: _service.authService,
        cacheService: context.read<LocalCacheService>(),
      ),
    ));
  }

  Future<void> _trackView() async {
    try {
      await _service.incrementViews(_post.postId);
    } catch (_) {}
  }

  Future<void> _loadMerchant() async {
    if (_post.merchantId.isEmpty) return;
    try {
      final m = await _service.fetchMerchantById(_post.merchantId);
      if (mounted) setState(() => _merchant = m);
    } catch (_) {}
  }

  // ── Like ───────────────────────────────────────────────────────────────────

  Future<void> _toggleLike(bool currentlyLiked) async {
    try {
      await _service.toggleLike(_post.postId, currentlyLiked);
    } catch (_) {}
  }

  int _likeCount(bool liked) {
    var count = _post.likesCount;
    if (_likedBaseline == false && liked) count += 1;
    if (_likedBaseline == true && !liked) count -= 1;
    return count < 0 ? 0 : count;
  }

  void _openReviews() {
    showReviewsSheet(context,
        feedService: _service,
        postId: _post.postId,
        merchantId: _post.merchantId);
  }

  void _share() {
    ShareUtils.shareFeedPost(
      title: _post.title,
      merchantName: _post.merchantName,
    );
  }

  // ── Bild-Vollbild (Pinch-Zoom) ─────────────────────────────────────────────

  void _openFullscreenImage() {
    final url = _post.imageUrl;
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                    errorWidget: (_, _, _) => const Icon(
                        Icons.broken_image_rounded,
                        size: 48,
                        color: Colors.white54),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: AppSpacing.md,
              child: _CircleIconButton(
                  icon: Icons.close_rounded, onTap: () => Navigator.pop(ctx)),
            ),
          ],
        ),
      ),
    );
  }

  // ── QuickActionBar-Aktionen (Route / Anrufen / Social) ─────────────────────

  Future<void> _launchMaps() async {
    final m = _merchant;
    if (m == null) return;
    final query = m.hasCoordinates
        ? '${m.lat},${m.lng}'
        : Uri.encodeComponent(
            m.fullAddress.isNotEmpty ? m.fullAddress : m.address);
    if (query.isEmpty) return;
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('Karten-App konnte nicht geöffnet werden');
    }
  }

  Future<void> _call() async {
    final phone = _merchant?.phone.trim() ?? '';
    if (phone.isEmpty) return;
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (_) {
      _snack('Anruf nicht möglich');
    }
  }

  void _openSocial() {
    final links = _merchant?.socialLinks ?? const <String, String>{};
    if (links.isEmpty) return;
    const meta = <(String, String, IconData)>[
      ('website', 'Website', Icons.language_rounded),
      ('instagram', 'Instagram', Icons.camera_alt_rounded),
      ('tiktok', 'TikTok', Icons.music_note_rounded),
      ('facebook', 'Facebook', Icons.facebook),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            for (final (key, label, icon) in meta)
              if ((links[key] ?? '').isNotEmpty)
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () {
                    Navigator.pop(ctx);
                    _launchExternal(links[key]!);
                  },
                ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _launchExternal(String url) async {
    var u = url.trim();
    if (u.isEmpty) return;
    if (!u.startsWith('http')) u = 'https://$u';
    final opened = await ExternalLinkService.openInNewTab(u);
    if (!opened) {
      try {
        await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
      } catch (_) {
        _snack('Link konnte nicht geöffnet werden');
      }
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  // ── Händler öffnen ─────────────────────────────────────────────────────────

  Future<void> _openMerchant() async {
    final merchantId = _post.merchantId;
    if (merchantId.isEmpty) return;
    // Bereits geladenen Händler direkt verwenden, sonst nachladen.
    if (_merchant != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UserPartnerDetailPage(merchant: _merchant!)),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final merchant = await _service.fetchMerchantById(merchantId);
      if (!mounted) return;
      Navigator.pop(context);
      if (merchant != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => UserPartnerDetailPage(merchant: merchant)),
        );
      } else {
        _snack('Partner konnte nicht geladen werden.');
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          ResponsiveContentWidth(
            child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1 — Bild-Hero (nur Bild)
          _HeroImage(post: post),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 2 — Titel + Untertitel
                _TitleBlock(post: post),
                const SizedBox(height: AppSpacing.sm),
                // 3 — Like · Kommentar · Teilen
                StreamBuilder<bool>(
                  stream: _service.likedStream(post.postId),
                  builder: (context, snapshot) {
                    final liked = snapshot.data ?? false;
                    if (snapshot.hasData) _likedBaseline ??= snapshot.data;
                    return _SocialActionBar(
                      liked: liked,
                      likeCount: _likeCount(liked),
                      commentCount: 0,
                      publishedAt: post.publishedAt ?? post.createdAt,
                      onLike: () => _toggleLike(liked),
                      onComment: _openReviews,
                      onShare: _share,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // 4 — Deal-Block
                if (_DealCard.hasContent(post)) ...[
                  _DealCard(post: post),
                  const SizedBox(height: AppSpacing.md),
                ],
                // 5 — Beschreibung
                if (post.description.trim().isNotEmpty) ...[
                  _DescriptionCard(text: post.description.trim()),
                  const SizedBox(height: AppSpacing.md),
                ],
                // 6 — CTA
                if (post.hasButton) ...[
                  _CtaButton(post: post, feedService: _service),
                  const SizedBox(height: AppSpacing.md),
                ],
                // 7 — QuickActionBar (Route / Anrufen / Social)
                _quickActions(),
                const SizedBox(height: AppSpacing.md),
                // 8 — Händler
                _MerchantCard(post: post, onTap: _openMerchant),
                const SizedBox(height: AppSpacing.lg),
                // 9 — Bewertungen
                RatingSection(
                  feedService: _service,
                  postId: post.postId,
                  merchantId: post.merchantId,
                ),
                SizedBox(
                    height:
                        AppSpacing.xxl + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
          ),
          // Schwebende Steuerung: bleibt beim Scrollen sichtbar.
          Positioned(
            top: topPad + 8,
            left: 12,
            child: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context)),
          ),
          if (post.imageUrl.isNotEmpty)
            Positioned(
              top: topPad + 8,
              right: 12,
              child: _CircleIconButton(
                  icon: Icons.fullscreen_rounded, onTap: _openFullscreenImage),
            ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final m = _merchant;
    final hasRoute =
        m != null && (m.address.isNotEmpty || m.hasCoordinates);
    final hasPhone = (m?.phone.trim().isNotEmpty) ?? false;
    final hasSocial = (m?.socialLinks.isNotEmpty) ?? false;
    return QuickActionBar(
      actions: [
        QuickAction(
          icon: Icons.near_me_rounded,
          label: 'Route',
          enabled: hasRoute,
          onTap: hasRoute ? _launchMaps : null,
        ),
        QuickAction(
          icon: Icons.call_rounded,
          label: 'Anrufen',
          enabled: hasPhone,
          onTap: hasPhone ? _call : null,
        ),
        QuickAction(
          icon: Icons.public_rounded,
          label: 'Social',
          enabled: hasSocial,
          onTap: hasSocial ? _openSocial : null,
        ),
      ],
    );
  }
}

// ── 1 · Bild-Hero (nur Bild; Back/Zoom schweben auf Seiten-Ebene) ─────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.post});

  final FeedPostModel post;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      child: AspectRatio(
        aspectRatio: 1.05,
        child: post.imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: post.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppColors.gray100),
                errorWidget: (_, _, _) => Container(
                  color: AppColors.gray100,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: AppColors.gray300),
                  ),
                ),
              )
            : Container(
                color: AppColors.greenTint,
                child: const Center(
                  child: Icon(Icons.storefront_rounded,
                      size: 56, color: AppColors.mintStrong),
                ),
              ),
      ),
    );
  }
}

// ── 2 · Titel + Untertitel ────────────────────────────────────────────────────

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.post});

  final FeedPostModel post;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _TypePill(label: _typeLabel(post.type)),
            if (post.isForRegulars) ...[
              const SizedBox(width: 6),
              const _TypePill(label: 'Für Stammgäste'),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          post.title,
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.3,
            color: AppColors.onSurfaceDark,
          ),
        ),
        if (post.subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            post.subtitle.trim(),
            style: tt.titleSmall?.copyWith(
              color: AppColors.onSurfaceMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.greenTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.greenLine),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.mintStrong,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── 3 · Like · Kommentar · Teilen ─────────────────────────────────────────────

class _SocialActionBar extends StatelessWidget {
  const _SocialActionBar({
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.publishedAt,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  final bool liked;
  final int likeCount;
  final int commentCount;
  final DateTime? publishedAt;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BarButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? AppColors.googleRed : AppColors.onSurfaceMuted,
          label: likeCount > 0 ? '$likeCount' : null,
          tooltip: liked ? 'Gefällt mir nicht mehr' : 'Gefällt mir',
          onTap: onLike,
        ),
        _BarButton(
          icon: Icons.rate_review_outlined,
          color: AppColors.onSurfaceMuted,
          label: commentCount > 0 ? '$commentCount' : null,
          tooltip: 'Bewertungen',
          onTap: onComment,
        ),
        _BarButton(
          icon: Icons.share_outlined,
          color: AppColors.onSurfaceMuted,
          tooltip: 'Teilen',
          onTap: onShare,
        ),
        const Spacer(),
        // Veröffentlichungsdatum – passend rechts neben den Aktionen.
        if (publishedAt != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.onSurfaceMuted,
              ),
              const SizedBox(width: 4),
              Text(
                _fmtDate(publishedAt!),
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Tooltip(
      message: tooltip,
      // Sonst zeigt der Tooltip auf Touch nur bei Long-Press (Default), nicht
      // bei normalem Tap.
      triggerMode: TooltipTriggerMode.tap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 24, color: color),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: Icon(icon, size: 20, color: Colors.white)),
        ),
      ),
    );
  }
}

// ── 4 · Deal-Block ────────────────────────────────────────────────────────────

class _DealCard extends StatelessWidget {
  const _DealCard({required this.post});

  final FeedPostModel post;

  static bool hasContent(FeedPostModel post) =>
      post.hasPriceInfo || post.validFrom != null || post.validUntil != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final expired = post.validUntil != null && now.isAfter(post.validUntil!);
    final validity = _validityText(now);
    final priceColor = expired ? AppColors.onSurfaceMuted : cs.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: expired ? AppColors.surfaceGray : AppColors.greenTint,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
            color: expired ? AppColors.outlineGray : AppColors.greenLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.newPrice != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _euro(post.newPrice!),
                  style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: priceColor,
                      letterSpacing: -0.5),
                ),
                if (post.oldPrice != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _euro(post.oldPrice!),
                      style: tt.titleMedium?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          decoration: TextDecoration.lineThrough),
                    ),
                  ),
                ],
                const Spacer(),
                if (post.hasDiscount)
                  _DiscountPill(percent: post.discountPercent!, muted: expired),
              ],
            )
          else if (post.hasDiscount)
            Row(
              children: [
                Text(
                  '-${post.discountPercent}%',
                  style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: priceColor,
                      letterSpacing: -0.5),
                ),
                const Spacer(),
                Text('Rabatt',
                    style: tt.labelLarge
                        ?.copyWith(color: AppColors.onSurfaceMuted)),
              ],
            ),
          if (validity != null) ...[
            if (post.hasPriceInfo) const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  expired
                      ? Icons.event_busy_rounded
                      : Icons.event_available_rounded,
                  size: 16,
                  color:
                      expired ? AppColors.googleRed : AppColors.onSurfaceMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    validity,
                    style: tt.bodySmall?.copyWith(
                      color: expired
                          ? AppColors.googleRed
                          : AppColors.onSurfaceMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _validityText(DateTime now) {
    final from = post.validFrom;
    final until = post.validUntil;
    if (until != null && now.isAfter(until)) {
      return 'Abgelaufen am ${_fmtDate(until)}';
    }
    if (from != null && now.isBefore(from)) {
      return until == null
          ? 'Gültig ab ${_fmtDate(from)}'
          : 'Gültig ${_fmtDate(from)} – ${_fmtDate(until)}';
    }
    if (until != null) return 'Gültig bis ${_fmtDate(until)}';
    if (from != null) return 'Gültig seit ${_fmtDate(from)}';
    return null;
  }
}

class _DiscountPill extends StatelessWidget {
  const _DiscountPill({required this.percent, required this.muted});

  final int percent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: muted ? AppColors.outlineGray : cs.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '-$percent%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: muted ? AppColors.onSurfaceMuted : cs.onPrimary,
        ),
      ),
    );
  }
}

// ── 5 · Beschreibung ──────────────────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: tt.bodyMedium?.copyWith(color: AppColors.gray700, height: 1.6),
      ),
    );
  }
}

// ── 6 · CTA ───────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.post, required this.feedService});

  final FeedPostModel post;
  final UserFeedService feedService;

  IconData get _icon {
    switch (post.effectiveCtaType) {
      case 'profile':
        return Icons.storefront_rounded;
      case 'stampCard':
        return Icons.card_giftcard_rounded;
      case 'shop':
      case 'catalog':
        return Icons.storefront_rounded;
      case 'feedPost':
        return Icons.article_rounded;
      case 'url':
      case 'external':
        return Icons.open_in_new_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }

  Future<void> _open(BuildContext context) async {
    final type = post.effectiveCtaType;
    // Merchant's own Lokka page (profile).
    if (type == 'profile') {
      await _trackClick();
      if (!context.mounted) return;
      context.push('/user/partners/${post.merchantId}');
      return;
    }
    // Deep link to the merchant's stamp cards → add to wallet.
    if (type == 'stampCard') {
      await _trackClick();
      if (!context.mounted) return;
      context.push('/user/stamps/${post.merchantId}');
      return;
    }
    if (type == 'shop' || type == 'catalog') {
      await _trackClick();
      if (!context.mounted) return;
      context.push('/shop/${post.merchantId}');
      return;
    }
    if (type == 'feedPost' && (post.ctaTargetId ?? '').trim().isNotEmpty) {
      await _trackClick();
      if (!context.mounted) return;
      context.push('/user/feed/${post.ctaTargetId!.trim()}');
      return;
    }
    if ((type == 'url' || type == 'external') &&
        post.effectiveButtonUrl.isNotEmpty) {
      await _showExternalWarning(context);
      return;
    }
    _showUnavailable(context);
  }

  Future<void> _trackClick() async {
    try {
      await feedService.incrementClicks(post.postId);
    } catch (_) {}
  }

  Future<void> _showExternalWarning(BuildContext context) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            MediaQuery.of(ctx).padding.bottom + AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.open_in_new_rounded,
                size: 40, color: AppColors.mintStrong),
            const SizedBox(height: AppSpacing.md),
            const Text('Externen Link öffnen?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceDark)),
            const SizedBox(height: 8),
            const Text(
              'Du verlässt Lokka. Der Link wird im Browser geöffnet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.gray700, height: 1.35),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Im Browser öffnen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await _trackClick();
    final opened =
        await ExternalLinkService.openInNewTab(_safeExternalUrl(post.effectiveButtonUrl));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link konnte nicht geöffnet werden.')),
      );
    }
  }

  void _showUnavailable(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            MediaQuery.of(ctx).padding.bottom + AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app_rounded,
                size: 40, color: AppColors.mintStrong),
            const SizedBox(height: AppSpacing.md),
            Text(
              post.effectiveButtonText.isEmpty
                  ? 'Aktion nicht verfügbar'
                  : post.effectiveButtonText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Diese Aktion ist gerade nicht verfügbar. '
              'Schau später noch einmal vorbei.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.gray500),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _open(context),
      icon: Icon(_icon, size: 18),
      label: Text(post.effectiveButtonText,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

// ── 8 · Händler-Zeile ─────────────────────────────────────────────────────────

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({required this.post, required this.onTap});

  final FeedPostModel post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.greenTint,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: post.merchantLogoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: post.merchantLogoUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Icon(Icons.store_rounded,
                              size: 22, color: cs.primary),
                        )
                      : Icon(Icons.store_rounded, size: 22, color: cs.primary),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.merchantName.isEmpty
                            ? 'Partner ansehen'
                            : post.merchantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceDark),
                      ),
                      if (post.merchantCity.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          post.merchantCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall
                              ?.copyWith(color: AppColors.onSurfaceMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.onSurfaceMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helfer ────────────────────────────────────────────────────────────────────

String _typeLabel(String type) {
  const labels = {
    'offer': 'Angebot',
    'happyHour': 'Happy Hour',
    'news': 'Neuigkeit',
    'newProduct': 'Neu',
    'communityEvent': 'Event',
    'quickSell': 'Quick Deal',
  };
  return labels[type] ?? (type.isEmpty ? 'Beitrag' : type);
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

String _euro(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

String _safeExternalUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}
