import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/merchant/stamps/models/stampCardModel.dart';
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
      if (mounted) {
        setState(() {
          _isInWallet = inWallet;
          _checkingWallet = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingWallet = false);
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
      body: Column(
        children: [
          _header(),
          Expanded(child: _body()),
        ],
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
  const _CardPage({required this.card, required this.active});

  final StampCardModel card;
  final bool active;

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

// ── 1:1-Replikat der Merchant-Vorschau (MerchantStampPreview, nicht compact) ─
//
// Bewusst exakt vom Merchant-Rendering kopiert (Farben, Gradient, Form,
// Icon-Raster), damit die Karte beim User genauso aussieht wie der Merchant
// sie gestaltet hat. Schriftgewichte daher absichtlich wie im Original.

class _StampCardCanvas extends StatelessWidget {
  const _StampCardCanvas({required this.card});

  final StampCardModel card;

  @override
  Widget build(BuildContext context) {
    final bg = _colorFromHex(card.backgroundColor, const Color(0xFF171A18));
    final gradient = _colorFromHex(card.gradientColor, const Color(0xFF45C9A4));
    final fg = _colorFromHex(card.textColor, const Color(0xFFFEFFFC));
    final accent = _colorFromHex(card.accentColor, const Color(0xFF9CE8CF));
    final slots = math.min(card.requiredStamps, 15);
    final hasBackgroundImage =
        card.imageUrl.isNotEmpty && card.imagePlacement == 'background';

    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      decoration: BoxDecoration(
        color: bg,
        gradient: card.gradientEnabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bg, gradient],
              )
            : null,
        borderRadius: BorderRadius.circular(34),
        image: hasBackgroundImage
            ? DecorationImage(
                image: NetworkImage(card.imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.42),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.imageUrl.isNotEmpty && card.imagePlacement == 'top') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  card.imageUrl,
                  width: double.infinity,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title.isEmpty ? 'Deine Stempelkarte' : card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: 29,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (card.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          card.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Belohnung: ${card.rewardTitle.isEmpty ? 'Belohnung nach voller Karte' : card.rewardTitle}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fg.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (card.description.trim().isNotEmpty)
                            Tooltip(
                              message: card.description,
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: fg.withValues(alpha: 0.78),
                                size: 19,
                              ),
                            ),
                        ],
                      ),
                      if (card.rewardDescription.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          card.rewardDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (card.imageUrl.isNotEmpty &&
                    card.imagePlacement == 'side') ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      card.imageUrl,
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...List.generate(
                  slots,
                  (index) => _StampSlot(
                    accent: accent,
                    fg: fg,
                    shape: card.stampShape,
                    iconValue: card.stampIconValue,
                    iconType: card.stampIconType,
                  ),
                ),
                if (slots < card.requiredStamps)
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${card.requiredStamps - slots}',
                      style: TextStyle(color: fg, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StampSlot extends StatelessWidget {
  const _StampSlot({
    required this.accent,
    required this.fg,
    required this.shape,
    required this.iconValue,
    required this.iconType,
  });

  final Color accent;
  final Color fg;
  final String shape;
  final String iconValue;
  final String iconType;

  @override
  Widget build(BuildContext context) {
    final isSquare = shape == 'square';
    final isSoftSquare = shape == 'softSquare';
    final isDiamond = shape == 'diamond';
    // Lesbare Glyphen-Farbe abhängig von der gewählten Stempelfarbe.
    final onAccent = accent.computeLuminance() > 0.5
        ? const Color(0xFF171A18)
        : const Color(0xFFFEFFFC);
    return Container(
      width: 40,
      height: 40,
      transform: isDiamond ? (Matrix4.identity()..rotateZ(0.785398)) : null,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(
            isSquare ? 8 : isSoftSquare || isDiamond ? 16 : 999),
        border: Border.all(color: fg.withValues(alpha: 0.16)),
      ),
      child: Center(
        child: Transform.rotate(
          angle: isDiamond ? -0.785398 : 0,
          child: iconType == 'char'
              ? Text(
                  _stampText(iconValue),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                )
              : Icon(_iconFor(iconValue), color: onAccent, size: 20),
        ),
      ),
    );
  }
}

Color _colorFromHex(String value, Color fallback) {
  final clean = value.replaceAll('#', '');
  if (clean.length != 6) return fallback;
  final parsed = int.tryParse('FF$clean', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

IconData _iconFor(String value) {
  return switch (value) {
    'coffee' => Icons.local_cafe_rounded,
    'food' => Icons.fastfood_rounded,
    'gift' => Icons.card_giftcard_rounded,
    'heart' => Icons.favorite_rounded,
    'local' => Icons.storefront_rounded,
    _ => Icons.star_rounded,
  };
}

String _stampText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '*';
  return String.fromCharCodes(trimmed.runes.take(2));
}
