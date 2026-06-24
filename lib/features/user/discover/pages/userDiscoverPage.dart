import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/services/geoapifyService.dart';
import '../../../../core/utils/locationUtils.dart';
import '../../../../core/utils/shareUtils.dart';
import '../../../../core/widgets/appEmptyState.dart';
import '../../../../core/widgets/appErrorState.dart';
import '../../../../core/widgets/appSearchField.dart';
import '../../notifications/pages/userInboxPage.dart';
import '../../notifications/providers/userNotificationProvider.dart';
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
  int _topIndex = 0;

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
    // Grobe aktuelle Position für die „Neben mir"-Distanzanzeige rechts.
    final idx = ((offset - 60) / 470).floor().clamp(0, 100000);
    if (idx != _topIndex) setState(() => _topIndex = idx);
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
                  centerTitle: true,
                  titleSpacing: 4,
                  backgroundColor: AppColors.background,
                  title: _FeedModeToggle(
                    mode: provider.mode,
                    onChanged: provider.setMode,
                  ),
                  actions: [
                    _LocationButton(provider: provider),
                    const _InboxBell(),
                  ],
                ),
                if (provider.usedFallbackLocation)
                  const SliverToBoxAdapter(child: _LocationNotice()),
                if (provider.isLoading)
                  const SliverToBoxAdapter(child: _FeedSkeleton())
                else if (provider.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppErrorState(
                      message: 'Entdecken konnte nicht geladen werden.',
                      onRetry: provider.load,
                    ),
                  )
                else if (provider.visibleItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: switch (provider.mode) {
                      DiscoverFeedMode.following => AppEmptyState(
                          icon: Icons.favorite_border_rounded,
                          title: provider.hasFollowing
                              ? 'Noch nichts Neues'
                              : 'Du folgst noch keinem Partner',
                          message: provider.hasFollowing
                              ? 'Deine Partner haben aktuell keine Beiträge.'
                              : 'Füge Partner zu deiner Wallet hinzu – ihre Beiträge erscheinen dann hier.',
                        ),
                      DiscoverFeedMode.nearMe => const AppEmptyState(
                          icon: Icons.wrong_location_rounded,
                          title: 'Nichts in der Nähe',
                          message:
                              'Für deinen Standort gibt es gerade keine Beiträge mit Adresse.',
                        ),
                      DiscoverFeedMode.forYou => const AppEmptyState(
                          icon: Icons.explore_outlined,
                          title: 'Noch keine Beiträge',
                          message: 'Schau später nochmal vorbei.',
                        ),
                    },
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    sliver: SliverList.separated(
                      itemCount: provider.visibleItems.length + (provider.canLoadMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 18),
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
          // „Neben mir": rechts ein kleiner Distanz-Indikator, der beim Scrollen
          // grob mitrechnet, wie weit der aktuelle Beitrag entfernt ist.
          if (provider.mode == DiscoverFeedMode.nearMe &&
              provider.visibleItems.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: _NearMeDistanceBadge(
                  km: provider.distanceKmForItem(
                    provider.visibleItems[
                        _topIndex.clamp(0, provider.visibleItems.length - 1)],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 92,
            // Beim Runterscrollen schrumpfen (statt verschwinden), beim
            // Hochscrollen wieder normal.
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.bottomRight,
              scale: _showActions ? 1.0 : 0.55,
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
        ],
      ),
    );
  }
}

/// Lade-Skeleton (statt Spinner): pulsierende Platzhalter-Karten, damit der
/// Feed beim Laden nicht ruckelig nacheinander einfliegt.
class _FeedSkeleton extends StatefulWidget {
  const _FeedSkeleton();

  @override
  State<_FeedSkeleton> createState() => _FeedSkeletonState();
}

