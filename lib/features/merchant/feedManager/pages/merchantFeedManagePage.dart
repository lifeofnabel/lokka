import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantFeedManagePage extends StatelessWidget {
  const MerchantFeedManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantFeedManageProvider(
        service: MerchantToolsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantFeedManageView(),
    );
  }
}

class _MerchantFeedManageView extends StatelessWidget {
  const _MerchantFeedManageView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantFeedManageProvider>();
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.feedManage.title'),
      subtitle: texts.text('merchant.feedManage.tooltip'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.feedManage.tooltip')),
      child: provider.isLoading
          ? const MerchantLoadingCards()
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : provider.posts.isEmpty
                  ? MerchantEmptyState(
                      title: texts.text('merchant.feedManage.emptyTitle'),
                      message: texts.text('merchant.feedManage.emptyMessage'),
                      actionLabel: texts.text('common.refresh'),
                      onAction: provider.load,
                    )
                  : Column(
                      children: provider.posts
                          .map(
                            (post) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FeedPostCard(post: post),
                            ),
                          )
                          .toList(),
                    ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({required this.post});

  final MerchantFeedPostData post;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MerchantFeedManageProvider>();
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(24)),
                clipBehavior: Clip.antiAlias,
                child: post.imageUrl.isEmpty
                    ? const Icon(Icons.campaign_rounded, size: 30)
                    : CachedNetworkImage(imageUrl: post.imageUrl, fit: BoxFit.cover),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.title.isEmpty ? texts.text('merchant.feedManage.noTitle') : post.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      post.type.isEmpty
                          ? texts.text('merchant.feedManage.post')
                          : texts.text('feed.type.${post.type}'),
                      style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w700),
                    ),
                    if (post.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        post.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.gray700),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      children: [
                        _StatusChip(label: post.isArchived ? texts.text('merchant.feedManage.archived') : post.isActive ? texts.text('common.active') : texts.text('merchant.feedManage.paused')),
                        if (post.isPrivate) _StatusChip(label: texts.text('common.private')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showEditSheet(context, post),
                icon: const Icon(Icons.edit_rounded),
                label: Text(texts.text('common.edit')),
              ),
              OutlinedButton(
                onPressed: () => provider.updatePost(post.postId, {'isPrivate': !post.isPrivate}),
                child: Text(post.isPrivate ? texts.text('common.public') : texts.text('common.private')),
              ),
              OutlinedButton(
                onPressed: () => provider.updatePost(post.postId, {'isActive': !post.isActive}),
                child: Text(post.isActive ? texts.text('merchant.feedManage.pause') : texts.text('common.activate')),
              ),
              TextButton(
                onPressed: () => _confirmArchive(context, post),
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                child: Text(texts.text('merchant.feedManage.archive')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

Future<void> _confirmArchive(BuildContext context, MerchantFeedPostData post) async {
  final provider = context.read<MerchantFeedManageProvider>();
  final texts = context.read<LanguageService>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(texts.text('merchant.feedManage.archiveTitle')),
      content: Text(texts.text('merchant.feedManage.archiveMessage')),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(texts.text('common.cancel'))),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(texts.text('merchant.feedManage.archive'))),
      ],
    ),
  );
  if (confirmed == true) {
    await provider.updatePost(post.postId, {'isArchived': true, 'isActive': false});
  }
}

void _showEditSheet(BuildContext context, MerchantFeedPostData post) {
  final provider = context.read<MerchantFeedManageProvider>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    isScrollControlled: true,
    builder: (_) => _FeedEditSheet(post: post, provider: provider),
  );
}

class _FeedEditSheet extends StatefulWidget {
  const _FeedEditSheet({
    required this.post,
    required this.provider,
  });

  final MerchantFeedPostData post;
  final MerchantFeedManageProvider provider;

  @override
  State<_FeedEditSheet> createState() => _FeedEditSheetState();
}

class _FeedEditSheetState extends State<_FeedEditSheet> {
  late final TextEditingController titleController;
  late final TextEditingController subtitleController;
  late final TextEditingController descriptionController;
  late final TextEditingController ctaController;
  late bool isActive;
  late bool isPrivate;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.post.title);
    subtitleController = TextEditingController(text: widget.post.subtitle);
    descriptionController = TextEditingController(text: widget.post.description);
    ctaController = TextEditingController(text: widget.post.ctaLabel);
    isActive = widget.post.isActive;
    isPrivate = widget.post.isPrivate;
  }

  @override
  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    descriptionController.dispose();
    ctaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          4,
          18,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.edit_rounded, color: AppColors.white),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(texts.text('merchant.feedManage.editTitle'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(texts.text('merchant.feedManage.editTip'), style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              MerchantTextField(controller: titleController, label: texts.text('merchant.feedManage.titleLabel')),
              const SizedBox(height: AppSpacing.sm),
              MerchantTextField(controller: subtitleController, label: texts.text('merchant.feedManage.subtitleLabel')),
              const SizedBox(height: AppSpacing.sm),
              MerchantTextField(
                controller: descriptionController,
                label: texts.text('merchant.feedManage.descriptionLabel'),
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.sm),
              MerchantTextField(controller: ctaController, label: texts.text('merchant.feedManage.ctaLabel')),
              const SizedBox(height: AppSpacing.md),
              _EditSwitch(
                title: texts.text('common.active'),
                value: isActive,
                onChanged: (value) => setState(() => isActive = value),
              ),
              _EditSwitch(
                title: texts.text('common.private'),
                value: isPrivate,
                onChanged: (value) => setState(() => isPrivate = value),
              ),
              const SizedBox(height: AppSpacing.md),
              MerchantPrimaryButton(
                label: texts.text('merchant.feedManage.saveChanges'),
                icon: Icons.check_rounded,
                isLoading: widget.provider.isSaving,
                onPressed: () async {
                  await widget.provider.updatePost(widget.post.postId, {
                    'title': titleController.text.trim(),
                    'subtitle': subtitleController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'ctaLabel': ctaController.text.trim(),
                    'isActive': isActive,
                    'isPrivate': isPrivate,
                  });
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditSwitch extends StatelessWidget {
  const _EditSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      value: value,
      onChanged: onChanged,
    );
  }
}
