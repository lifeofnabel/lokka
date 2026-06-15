import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:lokka/features/user/feed/models/reviewModel.dart';

class MeineRezensionenPage extends StatefulWidget {
  const MeineRezensionenPage({super.key});

  @override
  State<MeineRezensionenPage> createState() => _MeineRezensionenPageState();
}

class _MeineRezensionenPageState extends State<MeineRezensionenPage> {
  late final AuthService _authService;
  late final FirestoreService _firestoreService;

  List<ReviewModel> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _firestoreService = context.read<FirestoreService>();
    _load();
  }

  Future<void> _load() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; });
      return;
    }
    try {
      final snap = await _firestoreService
          .collectionGroup(FirebasePaths.reviews)
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      final reviews = snap.docs
          .map((d) => ReviewModel.fromMap({...d.data(), 'reviewId': d.id}))
          .toList();
      if (mounted) setState(() { _reviews = reviews; _loading = false; });
    } catch (e) {
      if (mounted) {
        // A missing Firestore index shows as "failed-precondition" – treat as empty.
        final isIndexError = e is FirebaseException &&
            (e.code == 'failed-precondition' || e.code == 'unimplemented');
        setState(() {
          _error = isIndexError ? null : e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Meine Rezensionen'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingState();
    if (_error != null) {
      return AppErrorState(message: 'Laden fehlgeschlagen', onRetry: _load);
    }
    if (_reviews.isEmpty) {
      return const AppEmptyState(
        icon: Icons.star_outline_rounded,
        title: 'Noch keine Rezensionen',
        message: 'Bewerte Beiträge auf der Detailseite.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, i) => _ReviewCard(review: _reviews[i]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ReviewModel review;

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.postId.isNotEmpty
                      ? 'Beitrag · ${review.postId}'
                      : 'Beitrag',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: AppColors.googleYellow,
                  );
                }),
              ),
            ],
          ),
          if (review.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.text,
              style: tt.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
          if (review.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              _fmt(review.createdAt),
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
