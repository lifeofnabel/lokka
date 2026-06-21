import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../merchant/tables/models/merchantTableData.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../providers/publicShopProvider.dart';
import '../widgets/publicShopTheme.dart';
import 'publicOrderConfirmationPage.dart';

/// Vollbild-Warenkorb: Artikel (mit Optionen/Notiz, Mengen +/−),
/// Vor-Ort/Mitnehmen, Tisch-/Platzwahl bzw. Abholzeit, Wunschtext,
/// Gesamtsumme und Abschluss (QR an Kasse oder direkt senden).
class PublicCartPage extends StatefulWidget {
  const PublicCartPage({
    super.key,
    required this.palette,
    required this.merchantId,
  });

  final PublicShopPalette palette;
  final String merchantId;

  @override
  State<PublicCartPage> createState() => _PublicCartPageState();
}

class _PublicCartPageState extends State<PublicCartPage> {
  late final TextEditingController _noteController;

  PublicShopPalette get _p => widget.palette;

  @override
  void initState() {
    super.initState();
    _noteController =
        TextEditingController(text: context.read<PublicShopProvider>().orderNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _price(num value, LanguageService texts) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';

  Future<void> _order(String fulfillment) async {
    final provider = context.read<PublicShopProvider>();
    final ok = await provider.placeOrder(widget.merchantId, fulfillment: fulfillment);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: PublicOrderConfirmationPage(palette: _p),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(context.read<LanguageService>().text('common.errorTitle'))));
    }
  }

  Future<void> _pickTime(PublicShopProvider provider) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    provider.setPickupTime(value);
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<PublicShopProvider>();
    final config = provider.catalogConfig;
    final itemCount = provider.cart.fold<int>(0, (sum, item) => sum + item.quantity);
    // Im Runner-Modus gibt es kein „Mitnehmen" → immer Vor Ort.
    final isTakeaway =
        !config.modeRunner && provider.serviceType == 'mitnehmen';
    final shopName =
        (provider.merchant?['shopName'] ?? provider.merchant?['businessName'] ?? '').toString();
    final logoUrl = (provider.merchant?['logoUrl'] ?? '').toString();

    final hasTable = provider.effectiveTable != null;
    final tableBased = config.modeTable || config.modeRunner;
    // Senden = Tisch-/Runner-Modus (an „Bestellungen"). QR = Vor-Kasse-Modus.
    final showQr = config.showQrCashier;
    // Tisch-/Runner-Modus braucht einen Tisch; ohne QR-Alternative erst Tisch wählen.
    // Tisch-/Runner-Modus ohne QR-Alternative braucht zwingend einen Tisch –
    // keine tischlose Bestellung rauslassen (auch wenn noch keine Tische
    // angelegt sind: dann blocken + Hinweis statt Geister-Bestellung).
    final needsTable = tableBased && !showQr && !hasTable;
    final showSend = config.showSend && !needsTable;

    // Leerer Warenkorb -> kompletter Screen schwarz (auf Wunsch).
    final cartEmpty = provider.cart.isEmpty;
    final scaffoldBg = cartEmpty ? Colors.black : _p.background;
    final barFg = cartEmpty ? Colors.white : _p.ink;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        foregroundColor: barFg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          texts.text('public.shop.cart'),
          style: TextStyle(color: barFg, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: cartEmpty
            ? Center(child: _EmptyCart(texts: texts))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // Mini-Hero (Shop + Warenkorb)
                  _CartMiniHero(
                    palette: _p,
                    texts: texts,
                    shopName: shopName,
                    logoUrl: logoUrl,
                    itemCount: itemCount,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // 1) Artikel
                  Text(
                    '$itemCount ${texts.text('public.shop.itemsLabel')}',
                    style: TextStyle(color: _p.muted, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in provider.cart)
                    _CartItemRow(
                      palette: _p,
                      texts: texts,
                      name: entry.item.name,
                      imageUrl: entry.item.imageUrl,
                      quantity: entry.quantity,
                      lineTotal: _price(entry.total, texts),
                      options: entry.selectedOptions.map((o) => o.name).toList(),
                      note: entry.note,
                      onAdd: () => provider.incrementLine(entry),
                      onRemove: () => provider.decrementLine(entry),
                    ),
                  const SizedBox(height: AppSpacing.md),

                  // 2) Vor Ort / Mitnehmen – im Runner-Modus ausgeblendet
                  // (Runner bedienen am Tisch; kein Mitnehmen/Abholzeit).
                  if (!config.modeRunner) ...[
                    _SectionLabel(palette: _p, text: texts.text('public.shop.serviceType')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SegTile(
                            palette: _p,
                            icon: Icons.restaurant_rounded,
                            label: texts.text('public.shop.dineIn'),
                            selected: !isTakeaway,
                            onTap: () => provider.setServiceType('vor_ort'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SegTile(
                            palette: _p,
                            icon: Icons.takeout_dining_rounded,
                            label: texts.text('public.shop.takeaway'),
                            selected: isTakeaway,
                            onTap: () => provider.setServiceType('mitnehmen'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 3) Tisch/Platz (bei Vor Ort, nur Tisch-/Runner-Modus)
                  if (!isTakeaway && tableBased) ...[
                    _SectionLabel(palette: _p, text: texts.text('public.shop.tableSection')),
                    const SizedBox(height: 8),
                    if (provider.tables.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _p.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _p.line),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: _p.muted, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                texts.text('public.shop.noTablesConfigured'),
                                style: TextStyle(
                                  color: _p.muted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _TablePicker(
                        palette: _p,
                        texts: texts,
                        tables: provider.tables,
                        selectedId: provider.selectedTable?.tableId,
                        onChanged: provider.setSelectedTable,
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 4) Abholzeit (bei Mitnehmen)
                  if (isTakeaway) ...[
                    _SectionLabel(palette: _p, text: texts.text('public.shop.pickupTime')),
                    const SizedBox(height: 8),
                    _PickupTimeRow(
                      palette: _p,
                      texts: texts,
                      value: provider.pickupTime,
                      onPick: () => _pickTime(provider),
                      onClear: () => provider.setPickupTime(''),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 5) Wunschtext
                  TextField(
                    controller: _noteController,
                    onChanged: provider.setOrderNote,
                    maxLines: 2,
                    style: TextStyle(color: _p.ink, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: texts.text('public.shop.note'),
                      hintText: texts.text('public.shop.noteHint'),
                      prefixIcon: Icon(Icons.edit_note_rounded, color: _p.muted),
                      labelStyle: TextStyle(color: _p.muted, fontWeight: FontWeight.w800),
                      hintStyle: TextStyle(color: _p.muted.withValues(alpha: 0.7)),
                      filled: true,
                      fillColor: _p.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: _p.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: _p.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: _p.accent, width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 6) Gesamtsumme
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _p.card,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _p.line),
                    ),
                    child: Row(
                      children: [
                        Text(texts.text('merchant.orders.total'),
                            style: TextStyle(color: _p.muted, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text(
                          _price(provider.totalPrice, texts),
                          style: TextStyle(color: _p.ink, fontSize: 23, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 7) Abschluss
                  if (needsTable)
                    _HintCard(palette: _p, text: texts.text('public.shop.chooseTableHint'))
                  else if (!showSend && !showQr)
                    _HintCard(palette: _p, text: texts.text('public.shop.staffOrderHint'))
                  else ...[
                    if (showSend)
                      _SubmitButton(
                        palette: _p,
                        icon: Icons.send_rounded,
                        label: texts.text('public.shop.sendOrder'),
                        filled: true,
                        loading: provider.isSaving,
                        onTap: provider.isSaving ? null : () => _order('sent'),
                      ),
                    if (showSend && showQr) const SizedBox(height: 10),
                    if (showQr)
                      _SubmitButton(
                        palette: _p,
                        icon: Icons.qr_code_2_rounded,
                        label: texts.text('public.shop.qrCashier'),
                        filled: !showSend,
                        loading: provider.isSaving,
                        onTap: provider.isSaving ? null : () => _order('qr_cashier'),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.palette, required this.text});
  final PublicShopPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: palette.muted,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _CartMiniHero extends StatelessWidget {
  const _CartMiniHero({
    required this.palette,
    required this.texts,
    required this.shopName,
    required this.logoUrl,
    required this.itemCount,
  });

  final PublicShopPalette palette;
  final LanguageService texts;
  final String shopName;
  final String logoUrl;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accent.withValues(alpha: 0.20),
            palette.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.card,
              shape: BoxShape.circle,
              border: Border.all(color: palette.accent.withValues(alpha: 0.30), width: 2),
            ),
            child: logoUrl.isEmpty
                ? Icon(Icons.storefront_rounded, color: palette.accent)
                : CachedNetworkImage(imageUrl: logoUrl, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  texts.text('public.shop.cart'),
                  style: TextStyle(color: palette.ink, fontSize: 22, fontWeight: FontWeight.w900, height: 1.05),
                ),
                if (shopName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_rounded, color: palette.onAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$itemCount',
                  style: TextStyle(color: palette.onAccent, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.palette, required this.text});

  final PublicShopPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: palette.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _SegTile extends StatelessWidget {
  const _SegTile({
    required this.palette,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PublicShopPalette palette;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? palette.accent : palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? palette.accent : palette.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? palette.onAccent : palette.ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? palette.onAccent : palette.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TablePicker extends StatelessWidget {
  const _TablePicker({
    required this.palette,
    required this.texts,
    required this.tables,
    required this.selectedId,
    required this.onChanged,
  });

  final PublicShopPalette palette;
  final LanguageService texts;
  final List<TableData> tables;
  final String? selectedId;
  final ValueChanged<TableData?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: selectedId,
          dropdownColor: palette.card,
          hint: Text(texts.text('public.shop.tableChoose'),
              style: TextStyle(color: palette.muted)),
          icon: Icon(Icons.expand_more_rounded, color: palette.muted),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(texts.text('public.shop.tableNone'),
                  style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700)),
            ),
            for (final table in tables)
              DropdownMenuItem<String?>(
                value: table.tableId,
                child: Text(
                  table.areaName.trim().isEmpty
                      ? table.label
                      : '${table.areaName} · ${table.label}',
                  style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) {
              onChanged(null);
              return;
            }
            onChanged(tables.firstWhere((table) => table.tableId == value));
          },
        ),
      ),
    );
  }
}

class _PickupTimeRow extends StatelessWidget {
  const _PickupTimeRow({
    required this.palette,
    required this.texts,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final PublicShopPalette palette;
  final LanguageService texts;
  final String value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: palette.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value.isEmpty ? texts.text('public.shop.pickupTimeChoose') : value,
                style: TextStyle(
                  color: value.isEmpty ? palette.muted : palette.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (value.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, color: palette.muted, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.filled,
    required this.loading,
    required this.onTap,
  });

  final PublicShopPalette palette;
  final IconData icon;
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: palette.onAccent))
            : Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.accent, width: 1.5),
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.palette,
    required this.texts,
    required this.name,
    required this.imageUrl,
    required this.quantity,
    required this.lineTotal,
    required this.options,
    required this.note,
    required this.onAdd,
    required this.onRemove,
  });

  final PublicShopPalette palette;
  final LanguageService texts;
  final String name;
  final String imageUrl;
  final int quantity;
  final String lineTotal;
  final List<String> options;
  final String note;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 50,
                height: 50,
                child: imageUrl.isEmpty
                    ? Container(
                        color: palette.soft,
                        child: Icon(Icons.restaurant_menu_rounded, color: palette.muted, size: 22),
                      )
                    : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.ink, fontWeight: FontWeight.w900),
                  ),
                  if (options.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      options.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (note.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '„${note.trim()}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: palette.muted, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    lineTotal,
                    style: TextStyle(color: palette.accent, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    _QtyButton(icon: Icons.remove_rounded, palette: palette, onTap: onRemove),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '$quantity',
                        style: TextStyle(color: palette.ink, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                    _QtyButton(
                        icon: Icons.add_rounded, palette: palette, filled: true, onTap: onAdd),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.texts});

  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 44, color: Colors.white60),
          const SizedBox(height: 12),
          Text(
            texts.text('public.shop.cartEmpty'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: Text(texts.text('public.shop.backToMenu')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.palette,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final PublicShopPalette palette;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: filled ? palette.accent : palette.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: filled ? palette.onAccent : palette.ink),
      ),
    );
  }
}
