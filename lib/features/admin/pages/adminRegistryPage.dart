import 'package:flutter/material.dart';

import '../adminNav.dart';
import '../services/adminDataService.dart';
import '../services/adminService.dart';

/// Godmode → Stempel/Punkte/Stifte-Register. Stift-Inventar (mit „Bindung
/// lösen") + alle Stempelkarten über sämtliche Händler. Reparatur via Editor.
class AdminRegistryPage extends StatelessWidget {
  const AdminRegistryPage({super.key, this.admin, this.data});
  final AdminService? admin;
  final AdminDataService? data;

  @override
  Widget build(BuildContext context) {
    final a = admin ?? AdminService();
    final d = data ?? AdminDataService();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stempel & Stifte'),
          bottom: const TabBar(
              tabs: [Tab(text: 'Stifte'), Tab(text: 'Stempelkarten')]),
        ),
        body: TabBarView(
          children: [_SticksTab(admin: a, data: d), _CardsTab(data: d)],
        ),
      ),
    );
  }
}

class _SticksTab extends StatefulWidget {
  const _SticksTab({required this.admin, required this.data});
  final AdminService admin;
  final AdminDataService data;
  @override
  State<_SticksTab> createState() => _SticksTabState();
}

class _SticksTabState extends State<_SticksTab> {
  Future<List<StickInventoryItem>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = widget.admin.listSticks());

  Future<void> _unbind(StickInventoryItem s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bindung lösen?'),
        content: Text('Stift ${s.stickId} wird von seiner Karte getrennt. '
            'Taps schlagen danach fehl, bis er neu gebunden wird.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lösen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.data.mergeDoc('sticks/${s.stickId}', {
        'boundMerchantId': null,
        'boundCardId': null,
        'bound': false,
      });
      if (!mounted) return;
      adminSnack(context, 'Bindung gelöst.');
      _reload();
    } catch (e) {
      if (mounted) adminSnack(context, 'Fehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StickInventoryItem>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _Err(error: adminErrorMessage(snap.error!), onRetry: _reload);
        }
        final sticks = snap.data!;
        if (sticks.isEmpty) {
          return ListView(children: const [
            SizedBox(height: 100),
            Center(child: Text('Noch keine Stifte.')),
          ]);
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sticks.length,
            itemBuilder: (context, i) {
              final s = sticks[i];
              return Card(
                child: ListTile(
                  leading: Icon(
                      s.isStatic ? Icons.link_rounded : Icons.memory_rounded),
                  title: Text(s.stickId,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      s.isStatic ? 'Link-Stift' : 'Sicher-Chip',
                      if (s.bound) 'gebunden' else 'frei',
                      if (s.verified) 'verifiziert ✓',
                      if (s.note.isNotEmpty) s.note,
                    ].join(' · '),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'unbind':
                          _unbind(s);
                        case 'editor':
                          openAdminEditor(context, 'sticks/${s.stickId}');
                      }
                    },
                    itemBuilder: (_) => [
                      if (s.bound)
                        const PopupMenuItem(
                            value: 'unbind', child: Text('Bindung lösen')),
                      const PopupMenuItem(
                          value: 'editor', child: Text('Im Editor öffnen')),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CardsTab extends StatefulWidget {
  const _CardsTab({required this.data});
  final AdminDataService data;
  @override
  State<_CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<_CardsTab> {
  Future<List<AdminDoc>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = widget.data.stampCards());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminDoc>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _Err(error: '${snap.error}', onRetry: _reload);
        }
        final cards = snap.data!;
        if (cards.isEmpty) {
          return ListView(children: const [
            SizedBox(height: 100),
            Center(child: Text('Keine Stempelkarten.')),
          ]);
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: cards.length,
            itemBuilder: (context, i) {
              final c = cards[i];
              final title = (c.data['title'] ?? 'Stempelkarte').toString();
              final boundStick = (c.data['boundStickId'] ?? '').toString();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.confirmation_number_rounded),
                  title: Text(title),
                  subtitle: Text(
                    [
                      c.id, // full path
                      if (boundStick.isNotEmpty) 'Stift: $boundStick',
                    ].join('\n'),
                    style: const TextStyle(fontSize: 11),
                  ),
                  isThreeLine: boundStick.isNotEmpty,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_note_rounded),
                    tooltip: 'Im Editor öffnen',
                    onPressed: () => openAdminEditor(context, c.id),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Err extends StatelessWidget {
  const _Err({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Neu laden'),
              ),
            ],
          ),
        ),
      );
}
