import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/widgets/responsiveContentWidth.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/merchant/stamps/models/stampCardModel.dart';
import 'package:lokka/features/stamps/widgets/stampCardVisual.dart';
import 'package:lokka/features/user/discover/models/publicMerchantUserModel.dart';
import 'package:lokka/features/user/partners/services/userLoyaltyService.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';

/// Stempelkarten eines Partners (User-Sicht).
///
/// Zeigt jede aktive Stempelkarte exakt so, wie der Merchant sie gestaltet
/// hat (gleiches Rendering wie die Merchant-Vorschau). Der User swiped wie
/// zwischen physischen Karten und kann den Laden zur Wallet hinzufügen.
class UserPartnerStampsPage extends StatefulWidget {
  const UserPartnerStampsPage({
    super.key,
    required this.merchantId,
    required this.shopName,
    this.merchant,
  });

  final String merchantId;
  final String shopName;

  /// Optional: voller Public-Merchant für die Wallet-Aktion.
  /// Ohne Merchant wird der Folgen-Button ausgeblendet.
  final PublicMerchantUserModel? merchant;

  @override
  State<UserPartnerStampsPage> createState() => _UserPartnerStampsPageState();
}

class _UserPartnerStampsPageState extends State<UserPartnerStampsPage> {
  late final UserLoyaltyService _service;
  late final UserWalletService _walletService;
  late final PageController _pageController;

  List<StampCardModel> _cards = [];
  bool _loading = true;
  String? _error;
  int _page = 0;

  bool _isInWallet = false;
  bool _checkingWallet = true;
  bool _adding = false;

