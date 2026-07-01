import 'package:flutter/material.dart';

import '../adminNav.dart';
import '../services/adminDataService.dart';

/// Godmode → Inhalte moderieren. Beiträge (pausieren/löschen) + gemeldete
/// Inhalte. Alles Weitere via Sprung in den Firestore-Editor.
class AdminModerationPage extends StatelessWidget {
  const AdminModerationPage({super.key, this.service});
  final AdminDataService? service;

  @override
  Widget build(BuildContext context) {
    final data = service ?? AdminDataService();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inhalte moderieren'),
          bottom: const TabBar(tabs: [Tab(text: 'Beiträge'), Tab(text: 'Meldungen')]),
        ),
        body: TabBarView(
          children: [_PostsTab(data: data), _ReportsTab(data: data)],
        ),
      ),
    );
  }
}

class _PostsTab extends StatefulWidget {
  const _PostsTab({required this.data});
  final AdminDataService data;
  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  Future<List<AdminDoc>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() {
    final f = widget.data.recentPosts();
    setState(() {
      _future = f;
    });
    return f;
  }

  Future<void> _togglePause(AdminDoc p) async {
    final active = p.data['isActive'] != false;
    try {
      await widget.data.setPostActive(p.id, !active);
      if (!mounted) return;
      adminSnack(context, active ? 'Pausiert (aus Feed entfernt).' : 'Wieder aktiv.');
      _reload();
    } catch (e) {
      if (mounted) adminSnack(context, 'Fehler: $e');
    }
  }

  Future<void> _delete(AdminDoc p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beitrag löschen?'),
        content: Text(p.id),
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
    if (ok != true) return;
    try {
      await widget.data.deletePost(p.id);
      if (!mounted) return;
      adminSnack(context, 'Gelöscht.');
      _reload();
    } catch (e) {
      if (mounted) adminSnack(context, 'Fehler: $e');
    }
  }

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
        final posts = snap.data!;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            itemBuilder: (context, i) {
              final p = posts[i];
              final active = p.data['isActive'] != false;
              final title = (p.data['title'] ??
                      p.data['headline'] ??
                      p.data['text'] ??
                      p.id)
                  .toString();
              return Card(
                child: ListTile(
                  leading: Icon(
                    active ? Icons.visibility : Icons.visibility_off,
                    color: active ? null : Colors.orangeAccent,
                  ),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${p.data['merchantId'] ?? '–'} · ${active ? 'aktiv' : 'pausiert'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'pause':
                          _togglePause(p);
                        case 'editor':
                          openAdminEditor(context, 'feed/${p.id}');
                        case 'delete':
                          _delete(p);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pause',
                        child: Text(active ? 'Pausieren' : 'Aktivieren'),
                      ),
                      const PopupMenuItem(value: 'editor', child: Text('Im Editor öffnen')),
                      const PopupMenuItem(value: 'delete', child: Text('Löschen')),
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

class _ReportsTab extends StatefulWidget {
  const _ReportsTab({required this.data});
  final AdminDataService data;
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  Future<List<AdminDoc>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() {
    final f = widget.data.recentReports();
    setState(() {
      _future = f;
    });
    return f;
  }

  String? _targetPath(Map<String, dynamic> d) {
    final tp = (d['targetPath'] ?? d['path'] ?? '').toString();
    if (tp.isNotEmpty) return tp;
    final postId = (d['postId'] ?? d['feedId'] ?? '').toString();
    if (postId.isNotEmpty) return 'feed/$postId';
    final mid = (d['merchantId'] ?? '').toString();
    if (mid.isNotEmpty) return 'publicMerchants/$mid';
    return null;
  }

  Future<void> _delete(AdminDoc r) async {
    try {
      await widget.data.deleteReport(r.id);
      if (!mounted) return;
      adminSnack(context, 'Meldung gelöscht.');
      _reload();
    } catch (e) {
      if (mounted) adminSnack(context, 'Fehler: $e');
    }
  }

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
        final reports = snap.data!;
        if (reports.isEmpty) {
          return ListView(children: const [
            SizedBox(height: 100),
            Center(child: Text('Keine Meldungen.')),
          ]);
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (context, i) {
              final r = reports[i];
              final reason =
                  (r.data['reason'] ?? r.data['type'] ?? 'Meldung').toString();
              final target = _targetPath(r.data);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_rounded, color: Colors.redAccent),
                  title: Text(reason),
                  subtitle: Text(
                    target ?? 'contentReports/${r.id}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'target':
                          if (target != null) openAdminEditor(context, target);
                        case 'report':
                          openAdminEditor(context, 'contentReports/${r.id}');
                        case 'delete':
                          _delete(r);
                      }
                    },
                    itemBuilder: (_) => [
                      if (target != null)
                        const PopupMenuItem(
                            value: 'target', child: Text('Ziel im Editor')),
                      const PopupMenuItem(
                          value: 'report', child: Text('Meldung im Editor')),
                      const PopupMenuItem(value: 'delete', child: Text('Meldung löschen')),
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
