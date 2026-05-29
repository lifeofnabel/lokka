import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/providers/userFeedProvider.dart';
import 'package:lokka/features/user/feed/widgets/feedDealCard.dart';
import 'package:lokka/features/user/feed/widgets/feedFilterBar.dart';
import 'package:lokka/features/user/feed/pages/userFeedDetailPage.dart';

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
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.error != null)
            const SliverFillRemaining(child: _FeedErrorView())
          else if (provider.posts.isEmpty)
            const SliverFillRemaining(child: _FeedEmptyView())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 4 / 5,
                ),
                itemCount: provider.posts.length,
                itemBuilder: (ctx, i) {
                  final post = provider.posts[i];
                  final service = provider.service;
                  return _FeedCardWithLike(
                    post: post,
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => UserFeedDetailPage(
                          post: post,
                          feedService: service,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }
}

class _FeedCardWithLike extends StatelessWidget {
  const _FeedCardWithLike({required this.post, required this.onTap});

  final FeedPostModel post;
  final VoidCallback onTap;

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
        );
      },
    );
  }
}

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
          'Keine Deals gefunden',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.gray500,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Neue Angebote kommen bald.',
          style: TextStyle(fontSize: 14, color: AppColors.gray300),
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
