import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../merchant/catalog/models/itemTagData.dart';
import '../../../merchant/catalog/models/merchantItemData.dart';
import '../providers/publicShopProvider.dart';
import '../services/publicShopService.dart';
import '../widgets/publicShopActionBar.dart';
import '../widgets/publicShopHero.dart';

class PublicShopPage extends StatelessWidget {
  const PublicShopPage({
    super.key,
    required this.merchantId,
    this.tableId = '',
  });

  final String merchantId;
  final String tableId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PublicShopProvider(
        service: PublicShopService(
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(merchantId: merchantId, tableId: tableId),
      child: _PublicShopView(merchantId: merchantId),
    );
  }
}

class _PublicShopView extends StatefulWidget {
  const _PublicShopView({required this.merchantId});

  final String merchantId;

  @override
  State<_PublicShopView> createState() => _PublicShopViewState();
}

class _PublicShopViewState extends State<_PublicShopView> {
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicShopProvider>();
    final texts = context.watch<LanguageService>();
    final palette = _PublicShopPalette(dark: _darkMode);
    final Widget content;

    if (provider.isLoading) {
      content = _PublicLoading(palette: palette);
    } else if (provider.error != null) {
      content = _PublicError(message: provider.error!, palette: palette);
    } else if (provider.merchant == null) {
      content = _PublicEmpty(
        title: texts.text('public.shop.notFoundTitle'),
        message: texts.text('public.shop.notFoundMessage'),
        palette: palette,
      );
    } else if (!provider.catalogAvailable) {
      content = _PublicEmpty(
        title: texts.text('public.shop.catalogDisabledTitle'),
        message: texts.text('public.shop.catalogDisabledMessage'),
        palette: palette,
      );
    } else {
      content = Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 128),
            children: [
              _PublicTopControls(
                darkMode: _darkMode,
                palette: palette,
                onToggleTheme: () => setState(() => _darkMode = !_darkMode),
              ),
              const SizedBox(height: AppSpacing.md),
              PublicShopHero(
                merchant: provider.merchant!,
                tableLabel: provider.table?.label ?? '',
                darkMode: _darkMode,
              ),
              if ((provider.merchant!['publicNotice'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _PublicNoticeCard(
                  notice: (provider.merchant!['publicNotice'] ?? '').toString(),
                  palette: palette,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _CategoryBar(provider: provider, palette: palette),
              const SizedBox(height: AppSpacing.md),
              if (provider.visibleItems.isEmpty)
                _PublicEmpty(
                  title: texts.text('public.shop.emptyTitle'),
                  message: texts.text('public.shop.emptyMessage'),
                  palette: palette,
                )
              else
                ...provider.visibleItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PublicItemCard(
                      item: item,
                      canOrder: provider.canOrder,
                      palette: palette,
                    ),
                  ),
                ),
            ],
          ),
          if (provider.canOrder)
            Align(
              alignment: Alignment.bottomCenter,
              child: PublicShopActionBar(
                provider: provider,
                darkMode: _darkMode,
                onOrder: () => provider.placeOrder(widget.merchantId),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(child: content),
    );
  }
}

class _PublicShopPalette {
  const _PublicShopPalette({required this.dark});

  final bool dark;

  Color get background => dark ? const Color(0xFF10110F) : const Color(0xFFF7F5EF);
  Color get card => dark ? const Color(0xFF1A1B18) : const Color(0xFFFFFEFB);
  Color get ink => dark ? const Color(0xFFF8FAF5) : const Color(0xFF171A18);
  Color get muted => dark ? const Color(0xFFB7BEB6) : const Color(0xFF70766F);
  Color get soft => dark ? const Color(0xFF262824) : const Color(0xFFEDEAE1);
  Color get line => dark ? const Color(0xFF30342F) : const Color(0xFFE2DED3);
  Color get accent => const Color(0xFFCFA260);
}

class _PublicTopControls extends StatelessWidget {
  const _PublicTopControls({
    required this.darkMode,
    required this.palette,
    required this.onToggleTheme,
  });

  final bool darkMode;
  final _PublicShopPalette palette;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant_menu_rounded, color: palette.ink, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    texts.text('public.shop.menu'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: palette.card,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onToggleTheme,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.line),
              ),
              child: Icon(
                darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: palette.ink,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicNoticeCard extends StatelessWidget {
  const _PublicNoticeCard({required this.notice, required this.palette});

  final String notice;
  final _PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.ink,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.info_outline_rounded, color: palette.background, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              notice,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.background,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.provider, required this.palette});

