import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/uploadService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/reviewModel.dart';

/// Kompakte Ø-Sterne-Anzeige (Social Proof).
class ReviewStars extends StatelessWidget {
  const ReviewStars({
    super.key,
    required this.rating,
    this.count,
    this.size = 14,
    this.color = AppColors.onSurfaceDark,
  });

  final double rating;
  final int? count;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 3, color: AppColors.googleYellow),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: tt.labelMedium?.copyWith(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 3),
          Text(
            '($count)',
            style: tt.labelSmall?.copyWith(
              fontSize: size - 1,
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Einzelne Rezension in der Liste (mit optionalem Foto).
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.isMine = false});

  final ReviewModel review;
  final bool isMine;

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isMine ? cs.secondaryContainer : AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: isMine
            ? null
            : Border.all(color: AppColors.outlineGray.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isMine
                      ? 'Du'
                      : (review.userName.isEmpty ? 'Anonym' : review.userName),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceDark,
                  ),
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
            const SizedBox(height: 6),
            Text(
              review.text,
              style: tt.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
                height: 1.4,
              ),
            ),
          ],
          if (review.imageUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: CachedNetworkImage(
                imageUrl: review.imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],
          if (review.createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              _fmt(review.createdAt),
              style: tt.labelSmall?.copyWith(color: AppColors.onSurfaceMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Öffnet das Bottom-Sheet zum Schreiben/Bearbeiten einer Rezension.
Future<void> showReviewWriteSheet(
  BuildContext context, {
  required String title,
  double initialRating = 0,
  String initialText = '',
  String initialImageUrl = '',
  required Future<void> Function({
    required double rating,
    required String text,
    required String imageUrl,
  }) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _ReviewWriteSheet(
      title: title,
      initialRating: initialRating,
      initialText: initialText,
      initialImageUrl: initialImageUrl,
      onSubmit: onSubmit,
    ),
  );
}

class _ReviewWriteSheet extends StatefulWidget {
  const _ReviewWriteSheet({
    required this.title,
    required this.initialRating,
    required this.initialText,
    required this.initialImageUrl,
    required this.onSubmit,
  });

  final String title;
  final double initialRating;
  final String initialText;
  final String initialImageUrl;
  final Future<void> Function({
    required double rating,
    required String text,
    required String imageUrl,
  }) onSubmit;

  @override
  State<_ReviewWriteSheet> createState() => _ReviewWriteSheetState();
}

class _ReviewWriteSheetState extends State<_ReviewWriteSheet> {
  late double _rating;
  late final TextEditingController _ctrl;
  late String _imageUrl;
  Uint8List? _pickedBytes;
  String? _pickedName;
  bool _submitting = false;

  static const _ratingLabels = <String>[
    'Tippe zum Bewerten',
    'Schlecht',
    'Geht so',
    'Okay',
    'Gut',
    'Top',
  ];

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _ctrl = TextEditingController(text: widget.initialText);
    _imageUrl = widget.initialImageUrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final upload = context.read<UploadService>();
    final picked = await upload.pickImageWithImagePicker();
    if (picked == null || !mounted) return;
    setState(() {
      _pickedBytes = picked.bytes;
      _pickedName = picked.fileName;
    });
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);
    try {
      var imageUrl = _imageUrl;
      if (_pickedBytes != null) {
        final upload = context.read<UploadService>();
        final media = await upload.uploadOptimizedImageBytes(
          bytes: _pickedBytes!,
          fileName: _pickedName ?? 'review.jpg',
          type: UploadImageType.general,
        );
        imageUrl = media.secureUrl.isNotEmpty ? media.secureUrl : media.url;
      }
      await widget.onSubmit(
        rating: _rating,
        text: _ctrl.text.trim(),
        imageUrl: imageUrl,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konnte nicht gespeichert werden. Bitte erneut.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.title,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceDark,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () =>
                        setState(() => _rating = (i + 1).toDouble()),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: AppColors.googleYellow,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              _ratingLabels[_rating.round().clamp(0, 5)],
              style: tt.labelLarge?.copyWith(
                color: _rating > 0
                    ? AppColors.onSurfaceDark
                    : AppColors.onSurfaceMuted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Deine Meinung (optional) …',
              filled: true,
              fillColor: AppColors.surfaceGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _photoSection(),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_rating > 0 && !_submitting) ? _submit : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: _submitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Text(
                      'Absenden',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoSection() {
    final hasPicked = _pickedBytes != null;
    final hasExisting = _imageUrl.isNotEmpty;
    if (hasPicked || hasExisting) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: hasPicked
                ? Image.memory(_pickedBytes!,
                    width: 64, height: 64, fit: BoxFit.cover)
                : CachedNetworkImage(
                    imageUrl: _imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Foto ändern'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _pickedBytes = null;
              _pickedName = null;
              _imageUrl = '';
            }),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.googleRed,
            ),
            child: const Text('Entfernen'),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: _pickPhoto,
      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
      label: const Text('Foto hinzufügen (optional)'),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
