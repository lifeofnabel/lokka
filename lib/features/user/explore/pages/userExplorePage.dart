import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/utils/locationUtils.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/core/widgets/appSearchField.dart';
import 'package:lokka/features/user/discover/providers/userDiscoverProvider.dart';
import 'package:lokka/features/user/discover/services/userDiscoverService.dart';

/// Entdecken-Tab: visuelles Stöbern wie ein Pinnwand-Raster.
/// M3-Suchfeld filtert die Auswahl; große Bild-Kacheln öffnen die Ergebnisse.
class UserExplorePage extends StatefulWidget {
  const UserExplorePage({super.key});

  @override
  State<UserExplorePage> createState() => _UserExplorePageState();
}

class _UserExplorePageState extends State<UserExplorePage> {
  late final FirestoreService _firestoreService;
  List<String> _categories = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await _firestoreService.loadChooserShopTypes();
      if (mounted) {
        setState(() {
          _categories = categories;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openResults(String value) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ExploreResultsPage(value: value),
      ),
    );
  }

  List<String> _filtered(List<String> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items.where((e) => e.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final categories = _filtered(_categories);
    final noMatches =
        !_loading && _categories.isNotEmpty && categories.isEmpty;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppColors.surfaceBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: AppSpacing.md,
          title: Text(
            'Entdecken',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: cs.onSurface,
            ),
          ),
        ),
        if (!_loading && _categories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
              child: AppSearchField(
                hintText: 'Kategorie suchen…',
                onChanged: (v) => setState(() => _query = v),
                onClear: () => setState(() => _query = ''),
              ),
            ),
          ),
        if (_loading)
          const SliverFillRemaining(child: AppLoadingState())
        else if (_categories.isEmpty)
          const SliverFillRemaining(
            child: AppEmptyState(
              icon: Icons.explore_outlined,
              title: 'Nichts zu entdecken',
              message:
                  'Kategorien erscheinen hier, sobald Partner aktiv sind.',
            ),
          )
        else if (noMatches)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Keine Treffer',
              message: 'Für deine Suche gibt es keine passende Auswahl.',
            ),
          )
        else ...[
          if (categories.isNotEmpty) ...[
            const _SectionHeader(title: 'Kategorien'),
            _TileGrid(
              items: categories,
              isArea: false,
              onTap: (v) => _openResults(v),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ],
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
        child: Text(
          title,
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

// ── Visuelles Kachel-Raster (Instagram-Discovery) ────────────────────────────

class _TileGrid extends StatelessWidget {
  const _TileGrid({
    required this.items,
    required this.isArea,
    required this.onTap,
  });

  final List<String> items;
  final bool isArea;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.35,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return _ExploreTile(
              label: item,
              isArea: isArea,
              seed: index,
              onTap: () => onTap(item),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}

/// Große, weiche Bild-/Icon-Kachel. Eine Geste = Ergebnisse öffnen.
class _ExploreTile extends StatelessWidget {
  const _ExploreTile({
    required this.label,
    required this.isArea,
    required this.seed,
    required this.onTap,
  });

  final String label;
  final bool isArea;
  final int seed;
  final VoidCallback onTap;

  // Ruhige, tonale Verläufe – rotieren für visuelle Abwechslung.
  static const _palettes = <List<Color>>[
    [Color(0xFFE9FAF3), Color(0xFFC8F0E0)],
    [Color(0xFFEAF2FE), Color(0xFFD2E4FC)],
    [Color(0xFFFFF4E5), Color(0xFFFCE3C2)],
    [Color(0xFFF3EAFE), Color(0xFFE2D2FC)],
    [Color(0xFFFDEAEF), Color(0xFFFAD2DC)],
    [Color(0xFFEAFBF1), Color(0xFFCFF0DA)],
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final palette = _palettes[seed % _palettes.length];
    final accent = _darken(palette.last);
    final icon = isArea ? Icons.location_city_rounded : _categoryIcon(label);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 24, color: accent),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.1,
                    color: AppColors.onSurfaceDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.32).clamp(0.0, 1.0)).toColor();
  }

  static IconData _categoryIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('café') || l.contains('cafe') || l.contains('kaffee')) {
      return Icons.local_cafe_rounded;
    }
    if (l.contains('restaurant') || l.contains('essen') || l.contains('food')) {
      return Icons.restaurant_rounded;
    }
    if (l.contains('bäcker') || l.contains('backer') || l.contains('brot')) {
      return Icons.bakery_dining_rounded;
    }
    if (l.contains('bar') || l.contains('drink') || l.contains('cocktail')) {
      return Icons.local_bar_rounded;
    }
    if (l.contains('pizza')) return Icons.local_pizza_rounded;
    if (l.contains('eis') || l.contains('ice')) return Icons.icecream_rounded;
    if (l.contains('blume') || l.contains('flor')) return Icons.local_florist_rounded;
    if (l.contains('mode') || l.contains('kleid') || l.contains('fashion')) {
      return Icons.checkroom_rounded;
    }
    if (l.contains('friseur') || l.contains('beauty') || l.contains('hair')) {
      return Icons.content_cut_rounded;
    }
    if (l.contains('markt') || l.contains('super') || l.contains('lebensmittel')) {
      return Icons.shopping_basket_rounded;
    }
    if (l.contains('apotheke') || l.contains('pharma')) {
      return Icons.local_pharmacy_rounded;
    }
    if (l.contains('fitness') || l.contains('sport') || l.contains('gym')) {
      return Icons.fitness_center_rounded;
    }
    if (l.contains('buch') || l.contains('book')) return Icons.menu_book_rounded;
    return Icons.storefront_rounded;
  }
}

