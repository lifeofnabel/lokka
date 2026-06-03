import 'package:flutter/material.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../models/display_device.dart';
import '../providers/display_studio_provider.dart';

class DisplayDeviceDetailsSheet extends StatelessWidget {
  const DisplayDeviceDetailsSheet({
    super.key,
    required this.device,
    required this.provider,
  });

  final DisplayDevice device;
  final DisplayStudioProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.tv_rounded, color: AppColors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(device.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  _StatusBadge(status: device.status),
                ]),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Info grid
          _InfoGrid(device: device),
          const SizedBox(height: AppSpacing.lg),

          // Actions
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showRename(context);
                },
                icon: const Icon(Icons.drive_file_rename_outline_rounded, size: 16),
                label: const Text('Umbenennen'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  provider.stopDevice(device.id);
                },
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: const Text('Stoppen'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showUnlinkConfirm(context);
            },
            icon: const Icon(Icons.link_off_rounded, size: 16,
                color: Color(0xFFEF4444)),
            label: const Text('Entkoppeln',
                style: TextStyle(color: Color(0xFFEF4444))),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              side: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  void _showRename(BuildContext context) {
    final ctrl = TextEditingController(text: device.name);
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
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ctrl, autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  provider.renameDevice(device.id, ctrl.text.trim());
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

  void _showUnlinkConfirm(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(
                  color: AppColors.black, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.link_off_rounded, color: AppColors.white)),
            const SizedBox(height: AppSpacing.md),
            const Text('Display entkoppeln?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.sm),
            Text('"${device.name}" wird getrennt und stoppt die Wiedergabe.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gray700, height: 1.4)),
            const SizedBox(height: AppSpacing.lg),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen'),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  provider.unlinkDevice(device.id);
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.black),
                child: const Text('Entkoppeln'),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final DisplayDeviceStatus status;

  Color get _color {
    switch (status) {
      case DisplayDeviceStatus.playing: return const Color(0xFF22C55E);
      case DisplayDeviceStatus.online: return const Color(0xFF3B82F6);
      case DisplayDeviceStatus.offline: return AppColors.gray500;
      case DisplayDeviceStatus.stopped: return AppColors.gray500;
      case DisplayDeviceStatus.error: return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(status.label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _color)),
    ]);
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.device});
  final DisplayDevice device;

  String _fmt(DateTime? dt) {
    if (dt == null) return '–';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
    return 'vor ${diff.inDays} Tagen';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Column(
        children: [
          _Row('Aktives Layout', device.activeLayoutTitle.isEmpty ? '–' : device.activeLayoutTitle),
          _Row('Gerätetyp', device.deviceType),
          _Row('Ausrichtung', device.orientation == 'portrait' ? 'Hochformat' : 'Querformat'),
          if (device.screenSizeInch > 0)
            _Row('Bildschirm', '${device.screenSizeInch.toStringAsFixed(0)}"'),
          if (device.resolution.isNotEmpty)
            _Row('Auflösung', device.resolution),
          _Row('Letzter Sync', _fmt(device.lastSeenAt)),
          _Row('Verbunden seit', _fmt(device.pairedAt)),
          _Row('Verknüpft', device.isLinked ? 'Ja' : 'Nein'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.gray500, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
