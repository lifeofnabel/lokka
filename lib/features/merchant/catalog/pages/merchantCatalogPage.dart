import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/appConfig.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../public/shop/services/publicShopService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../../core/utils/shareUtils.dart';
import '../../orders/widgets/merchantRevenueWidgets.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantCatalogPage extends StatelessWidget {
  const MerchantCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.catalog.title'),
      subtitle: texts.text('merchant.catalog.subtitle'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.catalog.tooltip')),
      child: Column(
        children: [
          _CatalogPreviewHero(
            onTap: () {
              final merchantId = context.read<AuthService>().currentUser?.uid;
              if (merchantId == null || merchantId.isEmpty) return;
              context.push('/shop/$merchantId');
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ShopLinkActions(),
          const SizedBox(height: AppSpacing.md),
          // Tagesumsatz (≈) – nur im Runner-Modus sichtbar, sonst unsichtbar.
          const MerchantTagesumsatz(),
          _CatalogAction(
            icon: Icons.palette_rounded,
            title: texts.text('merchant.catalog.design'),
            tooltip: texts.text('merchant.catalog.designTip'),
            onTap: () => context.push('/merchant/catalog/design'),
          ),
          const _ModeTile(),
          _CatalogAction(
            icon: Icons.inventory_2_rounded,
            title: texts.text('merchant.catalog.items'),
            tooltip: texts.text('merchant.catalog.itemsTip'),
            onTap: () => context.push('/merchant/tools/items'),
          ),
          _CatalogAction(
            icon: Icons.category_rounded,
            title: texts.text('merchant.catalog.categories'),
            tooltip: texts.text('merchant.catalog.categoriesTip'),
            onTap: () => context.push('/merchant/tools/categories'),
          ),
          _CatalogAction(
            icon: Icons.fact_check_rounded,
            title: texts.text('merchant.itemTags.title'),
            tooltip: texts.text('merchant.itemTags.tooltip'),
            onTap: () => context.push('/merchant/tools/itemTags'),
          ),
          _CatalogAction(
            icon: Icons.table_bar_rounded,
            title: texts.text('merchant.catalog.tables'),
            tooltip: texts.text('merchant.catalog.tablesTip'),
            onTap: () => context.push('/merchant/tools/tables'),
          ),
          _CatalogAction(
            icon: Icons.receipt_long_rounded,
            title: texts.text('merchant.catalog.orders'),
            tooltip: texts.text('merchant.catalog.ordersTip'),
            onTap: () => context.push('/merchant/orders'),
          ),
        ],
      ),
    );
  }
}

/// Zeigt je nach aktivem Modus die passende Kachel: Runner-Modus → „Runner",
/// sonst → „QR-Codes & Links".
class _ModeTile extends StatefulWidget {
  const _ModeTile();

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile> {
  bool _runner = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    // Services VOR dem await greifen (context danach evtl. nicht mehr gültig).
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    try {
      final config = await PublicShopService(firestoreService: firestore)
          .loadCatalogConfig(uid);
      if (mounted) setState(() => _runner = config.modeRunner);
    } catch (_) {/* Default bleibt QR-Kachel */}
    // Öffentliche Speisekarte-URL automatisch im Merchant-Doc hinterlegen.
    try {
      await MerchantToolsService(authService: auth, firestoreService: firestore)
          .saveShopUrl('${AppConfig.shopLinkBase}/shop/$uid');
    } catch (_) {/* nicht kritisch fürs Rendern */}
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    if (_runner) {
      return _CatalogAction(
        icon: Icons.directions_run_rounded,
        title: texts.text('merchant.catalog.runners'),
        tooltip: texts.text('merchant.catalog.runnersTip'),
        onTap: () => context.push('/merchant/catalog/runners'),
      );
    }
    return _CatalogAction(
      icon: Icons.qr_code_2_rounded,
      title: texts.text('merchant.catalog.qrCodes'),
      tooltip: texts.text('merchant.catalog.qrCodesTip'),
      onTap: () => context.push('/merchant/catalog/qr'),
    );
  }
}

/// Aktionen für den öffentlichen Speisekarte-Link (Kundenansicht): kopieren
/// oder teilen – zum Veröffentlichen/Weitergeben.
class _ShopLinkActions extends StatelessWidget {
  const _ShopLinkActions();

  String? _link(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return '${AppConfig.shopLinkBase}/shop/$uid';
  }

  void _copy(BuildContext context, String link) {
    final texts = context.read<LanguageService>();
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(texts.text('merchant.catalog.linkCopied'))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Row(
      children: [
        TextButton.icon(
          onPressed: () {
            final link = _link(context);
            if (link != null) _copy(context, link);
          },
          icon: const Icon(Icons.link_rounded, size: 18),
          label: Text(texts.text('merchant.catalog.copyLink')),
          style: TextButton.styleFrom(foregroundColor: MerchantPremiumColors.gold),
        ),
        TextButton.icon(
          onPressed: () async {
            final link = _link(context);
            if (link == null) return;
            try {
              await ShareUtils.shareText(
                link,
                subject: texts.text('merchant.catalog.previewTitle'),
              );
            } catch (_) {
              // Teilen nicht verfügbar (z.B. Desktop-Web) → in Zwischenablage.
              if (context.mounted) _copy(context, link);
            }
          },
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: Text(texts.text('merchant.catalog.shareLink')),
          style: TextButton.styleFrom(foregroundColor: MerchantPremiumColors.gold),
        ),
      ],
    );
  }
}

class _CatalogPreviewHero extends StatelessWidget {
  const _CatalogPreviewHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A67E6), Color(0xFF2B2F66)],
          ),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: MerchantPremiumShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.phone_iphone_rounded, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.text('merchant.catalog.previewTitle'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.coral,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogAction extends StatelessWidget {
  const _CatalogAction({
    required this.icon,
    required this.title,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: MerchantPremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.goldSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: MerchantPremiumColors.ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Tooltip(
                message: tooltip,
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: MerchantPremiumColors.muted,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: MerchantPremiumColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
