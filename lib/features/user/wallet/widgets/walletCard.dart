import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lokka/core/constants/firebasePaths.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/utils/walletCode.dart';

/// Session cache: merchantId → coverUrl, so the cover is fetched at most once
/// per merchant per app run (the wallet has few cards).
final Map<String, String> _walletCoverCache = {};

/// Premium, credit-card-grade Wallet tile. The store's COVER image is the
/// background, heavily darkened so the text and QR stay readable. A scannable
/// QR sits top-right; the whole card opens the store detail page.
///
/// The cover is read live from `publicMerchants/{merchantId}.coverUrl` (with the
/// denormalised value as a fast path), so it shows even for stores that were
/// followed before the cover was denormalised.
class WalletCard extends StatefulWidget {
  const WalletCard({
    super.key,
    required this.card,
    required this.uid,
    this.onTap,
  });

  final WalletCardModel card;
  final String uid;
  final VoidCallback? onTap;

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  // Fallback gradient when the store has no cover image yet.
  static const _g1 = Color(0xFF0E4034);
  static const _g2 = Color(0xFF12835F);

  String _cover = '';

  String get _qrData =>
      'lokka://wallet/${widget.uid}/${widget.card.merchantId}/${widget.card.walletCode}';

  @override
  void initState() {
    super.initState();
    final mid = widget.card.merchantId;
    // 1) Fast path: the value denormalised onto the wallet card.
    if (widget.card.merchantCoverUrl.isNotEmpty) {
      _cover = widget.card.merchantCoverUrl;
    } else if (_walletCoverCache.containsKey(mid)) {
      // 2) Session cache.
      _cover = _walletCoverCache[mid] ?? '';
    } else {
      // 3) Read live from the public merchant document.
      _fetchCover(mid);
    }
  }

  Future<void> _fetchCover(String mid) async {
    try {
      final doc = await context
          .read<FirestoreService>()
          .readDocument(FirebasePaths.publicMerchant(mid));
      final cover = (doc?['coverUrl'] as String?) ?? '';
      _walletCoverCache[mid] = cover;
      if (mounted && cover.isNotEmpty) setState(() => _cover = cover);
    } catch (_) {
      // Network/permission issue → keep the gradient fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final card = widget.card;

    final city = card.merchantCity.trim();
    final title = [card.merchantName.trim(), if (city.isNotEmpty) city]
        .where((s) => s.isNotEmpty)
        .join('  –  ');
    final meta = [card.merchantShopType.trim(), card.merchantOrigin.trim()]
        .where((s) => s.isNotEmpty)
        .join('  ·  ');
    final code = WalletCode.pretty(card.walletCode);
    final hasCover = _cover.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Wallet-Karte ${card.merchantName}',
      child: AspectRatio(
        aspectRatio: 1.62,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: hasCover
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_g1, _g2],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1) Cover image background.
                    if (hasCover)
                      CachedNetworkImage(
                        imageUrl: _cover,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        errorWidget: (context, url, error) =>
                            const SizedBox.shrink(),
                      ),
                    // 2) Heavy darkening so text/QR never fight the photo.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x8C000000), // ~0.55 black
                            Color(0xD9000000), // ~0.85 black
                          ],
                        ),
                      ),
                    ),
                    // 3) Content.
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _logo(),
                              const Spacer(),
                              _qrBadge(),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            title.isEmpty ? 'Partner' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  code.isEmpty ? '— — —' : code,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white, size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    final card = widget.card;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: card.merchantLogoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: card.merchantLogoUrl,
                fit: BoxFit.cover,
                memCacheWidth: 120,
                errorWidget: (context, url, error) => _logoFallback(),
              )
            : _logoFallback(),
      ),
    );
  }

  Widget _logoFallback() {
    return const Icon(Icons.storefront_rounded, size: 22, color: Colors.white);
  }

  /// Small scannable QR top-right (replaces the old wordmark). White plate so it
  /// stays readable against any darkened cover.
  Widget _qrBadge() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: QrImageView(
        data: _qrData,
        version: QrVersions.auto,
        size: 46,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
