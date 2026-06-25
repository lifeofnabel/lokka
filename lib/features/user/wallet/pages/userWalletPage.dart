import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/utils/locationUtils.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/discover/services/userDiscoverService.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/providers/userWalletProvider.dart';
import 'package:lokka/features/user/wallet/widgets/walletCardStack.dart';
import 'package:lokka/features/user/wallet/widgets/walletDeck.dart';

enum WalletSort { latest, nearest }

class UserWalletPage extends StatefulWidget {
  const UserWalletPage({super.key});

  @override
  State<UserWalletPage> createState() => _UserWalletPageState();
}

class _UserWalletPageState extends State<UserWalletPage> {
  late final FirestoreService _firestore;
  late final UserDiscoverService _discover;

  WalletSort _sort = WalletSort.latest;
  UserLocation? _userLoc;
  final Map<String, (double, double)> _coords = {};
  bool _preparing = false;

  @override
  void initState() {
    super.initState();
    _firestore = context.read<FirestoreService>();
    _discover = UserDiscoverService(
      firestoreService: _firestore,
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
  }

  void _onSortSelected(WalletSort s) {
    setState(() => _sort = s);
    if (s == WalletSort.nearest) {
      _ensureNearestData(context.read<UserWalletProvider>().cards);
    }
  }

  /// Resolve the user's location (manual address → allowed GPS → Westendplatz)
  /// and fill in any missing merchant coordinates so the distance sort works
  /// even for cards followed before coords were denormalised.
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
        // ignore — card just sorts to the end without coords
      }
    }
    if (mounted) setState(() => _preparing = false);
  }

  List<WalletCardModel> _sortedCards(List<WalletCardModel> cards) {
    if (_sort == WalletSort.latest) return cards; // stream order = newest first
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    final deckHeight = MediaQuery.sizeOf(context).height * 0.70;

    return Consumer<UserWalletProvider>(
      builder: (context, provider, _) {
        final count = provider.cards.length;
        final subtitle = provider.isLoading
            ? 'Deine Karten an einem Ort'
            : count == 0
                ? 'Deine Partner-Karten an einem Ort'
                : '$count ${count == 1 ? 'Karte' : 'Karten'} gespeichert';
        final hasCards = !provider.isLoading &&
            provider.error == null &&
            provider.cards.isNotEmpty;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.mintGradient,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wallet',
                              style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (hasCards) _SortChip(
                        sort: _sort,
                        busy: _preparing,
                        onSelected: _onSortSelected,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (provider.isLoading)
              const SliverFillRemaining(child: AppLoadingState())
            else if (provider.error != null)
              const SliverFillRemaining(
                child: AppErrorState(
                  message: 'Wallet konnte nicht geladen werden',
                ),
              )
            else if (provider.cards.isEmpty)
              const SliverFillRemaining(
                child: AppEmptyState(
                  icon: Icons.wallet_outlined,
                  title: 'Noch keine Karten gespeichert',
                  message:
                      'Besuche einen Partner und füge ihn zu deiner Wallet hinzu.',
                ),
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: deckHeight,
                  child: WalletDeck(
                    cards: _sortedCards(provider.cards),
                    onOpen: (card) => openWalletCardStack(context, card, uid),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Compact "Nächste / Letzte" sort control, top-right of the wallet header.
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.sort,
    required this.busy,
    required this.onSelected,
  });

  final WalletSort sort;
  final bool busy;
  final ValueChanged<WalletSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return PopupMenuButton<WalletSort>(
      tooltip: 'Sortieren',
      initialValue: sort,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => const [
        PopupMenuItem(value: WalletSort.nearest, child: Text('Nähste')),
        PopupMenuItem(value: WalletSort.latest, child: Text('Letzte')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(sort == WalletSort.nearest
                  ? Icons.near_me_rounded
                  : Icons.schedule_rounded,
                  size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              sort == WalletSort.nearest ? 'Nähste' : 'Letzte',
              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
