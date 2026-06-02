import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/models/reviewModel.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';
import 'package:lokka/features/user/feed/widgets/feedActionButtons.dart';
import 'package:lokka/features/user/partners/pages/userPartnerDetailPage.dart';

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
  double? _averageRating;
  bool _ratingsLoaded = false;
  bool _showAllReviews = false;

  @override
  void initState() {
    super.initState();
    _incrementViews();
    _loadAverageRating();
  }

  Future<void> _incrementViews() async {
    try {
      await widget.feedService.incrementViews(widget.post.postId);
    } catch (_) {}
  }

  Future<void> _loadAverageRating() async {
    try {
      final r = await widget.feedService.averageRatingFor(widget.post.postId);
      if (mounted) setState(() { _averageRating = r; _ratingsLoaded = true; });
    } catch (_) {
      if (mounted) setState(() { _ratingsLoaded = true; });
    }
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
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  post.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: post.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.gray100),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.gray100),
                        )
                      : Container(color: AppColors.gray100),
                  if (post.hasDiscount || post.type.isNotEmpty)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: _TypeBadge(post: post),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClickableMerchantRow(
                    post: post,
                    feedService: service,
                  ),
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
                  if (post.validFrom != null || post.validUntil != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ValidityRow(post: post),
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
                  if (post.hasButton) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _CtaButton(post: post),
                  ],
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
                  const Divider(height: 40, color: AppColors.border),
                  _ReviewsSection(
                    post: post,
                    feedService: service,
                    averageRating: _averageRating,
                    ratingsLoaded: _ratingsLoaded,
                    showAll: _showAllReviews,
                    onToggleShowAll: () =>
                        setState(() => _showAllReviews = !_showAllReviews),
                  ),
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

// ── Merchant row (clickable) ─────────────────────────────────────────────────

class _ClickableMerchantRow extends StatelessWidget {
  const _ClickableMerchantRow({
    required this.post,
    required this.feedService,
  });

  final FeedPostModel post;
  final UserFeedService feedService;

  Future<void> _open(BuildContext context) async {
    if (post.merchantId.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final merchant = await feedService.fetchMerchantById(post.merchantId);
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
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
                  : const Icon(
                      Icons.store_rounded,
                      size: 20,
                      color: AppColors.mintStrong,
                    ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    };
    return labels[type] ?? type;
  }
}

// ── Type badge ───────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.post});

  final FeedPostModel post;

  @override
  Widget build(BuildContext context) {
    final label = post.hasDiscount
        ? '-${post.discountPercent}%'
        : _typeLabel(post.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: post.hasDiscount
            ? AppColors.mintStrong
            : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
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
    };
    return labels[type] ?? type;
  }
}

// ── Price row ────────────────────────────────────────────────────────────────

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

// ── Validity row ─────────────────────────────────────────────────────────────

class _ValidityRow extends StatelessWidget {
  const _ValidityRow({required this.post});

  final FeedPostModel post;

  String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (post.validFrom != null) parts.add('ab ${_fmt(post.validFrom!)}');
    if (post.validUntil != null) parts.add('bis ${_fmt(post.validUntil!)}');
    final expired =
        post.validUntil != null && DateTime.now().isAfter(post.validUntil!);
    return Row(
      children: [
        Icon(
          expired ? Icons.event_busy_rounded : Icons.event_available_rounded,
          size: 16,
          color: expired ? Colors.redAccent : AppColors.gray500,
        ),
        const SizedBox(width: 6),
        Text(
          expired ? 'Abgelaufen · ${parts.join(' ')}' : 'Gültig ${parts.join(' ')}',
          style: TextStyle(
            fontSize: 13,
            color: expired ? Colors.redAccent : AppColors.gray500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── CTA button ───────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.post});

  final FeedPostModel post;

  void _show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
              post.buttonText ?? 'Aktion',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Diese Funktion ist bald verfügbar.',
              style: TextStyle(fontSize: 14, color: AppColors.gray500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mintStrong,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
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
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _show(context),
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: Text(post.buttonText ?? 'Zur Aktion'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mintStrong,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

// ── Reviews section ──────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.post,
    required this.feedService,
    required this.averageRating,
    required this.ratingsLoaded,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final FeedPostModel post;
  final UserFeedService feedService;
  final double? averageRating;
  final bool ratingsLoaded;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Bewertungen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const Spacer(),
            if (ratingsLoaded && averageRating != null)
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 18, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    averageRating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showWriteReview(context),
            icon: const Icon(Icons.star_outline_rounded, size: 18),
            label: const Text('Rezension schreiben'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.mintStrong,
              side: const BorderSide(color: AppColors.mint),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        StreamBuilder<List<ReviewModel>>(
          stream: feedService.reviewsStream(post.postId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final reviews = snapshot.data ?? [];
            if (reviews.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Noch keine Bewertungen. Sei der Erste!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.gray500,
                  ),
                ),
              );
            }
            final displayed = showAll ? reviews : reviews.take(3).toList();
            return Column(
              children: [
                ...displayed.map((r) => _ReviewTile(review: r)),
                if (reviews.length > 3)
                  TextButton(
                    onPressed: onToggleShowAll,
                    child: Text(
                      showAll
                          ? 'Weniger anzeigen'
                          : 'Alle ${reviews.length} anzeigen',
                      style: const TextStyle(color: AppColors.mintStrong),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showWriteReview(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _WriteReviewSheet(
        post: post,
        feedService: feedService,
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  review.userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const Spacer(),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < review.rating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 14,
                      color: Colors.amber,
                    );
                  }),
                ),
              ],
            ),
            if (review.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                review.text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.gray700,
                  height: 1.4,
                ),
              ),
            ],
            if (review.createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                _fmt(review.createdAt!),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.gray300,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet({required this.post, required this.feedService});

  final FeedPostModel post;
  final UserFeedService feedService;

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  double _rating = 0;
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);
    try {
      await widget.feedService.submitReview(
        postId: widget.post.postId,
        merchantId: widget.post.merchantId,
        rating: _rating,
        text: _ctrl.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rezension schreiben',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = (i + 1).toDouble()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Deine Meinung ...',
              filled: true,
              fillColor: AppColors.gray50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _rating > 0 && !_submitting ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mintStrong,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Absenden'),
            ),
          ),
        ],
      ),
    );
  }
}
