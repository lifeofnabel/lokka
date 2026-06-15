import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';

/// Ein Zeitfenster eines Tages, z. B. 09:00–18:00.
class OpeningSlot {
  const OpeningSlot(this.open, this.close);
  final String open; // "HH:mm"
  final String close; // "HH:mm"

  int get openMinutes => _toMinutes(open);
  int get closeMinutes {
    final m = _toMinutes(close);
    // "00:00" als Tagesende interpretieren.
    return m == 0 ? 24 * 60 : m;
  }

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }
}

class OpeningDay {
  const OpeningDay({
    required this.key,
    required this.label,
    required this.closed,
    required this.slots,
  });

  final String key;
  final String label;
  final bool closed;
  final List<OpeningSlot> slots;

  bool get isOpenAllDay => !closed && slots.isEmpty == false;
}

const _dayDefs = <(String, String)>[
  ('monday', 'Montag'),
  ('tuesday', 'Dienstag'),
  ('wednesday', 'Mittwoch'),
  ('thursday', 'Donnerstag'),
  ('friday', 'Freitag'),
  ('saturday', 'Samstag'),
  ('sunday', 'Sonntag'),
];

/// Geparste Öffnungszeiten + aktueller Status, berechnet aus der
/// `openingHours`-Map des publicMerchants-Docs.
class OpeningHoursInfo {
  OpeningHoursInfo._(this.days);

  final List<OpeningDay> days;

  bool get hasData => days.any((d) => !d.closed && d.slots.isNotEmpty);

  factory OpeningHoursInfo.fromMap(Map<String, dynamic>? map) {
    final days = <OpeningDay>[];
    for (final def in _dayDefs) {
      final raw = map?[def.$1];
      var closed = false;
      final slots = <OpeningSlot>[];
      if (raw is Map) {
        closed = raw['closed'] as bool? ?? false;
        final rawSlots = raw['slots'];
        if (rawSlots is Iterable) {
          for (final s in rawSlots) {
            if (s is Map) {
              final open = s['open']?.toString() ?? '';
              final close = s['close']?.toString() ?? '';
              if (open.isNotEmpty && close.isNotEmpty) {
                slots.add(OpeningSlot(open, close));
              }
            }
          }
        }
        if (slots.isEmpty) {
          final open = raw['open']?.toString() ?? '';
          final close = raw['close']?.toString() ?? '';
          if (open.isNotEmpty && close.isNotEmpty) {
            slots.add(OpeningSlot(open, close));
          }
        }
      }
      days.add(OpeningDay(
        key: def.$1,
        label: def.$2,
        closed: closed,
        slots: slots,
      ));
    }
    return OpeningHoursInfo._(days);
  }

  int get _todayIndex => DateTime.now().weekday - 1; // Mo=0 … So=6

  OpeningDay get today => days[_todayIndex];

  /// Status für die Anzeige: offen + bis wann / geschlossen + Öffnet wann.
  OpeningStatus get status {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final day = today;

    if (!day.closed) {
      for (final slot in day.slots) {
        if (nowMin >= slot.openMinutes && nowMin < slot.closeMinutes) {
          return OpeningStatus(open: true, until: slot.close);
        }
      }
      // Heute noch ein späteres Fenster?
      OpeningSlot? next;
      for (final slot in day.slots) {
        if (slot.openMinutes > nowMin) {
          if (next == null || slot.openMinutes < next.openMinutes) next = slot;
        }
      }
      if (next != null) {
        return OpeningStatus(open: false, opensAt: next.open);
      }
    }
    return const OpeningStatus(open: false);
  }
}

class OpeningStatus {
  const OpeningStatus({required this.open, this.until, this.opensAt});
  final bool open;
  final String? until; // wenn offen: Schließzeit
  final String? opensAt; // wenn zu, aber öffnet heute noch

  String get label {
    if (open) return until != null ? 'Geöffnet · bis $until' : 'Geöffnet';
    if (opensAt != null) return 'Geschlossen · öffnet $opensAt';
    return 'Geschlossen';
  }
}

/// Tippbares Status-Badge für die Partner-Seite.
class OpeningHoursBadge extends StatelessWidget {
  const OpeningHoursBadge({super.key, required this.hours});

  final Map<String, dynamic>? hours;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = OpeningHoursInfo.fromMap(hours);
    if (!info.hasData) return const SizedBox.shrink();
    final status = info.status;
    final dotColor = status.open ? cs.primary : cs.onSurfaceVariant;
    final fg = status.open ? cs.onSecondaryContainer : cs.onSurfaceVariant;

    return Material(
      color: status.open ? cs.secondaryContainer : AppColors.surfaceGray,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () => showOpeningHoursSheet(context, hours),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                status.label,
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showOpeningHoursSheet(
  BuildContext context,
  Map<String, dynamic>? hours,
) {
  final info = OpeningHoursInfo.fromMap(hours);
  final todayKey = info.today.key;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Öffnungszeiten',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final day in info.days)
                _OpeningRow(day: day, isToday: day.key == todayKey),
            ],
          ),
        ),
      );
    },
  );
}

class _OpeningRow extends StatelessWidget {
  const _OpeningRow({required this.day, required this.isToday});

  final OpeningDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isClosed = day.closed || day.slots.isEmpty;
    final value = isClosed
        ? 'Geschlossen'
        : day.slots.map((s) => '${s.open}–${s.close}').join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isToday ? cs.secondaryContainer : AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day.label,
              style: tt.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? cs.onSecondaryContainer : cs.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
              color: isClosed
                  ? cs.onSurfaceVariant
                  : (isToday ? cs.onSecondaryContainer : cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
