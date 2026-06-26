import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/feed/feedPostTypeStyle.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../stamps/models/stampCardModel.dart';
import '../../stamps/services/merchantStampsService.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../services/merchantFeedCreateService.dart';

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
        stampsService: MerchantStampsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantFeedManageView(),
    );
  }
}

class _MerchantFeedManageView extends StatefulWidget {
  const _MerchantFeedManageView();

  @override
  State<_MerchantFeedManageView> createState() => _MerchantFeedManageViewState();
}

class _MerchantFeedManageViewState extends State<_MerchantFeedManageView> {
  _FeedManageFilter _filter = _FeedManageFilter.all;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantFeedManageProvider>();
    final texts = context.watch<LanguageService>();
    final filteredPosts = provider.posts.where(_matchesFilter).toList();
    return MerchantToolScaffold(
      title: texts.text('merchant.feedManage.title'),
      subtitle: texts.text('merchant.feedManage.tooltip'),
      backPath: '/merchant/dashboard',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.feedManage.tooltip')),
      child: provider.isLoading
          ? const MerchantLoadingCards()
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : provider.posts.isEmpty
                  ? _EmptyManage(onCreate: () => _showCreateChooser(context))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MerchantPrimaryButton(
                          label: texts.text('merchant.feedManage.newPost'),
                          icon: Icons.add_rounded,
                          onPressed: () => _showCreateChooser(context),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _FilterBar(
                          selected: _filter,
                          onSelected: (value) => setState(() => _filter = value),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (filteredPosts.isEmpty)
                          MerchantEmptyState(
                            title: texts.text('merchant.feedManage.emptyFilterTitle'),
                            message: texts.text('merchant.feedManage.emptyFilterMessage'),
                            actionLabel: texts.text('common.all'),
                            onAction: () => setState(() => _filter = _FeedManageFilter.all),
                          )
                        else
                          _FeedGrid(posts: filteredPosts),
                      ],
                    ),
    );
  }

  bool _matchesFilter(MerchantFeedPostData post) {
    return switch (_filter) {
      _FeedManageFilter.all => true,
      _FeedManageFilter.active =>
        post.isActive && !post.isPrivate && !post.isArchived && !post.isScheduled,
      _FeedManageFilter.scheduled => post.isScheduled && !post.isArchived,
      _FeedManageFilter.private => post.isPrivate && !post.isArchived,
      _FeedManageFilter.archived => post.isArchived,
    };
  }
}

enum _FeedManageFilter { all, active, scheduled, private, archived }

/// Bottom sheet that lets the merchant choose what kind of post to create: a
/// regular post or the ready-made stamp-card ad template.
void _showCreateChooser(BuildContext context) {
  final texts = context.read<LanguageService>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.baseElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              texts.text('merchant.feedManage.newPost'),
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _CreateChoiceTile(
              icon: Icons.post_add_rounded,
              title: texts.text('merchant.feedManage.create.standardTitle'),
              subtitle: texts.text('merchant.feedManage.create.standardSubtitle'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/merchant/feed/create');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _CreateChoiceTile(
              icon: Icons.card_giftcard_rounded,
              title: texts.text('merchant.feedManage.create.stampAdTitle'),
              subtitle: texts.text('merchant.feedManage.create.stampAdSubtitle'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/merchant/feed/stamp-ad');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _CreateChoiceTile extends StatelessWidget {
  const _CreateChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: MerchantPremiumColors.surfaceAlt,
      onTap: onTap,
      child: Row(
        children: [
          MerchantPremiumIconBox(icon: icon, size: 46),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: MerchantPremiumColors.muted),
        ],
      ),
    );
  }
}

