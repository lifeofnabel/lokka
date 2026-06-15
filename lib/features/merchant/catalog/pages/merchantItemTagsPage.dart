import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantItemTagsPage extends StatelessWidget {
  const MerchantItemTagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantItemTagsProvider(
        service: MerchantToolsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantItemTagsView(),
    );
  }
}

class _MerchantItemTagsView extends StatelessWidget {
  const _MerchantItemTagsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantItemTagsProvider>();
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.itemTags.title'),
      subtitle: texts.text('merchant.itemTags.subtitle'),
      backPath: '/merchant/catalog',
      trailing: MerchantInfoTooltip(message: texts.text('merchant.itemTags.tooltip')),
      child: provider.isLoading
          ? const MerchantLoadingCards(count: 4)
          : provider.error != null
              ? MerchantErrorState(message: provider.error!, onRetry: provider.load)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TagGroup(
                      title: texts.text('merchant.itemTags.allergens'),
                      type: ItemTagType.allergen,
                      tags: provider.allergens,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TagGroup(
                      title: texts.text('merchant.itemTags.additives'),
                      type: ItemTagType.additive,
                      tags: provider.additives,
                    ),
                  ],
                ),
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.title,
    required this.type,
    required this.tags,
  });

  final String title;
  final String type;
  final List<ItemTagData> tags;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              IconButton.filled(
                tooltip: texts.text('merchant.itemTags.add'),
                onPressed: () => _openTagSheet(context, type: type),
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: MerchantPremiumColors.ink,
                  foregroundColor: MerchantPremiumColors.base,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...tags.map((tag) => _TagRow(tag: tag)),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag});

  final ItemTagData tag;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MerchantItemTagsProvider>();
    final texts = context.watch<LanguageService>();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 34),
            height: 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: MerchantPremiumColors.ink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(tag.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(tag.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          if (tag.isCustom) ...[
            IconButton(
              tooltip: texts.text('common.edit'),
              onPressed: () => _openTagSheet(context, type: tag.type, tag: tag),
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              tooltip: texts.text('common.delete'),
              onPressed: () => provider.deleteTag(tag.id),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ] else
            Tooltip(
              message: texts.text('merchant.itemTags.standardTip'),
              child: const Icon(Icons.lock_outline_rounded, size: 18, color: MerchantPremiumColors.muted),
            ),
        ],
      ),
    );
  }
}

Future<void> _openTagSheet(
  BuildContext context, {
  required String type,
  ItemTagData? tag,
}) async {
  final provider = context.read<MerchantItemTagsProvider>();
  final texts = context.read<LanguageService>();
  final code = TextEditingController(text: tag?.code ?? '');
  final name = TextEditingController(text: tag?.name ?? '');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.baseElevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(texts.text(tag == null ? 'merchant.itemTags.add' : 'common.edit'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(controller: code, label: texts.text('merchant.itemTags.code')),
          const SizedBox(height: AppSpacing.md),
          MerchantTextField(controller: name, label: texts.text('common.name')),
          const SizedBox(height: AppSpacing.lg),
          MerchantPrimaryButton(
            label: texts.text('common.save'),
            isLoading: provider.isSaving,
            onPressed: () async {
              if (name.text.trim().isEmpty || code.text.trim().isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text(texts.text('merchant.itemTags.error'))),
                );
                return;
              }
              await provider.saveTag(
                id: tag?.id,
                type: type,
                code: code.text,
                name: name.text,
              );
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    ),
  );
  code.dispose();
  name.dispose();
}
