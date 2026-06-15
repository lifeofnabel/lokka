import 'package:flutter/material.dart';

import '../../../../core/theme/appColors.dart';
import '../../../../core/theme/appSpacing.dart';
import '../models/display_block.dart';

/// Bottom sheet for editing a single block's value map.
class BlockEditSheet extends StatefulWidget {
  const BlockEditSheet({
    super.key,
    required this.block,
    required this.onSave,
    required this.onDelete,
  });

  final DisplayBlock block;
  final void Function(Map<String, dynamic> newValue) onSave;
  final VoidCallback onDelete;

  @override
  State<BlockEditSheet> createState() => _BlockEditSheetState();
}

class _BlockEditSheetState extends State<BlockEditSheet> {
  late Map<String, dynamic> _value;

  @override
  void initState() {
    super.initState();
    _value = Map<String, dynamic>.from(widget.block.value);
  }

  void _set(String key, dynamic value) => setState(() => _value[key] = value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.block.type.label,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDelete();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._buildFields(),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              widget.onSave(_value);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.black,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Übernehmen', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFields() {
    switch (widget.block.type) {
      case DisplayBlockType.text:
        return [
          _TextRow('Inhalt', _value['content'] ?? '', (v) => _set('content', v), maxLines: 4),
          _DropRow('Ausrichtung', _value['alignment'] ?? 'center',
              const {'center': 'Zentriert', 'left': 'Links', 'right': 'Rechts'},
              (v) => _set('alignment', v)),
          _SliderRow('Schriftgröße', (_value['fontSize'] as num?)?.toDouble() ?? 20.0,
              8, 60, (v) => _set('fontSize', v)),
          _DropRow('Gewicht', _value['fontWeight'] ?? 'bold',
              const {'normal': 'Normal', 'bold': 'Fett', 'black': 'Extra Fett'},
              (v) => _set('fontWeight', v)),
          _ColorRow('Farbe', _value['color'] ?? '#FFFFFF', (v) => _set('color', v)),
        ];

      case DisplayBlockType.price:
        return [
          _TextRow('Preis', _value['price'] ?? '', (v) => _set('price', v)),
          _TextRow('Alter Preis (optional)', _value['oldPrice'] ?? '', (v) => _set('oldPrice', v)),
          _DropRow('Währung', _value['currency'] ?? '€',
              {'€': '€ Euro', '\$': '\$ Dollar', 'CHF': 'CHF Franken'},
              (v) => _set('currency', v)),
        ];

      case DisplayBlockType.image:
        return [
          _TextRow('Bild-URL', _value['url'] ?? '', (v) => _set('url', v)),
          _DropRow('Darstellung', _value['fit'] ?? 'cover',
              const {'cover': 'Ausfüllend', 'contain': 'Einpassen', 'fill': 'Strecken'},
              (v) => _set('fit', v)),
        ];

      case DisplayBlockType.qr:
        return [
          _DropRow('Ziel', _value['targetType'] ?? 'shop',
              const {
                'shop': 'Shop-Profil',
                'menu': 'Menü',
                'wallet': 'Wallet / Karte',
                'coupon': 'Gutschein',
                'review': 'Bewertung',
              },
              (v) => _set('targetType', v)),
          _TextRow('Label', _value['label'] ?? 'Scannen', (v) => _set('label', v)),
          _SwitchRow(
              'Label anzeigen',
              _value['showLabel'] as bool? ?? true,
              (v) => _set('showLabel', v)),
        ];

      case DisplayBlockType.badge:
        return [
          _TextRow('Text', _value['text'] ?? '', (v) => _set('text', v)),
          _ColorRow('Hintergrund', _value['backgroundColor'] ?? '#FF3B30',
              (v) => _set('backgroundColor', v)),
          _ColorRow('Textfarbe', _value['textColor'] ?? '#FFFFFF',
              (v) => _set('textColor', v)),
        ];

      case DisplayBlockType.menuList:
        return [_MenuListEditor(
          items: (_value['items'] as List?)
                  ?.whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList() ??
              [],
          onChanged: (items) => _set('items', items),
        )];

      case DisplayBlockType.gallery:
        return [
          _TextRow(
            'Bild-URLs (kommagetrennt)',
            (_value['urls'] as List? ?? []).join(', '),
            (v) {
              final urls = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              _set('urls', urls);
            },
            maxLines: 4,
          ),
          _SliderRow('Anzeigedauer (Sek)', (_value['durationSeconds'] as num?)?.toDouble() ?? 4,
              2, 15, (v) => _set('durationSeconds', v.toInt())),
          _DropRow('Effekt', _value['effect'] ?? 'fade',
              const {'fade': 'Fade', 'slide': 'Slide'},
              (v) => _set('effect', v)),
        ];

      case DisplayBlockType.loyalty:
        return [
          _TextRow('Titel', _value['title'] ?? '', (v) => _set('title', v)),
          _TextRow('Beschreibung', _value['description'] ?? '', (v) => _set('description', v)),
          _TextRow('Belohnung', _value['rewardText'] ?? '', (v) => _set('rewardText', v)),
          _SwitchRow('QR anzeigen', _value['showQr'] as bool? ?? false, (v) => _set('showQr', v)),
        ];

      case DisplayBlockType.review:
        return [
          _TextRow('Bewertungstext', _value['text'] ?? '', (v) => _set('text', v), maxLines: 4),
          _TextRow('Name', _value['authorName'] ?? '', (v) => _set('authorName', v)),
          _SliderRow('Sterne', (_value['rating'] as num?)?.toDouble() ?? 5, 1, 5,
              (v) => _set('rating', v.toInt())),
          _TextRow('Quelle (optional)', _value['source'] ?? '', (v) => _set('source', v)),
        ];

      case DisplayBlockType.divider:
        return [
          _SliderRow('Deckkraft', (_value['opacity'] as num?)?.toDouble() ?? 0.3, 0.05, 1.0,
              (v) => _set('opacity', v)),
        ];

      case DisplayBlockType.spacer:
        return [
          _SliderRow('Höhe (px)', (_value['height'] as num?)?.toDouble() ?? 16, 4, 80,
              (v) => _set('height', v)),
        ];
    }
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _TextRow extends StatefulWidget {
  const _TextRow(this.label, this.initial, this.onChange, {this.maxLines = 1});
  final String label;
  final String initial;
  final void Function(String) onChange;
  final int maxLines;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
    _ctrl.addListener(() => widget.onChange(_ctrl.text));
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _ctrl,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}

class _DropRow extends StatelessWidget {
  const _DropRow(this.label, this.value, this.options, this.onChange);
  final String label;
  final String value;
  final Map<String, String> options;
  final void Function(String) onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: options.containsKey(value) ? value : options.keys.first,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        items: options.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) { if (v != null) onChange(v); },
      ),
    );
  }
}

