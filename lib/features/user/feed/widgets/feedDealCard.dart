import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appShadows.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';

class FeedDealCard extends StatelessWidget {
  const FeedDealCard({
    super.key,
    required this.post,
    this.onTap,
    this.isLiked = false,
    this.onLikeTap,
  });

  final FeedPostModel post;
  final VoidCallback? onTap;
  final bool isLiked;
  final VoidCallback? onLikeTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImage(),
                _buildGradient(),
                _buildContent(),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildLikeButton(),
                ),
                if (post.hasDiscount)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildBadge('-${post.discountPercent}%'),
                  )
                else if (post.type.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildTypeBadge(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (post.imageUrl.isEmpty) {
      return Container(color: AppColors.gray100);
    }
    return CachedNetworkImage(
      imageUrl: post.imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppColors.gray100),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.gray100,
        child: const Icon(Icons.image_outlined, color: AppColors.gray300, size: 48),
      ),
    );
  }

  Widget _buildGradient() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.merchantName.isNotEmpty)
            Row(
              children: [
                if (post.merchantLogoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: post.merchantLogoUrl,
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (post.merchantLogoUrl.isNotEmpty) const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    post.merchantName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.newPrice != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${post.newPrice!.toStringAsFixed(2).replaceAll('.', ',')} €',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mint,
                  ),
                ),
                if (post.oldPrice != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${post.oldPrice!.toStringAsFixed(2).replaceAll('.', ',')} €',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 13, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                '${post.likesCount}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLikeButton() {
    return GestureDetector(
      onTap: onLikeTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 18,
          color: isLiked ? Colors.redAccent : Colors.white,
        ),
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.mintStrong,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _typeLabel(post.type),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
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
