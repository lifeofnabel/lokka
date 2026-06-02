import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/providers/userFeedProvider.dart';
import 'package:lokka/features/user/feed/widgets/feedDealCard.dart';
import 'package:lokka/features/user/feed/widgets/feedFilterBar.dart';
import 'package:lokka/features/user/feed/pages/userFeedDetailPage.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';

class UserFeedPage extends StatelessWidget {
  const UserFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserFeedProvider>(
      builder: (context, provider, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            expandedHeight: 60,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              title: Text(
                'Deals & Angebote',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                  letterSpacing: -0.5,
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
                  (_, __) => const _SkeletonCard(),
                  childCount: 4,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ] else if (provider.error != null) ...[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _FeedErrorView(),
            ),
          ] else if (provider.posts.isEmpty) ...[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _FeedEmptyView(),
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
        return FeedDealCard(
          post: post,
          onTap: onTap,
          isLiked: isLiked,
          onLikeTap: () async {
            try {
              await provider.service.toggleLike(post.postId, isLiked);
            } catch (_) {}
          },
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _Bone(width: 36, height: 36, radius: 8),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(width: 120, height: 12),
                        const SizedBox(height: 5),
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
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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

// ── Empty / Error ────────────────────────────────────────────────────────────

class _FeedEmptyView extends StatelessWidget {
  const _FeedEmptyView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.local_offer_outlined, size: 64, color: AppColors.gray300),
        SizedBox(height: AppSpacing.md),
        Text(
          'Noch keine lokalen Angebote.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.gray500,
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Ändere deine Filter oder schau später wieder rein.',
            style: TextStyle(fontSize: 14, color: AppColors.gray300),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _FeedErrorView extends StatelessWidget {
  const _FeedErrorView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.gray300),
        SizedBox(height: AppSpacing.md),
        Text(
          'Feed konnte nicht geladen werden',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.gray500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
