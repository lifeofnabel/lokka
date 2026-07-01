import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/utils/shareUtils.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/providers/userFeedProvider.dart';
import 'package:lokka/features/user/feed/widgets/reviewsSheet.dart';
import 'package:lokka/features/user/feed/widgets/postCard.dart';
import 'package:lokka/features/user/feed/widgets/reportSheet.dart';
import 'package:lokka/features/user/feed/widgets/feedFilterBar.dart';
import 'package:lokka/features/user/feed/pages/userFeedDetailPage.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';

class UserFeedPage extends StatelessWidget {
  const UserFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Consumer<UserFeedProvider>(
      builder: (context, provider, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: cs.surface,
            elevation: 0,
            expandedHeight: 60,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              title: Text(
                'Deals & Angebote',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: FeedFilterBar(
                options: provider.availableShopTypes,
                selected: provider.selectedShopType,
                onSelected: (v) => provider.setFilter(shopType: v),
                label: 'Alle Kategorien',
              ),
            ),
          ),
          if (provider.isLoading) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, _) => const _SkeletonCard(),
                  childCount: 4,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ] else if (provider.error != null) ...[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(message: 'Feed konnte nicht geladen werden'),
            ),
          ] else if (provider.posts.isEmpty) ...[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.local_offer_outlined,
                title: 'Noch keine lokalen Angebote',
                message: 'Ändere deine Filter oder schau später wieder rein.',
              ),
            ),
          ] else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final post = provider.posts[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _FeedCardWithLike(
                        post: post,
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => UserFeedDetailPage(
                              post: post,
                              feedService: provider.service,
                            ),
                          ),
                        ),
                        onMerchantTap: () =>
                            _openPartnerPage(ctx, provider, post),
                      ),
                    );
                  },
                  childCount: provider.posts.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ],
      ),
    );
  }

  Future<void> _openPartnerPage(
    BuildContext context,
    UserFeedProvider provider,
    FeedPostModel post,
  ) async {
    if (post.merchantId.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final merchant =
          await provider.service.fetchMerchantById(post.merchantId);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (merchant != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserPartnerDetailPage(merchant: merchant),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _FeedCardWithLike extends StatelessWidget {
  const _FeedCardWithLike({
    required this.post,
    required this.onTap,
    required this.onMerchantTap,
  });

  final FeedPostModel post;
  final VoidCallback onTap;
  final VoidCallback onMerchantTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<UserFeedProvider>();
    return StreamBuilder<bool>(
      stream: provider.service.likedStream(post.postId),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;
        return PostCard(
          post: post,
          onTap: onTap,
          isLiked: isLiked,
          onLikeTap: () async {
            try {
              await provider.service.toggleLike(post.postId, isLiked);
            } catch (_) {}
          },
          onCommentTap: () => showReviewsSheet(
            context,
            feedService: provider.service,
            postId: post.postId,
            merchantId: post.merchantId,
          ),
          onShareTap: () => ShareUtils.shareFeedPost(
            title: post.title,
            merchantName: post.merchantName,
          ),
          onReport: () => showReportPostSheet(
            context,
            feedService: provider.service,
            post: post,
          ),
          onMerchantTap: onMerchantTap,
        );
      },
    );
  }
}

// ── Skeleton ────────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _Bone(width: 36, height: 36, radius: 8),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(width: 120, height: 12),
                        SizedBox(height: 5),
                        _Bone(width: 80, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 1,
              child: Container(color: AppColors.gray100),
            ),
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [_Bone(width: 70, height: 18)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.width, required this.height, this.radius = 4});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

