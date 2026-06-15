import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantItemsPage extends StatelessWidget {
  const MerchantItemsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantItemsProvider(
        service: MerchantToolsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _MerchantItemsView(),
    );
  }
}

class _MerchantItemsView extends StatelessWidget {
  const _MerchantItemsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantItemsProvider>();
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.catalog.items'),
      subtitle: texts.text('merchant.items.subtitle'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.catalog.itemsTip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantPrimaryButton(
            label: texts.text('merchant.items.add'),
            icon: Icons.add_rounded,
            isLoading: provider.isSaving,
            onPressed: () {
              if (provider.categories.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(texts.text('merchant.items.needCategory'))),
                );
                return;
              }
              _openItemSheet(context);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards()
          else if (provider.error != null)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else ...[
            _CategoryChips(provider: provider),
            const SizedBox(height: AppSpacing.md),
            if (provider.visibleItems.isEmpty)
              MerchantEmptyState(
                title: texts.text('merchant.items.emptyTitle'),
                message: texts.text('merchant.items.emptyMessage'),
                actionLabel: texts.text('merchant.items.add'),
                onAction: () => _openItemSheet(context),
              )
            else
              ...provider.visibleItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ItemCard(item: item),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.provider});

  final MerchantItemsProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: texts.text('common.all'),
            selected: provider.selectedCategoryId == 'all',
            onTap: () => provider.selectCategory('all'),
          ),
          ...provider.categories.map(
            (category) => _FilterChip(
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: MerchantPremiumColors.surface,
        backgroundColor: MerchantPremiumColors.baseSoft,
        showCheckmark: true,
        checkmarkColor: MerchantPremiumColors.gold,
        side: BorderSide(
          color: selected ? MerchantPremiumColors.gold : MerchantPremiumColors.glassBorder,
        ),
        labelStyle: TextStyle(
          color: selected ? MerchantPremiumColors.ink : MerchantPremiumColors.mutedLight,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final MerchantItemData item;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MerchantItemsProvider>();
    final isSaving = context.watch<MerchantItemsProvider>().isSaving;
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl.isEmpty
                    ? const Icon(Icons.restaurant_menu_rounded, size: 30)
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
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_price(item.price)} ${texts.text('common.euro')} | ${item.categoryName}',
                      style: const TextStyle(
                        color: MerchantPremiumColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _StatusChip(
                          label: item.isPrivate ? texts.text('common.private') : item.isActive ? texts.text('common.active') : texts.text('common.inactive'),
                          background: item.isPrivate ? null : item.isActive ? MerchantPremiumColors.successSoft : null,
                          foreground: item.isPrivate ? null : item.isActive ? MerchantPremiumColors.success : MerchantPremiumColors.muted,
                        ),
                        if (!item.isAvailable)
                          _StatusChip(
                            label: texts.text('common.unavailable'),
                            background: MerchantPremiumColors.warningSoft,
                            foreground: MerchantPremiumColors.warning,
                          ),
                        if (item.allergenIds.isNotEmpty || item.additiveIds.isNotEmpty)
                          _StatusChip(label: '${texts.text('merchant.itemTags.short')} (${item.allergenIds.length + item.additiveIds.length})'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: texts.text('common.edit'),
                onPressed: () => _openItemSheet(context, item: item),
                icon: const Icon(Icons.edit_rounded, color: MerchantPremiumColors.ink),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton(
                onPressed: isSaving ? null : () => provider.saveItem(
                  id: item.id,
                  categoryId: item.categoryId,
                  name: item.name,
                  description: item.description,
                  price: item.price,
                  originalPrice: item.originalPrice,
                  imageUrl: item.imageUrl,
                  articleNumber: item.articleNumber,
                  allergenIds: item.allergenIds,
                  additiveIds: item.additiveIds,
                  isActive: item.isActive,
                  isAvailable: !item.isAvailable,
                  isPrivate: item.isPrivate,
                ),
                child: Text(item.isAvailable ? texts.text('common.unavailable') : texts.text('common.available')),
              ),
              TextButton(
                onPressed: isSaving ? null : () => provider.saveItem(
                  id: item.id,
                  categoryId: item.categoryId,
                  name: item.name,
                  description: item.description,
                  price: item.price,
                  originalPrice: item.originalPrice,
                  imageUrl: item.imageUrl,
                  articleNumber: item.articleNumber,
                  allergenIds: item.allergenIds,
                  additiveIds: item.additiveIds,
                  isActive: item.isActive,
                  isAvailable: item.isAvailable,
                  isPrivate: !item.isPrivate,
                ),
                child: Text(item.isPrivate ? texts.text('common.public') : texts.text('common.private')),
              ),
              const Spacer(),
              TextButton(
                onPressed: isSaving ? null : () => _confirmDelete(context, item),
                style: TextButton.styleFrom(foregroundColor: MerchantPremiumColors.danger),
                child: Text(texts.text('common.delete')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.background, this.foreground});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground ?? MerchantPremiumColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground ?? MerchantPremiumColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TagPicker extends StatelessWidget {
  const _TagPicker({
    required this.title,
    required this.tags,
    required this.selectedIds,
    required this.onToggle,
  });

  final String title;
  final List<ItemTagData> tags;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            Tooltip(
              message: texts.text('merchant.itemTags.tooltip'),
              child: const Icon(Icons.info_outline_rounded, size: 18, color: MerchantPremiumColors.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (tags.isEmpty)
          Text(texts.text('merchant.itemTags.empty'), style: const TextStyle(color: MerchantPremiumColors.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => FilterChip(
                    label: Text('${tag.code} ${tag.name}'),
                    selected: selectedIds.contains(tag.id),
                    onSelected: (_) => onToggle(tag.id),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

Future<void> _openItemSheet(BuildContext context, {MerchantItemData? item}) async {
  final provider = context.read<MerchantItemsProvider>();
  final texts = context.read<LanguageService>();
  if (provider.categories.isEmpty) return;

  final requestedCategoryId = item?.categoryId ?? (provider.selectedCategoryId == 'all' ? provider.categories.first.id : provider.selectedCategoryId);
  final initialCategoryId = provider.categories.any((category) => category.id == requestedCategoryId)
      ? requestedCategoryId
      : provider.categories.first.id;
  final name = TextEditingController(text: item?.name ?? '');
  final description = TextEditingController(text: item?.description ?? '');
  final price = TextEditingController(text: item == null ? '' : _price(item.price));
  final originalPrice = TextEditingController(text: item?.originalPrice == null ? '' : _price(item!.originalPrice!));
  final articleNumber = TextEditingController(text: item?.articleNumber ?? '');
  var categoryId = initialCategoryId;
  var imageUrl = item?.imageUrl ?? '';
  var isActive = item?.isActive ?? true;
  var isAvailable = item?.isAvailable ?? true;
  var isPrivate = item?.isPrivate ?? false;
  var allergenIds = item == null ? <String>[] : [...item.allergenIds];
  var additiveIds = item == null ? <String>[] : [...item.additiveIds];
  final allergens = provider.itemTags.where((tag) => tag.type == ItemTagType.allergen).toList();
  final additives = provider.itemTags.where((tag) => tag.type == ItemTagType.additive).toList();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.baseElevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item == null ? texts.text('merchant.items.add') : texts.text('merchant.items.edit'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: AppSpacing.md),
                _PreviewCard(name: name, price: price, imageUrl: imageUrl),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: InputDecoration(labelText: texts.text('merchant.catalog.categories')),
                  items: provider.categories
                      .map((category) => DropdownMenuItem(value: category.id, child: Text(category.name)))
                      .toList(),
                  onChanged: (value) => setState(() => categoryId = value ?? categoryId),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: name, label: texts.text('common.name')),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: description, label: texts.text('common.description'), maxLines: 3),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: MerchantTextField(controller: price, label: texts.text('merchant.items.price'), keyboardType: TextInputType.number)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: MerchantTextField(controller: originalPrice, label: texts.text('merchant.items.originalPrice'), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: articleNumber, label: texts.text('merchant.items.articleNumber')),
                const SizedBox(height: AppSpacing.md),
                _TagPicker(
                  title: texts.text('merchant.itemTags.allergens'),
                  tags: allergens,
                  selectedIds: allergenIds,
                  onToggle: (id) => setState(() => allergenIds = _toggleId(allergenIds, id)),
                ),
                const SizedBox(height: AppSpacing.md),
                _TagPicker(
                  title: texts.text('merchant.itemTags.additives'),
                  tags: additives,
                  selectedIds: additiveIds,
                  onToggle: (id) => setState(() => additiveIds = _toggleId(additiveIds, id)),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uploaded = await provider.uploadImage();
                    if (uploaded != null && uploaded.isNotEmpty) setState(() => imageUrl = uploaded);
                  },
                  icon: const Icon(Icons.image_rounded),
                  label: Text(imageUrl.isEmpty ? texts.text('common.uploadImage') : texts.text('common.replaceImage')),
                ),
                SwitchListTile(value: isActive, onChanged: (value) => setState(() => isActive = value), title: Text(texts.text('common.active'))),
                SwitchListTile(value: isAvailable, onChanged: (value) => setState(() => isAvailable = value), title: Text(texts.text('common.available'))),
                SwitchListTile(value: isPrivate, onChanged: (value) => setState(() => isPrivate = value), title: Text(texts.text('common.private'))),
                const SizedBox(height: AppSpacing.md),
                MerchantPrimaryButton(
                  label: texts.text('common.save'),
                  onPressed: () async {
                    final parsedPrice = _parsePrice(price.text);
                    final parsedOriginal = _parsePrice(originalPrice.text);
                    // Sichtbare Validierung statt stillem return (#90/#91).
                    final error = _validateItem(texts, name.text, parsedPrice, parsedOriginal);
                    if (error != null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                      return;
                    }
                    await provider.saveItem(
                      id: item?.id,
                      categoryId: categoryId,
                      name: name.text,
                      description: description.text,
                      price: parsedPrice!,
                      originalPrice: parsedOriginal,
                      imageUrl: imageUrl,
                      articleNumber: articleNumber.text,
                      allergenIds: allergenIds,
                      additiveIds: additiveIds,
                      isActive: isActive,
                      isAvailable: isAvailable,
                      isPrivate: isPrivate,
                    );
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  // Controller nach Schließen des Sheets freigeben (#27, Memory-Leak).
  name.dispose();
  description.dispose();
  price.dispose();
  originalPrice.dispose();
  articleNumber.dispose();
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.name,
    required this.price,
    required this.imageUrl,
  });

  final TextEditingController name;
  final TextEditingController price;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: MerchantPremiumColors.surfaceAlt,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: MerchantPremiumColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isEmpty ? const Icon(Icons.image_rounded) : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            // An die Controller binden, damit die Vorschau beim Tippen von
            // Name/Preis live aktualisiert (#25).
            child: AnimatedBuilder(
              animation: Listenable.merge([name, price]),
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.text.trim().isEmpty ? texts.text('merchant.items.preview') : name.text,
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price.text.trim().isEmpty ? texts.text('merchant.items.priceMissing') : '${price.text} ${texts.text('common.euro')}',
                    style: const TextStyle(color: MerchantPremiumColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, MerchantItemData item) async {
  final provider = context.read<MerchantItemsProvider>();
  final texts = context.read<LanguageService>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(texts.text('merchant.items.deleteTitle')),
      content: Text(texts.text('merchant.items.deleteMessage').replaceAll('{name}', item.name)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(texts.text('common.cancel'))),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(texts.text('common.delete'))),
      ],
    ),
  );
  if (confirmed == true) {
    await provider.deleteItem(item.id);
  }
}

num? _parsePrice(String value) {
  final cleaned = value.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return num.tryParse(cleaned);
}

/// Validiert die Artikel-Eingaben (#90/#91). Gibt eine lokalisierte
/// Fehlermeldung zurück oder null, wenn alles gültig ist.
String? _validateItem(LanguageService texts, String name, num? price, num? originalPrice) {
  if (name.trim().isEmpty) return texts.text('merchant.items.error.name');
  if (price == null || price <= 0) return texts.text('merchant.items.error.price');
  if (originalPrice != null && originalPrice <= price) {
    return texts.text('merchant.items.error.originalPrice');
  }
  return null;
}

List<String> _toggleId(List<String> values, String id) {
  final next = [...values];
  if (next.contains(id)) {
    next.remove(id);
  } else {
    next.add(id);
  }
  return next;
}

String _price(num value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 2).replaceAll('.', ',');
