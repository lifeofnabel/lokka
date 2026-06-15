import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/providers/merchantToolsProvider.dart';
import '../../tools/services/merchantToolsService.dart';
import '../../tools/widgets/merchantToolUi.dart';

class MerchantTablesPage extends StatelessWidget {
  const MerchantTablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantTablesProvider(
        service: MerchantToolsService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..load(),
      child: const _MerchantTablesView(),
    );
  }
}

class _MerchantTablesView extends StatelessWidget {
  const _MerchantTablesView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantTablesProvider>();
    final texts = context.watch<LanguageService>();
    return MerchantToolScaffold(
      title: texts.text('merchant.catalog.tables'),
      subtitle: texts.text('merchant.tables.subtitle'),
      trailing: MerchantInfoTooltip(message: texts.text('merchant.catalog.tablesTip')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: MerchantPrimaryButton(
                  label: texts.text('merchant.tables.area'),
                  icon: Icons.add_business_rounded,
                  isLoading: provider.isSaving,
                  onPressed: () => _openAreaSheet(context),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MerchantPrimaryButton(
                  label: texts.text('merchant.tables.table'),
                  icon: Icons.add_rounded,
                  isLoading: provider.isSaving,
                  onPressed: provider.areas.isEmpty ? null : () => _openTableSheet(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (provider.isLoading)
            const MerchantLoadingCards()
          else if (provider.error != null)
            MerchantErrorState(message: provider.error!, onRetry: provider.load)
          else ...[
            _AreaChips(provider: provider),
            const SizedBox(height: AppSpacing.md),
            if (provider.areas.isEmpty)
              MerchantEmptyState(
                title: texts.text('merchant.tables.emptyAreasTitle'),
                message: texts.text('merchant.tables.emptyAreasMessage'),
                actionLabel: texts.text('merchant.tables.addArea'),
                onAction: () => _openAreaSheet(context),
              )
            else if (provider.visibleTables.isEmpty)
              MerchantEmptyState(
                title: texts.text('merchant.tables.emptyTitle'),
                message: texts.text('merchant.tables.emptyMessage'),
                actionLabel: texts.text('merchant.tables.addTable'),
                onAction: () => _openTableSheet(context),
              )
            else
              ...provider.visibleTables.map(
                (table) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TableCard(table: table),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AreaChips extends StatelessWidget {
  const _AreaChips({required this.provider});

  final MerchantTablesProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _AreaChip(label: texts.text('common.all'), selected: provider.selectedAreaId == 'all', onTap: () => provider.selectArea('all')),
          ...provider.areas.map(
            (area) => _AreaChip(
              label: area.name,
              selected: provider.selectedAreaId == area.areaId,
              onTap: () => provider.selectArea(area.areaId),
              onLongPress: () => _openAreaSheet(context, area: area),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: MerchantPremiumColors.surface,
          backgroundColor: MerchantPremiumColors.baseSoft,
          side: BorderSide(
            color: selected ? MerchantPremiumColors.gold : Colors.white.withValues(alpha: 0.12),
          ),
          labelStyle: TextStyle(
            color: selected ? MerchantPremiumColors.ink : MerchantPremiumColors.mutedLight,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table});

  final TableData table;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MerchantTablesProvider>();
    final texts = context.watch<LanguageService>();
    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: MerchantPremiumColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MerchantPremiumColors.line),
                ),
                child: const Icon(Icons.table_bar_rounded, color: MerchantPremiumColors.ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table.label,
                      style: const TextStyle(
                        color: MerchantPremiumColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [table.areaName, if (table.seats != null) texts.text('merchant.tables.seatsValue').replaceAll('{count}', table.seats.toString())].join(' | '),
                      style: const TextStyle(color: MerchantPremiumColors.muted, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: table.isActive ? texts.text('common.active') : texts.text('merchant.features.disabled')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showQr(context, table),
                  icon: const Icon(Icons.qr_code_rounded),
                  label: Text(texts.text('merchant.tables.showQr')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: texts.text('common.edit'),
                onPressed: () => _openTableSheet(context, table: table),
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(
                tooltip: table.isActive ? texts.text('common.deactivate') : texts.text('common.activate'),
                onPressed: () => provider.saveTable(
                  tableId: table.tableId,
                  areaId: table.areaId,
                  label: table.label,
                  seats: table.seats,
                  isActive: !table.isActive,
                ),
                icon: Icon(table.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

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
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Future<void> _openAreaSheet(BuildContext context, {TableAreaData? area}) async {
  final provider = context.read<MerchantTablesProvider>();
  final texts = context.read<LanguageService>();
  final name = TextEditingController(text: area?.name ?? '');
  final sortOrder = TextEditingController(text: (area?.sortOrder ?? provider.areas.length + 1).toString());
  var isActive = area?.isActive ?? true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(area == null ? texts.text('merchant.tables.addArea') : texts.text('merchant.tables.editArea'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: name, label: texts.text('common.name'), hint: texts.text('merchant.tables.areaHint')),
            const SizedBox(height: AppSpacing.md),
            MerchantTextField(controller: sortOrder, label: texts.text('common.sortOrder'), keyboardType: TextInputType.number),
            SwitchListTile(value: isActive, onChanged: (value) => setState(() => isActive = value), title: Text(texts.text('common.active'))),
            const SizedBox(height: AppSpacing.md),
            MerchantPrimaryButton(
              label: texts.text('common.save'),
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await provider.saveArea(
                  areaId: area?.areaId,
                  name: name.text,
                  sortOrder: int.tryParse(sortOrder.text.trim()) ?? provider.areas.length + 1,
                  isActive: isActive,
                );
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
            if (area != null)
              TextButton(
                onPressed: () async {
                  await provider.deleteArea(area.areaId);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                child: Text(texts.text('merchant.tables.deleteArea')),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _openTableSheet(BuildContext context, {TableData? table}) async {
  final provider = context.read<MerchantTablesProvider>();
  final texts = context.read<LanguageService>();
  if (provider.areas.isEmpty) return;
  final areaIdInitial = table?.areaId ?? (provider.selectedAreaId == 'all' ? provider.areas.first.areaId : provider.selectedAreaId);
  var areaId = provider.areas.any((area) => area.areaId == areaIdInitial) ? areaIdInitial : provider.areas.first.areaId;
  final label = TextEditingController(text: table?.label ?? '');
  final seats = TextEditingController(text: table?.seats?.toString() ?? '');
  var isActive = table?.isActive ?? true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(table == null ? texts.text('merchant.tables.addTable') : texts.text('merchant.tables.editTable'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: areaId,
                decoration: InputDecoration(labelText: texts.text('merchant.tables.area')),
                items: provider.areas.map((area) => DropdownMenuItem(value: area.areaId, child: Text(area.name))).toList(),
                onChanged: (value) => setState(() => areaId = value ?? areaId),
              ),
              const SizedBox(height: AppSpacing.md),
              MerchantTextField(controller: label, label: texts.text('merchant.tables.label'), hint: texts.text('merchant.tables.labelHint')),
              const SizedBox(height: AppSpacing.md),
              MerchantTextField(controller: seats, label: texts.text('merchant.tables.seats'), keyboardType: TextInputType.number),
              SwitchListTile(value: isActive, onChanged: (value) => setState(() => isActive = value), title: Text(texts.text('common.active'))),
              const SizedBox(height: AppSpacing.md),
              MerchantPrimaryButton(
                label: texts.text('common.save'),
                onPressed: () async {
                  if (label.text.trim().isEmpty) return;
                  await provider.saveTable(
                    tableId: table?.tableId,
                    areaId: areaId,
                    label: label.text,
                    seats: int.tryParse(seats.text.trim()),
                    isActive: isActive,
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
              if (table != null)
                TextButton(
                  onPressed: () async {
                    await provider.deleteTable(table.tableId);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  child: Text(texts.text('merchant.tables.deleteTable')),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showQr(BuildContext context, TableData table) {
  final texts = context.read<LanguageService>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(table.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.md),
          Center(child: QrImageView(data: table.qrUrl, size: 180, backgroundColor: AppColors.white)),
          const SizedBox(height: AppSpacing.md),
          SelectableText(table.qrUrl, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          MerchantPrimaryButton(
            label: texts.text('common.copyLink'),
            icon: Icons.copy_rounded,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: table.qrUrl));
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            texts.text('merchant.tables.publicLinkHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray500),
          ),
        ],
      ),
    ),
  );
}
