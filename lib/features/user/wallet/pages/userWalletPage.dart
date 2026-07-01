import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/utils/locationUtils.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/core/widgets/appPillSwitch.dart';
import 'package:lokka/core/widgets/appSearchField.dart';
import 'package:lokka/features/user/discover/services/userDiscoverService.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/models/walletSort.dart';
import 'package:lokka/features/user/wallet/providers/userWalletProvider.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';
import 'package:lokka/features/user/wallet/services/walletStoreWarmupCache.dart';
import 'package:lokka/features/user/wallet/theme/walletDesignTokens.dart';
import 'package:lokka/features/user/wallet/widgets/walletStoreDeck.dart';

/// The Wallet home — laid out exactly like the Suche/Explore page:
///   1) a segmented toggle ("Zuletzt benutzt" / "Nähste von mir")
///   2) a search field
///   3) a "current / total" counter
///   4) the store carousel: one store fills the screen at a time (swipe
///      left/right between stores); within a store, swipe UP through its
///      stamp/points cards, which peek in from below one at a time.
class UserWalletPage extends StatefulWidget {
  const UserWalletPage({super.key});

  @override
  State<UserWalletPage> createState() => _UserWalletPageState();
}

class _UserWalletPageState extends State<UserWalletPage> {
  late final FirestoreService _firestore;
  late final UserDiscoverService _discover;
  late final UserWalletService _walletService;
  final _storeCtrl = PageController();

  WalletSort _sort = WalletSort.latest;
  UserLocation? _userLoc;
  final Map<String, (double, double)> _coords = {};
  bool _preparing = false;
  String _query = '';
  int _storeIndex = 0;
  List<WalletCardModel> _currentFiltered = const [];

