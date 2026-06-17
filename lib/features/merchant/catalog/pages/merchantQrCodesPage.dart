import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/appConfig.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../../core/utils/shareUtils.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';

/// „QR-Codes & Links" – erreichbar über die Speisekarte-Seite. Zeigt den
/// allgemeinen Shop-Link/QR (Vor-Kasse / zum Teilen) und – falls vorhanden –
/// die Tische mit eigenem Link + QR (Tisch-Modus), mit Bereichsfilter.
class MerchantQrCodesPage extends StatelessWidget {
  const MerchantQrCodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantTablesProvider(
        service: MerchantToolsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantQrCodesView(),
    );
  }
}

class _MerchantQrCodesView extends StatelessWidget {
  const _MerchantQrCodesView();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantTablesProvider>();
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    final shopLink = '${AppConfig.shopLinkBase}/shop/$uid';

    return MerchantToolScaffold(
      title: texts.text('merchant.qr.title'),
      subtitle: texts.text('merchant.qr.subtitle'),
      backPath: '/merchant/catalog',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.qr.tooltip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Allgemeiner Link/QR (Vor-Kasse, Aushang, Teilen).
          MerchantPremiumCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texts.text('merchant.qr.generalTitle'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texts.text('merchant.qr.generalHint'),
                  style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(child: _ShareableQr(data: shopLink, filename: 'shop-qr.png')),
                const SizedBox(height: AppSpacing.md),
                _LinkRow(link: shopLink),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards(count: 3)
          else if (provider.error != null)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else if (provider.tables.isNotEmpty) ...[
            Text(
              texts.text('merchant.qr.tablesTitle'),
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (provider.areas.isNotEmpty) ...[
              _AreaFilter(provider: provider),
              const SizedBox(height: AppSpacing.sm),
            ],
            ...provider.visibleTables.map(
              (table) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TableQrTile(table: table, merchantId: uid),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AreaFilter extends StatelessWidget {
  const _AreaFilter({required this.provider});

  final MerchantTablesProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _AreaChip(
            label: texts.text('common.all'),
            selected: provider.selectedAreaId == 'all',
            onTap: () => provider.selectArea('all'),
          ),
          ...provider.areas.map(
            (area) => _AreaChip(
              label: area.name,
              selected: provider.selectedAreaId == area.areaId,
              onTap: () => provider.selectArea(area.areaId),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? MerchantPremiumColors.gold : MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? MerchantPremiumColors.base : MerchantPremiumColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableQrTile extends StatelessWidget {
  const _TableQrTile({required this.table, required this.merchantId});

  final TableData table;
  final String merchantId;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final label = table.areaName.trim().isEmpty
        ? table.label
        : '${table.areaName} · ${table.label}';
    // Link immer frisch aus der Hosting-Basis bauen (nicht den evtl. veralteten
    // gespeicherten qrUrl nehmen) – so stimmt er auch für ältere Tische.
    final qrUrl =
        '${AppConfig.shopLinkBase}/shop/$merchantId/table/${table.tableId}';
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const MerchantPremiumIconBox(icon: Icons.table_restaurant_rounded),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: texts.text('common.copyLink'),
            onPressed: () => _copy(context, qrUrl),
            icon: const Icon(Icons.copy_rounded, color: MerchantPremiumColors.ink),
          ),
          IconButton(
            tooltip: texts.text('merchant.qr.showQr'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _QrDialog(title: label, data: qrUrl),
            ),
            icon: const Icon(Icons.qr_code_2_rounded, color: MerchantPremiumColors.gold),
          ),
        ],
      ),
    );
  }
}

class _QrDialog extends StatelessWidget {
  const _QrDialog({required this.title, required this.data});

  final String title;
  final String data;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MerchantPremiumColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ShareableQr(data: data, filename: 'tisch-qr.png', size: 220),
            const SizedBox(height: AppSpacing.md),
            _LinkRow(link: data),
          ],
        ),
      ),
    );
  }
}

/// QR-Code in einer RepaintBoundary + „Als Bild teilen" (Export/Download).
class _ShareableQr extends StatefulWidget {
  const _ShareableQr({required this.data, required this.filename, this.size = 200});

  final String data;
  final String filename;
  final double size;

  @override
  State<_ShareableQr> createState() => _ShareableQrState();
}

class _ShareableQrState extends State<_ShareableQr> {
  final _boundaryKey = GlobalKey();

  Future<void> _share() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await ShareUtils.shareImage(
        data.buffer.asUint8List(),
        filename: widget.filename,
        text: widget.data,
      );
    } catch (_) {/* Export nicht möglich – kein Crash */}
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: QrImageView(
              data: widget.data,
              size: widget.size,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _share,
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: Text(texts.text('merchant.qr.shareImage')),
          style: OutlinedButton.styleFrom(
            foregroundColor: MerchantPremiumColors.ink,
            side: const BorderSide(color: MerchantPremiumColors.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          IconButton(
            tooltip: context.watch<LanguageService>().text('common.copyLink'),
            onPressed: () => _copy(context, link),
            icon: const Icon(Icons.copy_rounded, size: 20, color: MerchantPremiumColors.gold),
          ),
        ],
      ),
    );
  }
}

void _copy(BuildContext context, String link) {
  final texts = context.read<LanguageService>();
  Clipboard.setData(ClipboardData(text: link));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texts.text('merchant.catalog.linkCopied'))));
}
