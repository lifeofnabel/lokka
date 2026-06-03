import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../providers/display_studio_provider.dart';
import '../widgets/display_layout_card.dart';
import '../widgets/layout_filter_sheet.dart';
import 'layout_create/layout_type_select_page.dart';

class DisplayLayoutsTab extends StatefulWidget {
  const DisplayLayoutsTab({super.key});

  @override
  State<DisplayLayoutsTab> createState() => _DisplayLayoutsTabState();
}

class _DisplayLayoutsTabState extends State<DisplayLayoutsTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DisplayStudioProvider>();
    final filtered = provider.filteredLayouts;

    return Column(
      children: [
        // ── Search + Filter bar ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: provider.setLayoutSearch,
                  decoration: InputDecoration(
                    hintText: 'Layouts suchen…',
                    hintStyle: const TextStyle(color: AppColors.gray300, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.gray500),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              provider.setLayoutSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      borderSide: const BorderSide(color: AppColors.black),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FilterButton(provider: provider, onOpen: () => _openFilter(context, provider)),
            ],
          ),
        ),

        // ── Active filter chips ───────────────────────────────────────────────
        if (provider.hasActiveFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 6, AppSpacing.md, 0),
            child: _ActiveFilterRow(provider: provider),
          ),

        const SizedBox(height: 8),

        // ── Content ────────────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty && provider.layouts.isEmpty
              ? _EmptyState(onCreate: () => _openCreate(context))
              : filtered.isEmpty
                  ? _NoResults(onClear: () {
                      _searchCtrl.clear();
                      provider.setLayoutSearch('');
                      provider.clearFilters();
                    })
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl + 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final layout = filtered[index];
                        return DisplayLayoutCard(
                          layout: layout,
                          onEdit: () => openLayoutEditor(context, layout),
                          onDuplicate: () => provider.duplicateLayout(layout),
                          onDelete: () => provider.deleteLayout(layout.id),
                          onRename: () => _showRename(context, provider, layout.id, layout.title),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _openCreate(BuildContext context) {
    final service = context.read<DisplayStudioProvider>().service;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LayoutTypeSelectPage(service: service),
      ),
    );
  }

  void _openFilter(BuildContext context, DisplayStudioProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => LayoutFilterSheet(
        initialOrientation: provider.filterOrientation,
        initialScreenSize: provider.filterScreenSize,
        initialMode: provider.filterMode,
        initialType: provider.filterType,
        onApply: ({orientation, screenSize, mode, type}) =>
            provider.setFilter(
                orientation: orientation,
                screenSize: screenSize,
                mode: mode,
                type: type),
        onClear: provider.clearFilters,
      ),
    );
  }

  void _showRename(
      BuildContext context, DisplayStudioProvider provider, String id, String current) {
    final ctrl = TextEditingController(text: current);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Layout umbenennen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Neuer Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  provider.renameLayout(id, ctrl.text.trim());
                }
                Navigator.of(ctx).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Speichern',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.provider, required this.onOpen});
  final DisplayStudioProvider provider;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final count = provider.activeFilterCount;
    return Stack(
      children: [
        IconButton(
          onPressed: onOpen,
          icon: const Icon(Icons.filter_list_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
                side: const BorderSide(color: AppColors.border)),
          ),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: AppColors.black, shape: BoxShape.circle),
              child: Center(
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.white)),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActiveFilterRow extends StatelessWidget {
  const _ActiveFilterRow({required this.provider});
  final DisplayStudioProvider provider;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._chips(provider),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: provider.clearFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.black, borderRadius: BorderRadius.circular(20)),
              child: const Text('Zurücksetzen',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.white)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _chips(DisplayStudioProvider p) {
    final chips = <Widget>[];
    if (p.filterOrientation != null) {
      chips.add(_Chip(p.filterOrientation == 'landscape' ? 'Querformat' : 'Hochformat'));
    }
    if (p.filterScreenSize != null) chips.add(_Chip(p.filterScreenSize!));
    if (p.filterMode != null) {
      chips.add(_Chip(p.filterMode == 'day' ? 'Tag' : 'Nacht'));
    }
    if (p.filterType != null) chips.add(_Chip(p.filterType!));
    return chips;
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border)),
      child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.gray700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.dashboard_rounded, color: AppColors.white, size: 34),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Noch keine Layouts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.sm),
            const Text('Erstelle dein erstes Layout für deine Displays.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Layout erstellen'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onClear});
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.gray300),
            const SizedBox(height: AppSpacing.md),
            const Text('Keine Layouts gefunden.',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onClear,
              child: const Text('Filter zurücksetzen'),
            ),
          ],
        ),
      ),
    );
  }
}
