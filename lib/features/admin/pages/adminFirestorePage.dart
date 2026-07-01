import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/adminDataService.dart';

/// Power-Tool: a generic Firestore browser/editor. Enter a path —
///   • collection (odd segments, e.g. `users`)      → lists document ids
///   • document  (even segments, e.g. `users/abc`)  → view + edit + delete
///
/// Editing is merge-based on JSON-native fields only (String/num/bool/list/map).
/// Timestamps, GeoPoints and references are shown read-only and left untouched
/// on save, so they can never be corrupted into strings.
class AdminFirestorePage extends StatefulWidget {
  const AdminFirestorePage({super.key, this.service, this.initialPath});

  final AdminDataService? service;
  final String? initialPath;

  @override
  State<AdminFirestorePage> createState() => _AdminFirestorePageState();
}

class _AdminFirestorePageState extends State<AdminFirestorePage> {
  late final AdminDataService _data = widget.service ?? AdminDataService();
  late final TextEditingController _pathCtrl =
      TextEditingController(text: widget.initialPath ?? '');
  final _editCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _loadedDocPath; // non-null when a document is loaded
  String _preview = '';
  List<String>? _collectionIds; // non-null when a collection is loaded
  // The editable (pure-JSON) fields as loaded — diffed on save so removing a key
  // from the JSON actually deletes the field (merge-set alone never can).
  Map<String, dynamic> _originalEditable = {};

  @override
  void initState() {
    super.initState();
    if ((widget.initialPath ?? '').isNotEmpty) _load();
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  bool _isDocPath(String path) {
    final segs = path.split('/').where((s) => s.isNotEmpty).toList();
    return segs.isNotEmpty && segs.length.isEven;
  }

  Future<void> _load() async {
    final path = _pathCtrl.text.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (path.isEmpty) {
      _snack('Pfad eingeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _loadedDocPath = null;
      _collectionIds = null;
      _preview = '';
    });
    try {
      if (_isDocPath(path)) {
        final data = await _data.getDoc(path);
        if (!mounted) return;
        if (data == null) {
          _editCtrl.text = '{\n  \n}';
          setState(() {
            _error = 'Dokument existiert nicht (Speichern legt es an).';
            _loadedDocPath = path;
            _originalEditable = {};
          });
        } else {
          final editable = _editable(data);
          _editCtrl.text = _pretty(editable);
          setState(() {
            _loadedDocPath = path;
            _preview = _pretty(_jsonSafe(data));
            _originalEditable = editable;
          });
        }
      } else {
        final ids = await _data.listCollection(path);
        if (!mounted) return;
        setState(() => _collectionIds = ids);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final path = _loadedDocPath;
    if (path == null) return;
    Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(_editCtrl.text);
      if (decoded is! Map) throw const FormatException('Kein JSON-Objekt.');
      parsed = Map<String, dynamic>.from(decoded);
    } catch (e) {
      _snack('Ungültiges JSON: $e');
      return;
    }
    // Mix in FieldValue.delete() for top-level fields the operator removed from
    // the editable JSON — a merge-set alone can never delete a field. (Nested-map
    // keys still can't be removed this way; use „Feld löschen" for those.)
    final update = <String, dynamic>{...parsed};
    for (final k in _originalEditable.keys) {
      if (!parsed.containsKey(k)) update[k] = FieldValue.delete();
    }
    setState(() => _busy = true);
    try {
      await _data.updateDoc(path, update);
      if (!mounted) return;
      _snack('Gespeichert.');
      await _load();
    } catch (e) {
      if (mounted) _snack('Fehler: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDoc() async {
    final path = _loadedDocPath;
    if (path == null) return;
    final ok = await _confirm('Dokument löschen?', path);
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _data.deleteDoc(path);
      if (!mounted) return;
      _snack('Gelöscht.');
      setState(() {
        _loadedDocPath = null;
        _preview = '';
        _editCtrl.clear();
        _originalEditable = {};
      });
    } catch (e) {
      if (mounted) _snack('Fehler: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteField() async {
    final path = _loadedDocPath;
    if (path == null) return;
    final field = await _prompt('Feld löschen', 'Feldname');
    if (field == null || field.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await _data.deleteField(path, field);
      if (!mounted) return;
      _snack('Feld „$field" gelöscht.');
      await _load();
    } catch (e) {
      if (mounted) _snack('Fehler: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Löschen')),
          ],
        ),
      );

  Future<String?> _prompt(String title, String label) async {
    final ctrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('OK')),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore-Editor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _pathCtrl,
            decoration: InputDecoration(
              labelText: 'Pfad (z. B. users  oder  merchants/<uid>)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: _busy ? null : _load,
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 8),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_collectionIds != null) _buildCollection(),
          if (_loadedDocPath != null) _buildDoc(),
        ],
      ),
    );
  }

  Widget _buildCollection() {
    final ids = _collectionIds!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('${ids.length} Dokumente',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (ids.isEmpty) const Text('Leer.'),
        for (final id in ids)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(id),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                _pathCtrl.text = '${_pathCtrl.text.replaceAll(RegExp(r'/+$'), '')}/$id';
                _load();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDoc() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(_loadedDocPath!, style: Theme.of(context).textTheme.titleSmall),
        if (_preview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Vorschau (read-only, inkl. Timestamps)',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(_preview,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ],
        const SizedBox(height: 12),
        Text('Bearbeitbare Felder (JSON, merge beim Speichern)',
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        TextField(
          controller: _editCtrl,
          maxLines: null,
          minLines: 6,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Speichern'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _deleteField,
              icon: const Icon(Icons.backspace_rounded, size: 18),
              label: const Text('Feld löschen'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _deleteDoc,
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Dokument löschen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _preview));
                _snack('Vorschau kopiert.');
              },
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('Kopieren'),
            ),
          ],
        ),
      ],
    );
  }
}

String _pretty(Object? v) => const JsonEncoder.withIndent('  ').convert(v);

/// Recursively converts Firestore types into JSON-displayable values (preview).
Object? _jsonSafe(Object? v) {
  if (v is Timestamp) return v.toDate().toIso8601String();
  if (v is GeoPoint) return {'lat': v.latitude, 'lng': v.longitude};
  if (v is DocumentReference) return '→ ${v.path}';
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), _jsonSafe(val)));
  }
  if (v is Iterable) return v.map(_jsonSafe).toList();
  return v;
}

/// True if a value is purely JSON-native (no Firestore-only types nested).
bool _isPureJson(Object? v) {
  if (v == null || v is String || v is num || v is bool) return true;
  if (v is Map) return v.values.every(_isPureJson);
  if (v is Iterable) return v.every(_isPureJson);
  return false;
}

/// Top-level fields that round-trip safely through JSON merge-save. Fields with
/// Timestamps/refs/etc. are omitted (shown in the preview, untouched on save).
Map<String, dynamic> _editable(Map<String, dynamic> data) {
  final out = <String, dynamic>{};
  data.forEach((k, v) {
    if (_isPureJson(v)) out[k] = v;
  });
  return out;
}
