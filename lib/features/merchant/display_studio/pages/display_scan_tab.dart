import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appSpacing.dart';
import '../providers/display_studio_provider.dart';
import 'scanner/display_scanner_page.dart';

class DisplayScanTab extends StatelessWidget {
  const DisplayScanTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DisplayStudioProvider>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                  color: AppColors.black, borderRadius: BorderRadius.circular(28)),
              child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.white, size: 44),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('TV-QR scannen',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Öffne Lokka Display auf dem Fernseher und scanne den QR-Code, um das Display zu verbinden.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w600, height: 1.5),
            ),
            const SizedBox(height: 10),
            const Text(
              'Der QR-Code am Fernseher wechselt regelmäßig.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray300, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DisplayScannerPage(service: provider.service),
                ),
              ),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Scanner öffnen'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