class _FeedSkeletonState extends State<_FeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_c),
              child: _card(cs),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(ColorScheme cs) {
    final block = cs.surfaceContainerHighest;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: block,
            borderRadius: BorderRadius.circular(8),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: block, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(120, 12),
                    const SizedBox(height: 6),
                    bar(80, 10),
                  ],
                ),
              ],
            ),
          ),
          AspectRatio(aspectRatio: 1.1, child: Container(color: block)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(220, 16),
                const SizedBox(height: 10),
                bar(120, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Oberer Umschalter „Für dich ↔ Folge ich" – ruhige M3-Pill.
class _FeedModeToggle extends StatelessWidget {
  const _FeedModeToggle({required this.mode, required this.onChanged});

  final DiscoverFeedMode mode;
  final ValueChanged<DiscoverFeedMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment(context, 'Für dich', DiscoverFeedMode.forYou, cs),
            _segment(context, 'Folge ich', DiscoverFeedMode.following, cs),
            _segment(context, 'Neben mir', DiscoverFeedMode.nearMe, cs),
          ],
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    DiscoverFeedMode value,
    ColorScheme cs,
  ) {
    final active = mode == value;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: active ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: tt.labelLarge?.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Standort-Button neben der Glocke. Durchgestrichenes Pin-Logo, wenn kein
/// echter Standort geteilt ist (Default Westendplatz).
class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.provider});

  final UserDiscoverProvider provider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = provider.hasSharedLocation;
    return IconButton(
      tooltip: provider.locationLabel,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _LocationSheet(provider: provider),
      ),
      icon: Icon(
        active ? Icons.location_on_rounded : Icons.location_off_rounded,
        color: active ? cs.primary : cs.onSurfaceVariant,
      ),
    );
  }
}

/// Süßes zentriertes Popup: Adresse tippen (Autocomplete, Hessen) · eigenen
/// Standort verwenden. Kein „Überspringen" mehr (kein Westendplatz-Default-
/// Angebot); zum Abbrechen tippt man neben den Dialog. Keine Karte.
class _LocationSheet extends StatefulWidget {
  const _LocationSheet({required this.provider});

  final UserDiscoverProvider provider;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _ctrl = TextEditingController();
  final _geo = GeoapifyService();
  List<GeoResult> _suggestions = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      final res =
          await _geo.autocomplete(text, filterRect: GeoapifyService.hessenRect);
      if (!mounted) return;
      setState(() {
        _suggestions = res;
        _loading = false;
      });
    });
  }

  Future<void> _pick(GeoResult g) async {
    await widget.provider.setManualLocation(
      lat: g.lat,
      lng: g.lng,
      label: g.formatted.isNotEmpty ? g.formatted : _ctrl.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _gps() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    // GPS → Adresse ermitteln und das Eingabefeld befüllen; der User bestätigt
    // danach selbst (tippt den Vorschlag an). So „funktioniert" der Standort
    // sichtbar, statt still im Hintergrund.
    final g = await widget.provider.gpsSuggestAddress();
    if (!mounted) return;
    setState(() => _loading = false);
    if (g == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Standort nicht verfügbar – Freigabe im Browser/Gerät prüfen.'),
      ));
      return;
    }
    _ctrl.text = g.formatted;
    setState(() => _suggestions = [g]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.location_on_rounded,
                      color: cs.onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Wo bist du?', style: tt.titleLarge)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Damit „Neben mir" dir die nächsten Beiträge zeigt.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Adresse eingeben…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (_, i) {
                    final g = _suggestions[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        g.formatted,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium,
                      ),
                      onTap: () => _pick(g),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _gps,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Meinen Standort verwenden'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rechter Scroll-Distanz-Indikator für „Neben mir".
class _NearMeDistanceBadge extends StatelessWidget {
  const _NearMeDistanceBadge({required this.km});

  final double? km;

  @override
  Widget build(BuildContext context) {
    if (km == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_rounded, size: 14, color: Colors.white),
          const SizedBox(height: 2),
          Text(
            LocationUtils.distanceLabel(km!),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final distanceKm = provider.mode == DiscoverFeedMode.nearMe
        ? provider.distanceKmForItem(item)
        : null;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          provider.incrementOpen(post.postId);
          await context.push('/user/feed/${post.postId}', extra: post);
          // Zurück im Feed → frische Daten, damit neue Bewertungen erscheinen.
          if (context.mounted) provider.refreshFresh();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Schlanker Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Row(
                  children: [
                    _Logo(url: merchant.logoUrl, name: merchant.shopName, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            merchant.shopName,
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [merchant.displayCity, merchant.shopType]
                                .where((v) => v.isNotEmpty)
                                .join(' · '),
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          color: cs.onSurfaceVariant),
                      onSelected: (value) {
                        switch (value) {
                          case 'share':
                            ShareUtils.shareFeedPost(
                              title: post.title,
                              merchantName: merchant.shopName,
                            );
                          case 'report':
                            _showReportSheet(
                              context,
                              provider,
                              post.postId,
                              merchant.merchantId,
                            );
                          case 'why':
                            _showWhySheet(context);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'share', child: Text('Teilen')),
                        PopupMenuItem(
                            value: 'why', child: Text('Warum sehe ich das?')),
                        PopupMenuItem(
                            value: 'report', child: Text('Beitrag melden')),
                      ],
                    ),
                  ],
                ),
              ),
              // Bild-Hero mit Titel-Overlay auf Scrim
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.1,
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.gray100),
                      errorWidget: (_, _, _) =>
                          Container(color: AppColors.gray100),
                    ),
                  ),
                  // Dunkler Verlauf unten, damit der Titel lesbar bleibt.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0.5, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _Badge(label: feedTypeLabel(post.type)),
                  ),
                  // Titel + Untertitel unten links auf dem Bild.
                  Positioned(
                    left: 16,
                    right: 60,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.15,
                          ),
                        ),
                        if (post.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            post.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.87),
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: _LikeButton(
                      liked: item.isLiked,
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await provider.toggleLike(item);
                        } catch (_) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Bitte einloggen')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              // Eine ruhige Meta-Zeile (Titel liegt auf dem Bild)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    if (distanceKm != null) ...[
                      Icon(Icons.near_me_rounded, size: 15, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        LocationUtils.distanceLabel(distanceKm),
                        style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600, color: cs.primary),
                      ),
                      const SizedBox(width: 14),
                    ],
                    if (item.averageRating != null) ...[
                      const Icon(Icons.star_rounded,
                          size: 18, color: AppColors.googleYellow),
                      const SizedBox(width: 4),
                      Text(
                        item.averageRating!.toStringAsFixed(1),
                        style: tt.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ] else
                      Text('Neu',
                          style: tt.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    if (post.likesCount > 0) ...[
                      const SizedBox(width: 14),
                      Icon(Icons.favorite_rounded,
                          size: 15, color: cs.primary),
                      const SizedBox(width: 4),
                      Text('${post.likesCount}',
                          style: tt.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant, size: 22),
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

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.large),
      color: Colors.transparent,
      child: AppSearchField(
        controller: controller,
        autofocus: true,
        hintText: 'Titel, Shop, Kategorie oder Stadt',
        onSubmitted: (_) => onSubmit(),
      ),
    );
  }
}

