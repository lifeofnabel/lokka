import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/feed/models/commentModel.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';

/// Opens the comments bottom sheet for a post. Reads live from
/// `feed/{postId}/comments`, lets the signed-in user post and delete their own
/// comments. Returns when the sheet is dismissed.
Future<void> showCommentsSheet(
  BuildContext context, {
  required UserFeedService feedService,
  required String postId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentsSheet(feedService: feedService, postId: postId),
  );
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.feedService, required this.postId});

  final UserFeedService feedService;
  final String postId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  bool get _signedIn => widget.feedService.authService.currentUser != null;
  String? get _uid => widget.feedService.authService.currentUser?.uid;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.feedService.addComment(widget.postId, text);
      if (mounted) _ctrl.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Kommentar konnte nicht gesendet werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(CommentModel c) async {
    try {
      await widget.feedService.deleteComment(widget.postId, c.commentId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konnte nicht gelöscht werden.')),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Kommentare',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceDark,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CommentModel>>(
                stream: widget.feedService.commentsStream(widget.postId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final comments = snapshot.data ?? const <CommentModel>[];
                  if (comments.isEmpty) {
                    return const Center(child: _EmptyComments());
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    itemCount: comments.length,
                    itemBuilder: (_, i) => _CommentTile(
                      comment: comments[i],
                      isMine: _uid != null && comments[i].userId == _uid,
                      onDelete: () => _delete(comments[i]),
                    ),
                  );
                },
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: _signedIn
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Kommentar schreiben …',
                        filled: true,
                        fillColor: AppColors.surfaceGray,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.onPrimary),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              )
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Bitte einloggen, um zu kommentieren.',
                  style: TextStyle(color: AppColors.onSurfaceMuted),
                ),
              ),
      ),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mode_comment_outlined,
            size: 40, color: AppColors.onSurfaceMuted),
        SizedBox(height: 10),
        Text(
          'Noch keine Kommentare.\nSchreib den ersten!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.onDelete,
  });

  final CommentModel comment;
  final bool isMine;
  final VoidCallback onDelete;

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
                      : (comment.userName.isEmpty ? 'Anonym' : comment.userName),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (comment.createdAt != null)
                Text(
                  _fmt(comment.createdAt),
                  style: tt.labelSmall
                      ?.copyWith(color: AppColors.onSurfaceMuted),
                ),
              if (isMine)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.googleRed),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            comment.text,
            style: tt.bodyMedium
                ?.copyWith(color: AppColors.onSurfaceMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