  final PublicShopProvider provider;
  final _PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CategoryChip(
            label: texts.text('common.all'),
            selected: provider.selectedCategoryId == 'all',
            palette: palette,
            onTap: () => provider.selectCategory('all'),
          ),
          ...provider.categories.map(
            (category) => _CategoryChip(
              label: category.name,
              selected: provider.selectedCategoryId == category.id,
              palette: palette,
              onTap: () => provider.selectCategory(category.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _PublicShopPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? palette.ink : palette.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? palette.ink : palette.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? palette.background : palette.ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PublicItemCard extends StatelessWidget {
  const _PublicItemCard({
    required this.item,
    required this.canOrder,
    required this.palette,
  });

  final MerchantItemData item;
  final bool canOrder;
  final _PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PublicShopProvider>();
    final texts = context.watch<LanguageService>();
    return InkWell(
      onTap: () => _openItemSheet(context, item: item, canOrder: canOrder, palette: palette),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: palette.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: palette.dark ? 0.12 : 0.045),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 92,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: item.imageUrl.isEmpty
                  ? Icon(Icons.restaurant_menu_rounded, color: palette.muted)
                  : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SizedBox(
                height: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _price(item.price, texts),
                            style: TextStyle(
                              color: palette.accent,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _ItemTagChips(item: item, tags: provider.itemTags, palette: palette),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (canOrder) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: () => provider.addItem(item),
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: palette.ink,
                  foregroundColor: palette.background,
                ),
              ),
            ] else
              Icon(Icons.arrow_forward_ios_rounded, size: 15, color: palette.muted),
          ],
        ),
      ),
    );
  }
}

void _openItemSheet(
  BuildContext context, {
  required MerchantItemData item,
  required bool canOrder,
  required _PublicShopPalette palette,
}) {
  final texts = context.read<LanguageService>();
  final provider = context.read<PublicShopProvider>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AspectRatio(
                aspectRatio: 1.6,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: item.imageUrl.isEmpty
                      ? Icon(Icons.restaurant_menu_rounded, color: palette.muted, size: 42)
                      : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (item.categoryName.isNotEmpty)
                    _TinyShopChip(label: item.categoryName, palette: palette),
                  if (item.articleNumber.isNotEmpty)
                    _TinyShopChip(label: '#${item.articleNumber}', palette: palette),
                  _ItemTagChips(item: item, tags: provider.itemTags, palette: palette),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                item.name,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  item.description,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _price(item.price, texts),
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (canOrder)
                    FilledButton.icon(
                      onPressed: () {
                        provider.addItem(item);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(texts.text('public.shop.add')),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.ink,
                        foregroundColor: palette.background,
                        minimumSize: const Size(136, 52),
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

class _PublicLoading extends StatelessWidget {
  const _PublicLoading({required this.palette});

  final _PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        5,
        (index) => Container(
          height: index == 0 ? 220 : 104,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: palette.line),
          ),
        ),
      ),
    );
  }
}

class _PublicError extends StatelessWidget {
  const _PublicError({required this.message, required this.palette});

  final String message;
  final _PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _PublicEmpty(
          title: texts.text('common.errorTitle'),
          message: texts.text(message.replaceFirst('Bad state: ', '')),
          palette: palette,
        ),
      ),
    );
  }
}

class _PublicEmpty extends StatelessWidget {
  const _PublicEmpty({
    required this.title,
    required this.message,
    required this.palette,
  });

  final String title;
  final String message;
  final _PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_rounded, size: 42, color: palette.ink),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.ink, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _ItemTagChips extends StatelessWidget {
  const _ItemTagChips({
    required this.item,
    required this.tags,
    required this.palette,
  });

  final MerchantItemData item;
  final List<ItemTagData> tags;
  final _PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    final selected = tags
        .where((tag) => item.allergenIds.contains(tag.id) || item.additiveIds.contains(tag.id))
        .toList();
    if (selected.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: selected
          .map(
            (tag) => Tooltip(
              message: tag.name,
              child: _TinyShopChip(label: tag.code, palette: palette),
            ),
          )
          .toList(),
    );
  }
}

class _TinyShopChip extends StatelessWidget {
  const _TinyShopChip({required this.label, required this.palette});

  final String label;
  final _PublicShopPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.ink,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _price(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}
