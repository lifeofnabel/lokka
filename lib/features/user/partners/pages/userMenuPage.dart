import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/models/menuDesign.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appEmptyState.dart';
import 'package:lokka/core/widgets/appErrorState.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/partners/models/userMenuModels.dart';
import 'package:lokka/features/user/partners/services/userMenuService.dart';

/// Vollbild-Speisekarte eines Partners (integrierte Lokka-Karte, read-only).
///
/// Das Aussehen bestimmt der Merchant über [style]: Vorlage, Akzentfarbe,
/// Hell/Dunkel und Artikel pro Reihe (siehe `MerchantMenuSettingsPage`).
class UserMenuPage extends StatefulWidget {
  const UserMenuPage({
    super.key,
    required this.merchantId,
    required this.shopName,
    this.tablesEnabled = false,
    this.style = const MenuDesign(),
  });

  final String merchantId;
  final String shopName;

  /// „Tisch wählen"-Stub einblenden (nur wenn der Merchant Tische pflegt).
  final bool tablesEnabled;

  /// Vom Merchant gewählte Gestaltung der Kundenkarte.
  final MenuDesign style;

  @override
  State<UserMenuPage> createState() => _UserMenuPageState();
}

class _UserMenuPageState extends State<UserMenuPage> {
  late final UserMenuService _service;
  List<UserMenuCategory> _categories = [];
  bool _loading = true;
  String? _error;

  _MenuPalette get _palette => _MenuPalette(widget.style);

  @override
  void initState() {
    super.initState();
    _service = UserMenuService(
      firestoreService: context.read<FirestoreService>(),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = await _service.fetchMenu(widget.merchantId);
      if (mounted) {
        setState(() {
          _categories = cats;
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

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Scaffold(
      backgroundColor: palette.pageBg,
      body: CustomScrollView(
        slivers: [
          _header(palette),
          if (_loading)
            const SliverFillRemaining(
                hasScrollBody: false, child: AppLoadingState())
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorState(
                  message: 'Speisekarte konnte nicht geladen werden',
                  onRetry: _load),
            )
          else if (_categories.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.restaurant_menu_rounded,
                title: 'Noch keine Speisekarte',
                message: 'Dieser Partner hat noch keine Einträge veröffentlicht.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
              sliver: SliverList.builder(
                itemCount: _categories.length,
                itemBuilder: (_, i) => _CategorySection(
                  category: _categories[i],
                  style: widget.style,
                  palette: palette,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(_MenuPalette palette) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(gradient: palette.headerGradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Speisekarte',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          Text(
                            widget.shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.tablesEnabled && !_loading && _error == null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _TableSelectButton(
                    onTap: () => _showTableStub(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showTableStub(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.event_seat_rounded,
                    color: cs.onSecondaryContainer, size: 32),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tisch wählen',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tischauswahl direkt aus der Speisekarte kommt in Kürze. '
                'Bald kannst du hier deinen Tisch reservieren.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      );
    },
  );
}

class _TableSelectButton extends StatelessWidget {
  const _TableSelectButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.event_seat_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Tisch wählen',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.style,
    required this.palette,
  });

  final UserMenuCategory category;
  final MenuDesign style;
  final _MenuPalette palette;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (category.emoji != null) ...[
                    Text(category.emoji!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      category.name,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
        _items(),
      ],
    );
  }

  Widget _items() {
    final items = category.items;
    if (style.safeColumns != 2) {
      return Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MenuItemTile(
                  item: item, style: style, palette: palette, grid: false),
            ),
        ],
      );
    }

    // Zwei Artikel pro Reihe.
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _MenuItemTile(
                  item: left, style: style, palette: palette, grid: true),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : _MenuItemTile(
                      item: right, style: style, palette: palette, grid: true),
            ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// Ein Speisekarten-Eintrag, gerendert je nach Vorlage und Spaltenmodus.
class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    required this.item,
    required this.style,
    required this.palette,
    required this.grid,
  });

  final UserMenuItem item;
  final MenuDesign style;
  final _MenuPalette palette;

  /// true = zwei Spalten (kompaktere Variante der Vorlage).
  final bool grid;

  String _price(num value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

  @override
  Widget build(BuildContext context) {
    switch (style.layout) {
      case MenuLayoutStyle.list:
        return grid ? _imageTopCard(imageAspect: 16 / 9) : _imageLeftRow();
      case MenuLayoutStyle.compact:
        return _compactRow();
      case MenuLayoutStyle.gallery:
        return _imageTopCard(imageAspect: grid ? 1 : 4 / 3);
      case MenuLayoutStyle.magazine:
        return _heroCard(height: grid ? 150 : 200);
    }
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: palette.cardBorder),
      );

  // Vorlage „Liste": Bild links, Text rechts, Preis ganz rechts.
  Widget _imageLeftRow() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: SizedBox(
                width: 68,
                height: 68,
                child: _image(item.imageUrl),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _priceColumn(),
        ],
      ),
    );
  }

  // Vorlagen „Liste (2 Spalten)" und „Galerie": Bild oben, Text darunter.
  Widget _imageTopCard({required double imageAspect}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: imageAspect,
            child: _image(item.imageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _price(item.price),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: palette.accent,
                      ),
                    ),
                    if (item.hasDiscount) ...[
                      const SizedBox(width: 6),
                      Text(
                        _price(item.originalPrice!),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textSecondary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Vorlage „Klassisch": Name · · · Preis mit Führungspunkten, ohne Bild.
  Widget _compactRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                  child: _LeaderDots(
                    color: palette.textSecondary.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Text(
                _price(item.price),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                ),
              ),
            ],
          ),
          if (item.hasDiscount) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _price(item.originalPrice!),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textSecondary,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Vorlage „Magazin": großes Bild mit Text-Overlay.
  Widget _heroCard({required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.imageUrl != null)
              _image(item.imageUrl)
            else
              DecoratedBox(
                decoration: BoxDecoration(gradient: palette.headerGradient),
              ),
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
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _price(item.price),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (item.hasDiscount) ...[
                          const SizedBox(width: 8),
                          Text(
                            _price(item.originalPrice!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _price(item.price),
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: palette.accent,
          ),
        ),
        if (item.hasDiscount)
          Text(
            _price(item.originalPrice!),
            style: TextStyle(
              fontSize: 12,
              color: palette.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }

  Widget _image(String? url) {
    if (url == null) return _placeholder();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, _) => Container(color: palette.placeholder),
      errorWidget: (context, _, error) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: palette.placeholder,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: palette.accent.withValues(alpha: 0.7),
          size: 24,
        ),
      ),
    );
  }
}

