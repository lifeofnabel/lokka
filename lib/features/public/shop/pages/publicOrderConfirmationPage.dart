import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/widgets/appImage.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../merchant/catalog/models/merchantItemData.dart';
import '../providers/publicShopProvider.dart';
import '../widgets/publicShopTheme.dart';

/// Nach dem Absenden: Bestätigung mit Bestellcode, Mini-Status und
/// „Lust auf mehr?"-Empfehlungen (zum Swipen & direkt in einen neuen
/// Warenkorb legen).
class PublicOrderConfirmationPage extends StatefulWidget {
  const PublicOrderConfirmationPage({super.key, required this.palette});

  final PublicShopPalette palette;

  @override
  State<PublicOrderConfirmationPage> createState() =>
      _PublicOrderConfirmationPageState();
}

class _PublicOrderConfirmationPageState
    extends State<PublicOrderConfirmationPage> {
  late final List<MerchantItemData> _recommendations;
  Stream<String>? _statusStream;

  PublicShopPalette get _p => widget.palette;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PublicShopProvider>();
    // Live-Status der Bestellung (new → preparing → done). Einmalig hier
    // abonnieren, damit der Stream nicht bei jedem Rebuild neu startet.
    _statusStream = provider.watchCreatedOrderStatus();
    final items = [...provider.items]..shuffle();
    _recommendations = items.take(8).toList();
  }

  /// Bestellstatus → aktiver Schritt im Mini-Status.
  int _statusToIndex(String status) {
    switch (status) {
      case 'preparing':
        return 1;
      case 'done':
        return 2;
      default: // 'new', 'qr_pending', 'cancelled' …
        return 0;
    }
  }

  String _price(num value, LanguageService texts) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';

  void _addRecommendation(MerchantItemData item, LanguageService texts) {
    context.read<PublicShopProvider>().addItem(item);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texts.text('public.shop.added'))));
    // Zurück zum Shop – der neue Warenkorb ist jetzt aktiv.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<PublicShopProvider>();
    final code = provider.createdOrderCode ?? '';
    final isQr = provider.lastFulfillment == 'qr_cashier';

    return Scaffold(
      backgroundColor: _p.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _p.accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: _p.accent, size: 44),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              texts.text(isQr
                  ? 'public.shop.qrConfirmTitle'
                  : 'public.shop.orderConfirmedTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _p.ink,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              texts.text(isQr
                  ? 'public.shop.qrConfirmMessage'
                  : 'public.shop.orderConfirmedMessage'),
              textAlign: TextAlign.center,
              style: TextStyle(color: _p.muted, fontWeight: FontWeight.w700, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Bestellcode (+ QR zum Vorzeigen an der Kasse)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _p.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _p.line),
              ),
              child: Column(
                children: [
                  Text(
                    texts.text('public.shop.orderCode'),
                    style: TextStyle(color: _p.muted, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: TextStyle(
                      color: _p.accent,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  if (isQr && code.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: code,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StreamBuilder<String>(
              stream: _statusStream,
              builder: (context, snapshot) => _MiniStatus(
                palette: _p,
                texts: texts,
                activeIndex: _statusToIndex(snapshot.data ?? 'new'),
              ),
            ),
            if (_recommendations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                texts.text('public.shop.recommendTitle'),
                style: TextStyle(color: _p.ink, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                texts.text('public.shop.recommendSubtitle'),
                style: TextStyle(color: _p.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 188,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommendations.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _RecommendationCard(
                    item: _recommendations[index],
                    palette: _p,
                    priceText: _price(_recommendations[index].price, texts),
                    addLabel: texts.text('public.shop.add'),
                    onAdd: () => _addRecommendation(_recommendations[index], texts),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(),
              icon: const Icon(Icons.storefront_rounded),
              label: Text(texts.text('public.shop.backToShop')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _p.ink,
                side: BorderSide(color: _p.line),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({
    required this.palette,
    required this.texts,
    required this.activeIndex,
  });

  final PublicShopPalette palette;
  final LanguageService texts;

  /// Aktiver Schritt: 0 = eingegangen, 1 = in Arbeit, 2 = fertig.
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final steps = [
      texts.text('public.shop.statusNew'),
      texts.text('public.shop.statusPreparing'),
      texts.text('public.shop.statusDone'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: i <= activeIndex ? palette.accent : palette.soft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    i < activeIndex ? Icons.check_rounded : Icons.circle,
                    size: i < activeIndex ? 16 : 9,
                    color: i <= activeIndex ? palette.onAccent : palette.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  steps[i],
                  style: TextStyle(
                    color: i <= activeIndex ? palette.ink : palette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: palette.line,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.item,
    required this.palette,
    required this.priceText,
    required this.addLabel,
    required this.onAdd,
  });

  final MerchantItemData item;
  final PublicShopPalette palette;
  final String priceText;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 84,
            width: double.infinity,
            child: item.imageUrl.isEmpty
                ? Container(
                    color: palette.soft,
                    child: Icon(Icons.restaurant_menu_rounded, color: palette.muted),
                  )
                : AppImage(
                    imageUrl: item.imageUrl,
                    errorWidget: Container(
                      color: palette.soft,
                      child: Icon(Icons.restaurant_menu_rounded, color: palette.muted),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.ink, fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  priceText,
                  style: TextStyle(color: palette.accent, fontWeight: FontWeight.w900, fontSize: 12.5),
                ),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: palette.onAccent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          addLabel,
                          style: TextStyle(
                            color: palette.onAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
