import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Lädt ein Legal-Dokument (AGB / Datenschutz) aus assets/legal/*.json und
/// zeigt es in einem hellen Material-3-Sheet. Backend-frei, rein lokal.
Future<void> showLegalSheet(BuildContext context, String asset) async {
  Map<String, dynamic>? data;
  try {
    final raw = await rootBundle.loadString(asset);
    data = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    data = null;
  }
  if (!context.mounted) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LegalSheet(data: data),
  );
}

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({this.data});

  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final d = data;

    if (d == null) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Dokument konnte nicht geladen werden.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final sections = (d['sections'] as List?) ?? const [];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => SafeArea(
        top: false,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            Text((d['title'] ?? '').toString(), style: tt.headlineSmall),
            if ((d['updated'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Stand: ${d['updated']}',
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if ((d['intro'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  // Theme-adaptiv (hell im User-Flow, dunkel im Merchant-Flow) –
                  // vorher fix hellgrau → weißer Kasten mit hellem Text auf Dark.
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  d['intro'].toString(),
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                ),
              ),
            ],
            const SizedBox(height: 18),
            ...sections.map((s) {
              final m = s as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((m['heading'] ?? '').toString(),
                        style: tt.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      (m['body'] ?? '').toString(),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        ),
      ),
    );
  }
}