  @override
  void initState() {
    super.initState();
    _firestore = context.read<FirestoreService>();
    _discover = UserDiscoverService(
      firestoreService: _firestore,
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
    _walletService = UserWalletService(
      firestoreService: _firestore,
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
    _storeCtrl.addListener(() {
      final p = _storeCtrl.page?.round() ?? 0;
      if (p != _storeIndex) {
        setState(() => _storeIndex = p);
        _prefetchNeighbors();
      }
    });
  }

  /// Lädt die Store-Karte(n) links/rechts vom aktuellen Index im Hintergrund
  /// vor (siehe [WalletStoreWarmupCache]), damit Weiterswipen sofort fertig
  /// ist statt jedes Mal kalt (3 sequenzielle Reads + Spinner) neu zu laden.
  /// Sicher, mehrfach für dieselbe Karte aufzurufen — der Cache dedupliziert.
  void _prefetchNeighbors() {
    for (final i in [_storeIndex - 1, _storeIndex + 1]) {
      if (i < 0 || i >= _currentFiltered.length) continue;
      unawaited(WalletStoreWarmupCache.warm(
        _currentFiltered[i].merchantId,
        service: _walletService,
      ));
    }
  }

  @override
  void dispose() {
    _storeCtrl.dispose();
    super.dispose();
  }

  /// Jumps back to the first store whenever the visible set reshuffles (new
  /// search, new sort) so the user is never left on a stale index.
  void _resetToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_storeCtrl.hasClients) _storeCtrl.jumpToPage(0);
    });
    setState(() => _storeIndex = 0);
  }

  List<WalletCardModel> _filter(List<WalletCardModel> cards) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return cards;
    return cards
        .where((c) =>
            c.merchantName.toLowerCase().contains(q) ||
            c.merchantCity.toLowerCase().contains(q) ||
            c.merchantShopType.toLowerCase().contains(q))
        .toList();
  }

  void _onQueryChanged(String q) {
    setState(() => _query = q);
    _resetToStart();
  }

  void _onSortChanged(WalletSort s) {
    if (s == _sort) return;
    setState(() => _sort = s);
    _resetToStart();
    if (s == WalletSort.nearest) {
      _ensureNearestData(context.read<UserWalletProvider>().cards);
    }
  }

  Future<void> _ensureNearestData(List<WalletCardModel> cards) async {
    setState(() => _preparing = true);
    _userLoc ??= await _discover.resolveLocation();
    for (final c in cards) {
      if (_coords.containsKey(c.merchantId)) continue;
      if (c.merchantLat != null && c.merchantLng != null) {
        _coords[c.merchantId] = (c.merchantLat!, c.merchantLng!);
        continue;
      }
      try {
        final doc = await _firestore
            .readDocument(FirebasePaths.publicMerchant(c.merchantId));
        final lat = (doc?['lat'] as num?)?.toDouble();
        final lng = (doc?['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) _coords[c.merchantId] = (lat, lng);
      } catch (_) {
        // card just sorts to the end without coords
      }
    }
    if (mounted) setState(() => _preparing = false);
  }

  List<WalletCardModel> _sortedCards(List<WalletCardModel> cards) {
    if (_sort == WalletSort.latest) {
      DateTime used(WalletCardModel c) =>
          c.lastActivityAt ?? c.joinedAt ?? DateTime(2000);
      return [...cards]..sort((a, b) => used(b).compareTo(used(a)));
    }
    final loc = _userLoc;
    double dist(WalletCardModel c) {
      final co = _coords[c.merchantId];
      if (co == null || loc == null) return double.infinity;
      return LocationUtils.distanceKm(loc.lat, loc.lng, co.$1, co.$2);
    }

    return [...cards]..sort((a, b) => dist(a).compareTo(dist(b)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';

    return Consumer<UserWalletProvider>(
      builder: (context, provider, _) {
        final hasCards = !provider.isLoading &&
            provider.error == null &&
            provider.cards.isNotEmpty;
        final filtered = hasCards
            ? _sortedCards(_filter(provider.cards))
            : const <WalletCardModel>[];

        return SafeArea(
          // Umschalter/Suche/Zähler nutzen bewusst die VOLLE Breite (wie Feed/
          // Suche, kein eigenes Max-Width-Limit) – nur das Karten-Deck darunter
          // bleibt auf Telefon-Breite gekapselt ("wie ein Handy auf dem Tisch").
          // Vorher lagen Umschalter UND Karten im selben 420px-Käfig, wodurch
          // der Wallet-Umschalter auf breiteren Screens schmaler/anders
          // positioniert war als der auf Feed/Suche.
          child: Column(
            children: [
              if (hasCards) ...[
                Padding(
                  padding: kSwitcherPadding,
                  child: AppPillSwitch<WalletSort>(
                    value: _sort,
                    expand: true,
                    onChanged: _onSortChanged,
                    segments: const [
                      (
                        value: WalletSort.latest,
                        label: 'Zuletzt benutzt',
                        icon: Icons.history_rounded,
                      ),
                      (
                        value: WalletSort.nearest,
                        label: 'Nähste von mir',
                        icon: Icons.near_me_rounded,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
                  child: AppSearchField(
                    hintText: 'Karte suchen…',
                    onChanged: _onQueryChanged,
                    onClear: () => _onQueryChanged(''),
                  ),
                ),
                if (_preparing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _PreparingRow(),
                  ),
                if (filtered.length > 1)
                  _CounterRow(index: _storeIndex, count: filtered.length),
              ],
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: WalletTokens.maxContentWidth),
                    child: _body(context, provider, filtered, uid),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    UserWalletProvider provider,
    List<WalletCardModel> filtered,
    String uid,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (provider.isLoading) return const AppLoadingState();
    if (provider.error != null) {
      return const AppErrorState(message: 'Wallet konnte nicht geladen werden');
    }
    if (provider.cards.isEmpty) {
      return const AppEmptyState(
        icon: Icons.wallet_outlined,
        title: 'Noch keine Karten gespeichert',
        message: 'Besuche einen Merchant und scanne deine erste Karte.',
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Text('Keine Karte gefunden',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      );
    }
    _currentFiltered = filtered;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchNeighbors());
    return PageView.builder(
      controller: _storeCtrl,
      itemCount: filtered.length,
      itemBuilder: (context, i) => WalletStoreDeck(
        key: ValueKey(filtered[i].merchantId),
        card: filtered[i],
        uid: uid,
      ),
    );
  }
}

/// "2 / 5" — which store, out of how many, in the horizontal carousel.
class _CounterRow extends StatelessWidget {
  const _CounterRow({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Text(
        '${index.clamp(0, count - 1) + 1} / $count',
        style: tt.labelMedium?.copyWith(
          fontWeight: WalletTokens.wBold,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PreparingRow extends StatelessWidget {
  const _PreparingRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Text('Standort wird ermittelt…',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}
