import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appSpacing.dart';

class PartnerFilterBar extends StatelessWidget {
  const PartnerFilterBar({
    super.key,
    required this.options,
    this.selected,
    required this.onSelected,
    this.label = 'Alle',
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final allOptions = [null, ...options];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: allOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final value = allOptions[i];
          final isSelected = value == selected;
          return Center(
            child: FilterChip(
              label: Text(value ?? label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(isSelected ? null : value),
            ),
          );
        },
      ),
    );
  }
}
