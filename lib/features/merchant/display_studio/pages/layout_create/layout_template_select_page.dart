import 'package:flutter/material.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../../data/display_templates_data.dart';
import '../../models/display_layout.dart';
import '../../models/display_template.dart';
import '../../services/display_studio_service.dart';
import 'layout_content_page.dart';

class LayoutTemplateSelectPage extends StatelessWidget {
  const LayoutTemplateSelectPage({super.key, required this.type, required this.service});

  final DisplayLayoutType type;
  final DisplayStudioService service;

  @override
  Widget build(BuildContext context) {
    final templates = DisplayTemplatesData.forType(type);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('${type.label} – Vorlage wählen',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _TemplateCard(
          template: templates[i],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LayoutContentPage(
                type: type,
                template: templates[i],
                service: service,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});

  final DisplayTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview area
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(template.icon, color: AppColors.white, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      template.name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${template.defaultBlocks.length} Blöcke',
                      style: const TextStyle(
                        color: Color(0xFF8A9A8A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(template.description,
                            style: const TextStyle(
                                color: AppColors.gray500,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.black,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Wählen',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
