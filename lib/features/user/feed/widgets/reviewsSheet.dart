import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/reviewModel.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';
import 'package:lokka/features/user/reviews/widgets/reviewWidgets.dart';

/// Opens the reviews (Bewertungen) for a post as a bottom sheet — the same
/// slide UX as before, but showing the post's reviews with the option to write
/// or edit your own (one editable review per user).
Future<void> showReviewsSheet(
  BuildContext context, {
  required UserFeedService feedService,
  required String postId,
  required String merchantId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewsSheet(
      feedService: feedService,
      postId: postId,
      merchantId: merchantId,
    ),
  );
}

class _ReviewsSheet extends StatefulWidget {
  const _ReviewsSheet({
    required this.feedService,
    required this.postId,
    required this.merchantId,
  });

  final UserFeedService feedService;
  final String postId;
  final String merchantId;

  @override
  State<_ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<_ReviewsSheet> {
  ReviewModel? _myReview;

  String? get _uid => widget.feedService.authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadMyReview();
  }

  Future<void> _loadMyReview() async {
    try {
      final mine = await widget.feedService.myReview(widget.postId);
      if (mounted) setState(() => _myReview = mine);
    } catch (_) {}
  }

  Future<void> _writeOrEdit() async {
    // Reload fresh so we never create a second review (doc-id == uid).
    ReviewModel? mine = _myReview;
    try {
      mine = await widget.feedService.myReview(widget.postId);
    } catch (_) {}
    if (!mounted) return;
    await showReviewWriteSheet(
      context,
      title:
          mine == null ? 'Bewertung schreiben' : 'Deine Bewertung bearbeiten',
      initialRating: mine?.rating ?? 0,
      initialText: mine?.text ?? '',
      initialImageUrl: mine?.imageUrl ?? '',
      onSubmit: ({required rating, required text, required imageUrl}) async {
        await widget.feedService.submitReview(
          postId: widget.postId,
          merchantId: widget.merchantId,
          rating: rating,
          text: text,
          imageUrl: imageUrl,
        );
      },
    );
    await _loadMyReview();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Bewertung löschen?'),
          content: const Text(
              'Deine Bewertung für diesen Beitrag wird entfernt. Das kann nicht '
              'rückgängig gemacht werden.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: cs.error, foregroundColor: cs.onError),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await widget.feedService.deleteReview(widget.postId);
      if (mounted) setState(() => _myReview = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Löschen fehlgeschlagen. Bitte erneut.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
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
            Expanded(
              child: StreamBuilder<List<ReviewModel>>(
                stream: widget.feedService.reviewsStream(widget.postId),
                builder: (context, snapshot) {
                  final reviews = snapshot.data ?? const <ReviewModel>[];
                  final ratings = reviews
                      .map((r) => r.rating)
                      .where((r) => r >= 1 && r <= 5)
                      .toList();
                  final avg = ratings.isEmpty
                      ? null
                      : ratings.reduce((a, b) => a + b) / ratings.length;
                  final waiting =
                      snapshot.connectionState == ConnectionState.waiting;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                            AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                        child: Row(
                          children: [
                            Text(
                              'Bewertungen',
                              style: tt.titleMedium?.copyWith(
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
                        child: waiting
                            ? const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : reviews.isEmpty
                                ? const Center(child: _EmptyReviews())
                                : ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                        AppSpacing.md,
                                        0,
                                        AppSpacing.md,
                                        AppSpacing.md),
                                    itemCount: reviews.length,
                                    itemBuilder: (_, i) => ReviewTile(
                                      review: reviews[i],
                                      isMine: _uid != null &&
                                          reviews[i].userId == _uid,
                                    ),
                                  ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final hasMine = _myReview != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _writeOrEdit,
                icon: Icon(
                    hasMine ? Icons.edit_rounded : Icons.star_outline_rounded,
                    size: 18),
                label: Text(hasMine
                    ? 'Deine Bewertung bearbeiten'
                    : 'Bewertung schreiben'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mintStrong,
                  side: const BorderSide(color: AppColors.mint),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
            if (hasMine) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Bewertung löschen',
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.googleRed),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.reviews_outlined, size: 40, color: AppColors.onSurfaceMuted),
        SizedBox(height: 10),
        Text(
          'Noch keine Bewertungen.\nGib die erste ab!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }
}
