import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/adminService.dart';
import 'adminHomePage.dart';

/// The secret Godmode entry (reached via the landing "powered by jajehelp" link
/// or by navigating to /godmode while signed in). Reveals nothing unless the
/// caller carries the admin claim:
///   • admin            → the Godmode panel
///   • owner, not admin → a one-time "Godmode aktivieren" (bootstrap) screen
///   • anyone else      → a neutral "not found" page
class AdminGatePage extends StatefulWidget {
  const AdminGatePage({super.key, this.service});

  final AdminService? service;

  @override
  State<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends State<AdminGatePage> {
  late final AdminService _admin = widget.service ?? AdminService();
  StreamSubscription<User?>? _sub;

  bool _loading = true;
  bool _isAdmin = false;
  bool _ownerLoggedIn = false;
  bool _signedIn = false;
  bool _bootstrapping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // IMPORTANT: wait for Firebase to restore the session before deciding.
    // On a cold load, currentUser is null for the first frame even when the
    // owner is signed in — a one-shot check would wrongly fall through to 404.
    // authStateChanges() emits the restored user (or null) once ready and again
    // on any login/logout, so the gate self-corrects.
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) => _evaluate());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _evaluate({bool refresh = false}) async {
    if (mounted) setState(() => _loading = true);
    final ok = await _admin.isAdmin(refresh: refresh);
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      _isAdmin = ok;
      _ownerLoggedIn = _admin.canBootstrap;
      _signedIn = user != null && !user.isAnonymous;
      _loading = false;
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootstrapping = true;
      _error = null;
    });
    try {
      await _admin.bootstrapAdmin();
      await _evaluate(refresh: true);
    } catch (e) {
      if (mounted) setState(() => _error = adminErrorMessage(e));
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isAdmin) {
      return AdminHomePage(service: _admin);
    }
    if (_ownerLoggedIn) {
      return _BootstrapScreen(
        busy: _bootstrapping,
        error: _error,
        onActivate: _bootstrap,
      );
    }
    // Signed in but not the owner → truly nothing here. Signed out → a neutral
    // sign-in prompt so the owner isn't stuck (the real gate is the claim, which
    // a normal login can never satisfy).
    return _signedIn ? const _NotFoundScreen() : const _SignInScreen();
  }
}

/// Neutral "please sign in" page for the signed-out case. Generic on purpose —
/// it doesn't reveal that an admin area lives here.
class _SignInScreen extends StatelessWidget {
  const _SignInScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 48),
            const SizedBox(height: 12),
            const Text('Anmeldung erforderlich.'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/auth/userLogin'),
              child: const Text('Anmelden'),
            ),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Zur Startseite'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen({
    required this.busy,
    required this.error,
    required this.onActivate,
  });
  final bool busy;
  final String? error;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_moon_rounded, size: 56, color: cs.primary),
                const SizedBox(height: 16),
                Text('Godmode aktivieren',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Dieses Konto darf sich einmalig als Admin freischalten. '
                  'Danach steht der Godmode dauerhaft zur Verfügung.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(error!, style: TextStyle(color: cs.error)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy ? null : onActivate,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.vpn_key_rounded),
                  label: Text(busy ? 'Aktiviere …' : 'Jetzt aktivieren'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Abbrechen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral, non-revealing page for non-admins.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('404', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Seite nicht gefunden.'),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Zur Startseite'),
            ),
          ],
        ),
      ),
    );
  }
}
