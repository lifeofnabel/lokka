import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/models/reviewModel.dart';
import 'package:lokka/features/user/feed/pages/userFeedDetailPage.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';

/// Time window the reviews are filtered by (based on when they were written).
enum _Range { all, today, yesterday, week, month }

/// A review the user wrote, together with the post it belongs to (for display).
class _MyReview {
  const _MyReview({
    required this.review,
    required this.post,
    required this.postTitle,
    required this.postImageUrl,
    required this.merchantName,
  });

  final ReviewModel review;
  final FeedPostModel post;
  final String postTitle;
  final String postImageUrl;
  final String merchantName;
}

/// „Meine Rezensionen" — every review the user wrote, filterable by date with a
/// small live counter in the top-right (same controls as „Gelikte Beiträge").
class MeineRezensionenPage extends StatefulWidget {
  const MeineRezensionenPage({super.key});

  @override
  State<MeineRezensionenPage> createState() => _MeineRezensionenPageState();
}

class _MeineRezensionenPageState extends State<MeineRezensionenPage> {
  late final AuthService _authService;
  late final FirestoreService _firestoreService;
  late final UserFeedService _feedService;

  List<_MyReview> _reviews = [];
  bool _loading = true;
  String? _error;

  _Range _range = _Range.all;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _firestoreService = context.read<FirestoreService>();
    _feedService = UserFeedService(
      firestoreService: _firestoreService,
      authService: _authService,
    );
    _load();
  }

  Future<void> _load() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Index-free by design: a collectionGroup('reviews') query needs a
      // COLLECTION_GROUP-scoped index (Firestore's automatic single-field
      // indexes are COLLECTION-scoped only), which isn't deployed — so it fails
      // with failed-precondition and the page used to show "empty". Instead we
      // read the feed once and fetch this user's review doc (id == uid) per post
      // via a direct get(). Single-doc reads never touch the index system, so
      // this always works and also gives us the post title/thumbnail.
      final postsSnap =
          await _firestoreService.collection(FirebasePaths.feed).get();
      final futures = postsSnap.docs.map((post) async {
        final data = await _firestoreService
            .readDocument(FirebasePaths.feedReview(post.id, uid));
        if (data == null) return null;
        final p = post.data();
        return _MyReview(
          review: ReviewModel.fromMap({...data, 'reviewId': uid}),
          post: FeedPostModel.fromMap({...p, 'postId': post.id}),
          postTitle: (p['title'] ?? '').toString(),
          postImageUrl: (p['imageUrl'] ?? '').toString(),
          merchantName: (p['merchantName'] ?? '').toString(),
        );
      });
      final reviews = (await Future.wait(futures))
          .whereType<_MyReview>()
          .toList()
        ..sort((a, b) => (b.review.createdAt ?? DateTime(2000))
            .compareTo(a.review.createdAt ?? DateTime(2000)));
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool _inRange(DateTime? at) {
    if (_range == _Range.all) return true;
    if (at == null) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.today:
        return !at.isBefore(todayStart);
      case _Range.yesterday:
        final y = todayStart.subtract(const Duration(days: 1));
        return !at.isBefore(y) && at.isBefore(todayStart);
      case _Range.week:
        return !at.isBefore(now.subtract(const Duration(days: 7)));
      case _Range.month:
        return !at.isBefore(now.subtract(const Duration(days: 30)));
      case _Range.all:
        return true;
    }
  }

  List<_MyReview> get _filtered =>
      _reviews.where((r) => _inRange(r.review.createdAt)).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Meine Rezensionen'),
        actions: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _CounterPill(count: filtered.length),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_loading && _error == null && _reviews.isNotEmpty)
            _FilterBar(
              range: _range,
              onRange: (r) => setState(() => _range = r),
            ),
          Expanded(child: _buildBody(filtered)),
        ],
      ),
    );
  }

  Widget _buildBody(List<_MyReview> filtered) {
    if (_loading) return const AppLoadingState();
    if (_error != null) {
      return AppErrorState(message: 'Laden fehlgeschlagen', onRetry: _load);
    }
    if (_reviews.isEmpty) {
      return const AppEmptyState(
        icon: Icons.reviews_outlined,
        title: 'Noch keine Rezensionen',
        message: 'Bewerte Beiträge auf der Detailseite.',
      );
    }
    if (filtered.isEmpty) {
      return const AppEmptyState(
        icon: Icons.filter_alt_off_rounded,
        title: 'Keine Treffer',
        message: 'In diesem Zeitraum hast du nichts bewertet.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _ReviewCard(
        entry: filtered[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserFeedDetailPage(
              post: filtered[i].post,
              feedService: _feedService,
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 13, color: cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.range, required this.onRange});

  final _Range range;
  final ValueChanged<_Range> onRange;

  static const _labels = <_Range, String>{
    _Range.all: 'Alle',
    _Range.today: 'Heute',
    _Range.yesterday: 'Gestern',
    _Range.week: 'Letzte 7 Tage',
    _Range.month: 'Letzter Monat',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          for (final entry in _labels.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: range == entry.key,
              onSelected: (_) => onRange(entry.key),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.entry, required this.onTap});

  final _MyReview entry;
  final VoidCallback onTap;

  String _label(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Heute';
    if (diff == 1) return 'Gestern';
    if (diff < 7) return 'vor $diff Tagen';
    return '${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')}.${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = entry.review;
    final title = entry.postTitle.isEmpty ? 'Beitrag' : entry.postTitle;
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post thumbnail.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                clipBehavior: Clip.antiAlias,
                child: entry.postImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: entry.postImageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                        errorWidget: (context, url, error) => Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: cs.onSecondaryContainer,
                        ),
                      )
                    : Icon(Icons.image_outlined,
                        size: 20, color: cs.onSecondaryContainer),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.merchantName.isNotEmpty)
                      Text(
                        entry.merchantName,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < r.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 15,
                    color: AppColors.googleYellow,
                  );
                }),
              ),
            ],
          ),
          if (r.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(r.text, style: tt.bodyMedium?.copyWith(height: 1.4)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _label(r.createdAt),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ],
          ),
        ),
      ),
    );
  }
}
