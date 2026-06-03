import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appSpacing.dart';
import '../models/display_device.dart';
import '../providers/display_studio_provider.dart';
import '../widgets/display_device_card.dart';
import '../widgets/display_device_details_sheet.dart';

class DisplayDevicesTab extends StatelessWidget {
  const DisplayDevicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DisplayStudioProvider>();
    final devices = provider.devices;

    if (devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.tv_rounded, color: AppColors.white, size: 34),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Noch keine Displays verbunden.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Öffne Lokka Display auf dem Fernseher und scanne den TV-QR-Code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.gray500, fontWeight: FontWeight.w600, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final device = devices[index];
        return DisplayDeviceCard(
          device: device,
          layouts: provider.layouts,
          onStop: () => provider.stopDevice(device.id),
          onUnlink: () => _confirmUnlink(context, provider, device.id, device.name),
          onRename: () => _showRename(context, provider, device.id, device.name),
          onDetails: () => _showDetails(context, device, provider),
          onStartLayout: (layout) => provider.startLayout(
            deviceId: device.id,
            layoutId: layout.id,
            layoutTitle: layout.title,
          ),
        );
      },
    );
  }

  void _confirmUnlink(
    BuildContext context,
    DisplayStudioProvider provider,
    String deviceId,
    String deviceName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.link_off_rounded, color: AppColors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Display entkoppeln?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '"$deviceName" wird getrennt und stoppt die Wiedergabe.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gray700, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      provider.unlinkDevice(deviceId);
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.black),
                    child: const Text('Entkoppeln'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(
      BuildContext context, DisplayDevice device, DisplayStudioProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => DisplayDeviceDetailsSheet(device: device, provider: provider),
    );
  }

  void _showRename(BuildContext context, DisplayStudioProvider provider,
      String deviceId, String current) {
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
            left: 22, right: 22, top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Display umbenennen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl, autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  provider.renameDevice(deviceId, ctrl.text.trim());
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
