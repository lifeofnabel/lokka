import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/utils/deferredWarmup.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/utils/locationUtils.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/core/widgets/appPillSwitch.dart';
import 'package:lokka/core/widgets/appSearchField.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/discover/providers/userDiscoverProvider.dart';
import 'package:lokka/features/user/discover/services/userDiscoverService.dart'
    show DiscoverFeedItem;
import 'package:lokka/features/user/feed/utils/feedTypeLabels.dart';
import 'package:lokka/features/user/partners/providers/userPartnersProvider.dart';
import 'package:lokka/features/user/partners/widgets/partnerCard.dart';

/// Was wird entdeckt: Deals (Beiträge) oder Partner (Shops).
enum ExploreMode { deals, partners }

/// Ergebnis-Sortierung innerhalb einer Kategorie: Top (beliebt) ↔ Näheste.
enum _ResultSort { top, near }

/// Entdecken-Tab: eine zusammenhängende Fläche.
/// Oben ein Deals/Partner-Umschalter, darunter ein Kategorie-Raster. Ein Tap auf
/// eine Kategorie öffnet die Ergebnisse INLINE (keine neue Seite, kein Back-Pfeil)
/// mit „Top"/„Näheste"-Sortierung – für Deals genauso wie für Partner.
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

  ExploreMode _mode = ExploreMode.deals;
  String? _selectedCategory;
  _ResultSort _sort = _ResultSort.top;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    // Tab-Index 1 ("Suche") – verzögert, solange ein anderer Tab aktiv ist,
    // damit ein Kaltstart im Feed diese leichte Anfrage nicht mit blockiert.
    DeferredWarmup.schedule(1, () => unawaited(_load()));
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

  void _setMode(ExploreMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  void _openCategory(String value) {
    setState(() {
      _selectedCategory = value;
      _sort = _ResultSort.top;
    });
  }

  void _backToGrid() => setState(() => _selectedCategory = null);

  List<String> _filtered(List<String> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items.where((e) => e.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _selectedCategory == null ? _buildBrowse() : _buildResults();
  }

  // ── Stöbern: Header + Kategorie-Raster ──────────────────────────────────────
  Widget _buildBrowse() {
    final categories = _filtered(_categories);
    final noMatches =
        !_loading && _categories.isNotEmpty && categories.isEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: _ExploreHeader(mode: _mode, onModeChanged: _setMode),
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
          _TileGrid(items: categories, onTap: _openCategory),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ],
    );
  }

  // ── Ergebnisse INLINE (gleiche Fläche, kein Back-Pfeil) ─────────────────────
  Widget _buildResults() {
    final category = _selectedCategory!;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _ExploreHeader(mode: _mode, onModeChanged: _setMode),
          _ResultsBar(
            category: category,
            mode: _mode,
            sort: _sort,
            onBack: _backToGrid,
            onSortChanged: (s) => setState(() => _sort = s),
          ),
          Expanded(
            child: _mode == ExploreMode.deals
                ? _DealsResultsBody(
                    key: ValueKey('deals-$category'),
                    category: category,
                    sort: _sort,
                  )
                : _PartnerResults(
                    key: ValueKey('partner-$category'),
                    category: category,
                    sort: _sort,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Moderner Kopfbereich mit Deals/Partner-Umschalter ─────────────────────────

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader({
    required this.mode,
    required this.onModeChanged,
  });

  final ExploreMode mode;
  final ValueChanged<ExploreMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kSwitcherPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPillSwitch<ExploreMode>(
            value: mode,
            onChanged: onModeChanged,
            expand: true,
            segments: const [
              (
                value: ExploreMode.deals,
                label: 'Deals',
                icon: Icons.local_offer_rounded
              ),
              (
                value: ExploreMode.partners,
                label: 'Partner',
                icon: Icons.storefront_rounded
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Inline-Leiste über den Ergebnissen: „‹ Kategorien"-Pille (statt Back-Pfeil),
/// die gewählte Kategorie als Überschrift und der Top/Näheste-Umschalter.
class _ResultsBar extends StatelessWidget {
  const _ResultsBar({
    required this.category,
    required this.mode,
    required this.sort,
    required this.onBack,
    required this.onSortChanged,
  });

  final String category;
  final ExploreMode mode;
  final _ResultSort sort;
  final VoidCallback onBack;
  final ValueChanged<_ResultSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final topLabel = mode == ExploreMode.deals ? 'Top Deals' : 'Beliebt';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // „Zurück" als Pille – bewusst KEIN AppBar-Back-Pfeil.
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: AppColors.surfaceGray,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left_rounded,
                          size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(
                        'Kategorien',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            category,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppPillSwitch<_ResultSort>(
            value: sort,
            onChanged: onSortChanged,
            segments: [
              (
                value: _ResultSort.top,
                label: topLabel,
                icon: Icons.local_fire_department_rounded
              ),
              (
                value: _ResultSort.near,
                label: 'Näheste',
                icon: Icons.near_me_rounded
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Kategorie-Raster (Instagram-Discovery) ────────────────────────────────────

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.items, required this.onTap});

  final List<String> items;
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
          childAspectRatio: 1.15,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return _ExploreTile(
              label: item,
              onTap: () => onTap(item),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}

/// Große, weiche Kategorie-Kachel. Eine Geste = Ergebnisse öffnen.
/// Eine EINHEITLICHE, ruhige Mint-Fläche (kein Regenbogen) + der eine
/// Deep-Green-Akzent fürs Icon — die App bleibt neutrale Bühne. Icon und Label
/// sind unten gruppiert, damit kein totes Mittelfeld entsteht.
class _ExploreTile extends StatelessWidget {
  const _ExploreTile({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.greenTint, AppColors.mintSoft],
            ),
            border: Border.all(color: AppColors.greenLine),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Icon(_categoryIcon(label),
                      size: 24, color: AppColors.accent),
                ),
                const SizedBox(height: AppSpacing.sm),
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
    if (l.contains('blume') || l.contains('flor')) {
      return Icons.local_florist_rounded;
    }
    if (l.contains('mode') || l.contains('kleid') || l.contains('fashion')) {
      return Icons.checkroom_rounded;
    }
    if (l.contains('friseur') || l.contains('beauty') || l.contains('hair')) {
      return Icons.content_cut_rounded;
    }
    if (l.contains('markt') ||
        l.contains('super') ||
        l.contains('lebensmittel')) {
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

// ── Deals-Ergebnisse einer Kategorie ──────────────────────────────────────────

/// Nutzt den geteilten [UserDiscoverProvider] (bereits vom Feed-Tab warm
/// geladen) statt eine eigene, neue Instanz zu erzeugen – ein Kategorie-Tap
/// löste sonst bei JEDEM Öffnen den vollen Feed-Ladepfad (Standort/Interessen/
/// Merchants/Beiträge) noch einmal komplett neu aus. Filter/Modus werden beim
/// Verlassen zurückgesetzt (gleiches Prinzip wie [_PartnerResults] für den
/// geteilten [UserPartnersProvider]), damit der Feed-Tab nicht kontaminiert
/// bleibt.
class _DealsResultsBody extends StatefulWidget {
  const _DealsResultsBody({super.key, required this.category, required this.sort});

  final String category;
  final _ResultSort sort;

  @override
  State<_DealsResultsBody> createState() => _DealsResultsBodyState();
}

class _DealsResultsBodyState extends State<_DealsResultsBody> {
  late final UserDiscoverProvider _provider;
  bool _scoped = false;
  _ResultSort? _appliedSort;
  String? _originalShopType;
  DiscoverSort? _originalSort;
  DiscoverFeedMode? _originalMode;

  @override
  void initState() {
    super.initState();
    _provider = context.read<UserDiscoverProvider>();
    _originalShopType = _provider.shopType;
    _originalSort = _provider.sort;
    _originalMode = _provider.mode;
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  @override
  void didUpdateWidget(_DealsResultsBody old) {
    super.didUpdateWidget(old);
    if (old.sort != widget.sort) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
    }
  }

  @override
  void dispose() {
    // Geteilten Feed-Provider zurücksetzen, sonst bleibt der Kategorie-Filter/
    // -Modus beim Zurückkehren zum Feed-Tab hängen.
    _provider.applyFilters(shopType: _originalShopType, sort: _originalSort);
    _provider.setMode(_originalMode ?? DiscoverFeedMode.forYou);
    super.dispose();
  }

  /// Erst auf die Kategorie eingrenzen, sobald die Daten geladen sind, dann die
  /// gewählte Sortierung anwenden. „Top" = meiste Likes, „Näheste" = Distanz.
  void _apply() {
    if (!mounted) return;
    if (_provider.isLoading) return;
    if (_scoped && _appliedSort == widget.sort) return;
    _scoped = true;
    _appliedSort = widget.sort;
    if (widget.sort == _ResultSort.near) {
      _provider.applyFilters(shopType: widget.category, sort: DiscoverSort.mostLiked);
      _provider.setMode(DiscoverFeedMode.nearMe);
    } else {
      _provider.setMode(DiscoverFeedMode.forYou);
      _provider.applyFilters(shopType: widget.category, sort: DiscoverSort.mostLiked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserDiscoverProvider>();
    if (!provider.isLoading &&
        (!_scoped || _appliedSort != widget.sort)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
    }

    if (provider.isLoading) return const AppLoadingState();
    if (provider.error != null) {
      return AppErrorState(
        message: 'Laden fehlgeschlagen',
        onRetry: provider.load,
      );
    }
    if (provider.visibleItems.isEmpty) {
      return AppEmptyState(
        icon: widget.sort == _ResultSort.near
            ? Icons.wrong_location_rounded
            : Icons.explore_outlined,
        title: 'Noch keine Deals',
        message: widget.sort == _ResultSort.near
            ? 'Für deinen Standort gibt es in „${widget.category}" gerade nichts mit Adresse.'
            : 'In „${widget.category}" ist gerade nichts los – schau später nochmal vorbei.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 140),
      itemCount: provider.visibleItems.length + (provider.canLoadMore ? 1 : 0),
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

// ── Partner-Ergebnisse einer Kategorie ────────────────────────────────────────

/// Nutzt den geteilten [UserPartnersProvider] (Stream). Standort kommt aus dem
/// Discover-Provider, damit „Näheste" konsistent zum Feed ist.
class _PartnerResults extends StatefulWidget {
  const _PartnerResults({super.key, required this.category, required this.sort});

  final String category;
  final _ResultSort sort;

  @override
  State<_PartnerResults> createState() => _PartnerResultsState();
}

class _PartnerResultsState extends State<_PartnerResults> {
  late final UserPartnersProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<UserPartnersProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid != null) await _provider.loadExtras(uid);
    if (!mounted) return;
    final loc = context.read<UserDiscoverProvider>().location;
    _provider.updateLocation(loc.lat, loc.lng);
    _provider.setFilter(category: widget.category);
  }

  @override
  void dispose() {
    // Geteilten Provider sauber zurücksetzen, sonst hält der Kategorie-Filter.
    _provider.clearFilters();
    super.dispose();
  }

  List<PublicMerchantUserModel> _sorted(UserPartnersProvider p) {
    final list = p.filteredPartners.toList();
    if (widget.sort == _ResultSort.near && p.userLat != null && p.userLng != null) {
      final withCoords = list.where((m) => m.hasCoordinates).toList()
        ..sort((a, b) => LocationUtils.distanceKm(
                p.userLat!, p.userLng!, a.lat!, a.lng!)
            .compareTo(LocationUtils.distanceKm(
                p.userLat!, p.userLng!, b.lat!, b.lng!)));
      final rest = list.where((m) => !m.hasCoordinates);
      return [...withCoords, ...rest];
    }
    list.sort((a, b) => p
        .beliebtScoreFor(b.merchantId)
        .compareTo(p.beliebtScoreFor(a.merchantId)));
    return list;
  }

  double? _distanceKm(UserPartnersProvider p, PublicMerchantUserModel m) {
    if (p.userLat == null || p.userLng == null || !m.hasCoordinates) return null;
    return LocationUtils.distanceKm(p.userLat!, p.userLng!, m.lat!, m.lng!);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserPartnersProvider>();
    if (provider.isLoading) return const AppLoadingState();
    if (provider.error != null) {
      return AppErrorState(
        message: 'Partner konnten nicht geladen werden',
        onRetry: provider.retry,
      );
    }

    final partners = _sorted(provider);
    if (partners.isEmpty) {
      return AppEmptyState(
        icon: Icons.store_outlined,
        title: 'Keine Partner',
        message: 'In „${widget.category}" gibt es gerade keine Partner.',
      );
    }

    final showDistance = widget.sort == _ResultSort.near;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 140),
      itemCount: partners.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, index) {
        final m = partners[index];
        final km = showDistance ? _distanceKm(provider, m) : null;
        return PartnerCard(
          merchant: m,
          distanceKm: km,
          onTap: () => context.push('/user/partners/${m.merchantId}', extra: m),
        );
      },
    );
  }
}

// ── Beitragskarte (optisch identisch zur Discover-`_FeedCard`) ───────────────

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
      borderRadius: BorderRadius.circular(AppRadius.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          provider.incrementOpen(post.postId);
          await context.push('/user/feed/${post.postId}', extra: post);
          if (context.mounted) provider.refreshFresh();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
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

