import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
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
    return MerchantToolScaffold(
      title: 'Feed verwalten',
      subtitle: 'Hier pausierst oder aenderst du bereits veroeffentlichte Beitraege.',
      trailing: const MerchantInfoTooltip(message: 'Hier pausierst oder aenderst du bereits veroeffentlichte Beitraege.'),
      child: provider.isLoading
          ? const MerchantLoadingCards()
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : provider.posts.isEmpty
                  ? MerchantEmptyState(
                      title: 'Noch keine Beitraege',
                      message: 'Sobald du Aktionen veroeffentlicht hast, kannst du sie hier pausieren oder archivieren.',
                      actionLabel: 'Aktualisieren',
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
                    Text(post.title.isEmpty ? 'Ohne Titel' : post.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(post.type.isEmpty ? 'Beitrag' : post.type, style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      children: [
                        _StatusChip(label: post.isArchived ? 'Archiviert' : post.isActive ? 'Aktiv' : 'Pausiert'),
                        if (post.isPrivate) const _StatusChip(label: 'Privat'),
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
                onPressed: () => _showEditHint(context),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Bearbeiten'),
              ),
              OutlinedButton(
                onPressed: () => provider.updatePost(post.postId, {'isPrivate': !post.isPrivate}),
                child: Text(post.isPrivate ? 'Oeffentlich' : 'Privat'),
              ),
              OutlinedButton(
                onPressed: () => provider.updatePost(post.postId, {'isActive': !post.isActive}),
                child: Text(post.isActive ? 'Pausieren' : 'Aktivieren'),
              ),
              TextButton(
                onPressed: () => _confirmArchive(context, post),
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                child: const Text('Archivieren'),
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Beitrag archivieren?'),
      content: const Text('Der Beitrag verschwindet aus dem aktiven Feed, bleibt aber nachvollziehbar.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Archivieren')),
      ],
    ),
  );
  if (confirmed == true) {
    await provider.updatePost(post.postId, {'isArchived': true, 'isActive': false});
  }
}

void _showEditHint(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.edit_rounded, color: AppColors.mint),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Bearbeiten kommt als eigener Editor', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          const Text('Hier kannst du den Beitrag schon privat setzen, pausieren oder archivieren.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray700)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Okay')),
        ],
      ),
    ),
  );
}
