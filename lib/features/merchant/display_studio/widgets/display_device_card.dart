import 'package:flutter/material.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../models/display_device.dart';
import '../models/display_layout.dart';

class DisplayDeviceCard extends StatelessWidget {
  const DisplayDeviceCard({
    super.key,
    required this.device,
    required this.layouts,
    required this.onStop,
    required this.onUnlink,
    required this.onStartLayout,
    required this.onRename,
    required this.onDetails,
  });

  final DisplayDevice device;
  final List<DisplayLayout> layouts;
  final VoidCallback onStop;
  final VoidCallback onUnlink;
  final VoidCallback onRename;
  final VoidCallback onDetails;
  final void Function(DisplayLayout layout) onStartLayout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, 0),
            child: Row(
              children: [
                _DeviceIcon(deviceType: device.deviceType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _StatusChip(status: device.status),
                    ],
                  ),
                ),
                _DeviceMenu(
                  device: device,
                  onUnlink: onUnlink,
                  onRename: onRename,
                  onDetails: onDetails,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Info grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (device.activeLayoutTitle.isNotEmpty)
                  _InfoChip(
                    icon: Icons.play_circle_outline_rounded,
                    label: device.activeLayoutTitle,
                  ),
                if (device.orientation.isNotEmpty)
                  _InfoChip(
                    icon: Icons.screen_rotation_rounded,
                    label: device.orientation == 'portrait' ? 'Hochformat' : 'Querformat',
                  ),
                if (device.screenSizeInch > 0)
                  _InfoChip(
                    icon: Icons.tv_rounded,
                    label: '${device.screenSizeInch.toStringAsFixed(0)}"',
                  ),
                if (device.lastSeenAt != null)
                  _InfoChip(
                    icon: Icons.access_time_rounded,
                    label: _relativeTime(device.lastSeenAt!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_rounded, size: 16),
                    label: const Text('Stoppen'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gray700,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: layouts.isEmpty
                        ? null
                        : () => _showLayoutPicker(context),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Wechseln'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: AppColors.white,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLayoutPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => _LayoutPickerSheet(
        layouts: layouts,
        currentLayoutId: device.activeLayoutId,
        onSelect: onStartLayout,
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'Gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
    return 'vor ${diff.inDays} Tagen';
  }
}

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.deviceType});
  final String deviceType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        deviceType == 'monitor' ? Icons.monitor_rounded : Icons.tv_rounded,
        color: AppColors.white,
        size: 22,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final DisplayDeviceStatus status;

  Color get _color {
    switch (status) {
      case DisplayDeviceStatus.playing:
        return const Color(0xFF22C55E);
      case DisplayDeviceStatus.online:
        return const Color(0xFF3B82F6);
      case DisplayDeviceStatus.offline:
        return AppColors.gray500;
      case DisplayDeviceStatus.stopped:
        return AppColors.gray500;
      case DisplayDeviceStatus.error:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          status.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gray500),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.gray700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceMenu extends StatelessWidget {
  const _DeviceMenu({
    required this.device,
    required this.onUnlink,
    required this.onRename,
    required this.onDetails,
  });
  final DisplayDevice device;
  final VoidCallback onUnlink;
  final VoidCallback onRename;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.gray500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'details') onDetails();
        if (value == 'rename') onRename();
        if (value == 'unlink') onUnlink();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'details',
            child: Row(children: [Icon(Icons.info_outline_rounded, size: 18), SizedBox(width: 10), Text('Details')])),
        PopupMenuItem(value: 'rename',
            child: Row(children: [Icon(Icons.drive_file_rename_outline_rounded, size: 18), SizedBox(width: 10), Text('Umbenennen')])),
        PopupMenuDivider(),
        PopupMenuItem(value: 'unlink',
            child: Row(children: [
              Icon(Icons.link_off_rounded, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('Entkoppeln', style: TextStyle(color: Color(0xFFEF4444))),
            ])),
      ],
    );
  }
}

class _LayoutPickerSheet extends StatelessWidget {
  const _LayoutPickerSheet({
    required this.layouts,
    required this.currentLayoutId,
    required this.onSelect,
  });

  final List<DisplayLayout> layouts;
  final String currentLayoutId;
  final void Function(DisplayLayout) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Layout wählen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.md),
          ...layouts.map(
            (layout) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(layout);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: layout.id == currentLayoutId
                        ? AppColors.black
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: layout.id == currentLayoutId
                          ? AppColors.black
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dashboard_rounded,
                        size: 18,
                        color: layout.id == currentLayoutId
                            ? AppColors.white
                            : AppColors.gray500,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          layout.title.isEmpty ? 'Ohne Titel' : layout.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: layout.id == currentLayoutId
                                ? AppColors.white
                                : AppColors.black,
                          ),
                        ),
                      ),
                      Text(
                        layout.type.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray500,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
