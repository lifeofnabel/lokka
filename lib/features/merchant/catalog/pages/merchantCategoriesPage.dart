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

class MerchantCategoriesPage extends StatelessWidget {
  const MerchantCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantCategoriesProvider(
        service: MerchantToolsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
        uploadService: context.read<UploadService>(),
      )..load(),
      child: const _MerchantCategoriesView(),
    );
  }
}

class _MerchantCategoriesView extends StatelessWidget {
  const _MerchantCategoriesView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantCategoriesProvider>();
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.catalog.categories'),
      subtitle: texts.text('merchant.categories.subtitle'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.catalog.categoriesTip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantPrimaryButton(
            label: texts.text('merchant.categories.add'),
            icon: Icons.add_rounded,
            isLoading: provider.isSaving,
            onPressed: () => _openCategorySheet(context),
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards()
          else if (provider.error != null)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else if (provider.categories.isEmpty)
            MerchantEmptyState(
              title: texts.text('merchant.categories.emptyTitle'),
              message: texts.text('merchant.categories.emptyMessage'),
              actionLabel: texts.text('merchant.categories.add'),
              onAction: () => _openCategorySheet(context),
            )
          else
            ...provider.categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryCard(category: category),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final ItemCategoryData category;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MerchantCategoriesProvider>();
    final isSaving = context.watch<MerchantCategoriesProvider>().isSaving;
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              _CategoryAvatar(category: category),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      children: [
                        _StatusChip(label: category.isActive ? texts.text('common.active') : texts.text('merchant.features.disabled')),
                        if (category.isPrivate) _StatusChip(label: texts.text('common.private')),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: texts.text('common.edit'),
                onPressed: () => _openCategorySheet(context, category: category),
                icon: const Icon(Icons.edit_rounded, color: MerchantPremiumColors.ink),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              IconButton(
                tooltip: texts.text('common.moveUp'),
                onPressed: isSaving ? null : () => provider.moveCategory(category, -1),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: texts.text('common.moveDown'),
                onPressed: isSaving ? null : () => provider.moveCategory(category, 1),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              const Spacer(),
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => provider.saveCategory(
                  id: category.id,
                  name: category.name,
                  emoji: category.emoji,
                  iconUrl: category.iconUrl,
                  sortOrder: category.sortOrder,
                  isActive: category.isActive,
                  isPrivate: !category.isPrivate,
                ),
                child: Text(category.isPrivate ? texts.text('common.public') : texts.text('merchant.categories.setPrivate')),
              ),
              TextButton(
                onPressed: isSaving ? null : () => _confirmDelete(context, category),
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

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({required this.category});

  final ItemCategoryData category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: category.iconUrl.isNotEmpty
          ? CachedNetworkImage(imageUrl: category.iconUrl, fit: BoxFit.cover)
          : Center(
              child: Text(
                category.emoji.isEmpty ? _firstLetter(category.name) : category.emoji,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }
}

String _firstLetter(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Future<void> _openCategorySheet(BuildContext context, {ItemCategoryData? category}) async {
  final provider = context.read<MerchantCategoriesProvider>();
  final texts = context.read<LanguageService>();
  final name = TextEditingController(text: category?.name ?? '');
  final emoji = TextEditingController(text: category?.emoji ?? '');
  final order = TextEditingController(text: (category?.sortOrder ?? provider.categories.length + 1).toString());
  var iconUrl = category?.iconUrl ?? '';
  var isActive = category?.isActive ?? true;
  var isPrivate = category?.isPrivate ?? false;

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
                Text(
                  category == null ? texts.text('merchant.categories.add') : texts.text('merchant.categories.edit'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: name, label: texts.text('common.name'), hint: texts.text('merchant.categories.nameHint')),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: emoji, label: texts.text('merchant.categories.emoji'), hint: texts.text('merchant.categories.emojiHint')),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: order, label: texts.text('common.sortOrder'), keyboardType: TextInputType.number),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uploaded = await provider.uploadIcon();
                    if (uploaded != null && uploaded.isNotEmpty) setState(() => iconUrl = uploaded);
                  },
                  icon: const Icon(Icons.image_rounded),
                  label: Text(iconUrl.isEmpty ? texts.text('merchant.categories.iconUpload') : texts.text('merchant.categories.iconReplace')),
                ),
                SwitchListTile(
                  value: isActive,
                  onChanged: (value) => setState(() => isActive = value),
                  title: Text(texts.text('common.active')),
                ),
                SwitchListTile(
                  value: isPrivate,
                  onChanged: (value) => setState(() => isPrivate = value),
                  title: Text(texts.text('common.private')),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantPrimaryButton(
                  label: texts.text('common.save'),
                  onPressed: () async {
                    if (name.text.trim().isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text(texts.text('merchant.categories.error.name'))),
                      );
                      return;
                    }
                    await provider.saveCategory(
                      id: category?.id,
                      name: name.text,
                      emoji: emoji.text,
                      iconUrl: iconUrl,
                      sortOrder: int.tryParse(order.text.trim()) ?? provider.categories.length + 1,
                      isActive: isActive,
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
  // Controller nach Schließen des Sheets freigeben (#26, Memory-Leak).
  name.dispose();
  emoji.dispose();
  order.dispose();
}

Future<void> _confirmDelete(BuildContext context, ItemCategoryData category) async {
  final provider = context.read<MerchantCategoriesProvider>();
  final texts = context.read<LanguageService>();
  final hasItems = await provider.categoryHasItems(category.id);
  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(texts.text('merchant.categories.deleteTitle')),
      content: Text(
        hasItems
            ? texts.text('merchant.categories.deleteHasItems')
            : texts.text('merchant.categories.deleteMessage'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(texts.text('common.cancel'))),
        FilledButton(
          onPressed: hasItems ? null : () => Navigator.of(context).pop(true),
          child: Text(texts.text('common.delete')),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await provider.deleteCategory(category.id);
  }
}
