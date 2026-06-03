import 'package:flutter/material.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../../models/display_layout.dart';
import '../../services/display_studio_service.dart';
import 'layout_template_select_page.dart';

class LayoutTypeSelectPage extends StatelessWidget {
  const LayoutTypeSelectPage({super.key, required this.service});

  final DisplayStudioService service;

  static const _types = [
    (DisplayLayoutType.deal, Icons.local_offer_rounded, 'Deal',
        'Angebote, Preise und Tagesaktionen.'),
    (DisplayLayoutType.menu, Icons.menu_book_rounded, 'Menü',
        'Artikel, Kategorien und Preise.'),
    (DisplayLayoutType.gallery, Icons.photo_library_rounded, 'Galerie',
        'Bilder vom Laden oder Atmosphäre.'),
    (DisplayLayoutType.qr, Icons.qr_code_2_rounded, 'QR Action',
        'QR-Code für Menü, Wallet, Coupon oder Profil.'),
    (DisplayLayoutType.loyalty, Icons.stars_rounded, 'Stempel & Punkte',
        'Sammelkarten, Punkte und Belohnungen.'),
    (DisplayLayoutType.feed, Icons.dynamic_feed_rounded, 'Beiträge',
        'Feed-Posts, Aktionen oder Social Wall.'),
    (DisplayLayoutType.orders, Icons.receipt_long_rounded, 'Bestellungen',
        'Küchen- und Bestellstatus.'),
    (DisplayLayoutType.free, Icons.crop_square_rounded, 'Freies Layout',
        'Eigene Inhalte ohne Vorlage.'),
    (DisplayLayoutType.review, Icons.format_quote_rounded, 'Review Wall',
        'Kundenfeedback und Bewertungen.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Typ wählen',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final (type, icon, label, desc) = _types[index];
          return _TypeCard(
            type: type,
            icon: icon,
            label: label,
            description: desc,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LayoutTemplateSelectPage(type: type, service: service),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final DisplayLayoutType type;
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.white, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(description,
                      style: const TextStyle(
                          color: AppColors.gray500, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppColors.gray300),
          ],
        ),
      ),
    );
  }
}
