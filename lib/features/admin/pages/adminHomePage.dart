import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../adminTheme.dart';
import '../services/adminService.dart';
import '../stickWorkshop/pages/adminStickWorkshopPage.dart';
import 'adminFirestorePage.dart';
import 'adminModerationPage.dart';
import 'adminRegistryPage.dart';
import 'adminUsersPage.dart';

/// Godmode dashboard. Sprint 1 ships the Stift-Werkstatt; the remaining control
/// surfaces are shown as locked tiles ("Sprint 2") so the structure is visible.
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key, required this.service});

  final AdminService service;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => adminThemed(page)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('GODMODE'),
        actions: [
          IconButton(
            tooltip: 'Verlassen',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withValues(alpha: 0.22), cs.surface],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_moon_rounded, color: cs.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lokka Godmode',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      Text('Voller Kontroll- und Werkstatt-Zugriff',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _Tile(
            icon: Icons.nfc_rounded,
            title: 'Stift-Werkstatt',
            subtitle: 'Stifte erzeugen, QR-Codes + Links, Inventar',
            onTap: () =>
                _push(context, AdminStickWorkshopPage(service: service)),
          ),
          _Tile(
            icon: Icons.people_alt_rounded,
            title: 'Händler & Nutzer',
            subtitle: 'Anträge freigeben, sperren, Rolle/Status setzen',
            onTap: () => _push(context, const AdminUsersPage()),
          ),
          _Tile(
            icon: Icons.flag_rounded,
            title: 'Inhalte moderieren',
            subtitle: 'Beiträge pausieren/löschen, Meldungen',
            onTap: () => _push(context, const AdminModerationPage()),
          ),
          _Tile(
            icon: Icons.confirmation_number_rounded,
            title: 'Stempel & Stifte-Register',
            subtitle: 'Alle Karten + Stift-Inventar, Bindungen lösen',
            onTap: () => _push(context, const AdminRegistryPage()),
          ),
          _Tile(
            icon: Icons.build_rounded,
            title: 'Power-Tools',
            subtitle: 'Roher Firestore-Editor — alles lesen & fixen',
            onTap: () => _push(context, const AdminFirestorePage()),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
