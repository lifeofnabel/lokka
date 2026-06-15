import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';

class FeedDealCard extends StatefulWidget {
  const FeedDealCard({
    super.key,
    required this.post,
    this.onTap,
    this.isLiked = false,
    this.onLikeTap,
    this.onMerchantTap,
  });

  final FeedPostModel post;
  final VoidCallback? onTap;
  final bool isLiked;
  final VoidCallback? onLikeTap;
  final VoidCallback? onMerchantTap;

  @override
  State<FeedDealCard> createState() => _FeedDealCardState();
}

class _FeedDealCardState extends State<FeedDealCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;

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
      CurvedAnimation(
        parent: _heartCtrl,
        curve: const Interval(0.55, 1.0),
      ),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (!widget.isLiked) {
      widget.onLikeTap?.call();
    }
    _heartCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
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
              onMerchantTap: widget.onMerchantTap,
              onMenuTap: () => _showMenu(context),
            ),
            GestureDetector(
              onDoubleTap: _onDoubleTap,
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: widget.post.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.post.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.gray100),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.gray100,
                              child: const Icon(
                                Icons.image_outlined,
                                color: AppColors.gray300,
                                size: 48,
                              ),
                            ),
                          )
                        : Container(color: AppColors.gray100),
                  ),
                  if (widget.post.hasDiscount || widget.post.type.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _Badge(post: widget.post),
                    ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _heartCtrl,
                      builder: (context, child) {
                        if (_heartCtrl.isDismissed) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: FadeTransition(
                            opacity: _heartOpacity,
                            child: ScaleTransition(
                              scale: _heartScale,
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 80,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 16,
                                  ),
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
            _ActionRow(
              post: widget.post,
              isLiked: widget.isLiked,
              onLikeTap: widget.onLikeTap,
              onReadMore: widget.onTap,
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).padding.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.flag_outlined,
              label: 'Beitrag melden',
              onTap: () => Navigator.pop(ctx),
            ),
            _MenuTile(
              icon: Icons.info_outline_rounded,
              label: 'Warum sehe ich das?',
              onTap: () => Navigator.pop(ctx),
            ),
            _MenuTile(
              icon: Icons.share_outlined,
              label: 'Teilen',
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

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
          AppSpacing.md,
          AppSpacing.sm,
          4,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            _LogoAvatar(logoUrl: post.merchantLogoUrl),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.merchantName,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.merchantArea.isNotEmpty ||
                      post.merchantShopType.isNotEmpty)
                    Text(
                      [
                        post.merchantArea,
                        _typeLabel(post.merchantShopType),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Tooltip(
              message: 'Weitere Optionen',
              child: IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: onMenuTap,
                splashRadius: 20,
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
      child: logoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.store_rounded,
                  size: 18,
                  color: cs.onSecondaryContainer,
                ),
              ),
            )
          : Icon(
              Icons.store_rounded,
              size: 18,
              color: cs.onSecondaryContainer,
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.post});

  final FeedPostModel post;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final label = post.hasDiscount
        ? '-${post.discountPercent}%'
        : _typeLabel(post.type);
    final bg = post.hasDiscount
        ? cs.primary
        : Colors.black.withValues(alpha: 0.6);
    final fg = post.hasDiscount ? cs.onPrimary : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    const labels = {
      'offer': 'Angebot',
      'happyHour': 'Happy Hour',
      'news': 'Neuigkeit',
      'newProduct': 'Neu',
      'communityEvent': 'Event',
      'quickSell': 'Quick Deal',
      'rescueMe': 'Rescue Me',
      'hiring': 'Wir suchen',
    };
    return labels[type] ?? type;
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.post,
    required this.isLiked,
    this.onLikeTap,
    this.onReadMore,
  });

  final FeedPostModel post;
  final bool isLiked;
  final VoidCallback? onLikeTap;
  final VoidCallback? onReadMore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        4,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Tooltip(
            message: isLiked ? 'Gefällt mir nicht mehr' : 'Gefällt mir',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onLikeTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 22,
                        color:
                            isLiked ? AppColors.googleRed : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.likesCount}',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: 'Details anzeigen',
            child: TextButton(
              onPressed: onReadMore,
              child: const Text('Mehr lesen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurfaceVariant, size: 22),
      title: Text(
        label,
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}
