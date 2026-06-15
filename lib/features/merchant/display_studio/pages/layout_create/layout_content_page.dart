import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // needed for ChangeNotifierProvider in _proceed

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../../models/display_layout.dart';
import '../../models/display_template.dart';
import '../../providers/layout_editor_provider.dart';
import '../../services/display_studio_service.dart';
import '../layout_editor/display_layout_editor_page.dart';

class LayoutContentPage extends StatefulWidget {
  const LayoutContentPage({
    super.key,
    required this.type,
    required this.template,
    required this.service,
  });

  final DisplayLayoutType type;
  final DisplayTemplate template;
  final DisplayStudioService service;

  @override
  State<LayoutContentPage> createState() => _LayoutContentPageState();
}

class _LayoutContentPageState extends State<LayoutContentPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Common fields
  final _titleCtrl = TextEditingController();
  DisplayOrientation _orientation = DisplayOrientation.landscape;
  String _screenSize = 'mittel';
  String _mode = 'day';
  String _animation = 'fade';

  // Type-specific controllers
  final _subtitleCtrl = TextEditingController();
  final _menuTitleCtrl = TextEditingController(); // eigener Titel für Menü (#10)
  final _priceCtrl = TextEditingController();
  final _oldPriceCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _qrTargetType = 'shop';
  bool _qrEnabled = true;
  String _ordersMode = 'kitchen';
  final List<Map<String, String>> _menuItems = [];

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _subtitleCtrl, _menuTitleCtrl, _priceCtrl, _oldPriceCtrl,
      _badgeCtrl, _textCtrl, _rewardCtrl, _descCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('${widget.type.label} – Inhalt',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _Section('Grundeinstellungen', [
              _Field('Layout-Titel (intern)', _titleCtrl, required: true),
              const SizedBox(height: AppSpacing.md),
              _SegmentRow<DisplayOrientation>(
                label: 'Ausrichtung',
                options: {
                  DisplayOrientation.landscape: 'Querformat',
                  DisplayOrientation.portrait: 'Hochformat',
                },
                selected: _orientation,
                onSelect: (v) => setState(() => _orientation = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SegmentRow<String>(
                label: 'Größe',
                options: const {
                  'klein': 'Klein',
                  'mittel': 'Mittel',
                  'groß': 'Groß',
                  '4K': '4K',
                },
                selected: _screenSize,
                onSelect: (v) => setState(() => _screenSize = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SegmentRow<String>(
                label: 'Modus',
                options: const {'day': 'Tag', 'night': 'Nacht'},
                selected: _mode,
                onSelect: (v) => setState(() => _mode = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SegmentRow<String>(
                label: 'Animation',
                options: const {
                  'fade': 'Fade',
                  'slide': 'Slide',
                  'softZoom': 'Soft Zoom',
                  'cardSwitch': 'Card Switch',
                },
                selected: _animation,
                onSelect: (v) => setState(() => _animation = v),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            ..._typeFields(),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _isSaving ? null : _proceed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                    )
                  : const Text('Weiter zum Editor',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Type-specific form fields ─────────────────────────────────────────────

  List<Widget> _typeFields() {
    switch (widget.type) {
      case DisplayLayoutType.deal:
        return [
          _Section('Deal-Inhalt', [
            _Field('Titel des Angebots', _textCtrl),
            const SizedBox(height: 10),
            _Field('Untertitel (optional)', _subtitleCtrl),
            const SizedBox(height: 10),
            _Field('Preis', _priceCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _Field('Alter Preis (optional)', _oldPriceCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _Field('Badge-Text (z.B. TOP DEAL)', _badgeCtrl),
          ]),
        ];

      case DisplayLayoutType.menu:
        return [
          _Section('Menü-Inhalt', [
            _Field('Kategorie / Titel', _menuTitleCtrl),
            const SizedBox(height: 10),
            _MenuItemsEditor(
              items: _menuItems,
              onChanged: (items) => setState(() {
                _menuItems.clear();
                _menuItems.addAll(items);
              }),
            ),
          ]),
        ];

      case DisplayLayoutType.gallery:
        return [
          _Section('Galerie', [
            _Field('Titel (optional)', _textCtrl),
          ]),
        ];

      case DisplayLayoutType.qr:
        return [
          _Section('QR-Code', [
            _Field('Titel', _textCtrl),
            const SizedBox(height: 10),
            _Field('Benefit-Text (z.B. Gratis Kaffee)', _subtitleCtrl),
            const SizedBox(height: 12),
            _DropField<String>(
              label: 'Ziel',
              value: _qrTargetType,
              options: const {
                'shop': 'Shop-Profil',
                'menu': 'Menü',
                'wallet': 'Wallet / Karte',
                'coupon': 'Gutschein',
                'review': 'Bewertung',
              },
              onChanged: (v) => setState(() => _qrTargetType = v!),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Expanded(child: Text('QR anzeigen', style: TextStyle(fontWeight: FontWeight.w700))),
              Switch(
                value: _qrEnabled,
                activeThumbColor: AppColors.black,
                onChanged: (v) => setState(() => _qrEnabled = v),
              ),
            ]),
          ]),
        ];

      case DisplayLayoutType.loyalty:
        return [
          _Section('Loyalty', [
            _Field('Titel', _textCtrl),
            const SizedBox(height: 10),
            _Field('Beschreibung', _descCtrl, maxLines: 3),
            const SizedBox(height: 10),
            _Field('Belohnungstext (z.B. 10 Stempel = 1 Kaffee gratis)', _rewardCtrl),
          ]),
        ];

      case DisplayLayoutType.feed:
        return [
          _Section('Beiträge', [
            _Field('Titel', _textCtrl),
            const SizedBox(height: 6),
            const Text(
              'Feed-Posts werden nach dem Speichern im Editor verknüpft.',
              style: TextStyle(color: AppColors.gray500, fontSize: 13),
            ),
          ]),
        ];

      case DisplayLayoutType.orders:
        return [
          _Section('Bestellungen', [
            _Field('Titel', _textCtrl),
            const SizedBox(height: 12),
            _DropField<String>(
              label: 'Modus',
              value: _ordersMode,
              options: const {
                'kitchen': 'Küche',
                'pickup': 'Abholung',
                'status': 'Status',
              },
              onChanged: (v) => setState(() => _ordersMode = v!),
            ),
          ]),
        ];

      case DisplayLayoutType.free:
        return [
          _Section('Freies Layout', [
            _Field('Haupttext', _textCtrl, maxLines: 4),
          ]),
        ];

      case DisplayLayoutType.review:
        return [
          _Section('Bewertung', [
            _Field('Bewertungstext', _textCtrl, maxLines: 4),
            const SizedBox(height: 10),
            _Field('Name (optional)', _subtitleCtrl),
          ]),
        ];
    }
  }

  // ── Build layout from form ────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildBlocks() {
    // Start from template blocks
    final blocks = widget.template.defaultBlocks
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    // Inject user input into corresponding blocks
    void updateBlockValue(String type, Map<String, dynamic> updates) {
      for (final b in blocks) {
        if (b['type'] == type) {
          final v = Map<String, dynamic>.from(b['value'] as Map? ?? {});
          v.addAll(updates);
          b['value'] = v;
          break;
        }
      }
    }

    // Aktualisiert den (skip+1)-ten Block eines Typs – z. B. den 2. text-Block
    // (Untertitel). Gibt false zurück, wenn es so viele Blöcke nicht gibt (#11).
    bool updateBlockValueAt(String type, int skip, Map<String, dynamic> updates) {
      var seen = 0;
      for (final b in blocks) {
        if (b['type'] == type) {
          if (seen == skip) {
            final v = Map<String, dynamic>.from(b['value'] as Map? ?? {});
            v.addAll(updates);
            b['value'] = v;
            return true;
          }
          seen++;
        }
      }
      return false;
    }

    switch (widget.type) {
      case DisplayLayoutType.deal:
        updateBlockValue('text', {'content': _textCtrl.text});
        // Untertitel → 2. text-Block, falls vorhanden (deal_splitimage); sonst
        // neuen text-Block anhängen (deal_bigprice hat nur einen), damit die
        // Eingabe in KEINEM Deal-Template verloren geht (#11).
        if (_subtitleCtrl.text.trim().isNotEmpty) {
          final subtitle = _subtitleCtrl.text.trim();
          final written = updateBlockValueAt('text', 1, {'content': subtitle});
          if (!written) {
            blocks.add({
              'type': 'text',
              'order': blocks.length,
              'isVisible': true,
              'value': {
                'content': subtitle,
                'fontSize': 14.0,
                'fontWeight': 'normal',
                'color': '#CCCCCC',
                'alignment': 'left',
              },
              'sourceType': 'manual',
              'sourceId': '',
              'style': const <String, dynamic>{},
            });
          }
        }
        updateBlockValue('price', {
          'price': _priceCtrl.text,
          'oldPrice': _oldPriceCtrl.text,
        });
        updateBlockValue('badge', {'text': _badgeCtrl.text});
        break;

      case DisplayLayoutType.menu:
        updateBlockValue('text', {'content': _menuTitleCtrl.text});
        updateBlockValue('menuList', {
          'items': _menuItems
              .map((item) => {'name': item['name'], 'price': item['price']})
              .toList(),
        });
        break;

      case DisplayLayoutType.gallery:
        updateBlockValue('text', {'content': _textCtrl.text});
        break;

      case DisplayLayoutType.qr:
        updateBlockValue('text', {'content': _textCtrl.text});
        updateBlockValue('qr', {
          'targetType': _qrTargetType,
          'showLabel': _qrEnabled,
          // Benefit-Text → echtes qr-Label (#11); leer = Template-Default behalten.
          if (_subtitleCtrl.text.trim().isNotEmpty) 'label': _subtitleCtrl.text.trim(),
        });
        break;

      case DisplayLayoutType.loyalty:
        updateBlockValue('loyalty', {
          'title': _textCtrl.text,
          'description': _descCtrl.text,
          'rewardText': _rewardCtrl.text,
        });
        break;

      case DisplayLayoutType.feed:
        updateBlockValue('text', {'content': _textCtrl.text});
        break;

      case DisplayLayoutType.orders:
        updateBlockValue('text', {'content': _textCtrl.text});
        break;

      case DisplayLayoutType.free:
        updateBlockValue('text', {'content': _textCtrl.text});
        break;

      case DisplayLayoutType.review:
        updateBlockValue('review', {
          'text': _textCtrl.text,
          'authorName': _subtitleCtrl.text,
        });
        break;
    }

    // Assign fresh IDs
    final rng = Random();
    for (final b in blocks) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      b['id'] = '${ts.toRadixString(16)}${rng.nextInt(0xFFFF).toRadixString(16)}';
    }

    return blocks;
  }

  Future<void> _proceed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_titleCtrl.text.isEmpty) {
      // Use type as default title if field is empty (menu uses other ctrl)
      _titleCtrl.text = widget.type.label;
    }

    setState(() => _isSaving = true);

    final service = widget.service;

    final layout = DisplayLayout(
      id: '',
      title: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : widget.type.label,
      type: widget.type,
      orientation: _orientation,
      screenSizeTarget: _screenSize,
      mode: _mode,
      templateId: widget.template.id,
      coverUrl: '',
      blocks: _buildBlocks(),
      animation: _animation,
      tags: [],
      isDraft: true,
      backgroundStyle: 'dark',
      lastUsedAt: null,
      createdAt: null,
      updatedAt: null,
    );

    final String newId;
    try {
      newId = await service.createLayout(layout);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    final saved = await service.getLayoutById(newId);
    if (!mounted || saved == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => LayoutEditorProvider(service: service, initial: saved),
          child: const DisplayLayoutEditorPage(),
        ),
      ),
    );

    if (mounted) {
      // Pop ContentPage + TemplateSelectPage + TypeSelectPage → back to DisplayStudio
      var pops = 0;
      Navigator.of(context).popUntil((_) => pops++ >= 3);
    }
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gray500)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.controller,
      {this.maxLines = 1, this.keyboardType, this.required = false});
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Pflichtfeld' : null
          : null,
    );
  }
}

class _DropField<T> extends StatelessWidget {
  const _DropField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final T value;
  final Map<T, String> options;
  final void Function(T?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _SegmentRow<T> extends StatelessWidget {
  const _SegmentRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });
  final String label;
  final Map<T, String> options;
  final T selected;
  final void Function(T) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gray500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options.entries.map((e) {
            final isSelected = e.key == selected;
            return GestureDetector(
              onTap: () => onSelect(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.black : AppColors.gray50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppColors.white : AppColors.gray700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MenuItemsEditor extends StatefulWidget {
  const _MenuItemsEditor({required this.items, required this.onChanged});
  final List<Map<String, String>> items;
  final void Function(List<Map<String, String>>) onChanged;
  @override
  State<_MenuItemsEditor> createState() => _MenuItemsEditorState();
}

class _MenuItemsEditorState extends State<_MenuItemsEditor> {
  late List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Menüpunkte',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gray500)),
        const SizedBox(height: 8),
        ..._items.asMap().entries.map((e) {
          final i = e.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: _items[i]['name'],
                  decoration: InputDecoration(
                    hintText: 'Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) { _items[i]['name'] = v; widget.onChanged(_items); },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: _items[i]['price'],
                  decoration: InputDecoration(
                    hintText: 'Preis',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) { _items[i]['price'] = v; widget.onChanged(_items); },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 20),
                onPressed: () {
                  setState(() => _items.removeAt(i));
                  widget.onChanged(_items);
                },
              ),
            ]),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() => _items.add({'name': '', 'price': ''}));
            widget.onChanged(_items);
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Eintrag hinzufügen'),
          style: TextButton.styleFrom(foregroundColor: AppColors.black),
        ),
      ],
    );
  }
}
