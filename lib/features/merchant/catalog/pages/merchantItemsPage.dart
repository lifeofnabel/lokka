import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/widgets/appImage.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/services/uploadService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../feedManager/widgets/squareImageCropSheet.dart';
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

class _MerchantItemsView extends StatefulWidget {
  const _MerchantItemsView();

  @override
  State<_MerchantItemsView> createState() => _MerchantItemsViewState();
}

class _MerchantItemsViewState extends State<_MerchantItemsView> {
  final _searchController = TextEditingController();

  /// Artikel werden in 6er-Schritten gerendert (schneller Seitenaufbau,
  /// echte Lazy-Slivers). Beim Runterscrollen lädt automatisch der nächste
  /// Block nach.
  static const int _pageSize = 6;
  int _visibleCount = _pageSize;
  String _lastFilterKey = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification, int total) {
    if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 400 &&
        _visibleCount < total) {
      setState(() {
        _visibleCount = (_visibleCount + _pageSize).clamp(0, total);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantItemsProvider>();
    final texts = context.watch<LanguageService>();

    // Bei Kategorie-/Suchwechsel wieder bei den ersten 6 anfangen.
    final filterKey = '${provider.selectedCategoryId}|${_searchController.text}';
    if (filterKey != _lastFilterKey) {
      _lastFilterKey = filterKey;
      _visibleCount = _pageSize;
    }

    final items = provider.visibleItems;
    final shown = items.take(_visibleCount).toList();
    final hasMore = _visibleCount < items.length;
    final ready = !provider.isLoading && provider.error == null;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => _onScroll(notification, items.length),
      child: MerchantToolScaffold(
        title: texts.text('merchant.catalog.items'),
        subtitle: texts.text('merchant.items.subtitle'),
        backPath: '/merchant/catalog',
        trailing: MerchantInfoTooltip(message: texts.text('merchant.catalog.itemsTip')),
        slivers: [
          SliverToBoxAdapter(
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
                const SizedBox(height: AppSpacing.sm),
                _ItemSearchBar(controller: _searchController, provider: provider),
                const SizedBox(height: AppSpacing.md),
                if (ready) ...[
                  _CategoryChips(provider: provider),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
          if (provider.isLoading)
            const SliverToBoxAdapter(child: MerchantLoadingCards())
          else if (provider.error != null)
            SliverToBoxAdapter(
              child: MerchantErrorState(message: provider.error!, onRetry: provider.load),
            )
          else if (items.isEmpty)
            SliverToBoxAdapter(
              child: MerchantEmptyState(
                title: texts.text('merchant.items.emptyTitle'),
                message: texts.text('merchant.items.emptyMessage'),
                actionLabel: texts.text('merchant.items.add'),
                onAction: () => _openItemSheet(context),
              ),
            )
          else
            SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ItemCard(item: shown[index]),
              ),
            ),
          if (ready && hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemSearchBar extends StatelessWidget {
  const _ItemSearchBar({
    required this.controller,
    required this.provider,
  });

  final TextEditingController controller;
  final MerchantItemsProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return TextField(
      controller: controller,
      onChanged: (value) => provider.setSearch(value),
      style: const TextStyle(
        color: MerchantPremiumColors.ink,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: texts.text('merchant.items.search'),
        hintStyle: const TextStyle(
          color: MerchantPremiumColors.muted,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: MerchantPremiumColors.muted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, color: MerchantPremiumColors.muted),
                onPressed: () {
                  controller.clear();
                  provider.setSearch('');
                },
              ),
        filled: true,
        fillColor: MerchantPremiumColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MerchantPremiumColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MerchantPremiumColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MerchantPremiumColors.gold, width: 1.4),
        ),
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
                    : AppImage(
                        imageUrl: item.imageUrl,
                        memCacheWidth: 240,
                        errorWidget: const Icon(Icons.restaurant_menu_rounded, size: 30),
                      ),
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
                  imageRatio: item.imageRatio,
                  optionGroups: item.optionGroups,
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
                  imageRatio: item.imageRatio,
                  optionGroups: item.optionGroups,
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

/// Allergen-/Zusatzstoff-Auswahl. Zeigt standardmäßig nur die gewählten plus
/// 3 weitere Chips; „Mehr anzeigen" klappt die komplette Liste auf (#Speisekarte).
class _TagPicker extends StatefulWidget {
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
  State<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<_TagPicker> {
  static const _collapsedExtra = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final tags = widget.tags;

    // Eingeklappt: gewählte Tags immer + die ersten 3 ungewählten.
    final List<ItemTagData> visible;
    if (_expanded) {
      visible = tags;
    } else {
      final selected = tags.where((tag) => widget.selectedIds.contains(tag.id)).toList();
      final unselected = tags
          .where((tag) => !widget.selectedIds.contains(tag.id))
          .take(_collapsedExtra)
          .toList();
      visible = [...selected, ...unselected];
    }
    final hidden = tags.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
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
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visible
                .map(
                  (tag) => FilterChip(
                    label: Text('${tag.code} ${tag.name}'),
                    selected: widget.selectedIds.contains(tag.id),
                    onSelected: (_) => widget.onToggle(tag.id),
                  ),
                )
                .toList(),
          ),
          if (hidden > 0 || _expanded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                label: Text(
                  _expanded
                      ? texts.text('merchant.itemTags.showLess')
                      : '${texts.text('merchant.itemTags.showMore')} (+$hidden)',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: MerchantPremiumColors.gold,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Editor für Artikel-Optionen (Gruppen mit Einzel-/Mehrfachauswahl, Pflicht
/// und Aufpreis je Option). Verwaltet eigene Controller; meldet Änderungen
/// live über [onChanged] an das Eltern-Sheet.
class _OptionGroupsEditor extends StatefulWidget {
  const _OptionGroupsEditor({required this.initial, required this.onChanged});

  final List<ItemOptionGroup> initial;
  final ValueChanged<List<ItemOptionGroup>> onChanged;

  @override
  State<_OptionGroupsEditor> createState() => _OptionGroupsEditorState();
}

class _EditOption {
  _EditOption({required this.id, required String name, required String price})
      : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(text: price);
  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _EditGroup {
  _EditGroup({
    required this.id,
    required String title,
    required this.isMulti,
    required this.isRequired,
    required this.options,
  }) : titleCtrl = TextEditingController(text: title);
  final String id;
  final TextEditingController titleCtrl;
  bool isMulti;
  bool isRequired;
  List<_EditOption> options;
  void dispose() {
    titleCtrl.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _OptionGroupsEditorState extends State<_OptionGroupsEditor> {
  late List<_EditGroup> _groups;
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    _groups = widget.initial
        .map(
          (group) => _EditGroup(
            id: group.id.isEmpty ? _newId('g') : group.id,
            title: group.title,
            isMulti: group.multiSelect,
            isRequired: group.isRequired,
            options: group.options
                .map(
                  (option) => _EditOption(
                    id: option.id.isEmpty ? _newId('o') : option.id,
                    name: option.name,
                    price: option.price == 0 ? '' : _price(option.price),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final group in _groups) {
      group.dispose();
    }
    super.dispose();
  }

  String _newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  void _emit() {
    widget.onChanged(
      _groups
          .map(
            (group) => ItemOptionGroup(
              id: group.id,
              title: group.titleCtrl.text.trim(),
              multiSelect: group.isMulti,
              isRequired: group.isRequired,
              options: group.options
                  .map(
                    (option) => ItemOption(
                      id: option.id,
                      name: option.nameCtrl.text.trim(),
                      price: _parsePrice(option.priceCtrl.text) ?? 0,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(texts.text('merchant.items.options'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            Tooltip(
              message: texts.text('merchant.items.optionsTip'),
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 6),
              child: const Icon(Icons.info_outline_rounded,
                  size: 18, color: MerchantPremiumColors.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var gi = 0; gi < _groups.length; gi++)
          _groupCard(texts, _groups[gi], gi),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _groups.add(_EditGroup(
                id: _newId('g'), title: '', isMulti: false, isRequired: false, options: []));
            _emit();
          }),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(texts.text('merchant.items.addOptionGroup')),
        ),
      ],
    );
  }

  Widget _groupCard(LanguageService texts, _EditGroup group, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: group.titleCtrl,
                  onChanged: (_) => _emit(),
                  style: const TextStyle(
                      color: MerchantPremiumColors.ink, fontWeight: FontWeight.w800),
                  decoration: _denseDecoration(texts.text('merchant.items.optionGroupTitle')),
                ),
              ),
              IconButton(
                tooltip: texts.text('common.delete'),
                onPressed: () => setState(() {
                  group.dispose();
                  _groups.removeAt(index);
                  _emit();
                }),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: MerchantPremiumColors.danger),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _toggle(
                  label: texts.text('merchant.items.optionMulti'),
                  value: group.isMulti,
                  onChanged: (v) => setState(() {
                    group.isMulti = v;
                    _emit();
                  }),
                ),
              ),
              Expanded(
                child: _toggle(
                  label: texts.text('merchant.items.optionRequired'),
                  value: group.isRequired,
                  onChanged: (v) => setState(() {
                    group.isRequired = v;
                    _emit();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var oi = 0; oi < group.options.length; oi++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: group.options[oi].nameCtrl,
                      onChanged: (_) => _emit(),
                      style: const TextStyle(color: MerchantPremiumColors.ink),
                      decoration: _denseDecoration(texts.text('merchant.items.optionName')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: group.options[oi].priceCtrl,
                      onChanged: (_) => _emit(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_PriceInputFormatter()],
                      style: const TextStyle(color: MerchantPremiumColors.ink),
                      decoration: _denseDecoration(texts.text('merchant.items.optionPrice'))
                          .copyWith(prefixText: '+ ', suffixText: '€'),
                    ),
                  ),
                  IconButton(
                    tooltip: texts.text('common.delete'),
                    onPressed: () => setState(() {
                      group.options[oi].dispose();
                      group.options.removeAt(oi);
                      _emit();
                    }),
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: MerchantPremiumColors.muted),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                group.options.add(_EditOption(id: _newId('o'), name: '', price: ''));
                _emit();
              }),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(texts.text('merchant.items.addOption')),
              style: TextButton.styleFrom(
                  foregroundColor: MerchantPremiumColors.gold, padding: EdgeInsets.zero),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Switch(value: value, onChanged: onChanged),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
                color: MerchantPremiumColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  InputDecoration _denseDecoration(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: MerchantPremiumColors.muted),
        filled: true,
        fillColor: MerchantPremiumColors.baseElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MerchantPremiumColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MerchantPremiumColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MerchantPremiumColors.gold, width: 1.3),
        ),
      );
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
  // Neue Artikel bekommen automatisch die nächsthöhere freie Nummer.
  final articleNumber = TextEditingController(
    text: item?.articleNumber ?? _nextArticleNumber(provider.items),
  );
  var categoryId = initialCategoryId;
  var imageUrl = item?.imageUrl ?? '';
  var isActive = item?.isActive ?? true;
  var isAvailable = item?.isAvailable ?? true;
  var isPrivate = item?.isPrivate ?? false;
  // „Alter Preis" nur sichtbar, wenn der Aktionspreis-Schalter an ist.
  var showOldPrice = item?.originalPrice != null;
  // Artikelbilder sind immer 1:1 (Format-Auswahl entfernt).
  const imageRatio = 'square';
  // Optionsgruppen (live vom Options-Editor aktualisiert).
  var optionGroups = item == null ? <ItemOptionGroup>[] : [...item.optionGroups];
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
                MerchantTextField(controller: price, label: texts.text('merchant.items.price'), keyboardType: TextInputType.number),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        texts.text('merchant.items.oldPriceToggle'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Tooltip(
                      message: texts.text('merchant.items.oldPriceTooltip'),
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 6),
                      child: const Icon(Icons.info_outline_rounded, size: 18, color: MerchantPremiumColors.muted),
                    ),
                    Switch(
                      value: showOldPrice,
                      onChanged: (value) => setState(() => showOldPrice = value),
                    ),
                  ],
                ),
                if (showOldPrice) ...[
                  const SizedBox(height: AppSpacing.sm),
                  MerchantTextField(controller: originalPrice, label: texts.text('merchant.items.originalPrice'), keyboardType: TextInputType.number),
                ],
                const SizedBox(height: AppSpacing.md),
                MerchantTextField(controller: articleNumber, label: texts.text('merchant.items.articleNumber'), keyboardType: TextInputType.number),
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
                _OptionGroupsEditor(
                  initial: optionGroups,
                  onChanged: (groups) => optionGroups = groups,
                ),
                const SizedBox(height: AppSpacing.md),
                ListenableBuilder(
                  listenable: provider,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: provider.isSaving
                            ? null
                            : () async {
                                final picked = await provider.uploadService.pickImageWithFilePicker();
                                if (picked == null || !context.mounted) return;
                                // Artikelbilder immer 1:1 zuschneiden.
                                final Uint8List? cropped = await showSquareImageCropSheet(
                                  context: context,
                                  imageBytes: picked.bytes,
                                  aspectRatio: 1.0,
                                );
                                if (cropped == null || !context.mounted) return;
                                final uploaded = await provider.uploadCroppedImage(
                                  bytes: cropped,
                                  fileName: picked.fileName,
                                  type: UploadImageType.item,
                                );
                                if (uploaded != null && uploaded.isNotEmpty) {
                                  setState(() => imageUrl = uploaded);
                                }
                              },
                        icon: const Icon(Icons.image_rounded),
                        label: Text(imageUrl.isEmpty ? texts.text('common.uploadImage') : texts.text('common.replaceImage')),
                      ),
                      if (provider.isSaving) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: provider.uploadProgress,
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SwitchListTile(value: isActive, onChanged: (value) => setState(() => isActive = value), title: Text(texts.text('common.active'))),
                SwitchListTile(value: isAvailable, onChanged: (value) => setState(() => isAvailable = value), title: Text(texts.text('common.available'))),
                SwitchListTile(value: isPrivate, onChanged: (value) => setState(() => isPrivate = value), title: Text(texts.text('common.private'))),
                const SizedBox(height: AppSpacing.md),
                MerchantPrimaryButton(
                  label: texts.text('common.save'),
                  onPressed: () async {
                    final parsedPrice = _parsePrice(price.text);
                    final parsedOriginal = showOldPrice ? _parsePrice(originalPrice.text) : null;
                    // Sichtbare Validierung statt stillem return (#90/#91).
                    final error = _validateItem(texts, name.text, parsedPrice, parsedOriginal);
                    if (error != null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                      return;
                    }
                    // Artikelnummer darf nicht doppelt vergeben werden (#Speisekarte).
                    final number = articleNumber.text.trim();
                    final numberTaken = number.isNotEmpty &&
                        provider.items.any((other) =>
                            other.id != item?.id && other.articleNumber.trim() == number);
                    if (numberTaken) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text(texts.text('merchant.items.error.articleNumberTaken'))),
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
                      imageRatio: imageRatio,
                      optionGroups: _sanitizeOptionGroups(optionGroups),
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
  // Controller erst NACH der Schließ-Animation freigeben (#27 Memory-Leak).
  // showModalBottomSheet löst sein Future bereits beim pop() aus – das Sheet
  // (inkl. der an name/price gebundenen Live-Vorschau in _PreviewCard) baut
  // sich während des Ausblendens aber noch einmal auf und würde sonst auf
  // bereits disposte Controller zugreifen ("TextEditingController used after
  // being disposed"). Ein kurzer Aufschub > Schließ-Animation verhindert das,
  // ohne den Leak wieder einzuführen.
  Future.delayed(const Duration(milliseconds: 400), () {
    name.dispose();
    description.dispose();
    price.dispose();
    originalPrice.dispose();
    articleNumber.dispose();
  });
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
            child: imageUrl.isEmpty
                ? const Icon(Icons.image_rounded)
                : AppImage(
                    imageUrl: imageUrl,
                    errorWidget: const Icon(Icons.image_rounded),
                  ),
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

/// Entfernt leere Optionsgruppen/-optionen vor dem Speichern: Optionen ohne
/// Namen und Gruppen ohne Titel oder ohne (gültige) Optionen fallen raus.
List<ItemOptionGroup> _sanitizeOptionGroups(List<ItemOptionGroup> groups) {
  final result = <ItemOptionGroup>[];
  for (final group in groups) {
    final title = group.title.trim();
    final options = group.options.where((option) => option.name.trim().isNotEmpty).toList();
    if (title.isEmpty || options.isEmpty) continue;
    result.add(ItemOptionGroup(
      id: group.id,
      title: title,
      multiSelect: group.multiSelect,
      isRequired: group.isRequired,
      options: options,
    ));
  }
  return result;
}

/// Erlaubt nur eine gültige Dezimalzahl im Aufpreis-Feld (blockt Buchstaben
/// und mehrfache Trennzeichen direkt bei der Eingabe).
class _PriceInputFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d{0,5}([.,]\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty || _pattern.hasMatch(newValue.text)) return newValue;
    return oldValue;
  }
}

/// Nächste freie Artikelnummer = höchste vorhandene numerische Nummer + 1.
/// Bereits vergebene Nummern werden so nie erneut vorgeschlagen.
String _nextArticleNumber(List<MerchantItemData> items) {
  var max = 0;
  for (final item in items) {
    final number = int.tryParse(item.articleNumber.trim());
    if (number != null && number > max) max = number;
  }
  return (max + 1).toString();
}