/// Aufgelöste Farben der Kundenkarte aus dem [MenuDesign] (Hell/Dunkel + Akzent).
class _MenuPalette {
  _MenuPalette(this.style)
      : accent = style.accent,
        dark = style.darkMode;

  final MenuDesign style;
  final Color accent;
  final bool dark;

  Color get pageBg =>
      dark ? const Color(0xFF121417) : const Color(0xFFF6F7F4);
  Color get cardBg => dark ? const Color(0xFF1E2126) : Colors.white;
  Color get cardBorder =>
      dark ? const Color(0xFF2C3036) : const Color(0xFFE7E9E3);
  Color get textPrimary =>
      dark ? const Color(0xFFF1F3F5) : const Color(0xFF1A1C1A);
  Color get textSecondary =>
      dark ? const Color(0xFFAEB4BB) : const Color(0xFF6B6F69);
  Color get placeholder =>
      dark ? const Color(0xFF2C3036) : const Color(0xFFEDEFEA);

  LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, _darken(accent, 0.22)],
      );
}

Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Führungspunkte (· · ·) zwischen Name und Preis der „Klassisch"-Vorlage.
class _LeaderDots extends StatelessWidget {
  const _LeaderDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 5,
      child: CustomPaint(
        painter: _LeaderDotsPainter(color),
        size: Size.infinite,
      ),
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
    // Von rechts nach links zeichnen, damit die Punkte bündig am Preis enden.
    for (double x = size.width; x >= 0; x -= gap) {
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LeaderDotsPainter oldDelegate) =>
      oldDelegate.color != color;
}