  /// Stamp cards the user already added to their wallet (this is the ONLY place
  /// cards can be added → the wallet only shows what was added here).
  Set<String> _addedCardIds = {};
  String? _addingCardId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.86);
    final firestore = context.read<FirestoreService>();
    _service = UserLoyaltyService(firestoreService: firestore);
    _walletService = UserWalletService(
      firestoreService: firestore,
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
    _load();
    _checkWallet();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await _service.fetchStampCards(widget.merchantId);
      if (mounted) {
        setState(() {
          _cards = cards;
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

  Future<void> _checkWallet() async {
    if (widget.merchant == null) {
      if (mounted) setState(() => _checkingWallet = false);
      return;
    }
    try {
      final inWallet = await _walletService.isInWallet(widget.merchantId);
      final added =
          await _walletService.loadAddedStampCardIds(widget.merchantId);
      if (mounted) {
        setState(() {
          _isInWallet = inWallet;
          _addedCardIds = added;
          _checkingWallet = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingWallet = false);
    }
  }

  /// Add ONE stamp card to the wallet (client write — no Cloud Function). Also
  /// follows the store so it appears in the wallet list.
  Future<void> _addCard(StampCardModel card) async {
    if (_addingCardId != null || _addedCardIds.contains(card.id)) return;
    setState(() => _addingCardId = card.id);
    try {
      final merchant = widget.merchant;
      if (merchant != null && !_isInWallet) {
        await _walletService.addToWallet(merchant);
        _isInWallet = true;
      }
      await _walletService.addStampCardToWallet(widget.merchantId, card.id);
      if (mounted) {
        setState(() => _addedCardIds = {..._addedCardIds, card.id});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Karte zu deiner Wallet hinzugefügt'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fehler beim Hinzufügen. Bitte erneut versuchen.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingCardId = null);
    }
  }

  Future<void> _addToWallet() async {
    final merchant = widget.merchant;
    if (merchant == null || _adding || _isInWallet) return;
    setState(() => _adding = true);
    try {
      await _walletService.addToWallet(merchant);
      if (mounted) {
        setState(() {
          _isInWallet = true;
          _adding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Du folgst jetzt ${merchant.shopName}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _adding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Fehler beim Hinzufügen. Bitte erneut versuchen.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  bool get _showBottomBar =>
      widget.merchant != null && !_loading && _error == null && _cards.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.greenTint,
      body: ResponsiveContentWidth(
        child: Column(
          children: [
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar: _showBottomBar ? _bottomBar() : null,
    );
  }

  Widget _body() {
    if (_loading) return const AppLoadingState();
    if (_error != null) {
      return AppErrorState(
        message: 'Stempelkarten konnten nicht geladen werden',
        onRetry: _load,
      );
    }
    if (_cards.isEmpty) {
      return const AppEmptyState(
        icon: Icons.approval_rounded,
        title: 'Noch keine Stempelkarten',
        message: 'Dieser Partner hat aktuell keine aktiven Stempelkarten.',
      );
    }
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _cards.length,
            itemBuilder: (_, i) => _CardPage(
              card: _cards[i],
              active: i == _page,
              added: _addedCardIds.contains(_cards[i].id),
              busy: _addingCardId == _cards[i].id,
              onAdd: () => _addCard(_cards[i]),
            ),
          ),
        ),
        if (_cards.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          _dots(),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _dots() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _cards.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == _page ? cs.primary : cs.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  Widget _bottomBar() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget child;
    if (_checkingWallet) {
      child = const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_isInWallet) {
      // Bereits in der Wallet: tonal + deaktiviert.
      child = Container(
        height: 56,
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: cs.onSecondaryContainer, size: 20),
            const SizedBox(width: 8),
            Text(
              'Du folgst diesem Laden',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSecondaryContainer,
              ),
            ),
          ],
        ),
      );
    } else {
      child = SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _adding ? null : _addToWallet,
          icon: _adding
              ? const SizedBox.shrink()
              : const Icon(Icons.add_rounded, size: 20),
          label: _adding
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Zur Wallet hinzufügen'),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
        child: child,
      ),
    );
  }

  Widget _header() {
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.mintGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stempelkarten',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      widget.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
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

// ── Eine Seite im Karten-Pager ───────────────────────────────────────────────

class _CardPage extends StatelessWidget {
  const _CardPage({
    required this.card,
    required this.active,
    required this.added,
    required this.busy,
    required this.onAdd,
  });

  final StampCardModel card;
  final bool active;
  final bool added;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AnimatedScale(
      scale: active ? 1 : 0.95,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              children: [
                _StampCardCanvas(card: card),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(Icons.info_outline_rounded,
                          size: 15, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _conditionLabel(card),
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: added
                      ? Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 18, color: cs.onSecondaryContainer),
                              const SizedBox(width: 8),
                              Text(
                                'In deiner Wallet',
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: busy ? null : onAdd,
                          icon: busy
                              ? const SizedBox.shrink()
                              : const Icon(Icons.add_rounded, size: 20),
                          label: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Zur Wallet hinzufügen'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _euro(num value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

String _conditionLabel(StampCardModel card) {
  final custom = card.conditionText.trim();
  if (custom.isNotEmpty) return custom;
  switch (card.conditionType) {
    case StampConditionType.minimumAmount:
      final amount = card.minimumAmount;
      if (amount != null) {
        return 'Ein Stempel ab ${_euro(amount)} Einkaufswert';
      }
      return 'Ein Stempel ab Mindesteinkauf';
    case StampConditionType.item:
      if (card.requiredItemName.isNotEmpty) {
        return 'Ein Stempel pro ${card.requiredItemName}';
      }
      return 'Ein Stempel pro gekauftem Artikel';
    case StampConditionType.visit:
      return 'Ein Stempel pro Besuch';
    default:
      return 'Stempel sammeln bei jedem Einkauf';
  }
}

// User-Sicht-Karte = exakt dieselbe Vorschau wie beim Merchant, jetzt über das
// gemeinsame [StampCardVisual] (eine Quelle für Carousel, Builder, Wallet und
// die Stempelkarten-Werbung) — keine kopierte Render-Logik mehr.
class _StampCardCanvas extends StatelessWidget {
  const _StampCardCanvas({required this.card});

  final StampCardModel card;

  @override
  Widget build(BuildContext context) => StampCardVisual(card: card);
}
