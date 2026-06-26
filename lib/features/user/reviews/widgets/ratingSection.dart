import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/reviewModel.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';
import 'package:lokka/features/user/reviews/widgets/reviewWidgets.dart';

/// Reusable rating block: shows the average rating + the latest review, lets the
/// signed-in user write/edit their **single** review for this post, and opens a
/// popout with all reviews. Self-contained — manages its own "my review" state.
///
/// Per the product decision, ratings are scoped to the post
/// (`feed/{postId}/reviews/{uid}`), not the merchant.
class RatingSection extends StatefulWidget {
  const RatingSection({
    super.key,
    required this.feedService,
    required this.postId,
    required this.merchantId,
  });

  final UserFeedService feedService;
  final String postId;
  final String merchantId;

  @override
  State<RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<RatingSection> {
  ReviewModel? _myReview;

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

  Future<void> _confirmDeleteMyReview() async {
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
    final uid = widget.feedService.authService.currentUser?.uid;
    return StreamBuilder<List<ReviewModel>>(
      stream: widget.feedService.reviewsStream(widget.postId),
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final reviews = snapshot.data ?? const <ReviewModel>[];
        final ratings =
            reviews.map((r) => r.rating).where((r) => r >= 1 && r <= 5).toList();
        final avg = ratings.isEmpty
            ? null
            : ratings.reduce((a, b) => a + b) / ratings.length;
        final latest = reviews.isEmpty ? null : reviews.first;
        final hasMine = _myReview != null ||
            (uid != null && reviews.any((r) => r.userId == uid));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Bewertungen',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceDark,
                  ),
                ),
                const Spacer(),
                if (avg != null) ReviewStars(rating: avg, count: reviews.length),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            if (waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (latest == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: const Text(
                  'Noch keine Bewertungen. Sei die oder der Erste!',
                  style: TextStyle(fontSize: 14, color: AppColors.onSurfaceMuted),
                ),
              )
            else ...[
              ReviewTile(review: latest, isMine: uid != null && latest.userId == uid),
              if (reviews.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _showAllReviews(context, reviews, avg),
                    child: Text(
                      'Alle ${reviews.length} anzeigen',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.mintStrong,
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _writeOrEdit,
              icon: Icon(
                hasMine ? Icons.edit_rounded : Icons.star_outline_rounded,
                size: 18,
              ),
              label: Text(
                hasMine ? 'Deine Bewertung bearbeiten' : 'Bewertung schreiben',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mintStrong,
                side: const BorderSide(color: AppColors.mint),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (hasMine)
              Center(
                child: TextButton.icon(
                  onPressed: _confirmDeleteMyReview,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Bewertung löschen'),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.googleRed),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAllReviews(
    BuildContext context,
    List<ReviewModel> reviews,
    double? avg,
  ) {
    final uid = widget.feedService.authService.currentUser?.uid;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    Text(
                      'Alle Bewertungen',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
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
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    MediaQuery.of(ctx).padding.bottom + AppSpacing.lg,
                  ),
                  itemCount: reviews.length,
                  itemBuilder: (_, i) => ReviewTile(
                    review: reviews[i],
                    isMine: uid != null && reviews[i].userId == uid,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
