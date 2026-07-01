import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';

/// Opening-hours bottom sheet, shared by any wallet view that surfaces a
/// merchant's "Zeiten" action.
void showHoursSheet(BuildContext context, Map<String, dynamic> hours) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surfaceBg,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      child: _HoursSheet(hours: hours),
    ),
  );
}

/// Social-links bottom sheet, shared by any wallet view that surfaces a
/// merchant's "Social" action. [onOpen] receives the raw stored URL/handle.
void showSocialSheet(
  BuildContext context,
  Map<String, String> links,
  void Function(String url) onOpen,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surfaceBg,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      child: _SocialSheet(links: links, onOpen: onOpen),
    ),
  );
}

class _HoursSheet extends StatelessWidget {
  const _HoursSheet({required this.hours});

  final Map<String, dynamic> hours;

  static const _days = [
    ('monday', 'Montag'),
    ('tuesday', 'Dienstag'),
    ('wednesday', 'Mittwoch'),
    ('thursday', 'Donnerstag'),
    ('friday', 'Freitag'),
    ('saturday', 'Samstag'),
    ('sunday', 'Sonntag'),
  ];

  String _format(dynamic value) {
    if (value is Map) {
      if (value['closed'] == true) return 'Geschlossen';
      final open = value['open']?.toString();
      final close = value['close']?.toString();
      if (open != null && close != null) return '$open – $close';
      final slots = value['slots'];
      if (slots is List && slots.isNotEmpty) {
        return slots
            .whereType<Map>()
            .map((s) => '${s['open']} – ${s['close']}')
            .join(', ');
      }
    }
    return 'Geschlossen';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final todayIdx = DateTime.now().weekday - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Öffnungszeiten',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < _days.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Text(_days[i].$2,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight:
                          i == todayIdx ? FontWeight.w700 : FontWeight.w500,
                      color: i == todayIdx ? cs.primary : cs.onSurface,
                    )),
                const Spacer(),
                Text(_format(hours[_days[i].$1]),
                    style: tt.bodyMedium?.copyWith(
                      color: i == todayIdx ? cs.primary : cs.onSurfaceVariant,
                      fontWeight:
                          i == todayIdx ? FontWeight.w700 : FontWeight.w500,
                    )),
              ],
            ),
          ),
      ],
    );
  }
}

class _SocialSheet extends StatelessWidget {
  const _SocialSheet({required this.links, required this.onOpen});

  final Map<String, String> links;
  final void Function(String url) onOpen;

  static const _meta = <(String, String, IconData)>[
    ('website', 'Website', Icons.language_rounded),
    ('instagram', 'Instagram', Icons.camera_alt_rounded),
    ('tiktok', 'TikTok', Icons.music_note_rounded),
    ('facebook', 'Facebook', Icons.facebook),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Social Media',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        for (final (key, label, icon) in _meta)
          if ((links[key] ?? '').isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.onSecondaryContainer, size: 20),
              ),
              title: Text(label,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () {
                Navigator.pop(context);
                onOpen(links[key]!);
              },
            ),
      ],
    );
  }
}
