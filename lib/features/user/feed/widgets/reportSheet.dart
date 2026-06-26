import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/feedPostModel.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';

/// Available report reasons (label shown to the user → reason code stored).
const _reasons = <(String, String)>[
  ('Spam', 'spam'),
  ('Unangemessen', 'inappropriate'),
  ('Falsche Infos', 'misinformation'),
  ('Sonstiges', 'other'),
];

/// Opens a small reason picker for reporting a post. On selection it writes the
/// report via [UserFeedService.reportPost] and confirms with a snackbar.
Future<void> showReportPostSheet(
  BuildContext context, {
  required UserFeedService feedService,
  required FeedPostModel post,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm + 4),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Text(
              'Beitrag melden',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceDark,
                  ),
            ),
          ),
          for (final (label, code) in _reasons)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(label),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await feedService.reportPost(
                    postId: post.postId,
                    reason: code,
                    merchantId: post.merchantId,
                  );
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Danke für deine Meldung')),
                  );
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Meldung konnte nicht gesendet werden.')),
                  );
                }
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}
