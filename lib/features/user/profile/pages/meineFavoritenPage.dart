import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/pages/userFeedDetailPage.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';

/// „Meine Favoriten" — Chromium Experience / Material 3.
class MeineFavoritenPage extends StatefulWidget {
  const MeineFavoritenPage({super.key});

  @override
  State<MeineFavoritenPage> createState() => _MeineFavoritenPageState();
}

class _MeineFavoritenPageState extends State<MeineFavoritenPage> {
  late final UserFeedService _feedService;

  List<FeedPostModel> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _feedService = UserFeedService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _feedService.fetchLikedPosts();
      if (mounted) setState(() { _posts = posts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _loading || _error != null
        ? null
        : _posts.isEmpty
            ? 'Noch leer'
            : '${_posts.length} gespeicherte ${_posts.length == 1 ? 'Beitrag' : 'Beiträge'}';

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meine Favoriten'),
            if (subtitle != null)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingState();
    if (_error != null) {
      return AppErrorState(message: 'Laden fehlgeschlagen', onRetry: _load);
    }
    if (_posts.isEmpty) {
      return const AppEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Noch keine Favoriten',
        message: 'Tippe das Herz bei einem Beitrag — er landet dann hier.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _FavoriteCard(
        post: _posts[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserFeedDetailPage(
              post: _posts[i],
              feedService: _feedService,
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.post, required this.onTap});

  final FeedPostModel post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover mit Scrim + Titel-Overlay + Herz
              Stack(
                children: [
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: post.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: post.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _imgFallback(context),
                            errorWidget: (_, __, ___) => _imgFallback(context),
                          )
                        : _imgFallback(context),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.favorite_rounded,
                          color: cs.error, size: 18),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.sm,
                    child: Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Icon(Icons.storefront_rounded,
                          size: 16, color: cs.onSecondaryContainer),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        post.merchantName.isEmpty ? 'Partner' : post.merchantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (post.likesCount > 0) ...[
                      Icon(Icons.favorite_rounded,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text('${post.likesCount}',
                          style: tt.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgFallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.secondaryContainer,
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 36, color: cs.onSecondaryContainer),
      ),
    );
  }
}
