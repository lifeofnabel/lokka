import 'package:flutter/material.dart';

import '../adminNav.dart';
import '../services/adminDataService.dart';

/// Godmode → Händler & Nutzer. Pending-Freigaben, Suche, Status/Rolle setzen,
/// und Sprung in den Firestore-Editor für alles Weitere.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, this.service});
  final AdminDataService? service;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late final AdminDataService _data = widget.service ?? AdminDataService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Händler & Nutzer'),
          bottom: const TabBar(tabs: [Tab(text: 'Händler'), Tab(text: 'Nutzer')]),
        ),
        body: TabBarView(
          children: [
            _MerchantsTab(data: _data),
            _UsersTab(data: _data),
          ],
        ),
      ),
    );
  }
}

String _name(Map<String, dynamic> d, String fallback) =>
    (d['shopName'] ?? d['companyName'] ?? d['name'] ?? fallback).toString();

// ── Händler ──────────────────────────────────────────────────────────────────
class _MerchantsTab extends StatefulWidget {
  const _MerchantsTab({required this.data});
  final AdminDataService data;
  @override
  State<_MerchantsTab> createState() => _MerchantsTabState();
}

class _MerchantsTabState extends State<_MerchantsTab> {
  final _searchCtrl = TextEditingController();
  Future<_MerchantBundle>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() {
    final f = () async {
      final pending = await widget.data.pendingMerchants();
      final all = await widget.data.listMerchants();
      return _MerchantBundle(pending, all);
    }();
    setState(() {
      _future = f;
    });
    return f;
  }

  Future<void> _setStatus(String uid, String status) async {
    try {
      await widget.data.setMerchantStatus(uid, status);
      if (!mounted) return;
      adminSnack(context, 'Status → $status');
      _reload();
    } catch (e) {
      if (mounted) adminSnack(context, 'Fehler: $e');
    }
  }

  void _actions(AdminDoc m) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_name(m.data, m.id)),
              subtitle: Text('merchants/${m.id}'),
            ),
            const Divider(height: 1),
            for (final s in ['approved', 'rejected', 'blocked', 'paused', 'pending'])
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text('Status: $s'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatus(m.id, s);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('merchants/… im Editor'),
              onTap: () {
                Navigator.pop(ctx);
                openAdminEditor(context, 'merchants/${m.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: const Text('publicMerchants/… im Editor'),
              onTap: () {
                Navigator.pop(ctx);
                openAdminEditor(context, 'publicMerchants/${m.id}');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Suche (Name, Handle, ID)',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<_MerchantBundle>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErrorView(error: '${snap.error}', onRetry: _reload);
              }
              final b = snap.data!;
              final filtered = b.all.where((m) {
                if (_query.isEmpty) return true;
                final hay =
                    '${m.id} ${_name(m.data, '')} ${m.data['handle'] ?? ''}'
                        .toLowerCase();
                return hay.contains(_query);
              }).toList();
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    if (b.pending.isNotEmpty) ...[
                      _Header('Offene Anträge (${b.pending.length})'),
                      for (final m in b.pending)
                        Card(
                          child: ListTile(
                            title: Text(_name(m.data, m.id)),
                            subtitle: Text(m.id,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Freigeben',
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.green),
                                  onPressed: () => _setStatus(m.id, 'approved'),
                                ),
                                IconButton(
                                  tooltip: 'Ablehnen',
                                  icon: const Icon(Icons.cancel,
                                      color: Colors.redAccent),
                                  onPressed: () => _setStatus(m.id, 'rejected'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                    _Header('Alle Händler (${filtered.length})'),
                    for (final m in filtered)
                      Card(
                        child: ListTile(
                          title: Text(_name(m.data, m.id)),
                          subtitle: Text(
                            [
                              if ((m.data['handle'] ?? '').toString().isNotEmpty)
                                '@${m.data['handle']}',
                              m.id,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.more_vert_rounded),
                          onTap: () => _actions(m),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MerchantBundle {
  _MerchantBundle(this.pending, this.all);
  final List<AdminDoc> pending;
  final List<AdminDoc> all;
}

// ── Nutzer ───────────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  const _UsersTab({required this.data});
  final AdminDataService data;
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _searchCtrl = TextEditingController();
  Future<List<AdminDoc>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() {
    final f = widget.data.listUsers();
    setState(() {
      _future = f;
    });
    return f;
  }

  void _actions(AdminDoc u) {
    final active = u.data['isActive'] != false;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_name(u.data, u.id)),
              subtitle: Text('users/${u.id} · Rolle: ${u.data['role'] ?? '–'}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Rolle: user'),
              onTap: () => _set(ctx, () => widget.data.setUserRole(u.id, 'user')),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_rounded),
              title: const Text('Rolle: merchant'),
              onTap: () =>
                  _set(ctx, () => widget.data.setUserRole(u.id, 'merchant')),
            ),
            ListTile(
              leading: Icon(active ? Icons.block_rounded : Icons.check_rounded),
              title: Text(active ? 'Deaktivieren (isActive=false)' : 'Aktivieren'),
              onTap: () =>
                  _set(ctx, () => widget.data.setUserActive(u.id, !active)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('users/… im Editor'),
              onTap: () {
                Navigator.pop(ctx);
                openAdminEditor(context, 'users/${u.id}');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _set(BuildContext sheetCtx, Future<void> Function() op) async {
    Navigator.pop(sheetCtx);
    try {
      await op();
      if (!mounted) return;
      adminSnack(context, 'Gespeichert.');
      _reload();
    } catch (e) {
      if (mounted) adminSnack(context, 'Fehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Suche (Name, E-Mail, ID, Rolle)',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AdminDoc>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErrorView(error: '${snap.error}', onRetry: _reload);
              }
              final users = snap.data!.where((u) {
                if (_query.isEmpty) return true;
                final hay =
                    '${u.id} ${_name(u.data, '')} ${u.data['email'] ?? ''} ${u.data['role'] ?? ''}'
                        .toLowerCase();
                return hay.contains(_query);
              }).toList();
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final active = u.data['isActive'] != false;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          active ? Icons.person : Icons.person_off,
                          color: active ? null : Colors.redAccent,
                        ),
                        title: Text(_name(u.data, u.id)),
                        subtitle: Text(
                          '${u.data['role'] ?? '–'} · ${u.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.more_vert_rounded),
                        onTap: () => _actions(u),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Shared ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
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
