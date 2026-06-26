import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lokka/core/feed/feedPostTypeStyle.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';

/// The single, reusable feed post card — used **identically** in the Feed and
/// on a Merchant Profile. Behaviour is driven by [enableProfileNavigation]:
/// `true` in the Feed (tapping the merchant opens their profile), `false` on a
/// merchant's own profile (you are already there, so the header is inert).
///
/// Interactions:
/// - double-tap the image → like (with an Instagram-style heart burst)
/// - single-tap the image/body OR the bottom-right mini-arrow → [onTap]
/// - bottom action bar: Like · Kommentar · Teilen (no Save)
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.isLiked = false,
    this.commentCount = 0,
    this.enableProfileNavigation = true,
    this.isExpired = false,
    this.onTap,
    this.onLikeTap,
    this.onCommentTap,
    this.onShareTap,
    this.onMerchantTap,
    this.onReport,
  });

  final FeedPostModel post;
  final bool isLiked;

  /// Live comment count for the bar badge (0 → no number shown).
  final int commentCount;

  /// Whether tapping the merchant logo/name navigates to their profile.
  final bool enableProfileNavigation;

  /// Renders the card dimmed + greyscale for expired posts (profile filter).
  final bool isExpired;

  final VoidCallback? onTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onMerchantTap;
  final VoidCallback? onReport;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartCtrl;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;

  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = Tween<double>(begin: 0.4, end: 1.5).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut),
    );
    _heartOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _heartCtrl, curve: const Interval(0.55, 1.0)),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    // Only fire the like callback when not already liked, so a double-tap never
    // accidentally un-likes; always play the burst as positive feedback.
    if (!widget.isLiked) widget.onLikeTap?.call();
    _heartCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: widget.isExpired ? 0.78 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MerchantHeader(
                post: widget.post,
                onMerchantTap:
                    widget.enableProfileNavigation ? widget.onMerchantTap : null,
                onMenuTap: () => _showMenu(context),
              ),
              _image(),
              _ActionBar(
                post: widget.post,
                isLiked: widget.isLiked,
                commentCount: widget.commentCount,
                onLikeTap: widget.onLikeTap,
                onCommentTap: widget.onCommentTap,
                onShareTap: widget.onShareTap,
                onOpen: widget.onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image() {
    Widget img = widget.post.imageUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: widget.post.imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 800,
            placeholder: (_, _) => Container(color: AppColors.gray100),
            errorWidget: (_, _, _) => Container(
              color: AppColors.gray100,
              child: const Icon(Icons.image_outlined,
                  color: AppColors.gray300, size: 48),
            ),
          )
        : Container(
            color: AppColors.gray100,
            child: const Icon(Icons.storefront_rounded,
                color: AppColors.gray300, size: 48),
          );
    if (widget.isExpired) {
      img = ColorFiltered(colorFilter: _greyscale, child: img);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _onDoubleTap,
      child: Stack(
        children: [
          AspectRatio(aspectRatio: 1, child: img),
          if (widget.post.hasDiscount || widget.post.type.isNotEmpty)
            Positioned(top: 10, left: 10, child: _Badge(post: widget.post)),
          if (widget.isExpired)
            const Positioned(top: 10, right: 10, child: _ExpiredBadge()),
          // Title/subtitle overlay (kept on the FEED card for parity; the Post
          // page renders these below the image instead).
          if (widget.post.title.isNotEmpty)
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: IgnorePointer(child: _TitleOverlay(post: widget.post)),
            ),
          Positioned.fill(child: _HeartBurst(
            controller: _heartCtrl,
            scale: _heartScale,
            opacity: _heartOpacity,
          )),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.onReport != null)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Beitrag melden'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onReport!.call();
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Teilen'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onShareTap?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Heart burst overlay ───────────────────────────────────────────────────────

class _HeartBurst extends StatelessWidget {
  const _HeartBurst({
    required this.controller,
    required this.scale,
    required this.opacity,
  });

  final AnimationController controller;
  final Animation<double> scale;
  final Animation<double> opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isDismissed) return const SizedBox.shrink();
          return Center(
            child: FadeTransition(
              opacity: opacity,
              child: ScaleTransition(
                scale: scale,
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 80,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 16)],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Title overlay (feed parity) ───────────────────────────────────────────────

class _TitleOverlay extends StatelessWidget {
  const _TitleOverlay({required this.post});

  final FeedPostModel post;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.2,
            ),
          ),
          if (post.subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              post.subtitle.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Merchant header ───────────────────────────────────────────────────────────

class _MerchantHeader extends StatelessWidget {
  const _MerchantHeader({
    required this.post,
    this.onMerchantTap,
    this.onMenuTap,
  });

  final FeedPostModel post;
  final VoidCallback? onMerchantTap;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onMerchantTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, 4, AppSpacing.sm),
        child: Row(
          children: [
            _LogoAvatar(logoUrl: post.merchantLogoUrl),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.merchantName.isEmpty ? 'Partner' : post.merchantName,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.merchantCity.isNotEmpty ||
                      post.merchantShopType.isNotEmpty)
                    Text(
                      [post.merchantCity, _typeLabel(post.merchantShopType)]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Tooltip(
              message: 'Weitere Optionen',
              child: IconButton(
                icon: Icon(Icons.more_vert_rounded,
                    size: 20, color: cs.onSurfaceVariant),
                onPressed: onMenuTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    const labels = {
      'restaurant': 'Restaurant',
      'cafe': 'Café',
      'bakery': 'Bäckerei',
      'retail': 'Einzelhandel',
      'service': 'Dienstleistung',
      'beauty': 'Beauty',
      'fitness': 'Fitness',
      'bar': 'Bar',
      'other': 'Sonstiges',
    };
    return labels[type] ?? type;
  }
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({required this.logoUrl});

  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Icon(Icons.store_rounded,
                  size: 18, color: cs.onSecondaryContainer),
            )
          : Icon(Icons.store_rounded, size: 18, color: cs.onSecondaryContainer),
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.post});

  final FeedPostModel post;

  @override
  Widget build(BuildContext context) {
    // A discount keeps its own strong red chip (the clearest deal signal);
    // every other type uses the shared icon+colour marker so each post template
    // is recognisable at a glance in the feed.
    if (post.hasDiscount) {
      final cs = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(20)),
        child: Text(
          '-${post.discountPercent}%',
          style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onPrimary),
        ),
      );
    }
    if (post.type.isEmpty) return const SizedBox.shrink();
    return FeedTypeBadge(type: post.type, onImage: true);
  }
}

