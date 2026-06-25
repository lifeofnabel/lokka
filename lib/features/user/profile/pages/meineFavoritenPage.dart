import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/feed/pages/userFeedDetailPage.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';

/// Time window the liked posts are filtered by (based on when they were liked).
enum _Range { all, today, yesterday, week, month }

/// „Gelikte Beiträge" — every post the user liked, filterable by like date and
/// by "still available", with a small live counter in the top-right.
class MeineFavoritenPage extends StatefulWidget {
  const MeineFavoritenPage({super.key});

  @override
  State<MeineFavoritenPage> createState() => _MeineFavoritenPageState();
}

class _MeineFavoritenPageState extends State<MeineFavoritenPage> {
  late final UserFeedService _feedService;

  List<LikedFeedPost> _entries = [];
  bool _loading = true;
  String? _error;

  _Range _range = _Range.all;
  bool _onlyAvailable = false;

  @override
  void initState() {
    super.initState();
    _feedService = UserFeedService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _feedService.fetchLikedEntries();
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool _inRange(DateTime? at) {
    if (_range == _Range.all) return true;
    if (at == null) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.today:
        return !at.isBefore(todayStart);
      case _Range.yesterday:
        final y = todayStart.subtract(const Duration(days: 1));
        return !at.isBefore(y) && at.isBefore(todayStart);
      case _Range.week:
        return !at.isBefore(now.subtract(const Duration(days: 7)));
      case _Range.month:
        return !at.isBefore(now.subtract(const Duration(days: 30)));
      case _Range.all:
        return true;
    }
  }

  List<LikedFeedPost> get _filtered => _entries
      .where((e) =>
          _inRange(e.likedAt) &&
          (!_onlyAvailable || e.post.isCurrentlyValid))
      .toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Gelikte Beiträge'),
        actions: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _CounterPill(count: filtered.length),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_loading && _error == null && _entries.isNotEmpty)
            _FilterBar(
              range: _range,
              onlyAvailable: _onlyAvailable,
              onRange: (r) => setState(() => _range = r),
              onToggleAvailable: () =>
                  setState(() => _onlyAvailable = !_onlyAvailable),
            ),
          Expanded(child: _buildBody(filtered, cs)),
        ],
      ),
    );
  }

  Widget _buildBody(List<LikedFeedPost> filtered, ColorScheme cs) {
    if (_loading) return const AppLoadingState();
    if (_error != null) {
      return AppErrorState(message: 'Laden fehlgeschlagen', onRetry: _load);
    }
    if (_entries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Noch keine Likes',
        message: 'Tippe das Herz bei einem Beitrag — er landet dann hier.',
      );
    }
    if (filtered.isEmpty) {
      return AppEmptyState(
        icon: Icons.filter_alt_off_rounded,
        title: 'Keine Treffer',
        message: _onlyAvailable
            ? 'In diesem Zeitraum ist gerade nichts mehr verfügbar.'
            : 'Für diesen Zeitraum hast du nichts gelikt.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => _FavoriteCard(
        entry: filtered[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserFeedDetailPage(
              post: filtered[i].post,
              feedService: _feedService,
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: 13, color: cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.range,
    required this.onlyAvailable,
    required this.onRange,
    required this.onToggleAvailable,
  });

  final _Range range;
  final bool onlyAvailable;
  final ValueChanged<_Range> onRange;
  final VoidCallback onToggleAvailable;

  static const _labels = <_Range, String>{
    _Range.all: 'Alle',
    _Range.today: 'Heute',
    _Range.yesterday: 'Gestern',
    _Range.week: 'Letzte 7 Tage',
    _Range.month: 'Letzter Monat',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          for (final entry in _labels.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: range == entry.key,
              onSelected: (_) => onRange(entry.key),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
          // Separator + "still available" toggle.
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            color: cs.outlineVariant,
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: Icon(
              Icons.bolt_rounded,
              size: 18,
              color: onlyAvailable ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
            label: const Text('Noch verfügbar'),
            selected: onlyAvailable,
            onSelected: (_) => onToggleAvailable(),
            showCheckmark: false,
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.entry, required this.onTap});

  final LikedFeedPost entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final post = entry.post;
    final available = post.isCurrentlyValid;
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: post.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: post.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _imgFallback(context),
                            errorWidget: (context, url, error) =>
                                _imgFallback(context),
                          )
                        : _imgFallback(context),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // "Abgelaufen" pill when no longer available.
                  if (!available)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Abgelaufen',
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.favorite_rounded, color: cs.error, size: 18),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.sm,
                    child: Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    _MerchantLogo(
                      merchantId: post.merchantId,
                      initialUrl: post.merchantLogoUrl,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        post.merchantName.isEmpty ? 'Partner' : post.merchantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (entry.likedAt != null) ...[
                      Text(
                        _likedLabel(entry.likedAt!),
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _likedLabel(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Heute';
    if (diff == 1) return 'Gestern';
    if (diff < 7) return 'vor $diff Tagen';
    return '${at.day}.${at.month}.${at.year}';
  }

  Widget _imgFallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.secondaryContainer,
      child: Center(
        child: Icon(Icons.image_outlined, size: 36, color: cs.onSecondaryContainer),
      ),
    );
  }
}

/// Session cache: merchantId → logoUrl (fetched at most once per merchant).
final Map<String, String> _favMerchantLogoCache = {};

/// The merchant's logo next to its name. Uses the value denormalised on the post
/// and falls back to a live read of `publicMerchants/{merchantId}.logoUrl` so it
/// shows even when the post has no logo stored.
class _MerchantLogo extends StatefulWidget {
  const _MerchantLogo({required this.merchantId, required this.initialUrl});

  final String merchantId;
  final String initialUrl;

  @override
  State<_MerchantLogo> createState() => _MerchantLogoState();
}

class _MerchantLogoState extends State<_MerchantLogo> {
  String _url = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl.isNotEmpty) {
      _url = widget.initialUrl;
    } else if (_favMerchantLogoCache.containsKey(widget.merchantId)) {
      _url = _favMerchantLogoCache[widget.merchantId] ?? '';
    } else {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (widget.merchantId.isEmpty) return;
    try {
      final doc = await context
          .read<FirestoreService>()
          .readDocument(FirebasePaths.publicMerchant(widget.merchantId));
      final url = (doc?['logoUrl'] as String?) ?? '';
      _favMerchantLogoCache[widget.merchantId] = url;
      if (mounted && url.isNotEmpty) setState(() => _url = url);
    } catch (_) {
      // keep the fallback icon
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      clipBehavior: Clip.antiAlias,
      child: _url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: _url,
              fit: BoxFit.cover,
              memCacheWidth: 90,
              errorWidget: (context, url, error) => _fallback(cs),
            )
          : _fallback(cs),
    );
  }

  Widget _fallback(ColorScheme cs) =>
      Icon(Icons.storefront_rounded, size: 16, color: cs.onSecondaryContainer);
}
