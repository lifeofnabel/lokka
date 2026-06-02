import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
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

class _PublicShopView extends StatelessWidget {
  const _PublicShopView({required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicShopProvider>();
    final texts = context.watch<LanguageService>();
    final Widget content;

    if (provider.isLoading) {
      content = const _PublicLoading();
    } else if (provider.error != null) {
      content = _PublicError(message: provider.error!);
    } else if (provider.merchant == null) {
      content = _PublicEmpty(
        title: texts.text('public.shop.notFoundTitle'),
        message: texts.text('public.shop.notFoundMessage'),
      );
    } else if (!provider.catalogAvailable) {
      content = _PublicEmpty(
        title: texts.text('public.shop.catalogDisabledTitle'),
        message: texts.text('public.shop.catalogDisabledMessage'),
      );
    } else {
      content = Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
            children: [
              PublicShopHero(
                merchant: provider.merchant!,
                tableLabel: provider.table?.label ?? '',
              ),
              const SizedBox(height: AppSpacing.md),
              _CategoryBar(provider: provider),
              const SizedBox(height: AppSpacing.md),
              if (provider.visibleItems.isEmpty)
                _PublicEmpty(
                  title: texts.text('public.shop.emptyTitle'),
                  message: texts.text('public.shop.emptyMessage'),
                )
              else
                ...provider.visibleItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PublicItemCard(
                      item: item,
                      canOrder: provider.canOrder,
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
                onOrder: () => provider.placeOrder(merchantId),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: content,
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.provider});

  final PublicShopProvider provider;

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
            onTap: () => provider.selectCategory('all'),
          ),
          ...provider.categories.map(
            (category) => _CategoryChip(
              label: category.name,
              selected: provider.selectedCategoryId == category.id,
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
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        selectedColor: AppColors.black,
        labelStyle: TextStyle(
          color: selected ? AppColors.white : AppColors.black,
          fontWeight: FontWeight.w900,
        ),
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _PublicItemCard extends StatelessWidget {
  const _PublicItemCard({
    required this.item,
    required this.canOrder,
  });

  final MerchantItemData item;
  final bool canOrder;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PublicShopProvider>();
    final texts = context.watch<LanguageService>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(22),
            ),
            child: item.imageUrl.isEmpty
                ? const Icon(Icons.restaurant_menu_rounded)
                : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.gray700, height: 1.25),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _price(item.price, texts),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (canOrder) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: () => provider.addItem(item),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublicLoading extends StatelessWidget {
  const _PublicLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        5,
        (index) => Container(
          height: index == 0 ? 180 : 96,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

class _PublicError extends StatelessWidget {
  const _PublicError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _PublicEmpty(
          title: texts.text('common.errorTitle'),
          message: texts.text(message.replaceFirst('Bad state: ', '')),
        ),
      ),
    );
  }
}

class _PublicEmpty extends StatelessWidget {
  const _PublicEmpty({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.storefront_rounded, size: 42),
          const SizedBox(height: AppSpacing.md),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray700)),
        ],
      ),
    );
  }
}

String _price(num value, LanguageService texts) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${texts.text('common.euro')}';
}
