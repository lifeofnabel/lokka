import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
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
    return MerchantToolScaffold(
      title: 'Artikel',
      subtitle: 'Hier pflegst du Produkte, Preise und Verfuegbarkeit.',
      trailing: const MerchantInfoTooltip(message: 'Hier pflegst du Produkte, Preise und Verfuegbarkeit.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantPrimaryButton(
            label: 'Artikel hinzufuegen',
            icon: Icons.add_rounded,
            isLoading: provider.isSaving,
            onPressed: () {
              if (provider.categories.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lege zuerst eine Kategorie an.')),
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
                title: 'Noch keine Artikel',
                message: 'Fuege Produkte, Speisen oder Leistungen zu deinem Sortiment hinzu.',
                actionLabel: 'Artikel hinzufuegen',
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Alle',
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
        selectedColor: AppColors.black,
        labelStyle: TextStyle(
          color: selected ? AppColors.white : AppColors.black,
          fontWeight: FontWeight.w800,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.gray50,
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
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${_price(item.price)} Euro · ${item.categoryName}', style: const TextStyle(color: AppColors.gray700, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      children: [
                        _StatusChip(label: item.isPrivate ? 'Privat' : item.isActive ? 'Aktiv' : 'Inaktiv'),
                        if (!item.isAvailable) const _StatusChip(label: 'Nicht verfuegbar'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Bearbeiten',
                onPressed: () => _openItemSheet(context, item: item),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton(
                onPressed: () => provider.saveItem(
                  id: item.id,
                  categoryId: item.categoryId,
                  name: item.name,
                  description: item.description,
                  price: item.price,
                  originalPrice: item.originalPrice,
                  imageUrl: item.imageUrl,
                  articleNumber: item.articleNumber,
                  isActive: item.isActive,
                  isAvailable: !item.isAvailable,
                  isPrivate: item.isPrivate,
                ),
                child: Text(item.isAvailable ? 'Nicht verfuegbar' : 'Verfuegbar'),
              ),
              TextButton(
                onPressed: () => provider.saveItem(
                  id: item.id,
                  categoryId: item.categoryId,
                  name: item.name,
                  description: item.description,
                  price: item.price,
                  originalPrice: item.originalPrice,
                  imageUrl: item.imageUrl,
                  articleNumber: item.articleNumber,
                  isActive: item.isActive,
                  isAvailable: item.isAvailable,
                  isPrivate: !item.isPrivate,
                ),
                child: Text(item.isPrivate ? 'Oeffentlich' : 'Privat'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _confirmDelete(context, item),
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                child: const Text('Loeschen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

Future<void> _openItemSheet(BuildContext context, {MerchantItemData? item}) async {
  final provider = context.read<MerchantItemsProvider>();
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

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
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
                Text(item == null ? 'Artikel hinzufuegen' : 'Artikel bearbeiten', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: AppSpacing.md),
                _PreviewCard(name: name, price: price, imageUrl: imageUrl),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: categoryId,
                  decoration: const InputDecoration(labelText: 'Kategorie'),
                  items: provider.categories
                      .map((category) => DropdownMenuItem(value: category.id, child: Text(category.name)))
                      .toList(),
                  onChanged: (value) => setState(() => categoryId = value ?? categoryId),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: name, label: 'Name'),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: description, label: 'Beschreibung', maxLines: 3),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: MerchantTextField(controller: price, label: 'Preis', keyboardType: TextInputType.number)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: MerchantTextField(controller: originalPrice, label: 'Alter Preis', keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: articleNumber, label: 'Artikelnummer'),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uploaded = await provider.uploadImage();
                    if (uploaded != null && uploaded.isNotEmpty) setState(() => imageUrl = uploaded);
                  },
                  icon: const Icon(Icons.image_rounded),
                  label: Text(imageUrl.isEmpty ? 'Bild hochladen' : 'Bild ersetzen'),
                ),
                SwitchListTile(value: isActive, onChanged: (value) => setState(() => isActive = value), title: const Text('Aktiv')),
                SwitchListTile(value: isAvailable, onChanged: (value) => setState(() => isAvailable = value), title: const Text('Verfuegbar')),
                SwitchListTile(value: isPrivate, onChanged: (value) => setState(() => isPrivate = value), title: const Text('Privat')),
                const SizedBox(height: AppSpacing.md),
                MerchantPrimaryButton(
                  label: 'Speichern',
                  onPressed: () async {
                    final parsedPrice = _parsePrice(price.text);
                    if (name.text.trim().isEmpty || parsedPrice == null) return;
                    await provider.saveItem(
                      id: item?.id,
                      categoryId: categoryId,
                      name: name.text,
                      description: description.text,
                      price: parsedPrice,
                      originalPrice: _parsePrice(originalPrice.text),
                      imageUrl: imageUrl,
                      articleNumber: articleNumber.text,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isEmpty ? const Icon(Icons.image_rounded) : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.text.trim().isEmpty ? 'Artikelvorschau' : name.text, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(price.text.trim().isEmpty ? 'Preis fehlt' : '${price.text} Euro', style: const TextStyle(color: AppColors.gray700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, MerchantItemData item) async {
  final provider = context.read<MerchantItemsProvider>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Artikel loeschen?'),
      content: Text('${item.name} wird dauerhaft entfernt.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Loeschen')),
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

String _price(num value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 2).replaceAll('.', ',');