// ── Kategorie-Feed ────────────────────────────────────────────────────────────

/// Tap auf eine Kategorie öffnet einen Beitrags-Feed, der GENAU auf diese
/// Kategorie (Merchant-shopType) eingegrenzt ist – gleiche Optik & gleiches
/// Verhalten wie der „Für dich"-Feed, nur gefiltert.
///
/// Eigener [UserDiscoverProvider], damit der Haupt-Feed unberührt bleibt; der
/// globale Nutzer-Standort kommt aus demselben geteilten Cache (konsistent).
class _ExploreResultsPage extends StatelessWidget {
  const _ExploreResultsPage({required this.value});

  /// Ausgewählte Kategorie = Merchant-shopType.
  final String value;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserDiscoverProvider>(
      create: (ctx) => UserDiscoverProvider(
        service: UserDiscoverService(
          firestoreService: ctx.read<FirestoreService>(),
          authService: ctx.read<AuthService>(),
          cacheService: ctx.read<LocalCacheService>(),
        ),
      ),
      child: _ExploreCategoryFeed(category: value),
    );
  }
}

class _ExploreCategoryFeed extends StatefulWidget {
  const _ExploreCategoryFeed({required this.category});

  final String category;

  @override
  State<_ExploreCategoryFeed> createState() => _ExploreCategoryFeedState();
}

class _ExploreCategoryFeedState extends State<_ExploreCategoryFeed> {
  bool _scoped = false;

  @override
  void initState() {
    super.initState();
    // Nach dem ersten Frame auf die Kategorie eingrenzen. Der Provider lädt
    // asynchron; sobald das Laden durch ist, den shopType-Filter setzen (und
    // erneut anwenden, falls der erste Versuch vor dem Laden lag).
    WidgetsBinding.instance.addPostFrameCallback((_) => _scopeToCategory());
  }

  void _scopeToCategory() {
    if (_scoped || !mounted) return;
    final provider = context.read<UserDiscoverProvider>();
    if (provider.isLoading) return; // warten, bis Daten da sind
    provider.applyFilters(shopType: widget.category);
    _scoped = true;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<UserDiscoverProvider>();

    // Solange noch nicht eingegrenzt wurde und das Laden fertig ist, jetzt
    // nachholen (z. B. wenn der erste Versuch noch während des Ladens lief).
    if (!_scoped && !provider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scopeToCategory());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.category,
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: cs.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
            child: _FeedModeToggle(
              mode: provider.mode,
              onChanged: provider.setMode,
            ),
          ),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildBody(UserDiscoverProvider provider) {
    if (provider.isLoading) return const AppLoadingState();
    if (provider.error != null) {
      return AppErrorState(
        message: 'Laden fehlgeschlagen',
        onRetry: provider.load,
      );
    }
    if (provider.visibleItems.isEmpty) {
      return switch (provider.mode) {
        DiscoverFeedMode.following => AppEmptyState(
            icon: Icons.favorite_border_rounded,
            title: provider.hasFollowing
                ? 'Noch nichts Neues'
                : 'Du folgst noch keinem Partner',
            message: provider.hasFollowing
                ? 'Deine Partner haben in „${widget.category}" gerade keine Beiträge.'
                : 'Füge Partner zu deiner Wallet hinzu – ihre Beiträge erscheinen dann hier.',
          ),
        DiscoverFeedMode.nearMe => AppEmptyState(
            icon: Icons.wrong_location_rounded,
            title: 'Nichts in der Nähe',
            message:
                'Für deinen Standort gibt es in „${widget.category}" gerade keine Beiträge mit Adresse.',
          ),
        DiscoverFeedMode.forYou => AppEmptyState(
            icon: Icons.explore_outlined,
            title: 'Noch keine Beiträge',
            message: 'In „${widget.category}" ist gerade nichts los – schau später nochmal vorbei.',
          ),
      };
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
      itemCount:
          provider.visibleItems.length + (provider.canLoadMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (_, index) {
        if (index >= provider.visibleItems.length) {
          return FilledButton(
            onPressed: provider.isLoadingMore ? null : provider.loadMore,
            child: const Text('Mehr laden'),
          );
        }
        return _CategoryFeedCard(item: provider.visibleItems[index]);
      },
    );
  }
}

/// Oberer 3-Segment-Umschalter „Für dich · Folge ich · Neben mir" – lokale
/// Kopie der (privaten) Discover-Pille, gleiche Semantik.
class _FeedModeToggle extends StatelessWidget {
  const _FeedModeToggle({required this.mode, required this.onChanged});

  final DiscoverFeedMode mode;
  final ValueChanged<DiscoverFeedMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: FittedBox(
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

/// Beitragskarte – optisch identisch zur Discover-`_FeedCard`: weiße Karte,
/// Radius 28, schlanker Merchant-Header, Bild-Hero mit Typ-Badge + Like +
/// Titel/Untertitel-Overlay, ruhige Meta-Zeile (Distanz-Pille bei „Neben mir").
class _CategoryFeedCard extends StatelessWidget {
  const _CategoryFeedCard({required this.item});

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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    _Logo(
                        url: merchant.logoUrl,
                        name: merchant.shopName,
                        size: 40),
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
                      Icon(Icons.favorite_rounded, size: 15, color: cs.primary),
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

// ── Karten-Bausteine (lokal, gespiegelt aus dem Discover-Feed) ───────────────

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

String _initials(String value) {
  final parts =
      value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'L';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
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