class _EmptyManage extends StatelessWidget {
  const _EmptyManage({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantEmptyState(
      icon: Icons.post_add_rounded,
      title: texts.text('merchant.feedManage.emptyTitle'),
      message: texts.text('merchant.feedManage.emptyMessage'),
      actionLabel: texts.text('merchant.feedManage.newPost'),
      onAction: onCreate,
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.onSelected,
  });

  final _FeedManageFilter selected;
  final ValueChanged<_FeedManageFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final options = [
      (_FeedManageFilter.all, texts.text('common.all')),
      (_FeedManageFilter.active, texts.text('common.active')),
      (_FeedManageFilter.scheduled, texts.text('merchant.feedManage.scheduled')),
      (_FeedManageFilter.private, texts.text('common.private')),
      (_FeedManageFilter.archived, texts.text('merchant.feedManage.archived')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options
            .map(
              (option) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(option.$2),
                  selected: selected == option.$1,
                  selectedColor: MerchantPremiumColors.ink,
                  backgroundColor: MerchantPremiumColors.baseSoft,
                  side: BorderSide(
                    color: selected == option.$1 ? MerchantPremiumColors.gold : Colors.white.withValues(alpha: 0.12),
                  ),
                  labelStyle: TextStyle(
                    color: selected == option.$1 ? Colors.white : MerchantPremiumColors.mutedLight,
                    fontWeight: FontWeight.w900,
                  ),
                  onSelected: (_) => onSelected(option.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Instagram-style uniform tile grid. Uses a width-aware Wrap so it nests
/// safely inside the scaffold's scroll view (no nested-scroll conflicts).
class _FeedGrid extends StatelessWidget {
  const _FeedGrid({required this.posts});

  final List<MerchantFeedPostData> posts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final maxW = constraints.maxWidth;
        final columns = maxW >= 900
            ? 4
            : maxW >= 600
                ? 3
                : 2;
        final tileWidth = (maxW - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: posts
              .map((post) => SizedBox(
                    width: tileWidth,
                    child: _FeedTile(post: post),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.post});

  final MerchantFeedPostData post;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final dimmed = post.isArchived || (!post.isActive && !post.isScheduled);
    return GestureDetector(
      onTap: () => _showPostActions(context, post),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail (image-forward).
              ColoredBox(
                color: MerchantPremiumColors.surfaceAlt,
                child: post.imageUrl.isEmpty
                    ? const Center(
                        child: Icon(Icons.campaign_rounded, size: 34, color: MerchantPremiumColors.muted),
                      )
                    : CachedNetworkImage(
                        imageUrl: post.imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image_rounded, size: 30, color: MerchantPremiumColors.muted),
                        ),
                      ),
              ),
              if (dimmed)
                Container(color: Colors.black.withValues(alpha: 0.45)),
              // Bottom scrim + title.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.66),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.type.isNotEmpty) ...[
                        FeedTypeBadge(type: post.type, onImage: true, compact: true),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        post.title.isEmpty ? texts.text('merchant.feedManage.noTitle') : post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Status badge (top-left).
              Positioned(
                top: 8,
                left: 8,
                child: _StatusBadge(status: post.status),
              ),
              // Stamp-ad / CTA markers (top-right).
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    if (post.isStampAd)
                      const _TileIconPill(icon: Icons.card_giftcard_rounded),
                    if (post.hasButton) ...[
                      const SizedBox(width: 5),
                      const _TileIconPill(icon: Icons.link_rounded),
                    ],
                    if (post.isPrivate) ...[
                      const SizedBox(width: 5),
                      const _TileIconPill(icon: Icons.lock_rounded),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileIconPill extends StatelessWidget {
  const _TileIconPill({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 15, color: Colors.white),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final MerchantPostStatus status;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final (label, color) = switch (status) {
      MerchantPostStatus.published => (texts.text('merchant.feedManage.status.published'), MerchantPremiumColors.gold),
      MerchantPostStatus.scheduled => (texts.text('merchant.feedManage.scheduled'), const Color(0xFF6FA8FF)),
      MerchantPostStatus.paused => (texts.text('merchant.feedManage.paused'), MerchantPremiumColors.muted),
      MerchantPostStatus.archived => (texts.text('merchant.feedManage.archived'), const Color(0xFFE08A8A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile actions ──────────────────────────────────────────────────────────────

void _showPostActions(BuildContext context, MerchantFeedPostData post) {
  final provider = context.read<MerchantFeedManageProvider>();
  final texts = context.read<LanguageService>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.baseElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                post.title.isEmpty ? texts.text('merchant.feedManage.noTitle') : post.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _ActionRow(
              icon: Icons.edit_rounded,
              label: texts.text('common.edit'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showEditSheet(context, post);
              },
            ),
            _ActionRow(
              icon: Icons.link_rounded,
              label: texts.text('merchant.feedManage.editLink'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showEditSheet(context, post, focusCta: true);
              },
            ),
            if (post.isScheduled)
              _ActionRow(
                icon: Icons.rocket_launch_rounded,
                label: texts.text('merchant.feedManage.publishNow'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  provider.updatePost(post.postId, {
                    'isScheduled': false,
                    'isActive': true,
                    'publishedAt': FieldValue.serverTimestamp(),
                  });
                },
              ),
            if (!post.isScheduled && !post.isArchived)
              _ActionRow(
                icon: post.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: post.isActive
                    ? texts.text('merchant.feedManage.pause')
                    : texts.text('common.activate'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  provider.updatePost(post.postId, {'isActive': !post.isActive});
                },
              ),
            if (!post.isArchived)
              _ActionRow(
                icon: post.isPrivate ? Icons.public_rounded : Icons.lock_rounded,
                label: post.isPrivate ? texts.text('common.public') : texts.text('common.private'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  provider.updatePost(post.postId, {'isPrivate': !post.isPrivate});
                },
              ),
            if (!post.isArchived)
              _ActionRow(
                icon: Icons.archive_rounded,
                label: texts.text('merchant.feedManage.archive'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmArchive(context, post);
                },
              ),
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: texts.text('common.delete'),
              isDanger: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, post);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.red.shade400 : MerchantPremiumColors.ink;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
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

Future<void> _confirmDelete(BuildContext context, MerchantFeedPostData post) async {
  final provider = context.read<MerchantFeedManageProvider>();
  final texts = context.read<LanguageService>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(texts.text('merchant.feedManage.deleteTitle')),
      content: Text(texts.text('merchant.feedManage.deleteMessage')),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(texts.text('common.cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(texts.text('common.delete')),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await provider.deletePost(post.postId);
  }
}

void _showEditSheet(BuildContext context, MerchantFeedPostData post, {bool focusCta = false}) {
  final provider = context.read<MerchantFeedManageProvider>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.baseElevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider<MerchantFeedManageProvider>.value(
      value: provider,
      child: _FeedEditSheet(post: post, provider: provider, focusCta: focusCta),
    ),
  );
}

class _FeedEditSheet extends StatefulWidget {
  const _FeedEditSheet({
    required this.post,
    required this.provider,
    this.focusCta = false,
  });

  final MerchantFeedPostData post;
  final MerchantFeedManageProvider provider;
  final bool focusCta;

  @override
  State<_FeedEditSheet> createState() => _FeedEditSheetState();
}

class _FeedEditSheetState extends State<_FeedEditSheet> {
  late final TextEditingController titleController;
  late final TextEditingController subtitleController;
  late final TextEditingController descriptionController;
  late final TextEditingController ctaController;
  late final TextEditingController urlController;
  late bool isActive;
  late bool isPrivate;

  /// CTA target: 'none' | 'profile' | 'url' | 'stampCard'.
  late String ctaTarget;
  String? selectedCardId;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.post.title);
    subtitleController = TextEditingController(text: widget.post.subtitle);
    descriptionController = TextEditingController(text: widget.post.description);
    ctaController = TextEditingController(text: widget.post.ctaLabel);
    urlController = TextEditingController(text: widget.post.ctaUrl);
    isActive = widget.post.isActive;
    isPrivate = widget.post.isPrivate;
    ctaTarget = _normalizeTarget(widget.post.ctaLinkType, widget.post.ctaLabel);
    selectedCardId = widget.post.ctaTargetId.isNotEmpty ? widget.post.ctaTargetId : null;
  }

  /// Maps legacy link types onto the editor's three targets so old posts open
  /// with a sensible selection.
  String _normalizeTarget(String linkType, String label) {
    final t = linkType.trim();
    if (t.isEmpty) return label.trim().isEmpty ? 'none' : 'profile';
    return switch (t) {
      'profile' => 'profile',
      'stampCard' => 'stampCard',
      'url' || 'external' => 'url',
      // shop/catalog/feedPost legacy → treat as profile so the merchant can
      // re-point it; the original value stays until they save.
      _ => 'profile',
    };
  }

  @override
  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    descriptionController.dispose();
    ctaController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final isSaving = context.watch<MerchantFeedManageProvider>().isSaving;
    final cards = widget.provider.linkableCards;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.of(context).viewInsets.bottom + 18),
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
                    decoration: BoxDecoration(
                      color: MerchantPremiumColors.ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          texts.text('merchant.feedManage.editTitle'),
                          style: const TextStyle(
                            color: MerchantPremiumColors.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          texts.text('merchant.feedManage.editTip'),
                          style: const TextStyle(
                            color: MerchantPremiumColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
              const SizedBox(height: AppSpacing.lg),
              // ── CTA / Link editor ────────────────────────────────────────
              Text(
                texts.text('merchant.feedManage.ctaSection'),
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              MerchantTextField(controller: ctaController, label: texts.text('merchant.feedManage.ctaLabel')),
              const SizedBox(height: AppSpacing.sm),
              _TargetPicker(
                selected: ctaTarget,
                onSelected: (value) => setState(() {
                  ctaTarget = value;
                  _urlError = null;
                }),
              ),
              if (ctaTarget == 'url') ...[
                const SizedBox(height: AppSpacing.sm),
                MerchantTextField(
                  controller: urlController,
                  label: texts.text('merchant.feedManage.ctaUrl'),
                  keyboardType: TextInputType.url,
                ),
                if (_urlError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _urlError!,
                    style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ],
              ],
              if (ctaTarget == 'stampCard') ...[
                const SizedBox(height: AppSpacing.sm),
                _CardPickerField(
                  cards: cards,
                  selectedCardId: selectedCardId,
                  onChanged: (value) => setState(() => selectedCardId = value),
                ),
              ],
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
                isLoading: isSaving,
                onPressed: () => _save(context, texts),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, LanguageService texts) async {
    if (widget.provider.isSaving) return;
    final label = ctaController.text.trim();
    final hasButton = ctaTarget != 'none' && label.isNotEmpty;

    // Validation.
    if (ctaTarget != 'none' && label.isEmpty) {
      _toast(context, texts.text('merchant.feedManage.error.ctaLabel'));
      return;
    }
    if (ctaTarget == 'url') {
      final normalized = _validateUrl(urlController.text.trim());
      if (normalized == null) {
        setState(() => _urlError = texts.text('merchant.feedManage.error.url'));
        return;
      }
      urlController.text = normalized;
    }
    if (ctaTarget == 'stampCard' && (selectedCardId == null || selectedCardId!.isEmpty)) {
      _toast(context, texts.text('merchant.feedManage.error.card'));
      return;
    }

    final values = <String, dynamic>{
      'title': titleController.text.trim(),
      'subtitle': subtitleController.text.trim(),
      'description': descriptionController.text.trim(),
      'isActive': isActive,
      'isPrivate': isPrivate,
      'ctaLabel': hasButton ? label : '',
      'ctaType': hasButton ? 'primary' : '',
      'ctaLinkType': hasButton ? ctaTarget : '',
      'ctaTargetId': hasButton && ctaTarget == 'stampCard' ? (selectedCardId ?? '') : '',
      'ctaUrl': hasButton && ctaTarget == 'url' ? urlController.text.trim() : '',
      'ctaRoute': hasButton
          ? MerchantFeedCreateService.ctaRouteFor(
              merchantId: widget.provider.merchantId,
              linkType: ctaTarget,
              targetId: ctaTarget == 'stampCard' ? (selectedCardId ?? '') : '',
            )
          : '',
    };
    await widget.provider.updatePost(widget.post.postId, values);
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Returns a normalised https URL, or null if invalid.
  String? _validateUrl(String input) {
    if (input.isEmpty) return null;
    var candidate = input;
    if (!candidate.startsWith('http://') && !candidate.startsWith('https://')) {
      candidate = 'https://$candidate';
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasAuthority || !uri.host.contains('.')) return null;
    return candidate;
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TargetPicker extends StatelessWidget {
  const _TargetPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    const options = ['none', 'profile', 'url', 'stampCard'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (value) => ChoiceChip(
              label: Text(texts.text('merchant.feedManage.cta.$value')),
              selected: selected == value,
              selectedColor: MerchantPremiumColors.ink,
              backgroundColor: MerchantPremiumColors.surfaceAlt,
              side: BorderSide(
                color: selected == value ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
              ),
              labelStyle: TextStyle(
                color: selected == value ? Colors.white : MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
              ),
              onSelected: (_) => onSelected(value),
            ),
          )
          .toList(),
    );
  }
}

class _CardPickerField extends StatelessWidget {
  const _CardPickerField({
    required this.cards,
    required this.selectedCardId,
    required this.onChanged,
  });

  final List<StampCardModel> cards;
  final String? selectedCardId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    if (cards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: Text(
          texts.text('merchant.feedManage.noCards'),
          style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w800),
        ),
      );
    }
    // Guard against a stale id (e.g. linked card later archived).
    final value = cards.any((c) => c.id == selectedCardId) ? selectedCardId : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(
            texts.text('merchant.feedManage.pickCard'),
            style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w800),
          ),
          dropdownColor: MerchantPremiumColors.baseElevated,
          items: cards
              .map(
                (card) => DropdownMenuItem(
                  value: card.id,
                  child: Text(
                    card.title.isEmpty ? texts.text('merchant.stamps.untitled') : card.title,
                    style: const TextStyle(color: MerchantPremiumColors.ink, fontWeight: FontWeight.w800),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
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
      title: Text(
        title,
        style: const TextStyle(
          color: MerchantPremiumColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
