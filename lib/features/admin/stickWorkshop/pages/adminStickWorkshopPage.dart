import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../stamps/services/appLinkBase.dart';
import '../../services/adminService.dart';
import '../services/fileDownload.dart';
import '../services/stickArtifacts.dart';

/// Godmode → Stift-Werkstatt. Centrally mass-produces UNBOUND sticks:
///   • Link-Stifte (Path A): mint N sticks → claim QR `lokka-stick-a:…`.
///   • Sicher-Chips (Path B): derive chip keys + provToken QR `lokka-stick:…`.
/// Plus an inventory register. Merchants bind the sticks themselves later.
class AdminStickWorkshopPage extends StatefulWidget {
  const AdminStickWorkshopPage({super.key, this.service});

  final AdminService? service;

  @override
  State<AdminStickWorkshopPage> createState() => _AdminStickWorkshopPageState();
}

class _AdminStickWorkshopPageState extends State<AdminStickWorkshopPage> {
  late final AdminService _admin = widget.service ?? AdminService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stift-Werkstatt'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Erzeugen', icon: Icon(Icons.add_circle_outline_rounded)),
              Tab(text: 'Inventar', icon: Icon(Icons.inventory_2_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CreateTab(admin: _admin),
            _InventoryTab(admin: _admin),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Erzeugen ──────────────────────────────────────────────────────────
class _CreateTab extends StatefulWidget {
  const _CreateTab({required this.admin});
  final AdminService admin;

  @override
  State<_CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends State<_CreateTab> {
  final _countCtrl = TextEditingController(text: '5');
  final _noteCtrl = TextEditingController();

  bool _mintingA = false;
  List<MintedStick> _minted = const [];

  @override
  void dispose() {
    _countCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _mint() async {
    final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (count < 1 || count > 100) {
      _snack('Anzahl 1–100 eingeben.');
      return;
    }
    setState(() => _mintingA = true);
    try {
      final sticks = await widget.admin
          .mintStaticSticks(count: count, note: _noteCtrl.text.trim());
      if (!mounted) return;
      setState(() => _minted = sticks);
    } catch (e) {
      _snack(adminErrorMessage(e));
    } finally {
      if (mounted) setState(() => _mintingA = false);
    }
  }

  Future<void> _downloadAllPdf() async {
    if (!downloadSupported) {
      _snack('PDF-Export nur im Web verfügbar.');
      return;
    }
    _snack('PDF wird erzeugt …');
    try {
      final items = <StickPrintItem>[];
      for (final s in _minted) {
        items.add(StickPrintItem(
          png: await qrPng(s.code, module: 360),
          title: s.stickId,
          sub: 'Link-Stift • zum Binden scannen',
        ));
      }
      final bytes = await sticksPdf(items);
      downloadBytes(bytes, 'lokka-link-stifte.pdf', 'application/pdf');
    } catch (e) {
      _snack('PDF fehlgeschlagen: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        // ── Path A ──────────────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.link_rounded,
          title: 'Stifte erzeugen',
          subtitle:
              'Pro Stift entstehen zwei Dinge: der NFC-Link (du schreibst ihn '
              'einmal auf den Chip) und der Binde-QR (liegt dem Stift bei — der '
              'Händler scannt ihn auf eine seiner Stempelkarten).',
          children: [
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Anzahl',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notiz (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _mintingA ? null : _mint,
              icon: _mintingA
                  ? const _Spinner()
                  : const Icon(Icons.bolt_rounded),
              label: Text(_mintingA ? 'Erzeuge …' : 'Stifte erzeugen'),
            ),
            if (_minted.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('${_minted.length} erzeugt',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _downloadAllPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Alle als PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final s in _minted)
                _MintedStickTile(stick: s, onSnack: _snack),
            ],
          ],
        ),
      ],
    );
  }
}

class _MintedStickTile extends StatelessWidget {
  const _MintedStickTile({required this.stick, required this.onSnack});
  final MintedStick stick;
  final void Function(String) onSnack;

  /// The exact URL to write onto the stick's NFC tag.
  String get _nfcUrl {
    final base = appLinkBase();
    final b = base.isNotEmpty ? base : Uri.base.origin;
    final root = b.endsWith('/') ? b : '$b/';
    return '${root}s/${stick.redeemToken}';
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: _nfcUrl));
    onSnack('NFC-Link kopiert.');
  }

  Future<void> _copyBind() async {
    await Clipboard.setData(ClipboardData(text: stick.code));
    onSnack('Binde-Code kopiert.');
  }

  Future<void> _bindPng() async {
    if (!downloadSupported) {
      onSnack('PNG-Download nur im Web verfügbar.');
      return;
    }
    final bytes = await qrPng(stick.code);
    downloadBytes(bytes, 'binde-qr-${stick.stickId}.png', 'image/png');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stick.stickId,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            // 1) NFC-Link — der Owner schreibt ihn auf den Chip.
            Row(
              children: [
                Icon(Icons.nfc_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('NFC-Link — auf den Chip schreiben',
                      style:
                          tt.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(_nfcUrl, style: tt.bodySmall),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _copyUrl,
                icon: const Icon(Icons.content_copy_rounded, size: 16),
                label: const Text('Link kopieren'),
              ),
            ),
            const Divider(height: 18),
            // 2) Binde-QR — liegt dem Stift bei; der Händler scannt ihn.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QrImageView(
                  data: stick.code,
                  size: 82,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Binde-QR — dem Stift beilegen',
                          style: tt.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        'Der Händler scannt ihn auf seine Stempelkarte.',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _copyBind,
                            icon: const Icon(Icons.content_copy_rounded,
                                size: 16),
                            label: const Text('Code'),
                          ),
                          TextButton.icon(
                            onPressed: _bindPng,
                            icon: const Icon(Icons.image_rounded, size: 16),
                            label: const Text('PNG'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Inventar ──────────────────────────────────────────────────────────
class _InventoryTab extends StatefulWidget {
  const _InventoryTab({required this.admin});
  final AdminService admin;

  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  late Future<List<StickInventoryItem>> _future = widget.admin.listSticks();

  Future<void> _reload() {
    final f = widget.admin.listSticks();
    setState(() => _future = f);
    return f;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<StickInventoryItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text(adminErrorMessage(snap.error!))),
                const SizedBox(height: 16),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Neu laden'),
                  ),
                ),
              ],
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Noch keine Stifte erzeugt.')),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _InventoryTile(item: items[i]),
          );
        },
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.item});
  final StickInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          item.isStatic ? Icons.link_rounded : Icons.memory_rounded,
          color: cs.primary,
        ),
        title: Text(item.stickId,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            item.isStatic ? 'Link-Stift' : 'Sicher-Chip',
            if (item.note.isNotEmpty) item.note,
            if (item.bound) 'gebunden' else 'frei',
            if (item.verified) 'verifiziert ✓',
          ].join(' · '),
        ),
        trailing: _StatusChip(item: item),
        isThreeLine: false,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});
  final StickInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bound = item.bound;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (bound ? cs.primary : cs.surfaceContainerHighest)
            .withValues(alpha: bound ? 0.18 : 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        bound ? 'gebunden' : 'frei',
        style: TextStyle(
          color: bound ? cs.primary : cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ── Shared bits ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}
