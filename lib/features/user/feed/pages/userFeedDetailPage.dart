import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';
import 'package:lokka/features/user/feed/widgets/feedActionButtons.dart';

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
  @override
  void initState() {
    super.initState();
    _incrementViews();
  }

  Future<void> _incrementViews() async {
    try {
      await widget.feedService.incrementViews(widget.post.postId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final service = widget.feedService;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: AppColors.black,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: post.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.gray100),
                      errorWidget: (_, __, ___) => Container(color: AppColors.gray100),
                    )
                  : Container(color: AppColors.gray100),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MerchantRow(post: post),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  if (post.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.gray700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (post.hasPriceInfo) ...[
                    const SizedBox(height: AppSpacing.md),
                    _PriceRow(post: post),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  StreamBuilder<bool>(
                    stream: service.likedStream(post.postId),
                    builder: (context, snapshot) {
                      final isLiked = snapshot.data ?? false;
                      return FeedActionButtons(
                        likesCount: post.likesCount,
                        isLiked: isLiked,
                        onLike: () async {
                          try {
                            await service.toggleLike(post.postId, isLiked);
                          } catch (_) {}
                        },
                      );
                    },
                  ),
                  if (post.description.isNotEmpty) ...[
                    const Divider(height: 32, color: AppColors.border),
                    Text(
                      post.description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.gray700,
                        height: 1.6,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({required this.post});

  final FeedPostModel post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.mintSoft,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: AppColors.border),
          ),
          child: post.merchantLogoUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: CachedNetworkImage(
                    imageUrl: post.merchantLogoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.store_rounded,
                      size: 20,
                      color: AppColors.mintStrong,
                    ),
                  ),
                )
              : const Icon(Icons.store_rounded, size: 20, color: AppColors.mintStrong),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.merchantName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              if (post.merchantArea.isNotEmpty)
                Text(
                  post.merchantArea,
                  style: const TextStyle(fontSize: 12, color: AppColors.gray500),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.mintSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _typeLabel(post.type),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.mintStrong,
            ),
          ),
        ),
      ],
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
    };
    return labels[type] ?? type;
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.post});

  final FeedPostModel post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          if (post.newPrice != null) ...[
            Text(
              '${post.newPrice!.toStringAsFixed(2).replaceAll('.', ',')} €',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.mintStrong,
              ),
            ),
            if (post.oldPrice != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${post.oldPrice!.toStringAsFixed(2).replaceAll('.', ',')} €',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.gray500,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ] else if (post.discountPercent != null)
            Text(
              '-${post.discountPercent}%',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.mintStrong,
              ),
            ),
        ],
      ),
    );
  }
}