void _showFilters(BuildContext context, UserDiscoverProvider provider) {
  final city = TextEditingController(text: provider.city);
  var radius = provider.radius;
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
              Text(
                'Filter',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
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
                  ButtonSegment(value: DiscoverSort.forYou, label: Text('Für dich')),
                  ButtonSegment(value: DiscoverSort.hottest, label: Text('Beliebt')),
                  ButtonSegment(value: DiscoverSort.newest, label: Text('Neu')),
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
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

void _showWhySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Du siehst diesen Beitrag, weil er zu deiner Stadt, deinen Filtern '
        'und beliebten lokalen Angeboten passt.',
      ),
    ),
  );
}

void _showReportSheet(
  BuildContext context,
  UserDiscoverProvider provider,
  String postId,
  String merchantId,
) {
  const reasons = [
    'Spam oder Betrug',
    'Unangemessener Inhalt',
    'Falsche Informationen',
    'Sonstiges',
  ];
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Beitrag melden',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          for (final reason in reasons)
            ListTile(
              title: Text(reason),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await provider.reportPost(
                    postId: postId,
                    reason: reason,
                    merchantId: merchantId,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Danke, dein Hinweis wurde gesendet.'),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Melden fehlgeschlagen. Bitte später erneut.'),
                      ),
                    );
                  }
                }
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
          : Center(
              child: Text(
                _initials(name),
                style: tt.labelLarge?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.onTap});

  final bool liked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton.filled(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: cs.surface.withValues(alpha: 0.92),
      ),
      icon: Icon(
        liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: liked ? AppColors.googleRed : cs.onSurface,
      ),
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(Icons.location_off_rounded,
              size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Standort nicht aktiv. Wir zeigen dir Frankfurt.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxBell extends StatelessWidget {
  const _InboxBell();

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<UserNotificationProvider>().unreadCount;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IconButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserInboxPage()),
        ),
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: Icon(Icons.notifications_none_rounded,
              color: cs.onSurfaceVariant),
        ),
      ),
    );
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
