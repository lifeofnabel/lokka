import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lokka/core/services/externalLinkService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/models/reviewModel.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';
import 'package:lokka/features/user/reviews/widgets/reviewWidgets.dart';

/// Beitrag-Detail („post-detail") — User-Bereich, helles Material 3.
///
/// Aufbau (oben → unten):
/// 1. Bild-Hero (Back/Like/Zoom floating, Scrim mit Badge + Titel)
/// 2. Deal-Block (Preise, Rabatt, Gültigkeit)
/// 3. CTA-Button
/// 4. Beschreibung
/// 5. Händler-Zeile (→ Partnerseite)
/// 6. Bewertungen kompakt (neueste + Popout, eine Rezension pro Nutzer)
///
/// Routen-/Konstruktor-Vertrag bleibt unverändert: Seite wird über
/// `/user/feed/<id>` mit `extra: post` ODER direkt via
/// `UserFeedDetailPage(post:, feedService:)` geöffnet.
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
  ReviewModel? _myReview;

  /// Erster Like-Status vom Server — Basis für die optimistische Zähler-Anzeige.
  bool? _likedBaseline;

  FeedPostModel get _post => widget.post;
  UserFeedService get _service => widget.feedService;

  @override
  void initState() {
    super.initState();
    _trackView();
    _loadMyReview();
  }

  Future<void> _trackView() async {
    try {
      await _service.incrementViews(_post.postId);
    } catch (_) {}
  }

  Future<void> _loadMyReview() async {
    try {
      final mine = await _service.myReview(_post.postId);
      if (mounted) setState(() => _myReview = mine);
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image_rounded,
                      size: 48,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: AppSpacing.md,
              child: _CircleIconButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Händler öffnen ─────────────────────────────────────────────────────────

  Future<void> _openMerchant() async {
    final merchantId = _post.merchantId;
    if (merchantId.isEmpty) return;
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
            builder: (_) => UserPartnerDetailPage(merchant: merchant),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partner konnte nicht geladen werden.')),
        );
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Bewertung schreiben/bearbeiten (max. eine pro Nutzer) ─────────────────

  Future<void> _writeOrEditReview() async {
    // Frisch laden, damit nie eine zweite Rezension entsteht
    // (Doc-ID = uid, submitReview überschreibt die eigene).
    ReviewModel? mine = _myReview;
    try {
      mine = await _service.myReview(_post.postId);
    } catch (_) {}
    if (!mounted) return;
    await showReviewWriteSheet(
      context,
      title: mine == null ? 'Bewertung schreiben' : 'Deine Bewertung bearbeiten',
      initialRating: mine?.rating ?? 0,
      initialText: mine?.text ?? '',
      initialImageUrl: mine?.imageUrl ?? '',
      onSubmit: ({required rating, required text, required imageUrl}) async {
        await _service.submitReview(
          postId: _post.postId,
          merchantId: _post.merchantId,
          rating: rating,
          text: text,
          imageUrl: imageUrl,
        );
      },
    );
    await _loadMyReview();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1 — Bild-Hero
          StreamBuilder<bool>(
            stream: _service.likedStream(post.postId),
            builder: (context, snapshot) {
              final liked = snapshot.data ?? false;
              if (snapshot.hasData) _likedBaseline ??= snapshot.data;
              return _HeroImage(
                post: post,
                liked: liked,
                likeCount: _likeCount(liked),
                onBack: () => Navigator.pop(context),
                onLike: () => _toggleLike(liked),
                onZoom: post.imageUrl.isEmpty ? null : _openFullscreenImage,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 2 — Deal-Block (nur wenn Daten existieren)
                if (_DealCard.hasContent(post)) ...[
                  _DealCard(post: post),
                  const SizedBox(height: AppSpacing.md),
                ],
                // 3 — CTA
                if (post.hasButton) ...[
                  _CtaButton(post: post, feedService: _service),
                  const SizedBox(height: AppSpacing.md),
                ],
                // 4 — Beschreibung
                if (post.description.trim().isNotEmpty) ...[
                  _DescriptionCard(text: post.description.trim()),
                  const SizedBox(height: AppSpacing.md),
                ],
                // 5 — Händler
                _MerchantCard(post: post, onTap: _openMerchant),
                const SizedBox(height: AppSpacing.lg),
                // 6 — Bewertungen
                _ReviewsSection(
                  post: post,
                  feedService: _service,
                  myReview: _myReview,
                  onWriteOrEdit: _writeOrEditReview,
                ),
                SizedBox(
                  height:
                      AppSpacing.xxl + MediaQuery.of(context).padding.bottom,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 1 · Bild-Hero ─────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.post,
    required this.liked,
    required this.likeCount,
    required this.onBack,
    required this.onLike,
    this.onZoom,
  });

  final FeedPostModel post;
  final bool liked;
  final int likeCount;
  final VoidCallback onBack;
  final VoidCallback onLike;
  final VoidCallback? onZoom;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1.05,
            child: post.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: AppColors.gray100),
                    errorWidget: (_, _, _) =>
                        Container(color: AppColors.gray100),
                  )
                : Container(
                    color: AppColors.greenTint,
                    child: const Center(
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 56,
                        color: AppColors.mintStrong,
                      ),
                    ),
                  ),
          ),
          // Scrim unten: Badge + Titel (+ Untertitel)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                56,
                AppSpacing.md,
                AppSpacing.md + 4,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ScrimPill(label: _typeLabel(post.type)),
                      if (post.isForRegulars) ...[
                        const SizedBox(width: 6),
                        const _ScrimPill(label: 'Für Stammgäste'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (post.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post.subtitle.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Back (oben links)
          Positioned(
            top: topPad + 8,
            left: 12,
            child: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
          ),
          // Like (oben rechts)
          Positioned(
            top: topPad + 8,
            right: 12,
            child: _LikePill(
              liked: liked,
              count: likeCount,
              onTap: onLike,
            ),
          ),
          // Zoom (unter dem Like)
          if (onZoom != null)
            Positioned(
              top: topPad + 56,
              right: 12,
              child: _CircleIconButton(
                icon: Icons.fullscreen_rounded,
                onTap: onZoom!,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScrimPill extends StatelessWidget {
  const _ScrimPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _LikePill extends StatelessWidget {
  const _LikePill({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
                color: liked ? AppColors.googleRed : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
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
          child: Center(
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ── 2 · Deal-Block ────────────────────────────────────────────────────────────

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
    final expired =
        post.validUntil != null && now.isAfter(post.validUntil!);
    final validity = _validityText(now);
    final priceColor = expired ? AppColors.onSurfaceMuted : cs.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: expired ? AppColors.surfaceGray : AppColors.greenTint,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: expired ? AppColors.outlineGray : AppColors.greenLine,
        ),
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
                    letterSpacing: -0.5,
                  ),
                ),
                if (post.oldPrice != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _euro(post.oldPrice!),
                      style: tt.titleMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (post.hasDiscount)
                  _DiscountPill(
                    percent: post.discountPercent!,
                    muted: expired,
                  ),
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
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  'Rabatt',
                  style: tt.labelLarge?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
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
                  color: expired
                      ? AppColors.googleRed
                      : AppColors.onSurfaceMuted,
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

// ── 3 · CTA ───────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.post, required this.feedService});

  final FeedPostModel post;
  final UserFeedService feedService;

  IconData get _icon {
    switch (post.effectiveCtaType) {
      case 'shop':
      case 'catalog':
        return Icons.storefront_rounded;
      case 'feedPost':
        return Icons.article_rounded;
      case 'external':
        return Icons.open_in_new_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }

  Future<void> _open(BuildContext context) async {
    final type = post.effectiveCtaType;
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
    if (type == 'external' && post.effectiveButtonUrl.isNotEmpty) {
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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.of(ctx).padding.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.open_in_new_rounded,
              size: 40,
              color: AppColors.mintStrong,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Externen Link öffnen?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Du verlässt Lokka. Der Link wird im Browser geöffnet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.gray700,
                height: 1.35,
              ),
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
    final opened = await ExternalLinkService.openInNewTab(
      _safeExternalUrl(post.effectiveButtonUrl),
    );
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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.of(ctx).padding.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.touch_app_rounded,
              size: 40,
              color: AppColors.mintStrong,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              post.effectiveButtonText.isEmpty
                  ? 'Aktion nicht verfügbar'
                  : post.effectiveButtonText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceDark,
              ),
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
      label: Text(
        post.effectiveButtonText,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

// ── 4 · Beschreibung ──────────────────────────────────────────────────────────

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
        style: tt.bodyMedium?.copyWith(
          color: AppColors.gray700,
          height: 1.6,
        ),
      ),
    );
  }
}

// ── 5 · Händler-Zeile ─────────────────────────────────────────────────────────

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
                          errorWidget: (_, _, _) => Icon(
                            Icons.store_rounded,
                            size: 22,
                            color: cs.primary,
                          ),
                        )
                      : Icon(
                          Icons.store_rounded,
                          size: 22,
                          color: cs.primary,
                        ),
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
                          color: AppColors.onSurfaceDark,
                        ),
                      ),
                      if (post.merchantArea.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          post.merchantArea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 6 · Bewertungen (kompakt + Popout) ────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.post,
    required this.feedService,
    required this.myReview,
    required this.onWriteOrEdit,
  });

  final FeedPostModel post;
  final UserFeedService feedService;
  final ReviewModel? myReview;
  final VoidCallback onWriteOrEdit;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final uid = feedService.authService.currentUser?.uid;
    return StreamBuilder<List<ReviewModel>>(
      stream: feedService.reviewsStream(post.postId),
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final reviews = snapshot.data ?? const <ReviewModel>[];
        final ratings = reviews
            .map((r) => r.rating)
            .where((r) => r >= 1 && r <= 5)
            .toList();
        final avg = ratings.isEmpty
            ? null
            : ratings.reduce((a, b) => a + b) / ratings.length;
        final latest = reviews.isEmpty ? null : reviews.first;
        final hasMine = myReview != null ||
            (uid != null && reviews.any((r) => r.userId == uid));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Bewertungen',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceDark,
                  ),
                ),
                const Spacer(),
                if (avg != null) ReviewStars(rating: avg, count: reviews.length),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            if (waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (latest == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: const Text(
                  'Noch keine Bewertungen. Sei die oder der Erste!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              )
            else ...[
              ReviewTile(
                review: latest,
                isMine: uid != null && latest.userId == uid,
              ),
              if (reviews.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _showAllReviews(context, reviews, avg),
                    child: Text(
                      'Alle ${reviews.length} anzeigen',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.mintStrong,
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onWriteOrEdit,
              icon: Icon(
                hasMine ? Icons.edit_rounded : Icons.star_outline_rounded,
                size: 18,
              ),
              label: Text(
                hasMine ? 'Deine Bewertung bearbeiten' : 'Bewertung schreiben',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mintStrong,
                side: const BorderSide(color: AppColors.mint),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAllReviews(
    BuildContext context,
    List<ReviewModel> reviews,
    double? avg,
  ) {
    final uid = feedService.authService.currentUser?.uid;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm + 4),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      'Alle Bewertungen',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceDark,
                          ),
                    ),
                    const Spacer(),
                    if (avg != null)
                      ReviewStars(rating: avg, count: reviews.length),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    MediaQuery.of(ctx).padding.bottom + AppSpacing.lg,
                  ),
                  itemCount: reviews.length,
                  itemBuilder: (_, i) => ReviewTile(
                    review: reviews[i],
                    isMine: uid != null && reviews[i].userId == uid,
                  ),
                ),
              ),
            ],
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
