import 'package:flutter/material.dart';

import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../models/display_layout.dart';

class LayoutFilterSheet extends StatefulWidget {
  const LayoutFilterSheet({
    super.key,
    this.initialOrientation,
    this.initialScreenSize,
    this.initialMode,
    this.initialType,
    required this.onApply,
    required this.onClear,
  });

  final String? initialOrientation;
  final String? initialScreenSize;
  final String? initialMode;
  final String? initialType;
  final void Function({
    String? orientation,
    String? screenSize,
    String? mode,
    String? type,
  }) onApply;
  final VoidCallback onClear;

  @override
  State<LayoutFilterSheet> createState() => _LayoutFilterSheetState();
}

class _LayoutFilterSheetState extends State<LayoutFilterSheet> {
  String? _orientation;
  String? _screenSize;
  String? _mode;
  String? _type;

  @override
  void initState() {
    super.initState();
    _orientation = widget.initialOrientation;
    _screenSize = widget.initialScreenSize;
    _mode = widget.initialMode;
    _type = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _orientation = null;
                    _screenSize = null;
                    _mode = null;
                    _type = null;
                  });
                  widget.onClear();
                  Navigator.of(context).pop();
                },
                child: const Text('Zurücksetzen'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _FilterSection(
            title: 'Ausrichtung',
            options: const [
              ('landscape', 'Querformat'),
              ('portrait', 'Hochformat'),
            ],
            selected: _orientation,
            onSelect: (v) => setState(() => _orientation = v == _orientation ? null : v),
          ),
          const SizedBox(height: AppSpacing.md),
          _FilterSection(
            title: 'Display-Größe',
            options: const [
              ('klein', 'Klein'),
              ('mittel', 'Mittel'),
              ('groß', 'Groß'),
              ('4K', '4K'),
            ],
            selected: _screenSize,
            onSelect: (v) => setState(() => _screenSize = v == _screenSize ? null : v),
          ),
          const SizedBox(height: AppSpacing.md),
          _FilterSection(
            title: 'Modus',
            options: const [
              ('day', 'Tag'),
              ('night', 'Nacht'),
            ],
            selected: _mode,
            onSelect: (v) => setState(() => _mode = v == _mode ? null : v),
          ),
          const SizedBox(height: AppSpacing.md),
          _FilterSection(
            title: 'Typ',
            options: DisplayLayoutType.values
                .map((t) => (t.name, t.label))
                .toList(),
            selected: _type,
            onSelect: (v) => setState(() => _type = v == _type ? null : v),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () {
              widget.onApply(
                orientation: _orientation,
                screenSize: _screenSize,
                mode: _mode,
                type: _type,
              );
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.black,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
            child: const Text('Anwenden', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<(String, String)> options;
  final String? selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gray500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((opt) {
            final isSelected = selected == opt.$1;
            return GestureDetector(
              onTap: () => onSelect(opt.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.black : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(
                    color: isSelected ? AppColors.black : AppColors.border,
                  ),
                ),
                child: Text(
                  opt.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