class _ExpiredBadge extends StatelessWidget {
  const _ExpiredBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'Abgelaufen',
        style: tt.labelMedium
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Action bar (Like · Kommentar · Teilen + mini-arrow) ───────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.post,
    required this.isLiked,
    required this.commentCount,
    this.onLikeTap,
    this.onCommentTap,
    this.onShareTap,
    this.onOpen,
  });

  final FeedPostModel post;
  final bool isLiked;
  final int commentCount;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 6),
      child: Row(
        children: [
          _ActionButton(
            icon: isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: isLiked ? AppColors.googleRed : cs.onSurfaceVariant,
            label: post.likesCount > 0 ? '${post.likesCount}' : null,
            tooltip: isLiked ? 'Gefällt mir nicht mehr' : 'Gefällt mir',
            onTap: onLikeTap,
          ),
          _ActionButton(
            icon: Icons.mode_comment_outlined,
            color: cs.onSurfaceVariant,
            label: commentCount > 0 ? '$commentCount' : null,
            tooltip: 'Kommentare',
            onTap: onCommentTap,
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            color: cs.onSurfaceVariant,
            tooltip: 'Teilen',
            onTap: onShareTap,
          ),
          const Spacer(),
          Tooltip(
            message: 'Beitrag öffnen',
            child: IconButton(
              onPressed: onOpen,
              icon: Icon(Icons.arrow_forward_rounded,
                  size: 20, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
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