class _SliderRow extends StatefulWidget {
  const _SliderRow(this.label, this.initial, this.min, this.max, this.onChange);
  final String label;
  final double initial;
  final double min;
  final double max;
  final void Function(double) onChange;
  @override
  State<_SliderRow> createState() => _SliderRowState();
}
class _SliderRowState extends State<_SliderRow> {
  late double _val;
  @override void initState() { super.initState(); _val = widget.initial.clamp(widget.min, widget.max); }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(widget.label, style: const TextStyle(fontSize: 12, color: AppColors.gray700, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(_val.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
          Slider(
            value: _val,
            min: widget.min,
            max: widget.max,
            activeColor: AppColors.black,
            onChanged: (v) { setState(() => _val = v); widget.onChange(v); },
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatefulWidget {
  const _SwitchRow(this.label, this.initial, this.onChange);
  final String label;
  final bool initial;
  final void Function(bool) onChange;
  @override State<_SwitchRow> createState() => _SwitchRowState();
}
class _SwitchRowState extends State<_SwitchRow> {
  late bool _val;
  @override void initState() { super.initState(); _val = widget.initial; }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Switch(
            value: _val,
            activeThumbColor: AppColors.black,
            onChanged: (v) { setState(() => _val = v); widget.onChange(v); },
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow(this.label, this.value, this.onChange);
  final String label;
  final String value;
  final void Function(String) onChange;
  @override
  Widget build(BuildContext context) {
    // Simplified: just a text field for hex color
    return _TextRow('$label (HEX)', value, onChange);
  }
}

class _MenuListEditor extends StatefulWidget {
  const _MenuListEditor({required this.items, required this.onChanged});
  final List<Map<String, dynamic>> items;
  final void Function(List<Map<String, dynamic>>) onChanged;
  @override State<_MenuListEditor> createState() => _MenuListEditorState();
}
class _MenuListEditorState extends State<_MenuListEditor> {
  late List<Map<String, dynamic>> _items;
  @override void initState() { super.initState(); _items = List.from(widget.items); }

  void _add() {
    setState(() => _items.add({'name': '', 'price': ''}));
    widget.onChanged(_items);
  }
  void _remove(int i) {
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Einträge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gray500)),
        const SizedBox(height: 6),
        ..._items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item['name'] ?? '',
                    decoration: InputDecoration(
                      hintText: 'Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _items[i]['name'] = v;
                      widget.onChanged(_items);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item['price'] ?? '',
                    decoration: InputDecoration(
                      hintText: 'Preis',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _items[i]['price'] = v;
                      widget.onChanged(_items);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  onPressed: () => _remove(i),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Eintrag hinzufügen'),
          style: TextButton.styleFrom(foregroundColor: AppColors.black),
        ),
      ],
    );
  }
}
