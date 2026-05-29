import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appShadows.dart';
import '../../../../core/theme/appSpacing.dart';
import '../models/publicMerchantUserModel.dart';
import '../providers/userDiscoverProvider.dart';
import '../services/userDiscoverService.dart';

class UserDiscoverPage extends StatefulWidget {
  const UserDiscoverPage({super.key});

  @override
  State<UserDiscoverPage> createState() => _UserDiscoverPageState();
}

class _UserDiscoverPageState extends State<UserDiscoverPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _showActions = true;
  bool _showSearch = false;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final shouldShow = offset <= _lastOffset || offset < 80;
    if (shouldShow != _showActions) {
      setState(() => _showActions = shouldShow);
    }
    _lastOffset = offset;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserDiscoverProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: provider.load,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: AppColors.background,
                  title: const Text('Entdecken'),
                ),
                if (provider.usedFallbackLocation)
                  const SliverToBoxAdapter(child: _LocationNotice()),
                SliverToBoxAdapter(
                  child: _StoriesBar(
                    opacity: (1 - (_scrollController.hasClients
                                ? (_scrollController.offset / 180)
                                : 0))
                            .clamp(0.0, 1.0)
                            .toDouble(),
                    merchants: provider.merchants,
                  ),
                ),
                if (provider.isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.error != null)
                  const SliverFillRemaining(hasScrollBody: false, child: _ErrorState())
                else if (provider.visibleItems.isEmpty)
                  const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    sliver: SliverList.separated(
                      itemCount: provider.visibleItems.length + (provider.canLoadMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 18),
                      itemBuilder: (context, index) {
                        if (index >= provider.visibleItems.length) {
                          return FilledButton(
                            onPressed: provider.isLoadingMore ? null : provider.loadMore,
                            child: const Text('Mehr laden'),
                          );
                        }
                        return _FeedCard(item: provider.visibleItems[index]);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_showSearch)
            Positioned(
              left: 16,
              right: 16,
              bottom: 92,
              child: _SearchPanel(
                controller: _searchController,
                onSubmit: () {
                  provider.applySearch(_searchController.text);
                  setState(() => _showSearch = false);
                },
              ),
            ),
          Positioned(
            right: 16,
            bottom: 92,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 180),
              offset: _showActions ? Offset.zero : const Offset(0, 2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showActions ? 1 : 0,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'discoverSearch',
                      onPressed: () => setState(() => _showSearch = !_showSearch),
                      child: const Icon(Icons.search_rounded),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'discoverFilter',
                      onPressed: () => _showFilters(context, provider),
                      child: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoriesBar extends StatefulWidget {
  const _StoriesBar({required this.merchants, required this.opacity});

  final List<PublicMerchantUserModel> merchants;
  final double opacity;

  @override
  State<_StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<_StoriesBar> {
  final _controller = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _StoriesBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.merchants.length != widget.merchants.length) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!_controller.hasClients || widget.merchants.length < 2) return;
      final next = _controller.offset + 0.45;
      if (next >= _controller.position.maxScrollExtent) {
        _controller.jumpTo(0);
      } else {
        _controller.jumpTo(next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.merchants.isEmpty) return const SizedBox.shrink();
    return Opacity(
      opacity: widget.opacity,
      child: SizedBox(
        height: 106,
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: widget.merchants.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) => _StoryBubble(merchant: widget.merchants[index]),
        ),
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({required this.merchant});

  final PublicMerchantUserModel merchant;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => context.push('/user/partners/${merchant.merchantId}', extra: merchant),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mintSoft,
                border: Border.all(color: AppColors.mintStrong, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: merchant.logoUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: merchant.logoUrl, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        _initials(merchant.shopName),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              merchant.shopName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final DiscoverFeedItem item;

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    final merchant = item.merchant;
    final provider = context.read<UserDiscoverProvider>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _Logo(url: merchant.logoUrl, name: merchant.shopName, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchant.shopName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        [merchant.area, merchant.shopType].where((v) => v.isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 12, color: AppColors.gray500),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _showInfoSheet(context, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'report', child: Text('Beitrag melden')),
                    PopupMenuItem(value: 'why', child: Text('Warum sehe ich das?')),
                    PopupMenuItem(value: 'share', child: Text('Teilen')),
                  ],
                ),
              ],
            ),
          ),
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.08,
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.gray100),
                  errorWidget: (_, __, ___) => Container(color: AppColors.gray100),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _Badge(label: feedTypeLabel(post.type)),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: _LikeButton(
                  liked: item.isLiked,
                  onTap: () async {
                    try {
                      await provider.toggleLike(item);
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bitte einloggen')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (item.averageRating != null)
                      Text('★ ${item.averageRating!.toStringAsFixed(1)}')
                    else
                      const Text('Neu', style: TextStyle(color: AppColors.gray500)),
                  ],
                ),
                if (post.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(post.subtitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
                if (post.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.gray700, height: 1.45),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await provider.incrementOpen(post.postId);
                      if (context.mounted) {
                        context.push('/user/feed/${post.postId}', extra: post);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                    label: const Text('Mehr lesen'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(999),
      color: AppColors.surface.withOpacity(0.96),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: 'Titel, Shop, Kategorie oder Area',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            onPressed: onSubmit,
            icon: const Icon(Icons.check_rounded),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

void _showFilters(BuildContext context, UserDiscoverProvider provider) {
  final city = TextEditingController(text: provider.city);
  var radius = provider.radius;
  var area = provider.area;
  var shopType = provider.shopType;
  var openNow = provider.openNow;
  var sort = provider.sort;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Filter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'Ort'),
              ),
              const SizedBox(height: 16),
              _ChipGroup(
                title: 'Umkreis',
                options: const ['1 km', '3 km', '5 km', '10 km', '25 km', 'Egal'],
                selected: radius,
                onSelected: (value) => setState(() => radius = value),
              ),
              _ChipGroup(
                title: 'Area',
                options: provider.areas,
                selected: area,
                onSelected: (value) => setState(() => area = value == area ? null : value),
              ),
              _ChipGroup(
                title: 'Kategorie',
                options: provider.shopTypes,
                selected: shopType,
                onSelected: (value) => setState(() => shopType = value == shopType ? null : value),
              ),
              SwitchListTile(
                value: openNow,
                onChanged: (value) => setState(() => openNow = value),
                title: const Text('Jetzt geöffnet'),
              ),
              SegmentedButton<DiscoverSort>(
                segments: const [
                  ButtonSegment(value: DiscoverSort.hottest, label: Text('Hottest')),
                  ButtonSegment(value: DiscoverSort.newest, label: Text('Neueste')),
                ],
                selected: {sort},
                onSelectionChanged: (value) => setState(() => sort = value.first),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        provider.resetFilters();
                        context.pop();
                      },
                      child: const Text('Zurücksetzen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        provider.applyFilters(
                          city: city.text,
                          radius: radius,
                          area: area,
                          shopType: shopType,
                          openNow: openNow,
                          sort: sort,
                        );
                        context.pop();
                      },
                      child: const Text('Anwenden'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => ChoiceChip(
                    label: Text(option),
                    selected: selected == option,
                    onSelected: (_) => onSelected(option),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

void _showInfoSheet(BuildContext context, String value) {
  final text = switch (value) {
    'report' => 'Danke. Diese Funktion wird bald vollständig aktiviert.',
    'why' =>
      'Du siehst diesen Beitrag, weil er zu deiner Stadt, deinen Filtern und beliebten lokalen Angeboten passt.',
    _ => 'Teilen kommt bald.',
  };
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.name, required this.size});

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.mintSoft, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
          : Center(child: Text(_initials(name))),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.black.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.white, fontSize: 12)),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.onTap});

  final bool liked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: AppColors.white.withOpacity(0.92)),
      icon: Icon(
        liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: liked ? Colors.redAccent : AppColors.black,
      ),
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text('Standort nicht aktiv. Wir zeigen dir Frankfurt.'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Noch keine Beiträge verfügbar.'));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Entdecken konnte nicht geladen werden.'));
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'L';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
}

String feedTypeLabel(String type) {
  const labels = {
    'offer': 'Angebot',
    'onePlusOneFree': '1+1 Gratis',
    'buyOneGetOneFree': 'Kauf 1, bekomme 1',
    'twoPlusOneFree': '2+1 Gratis',
    'buyTwoGetOneFree': 'Kauf 2, bekomme 1',
    'categoryDiscountPercent': 'Prozent-Rabatt',
    'categoryDiscountFixed': 'Rabatt',
    'happyHour': 'Happy Hour',
    'quickSell': 'Schnell weg',
    'rescueMe': 'Rette mich',
    'news': 'Neuigkeit',
    'newProduct': 'Neue Ware',
    'info': 'Info',
    'communityEvent': 'Event',
    'hiring': 'Team gesucht',
    'sponsoredSpot': 'Sponsored',
  };
  return labels[type] ?? type;
}
