import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/menuDesign.dart';
import '../../../../core/services/languageService.dart';
import '../../../merchant/catalog/models/itemTagData.dart';
import '../../../merchant/catalog/models/merchantItemData.dart';
import 'publicShopTheme.dart';

/// Artikelkarte der Kundensicht – rendert je nach vom Merchant gewählter
/// Vorlage (Liste / Klassisch / Galerie / Magazin) und nutzt die Akzentfarbe.
/// Bestell-Button erscheint nur, wenn [canOrder].
class PublicShopItemCard extends StatelessWidget {
  const PublicShopItemCard({
    super.key,
    required this.item,
    required this.palette,
    required this.layout,
    required this.texts,
    required this.tags,
    required this.canOrder,
    required this.grid,
    required this.onTap,
    required this.onAdd,
    this.translate,
  });

  final MerchantItemData item;
  final PublicShopPalette palette;
  final MenuLayoutStyle layout;
  final LanguageService texts;
  final List<ItemTagData> tags;
  final bool canOrder;
  final bool grid;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  /// Optionaler Übersetzungs-Hook (Sprachumschalter der Kundensicht).
  final String Function(String key, String text)? translate;

  String get _displayName =>
      translate?.call('item_name_${item.id}', item.name) ?? item.name;
  String get _displayDescription =>
      translate?.call('item_desc_${item.id}', item.description) ?? item.description;

  String _price(num value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';

  @override
  Widget build(BuildContext context) {
    // Vom Merchant pro Artikel gewähltes Bildformat (1:1 oder 16:9).
    final imageAspect = item.isWideImage ? 16 / 9 : 1.0;
    return GestureDetector(
      onTap: onTap,
      child: switch (layout) {
        MenuLayoutStyle.list => grid ? _imageTopCard(imageAspect) : _imageLeftRow(),
        MenuLayoutStyle.compact => _compactRow(),
        MenuLayoutStyle.gallery => _imageTopCard(imageAspect),
        MenuLayoutStyle.magazine => _heroCard(grid ? 150 : 196),
      },
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.line),
      );

  // ── Liste: Bild links, Text rechts, Preis + Add ─────────────────────────
  Widget _imageLeftRow() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration,
      child: Row(
        children: [
          _thumb(74),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _name(16),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _desc(maxLines: 2),
                ],
                const SizedBox(height: 7),
                _priceRow(),
                _tagChips(),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _addButton(),
        ],
      ),
    );
  }

  // ── Klassisch: Name · · · Preis, ohne Bild ──────────────────────────────
  Widget _compactRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: _name(15)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                        child: _LeaderDots(color: palette.muted.withValues(alpha: 0.5)),
                      ),
                    ),
                    Text(
                      _price(item.price),
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _desc(maxLines: 2),
                ],
                _tagChips(),
              ],
            ),
          ),
          if (canOrder) ...[
            const SizedBox(width: 8),
            _addButton(),
          ],
        ],
      ),
    );
  }

  // ── Galerie / Liste-Grid: Bild oben, Text darunter ──────────────────────
  Widget _imageTopCard(double aspect) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(aspectRatio: aspect, child: _image()),
              if (canOrder)
                Positioned(right: 8, bottom: 8, child: _addButton()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _name(15, maxLines: 1),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _desc(maxLines: 1),
                ],
                const SizedBox(height: 6),
                _priceRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Magazin: großes Bild mit Text-Overlay ───────────────────────────────
  Widget _heroCard(double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _image(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _price(item.price),
                          style: TextStyle(
                            color: palette.onAccent,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (canOrder) _addButton(light: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bausteine ───────────────────────────────────────────────────────────
  Widget _thumb(double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(width: size, height: size, child: _image()),
    );
  }

  Widget _image() {
    if (item.imageUrl.isEmpty) {
      return Container(
        color: palette.soft,
        child: Center(
          child: Icon(Icons.restaurant_menu_rounded,
              color: palette.accent.withValues(alpha: 0.7)),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: item.imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: palette.soft),
      errorWidget: (context, url, error) => Container(
        color: palette.soft,
        child: Center(child: Icon(Icons.restaurant_menu_rounded, color: palette.muted)),
      ),
    );
  }

  Widget _name(double size, {int maxLines = 1}) {
    return Text(
      _displayName,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.ink,
        fontSize: size,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _desc({required int maxLines}) {
    return Text(
      _displayDescription,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.muted,
        fontSize: 12.5,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _priceRow() {
    return Row(
      children: [
        Text(
          _price(item.price),
          style: TextStyle(
            color: palette.accent,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (item.originalPrice != null && item.originalPrice! > item.price) ...[
          const SizedBox(width: 6),
          Text(
            _price(item.originalPrice!),
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }

  Widget _tagChips() {
    final selected = tags
        .where((tag) =>
            item.allergenIds.contains(tag.id) || item.additiveIds.contains(tag.id))
        .toList();
    if (selected.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final tag in selected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.line),
              ),
              child: Text(
                tag.code,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addButton({bool light = false}) {
    if (!canOrder) {
      return Icon(Icons.arrow_forward_ios_rounded, size: 14, color: palette.muted);
    }
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: light ? palette.onAccent : palette.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.add_rounded,
          color: light ? palette.accent : palette.onAccent,
          size: 22,
        ),
      ),
    );
  }
}

/// Führungspunkte (· · ·) der „Klassisch"-Vorlage.
class _LeaderDots extends StatelessWidget {
  const _LeaderDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 5,
      child: CustomPaint(painter: _LeaderDotsPainter(color), size: Size.infinite),
    );
  }
}

class _LeaderDotsPainter extends CustomPainter {
  _LeaderDotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const radius = 1.0;
    const gap = 5.0;
    final y = size.height - radius;
    for (double x = size.width; x >= 0; x -= gap) {
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LeaderDotsPainter oldDelegate) =>
      oldDelegate.color != color;
}
