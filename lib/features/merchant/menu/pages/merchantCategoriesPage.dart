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
    return MerchantToolScaffold(
      title: 'Kategorien',
      subtitle: 'Gruppen helfen Kunden, deine Artikel schneller zu finden.',
      trailing: const MerchantInfoTooltip(message: 'Gruppen helfen Kunden, deine Artikel schneller zu finden.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MerchantPrimaryButton(
            label: 'Kategorie hinzufuegen',
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
              title: 'Noch keine Kategorien',
              message: 'Lege deine erste Gruppe an, zum Beispiel Kaffee, Snacks oder Services.',
              actionLabel: 'Kategorie hinzufuegen',
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
              _CategoryAvatar(category: category),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      children: [
                        _StatusChip(label: category.isActive ? 'Aktiv' : 'Aus'),
                        if (category.isPrivate) const _StatusChip(label: 'Privat'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Bearbeiten',
                onPressed: () => _openCategorySheet(context, category: category),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              IconButton(
                tooltip: 'Nach oben',
                onPressed: () => provider.moveCategory(category, -1),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: 'Nach unten',
                onPressed: () => provider.moveCategory(category, 1),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => provider.saveCategory(
                  id: category.id,
                  name: category.name,
                  emoji: category.emoji,
                  iconUrl: category.iconUrl,
                  sortOrder: category.sortOrder,
                  isActive: category.isActive,
                  isPrivate: !category.isPrivate,
                ),
                child: Text(category.isPrivate ? 'Oeffentlich' : 'Privat setzen'),
              ),
              TextButton(
                onPressed: () => _confirmDelete(context, category),
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

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({required this.category});

  final ItemCategoryData category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: category.iconUrl.isNotEmpty
          ? CachedNetworkImage(imageUrl: category.iconUrl, fit: BoxFit.cover)
          : Center(
              child: Text(
                category.emoji.isEmpty ? _firstLetter(category.name) : category.emoji,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
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
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

Future<void> _openCategorySheet(BuildContext context, {ItemCategoryData? category}) async {
  final provider = context.read<MerchantCategoriesProvider>();
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
                Text(
                  category == null ? 'Kategorie hinzufuegen' : 'Kategorie bearbeiten',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: name, label: 'Name', hint: 'z. B. Kaffee'),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: emoji, label: 'Emoji', hint: 'z. B. ☕'),
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: order, label: 'Reihenfolge', keyboardType: TextInputType.number),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uploaded = await provider.uploadIcon();
                    if (uploaded != null && uploaded.isNotEmpty) setState(() => iconUrl = uploaded);
                  },
                  icon: const Icon(Icons.image_rounded),
                  label: Text(iconUrl.isEmpty ? 'Bild/Icon hochladen' : 'Bild/Icon ersetzen'),
                ),
                SwitchListTile(
                  value: isActive,
                  onChanged: (value) => setState(() => isActive = value),
                  title: const Text('Aktiv'),
                ),
                SwitchListTile(
                  value: isPrivate,
                  onChanged: (value) => setState(() => isPrivate = value),
                  title: const Text('Privat'),
                ),
                const SizedBox(height: AppSpacing.md),
                MerchantPrimaryButton(
                  label: 'Speichern',
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
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
}

Future<void> _confirmDelete(BuildContext context, ItemCategoryData category) async {
  final provider = context.read<MerchantCategoriesProvider>();
  final hasItems = await provider.categoryHasItems(category.id);
  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kategorie loeschen?'),
      content: Text(
        hasItems
            ? 'Diese Kategorie enthaelt Artikel. Wenn du sie loeschst, bleiben Artikel ohne saubere Gruppe zurueck.'
            : 'Diese Kategorie wird dauerhaft entfernt.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Loeschen')),
      ],
    ),
  );

  if (confirmed == true) {
    await provider.deleteCategory(category.id);
  }
}
