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
  String? _error; // bootstrap-action error (shown inside the bootstrap screen)
  String? _checkError; // gate admin-check failed (timeout/network) → retry screen

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

  Future<void> _evaluate() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _checkError = null;
      });
    }
    try {
      bool ok;
      try {
        // Prefer a fresh token (picks up a just-granted claim) so Firestore
        // reads carry the up-to-date `admin` claim — but BOUND it: a stalled
        // secure-token endpoint must never freeze the gate.
        ok = await _admin.isAdmin(refresh: true).timeout(const Duration(seconds: 8));
      } catch (_) {
        // Fresh-token fetch stalled or errored → fall back to the cached token,
        // which already carries the claim after bootstrap. The owner is never
        // locked out by a slow/failed refresh. (A genuine "not admin" returns
        // false without throwing, so it never reaches here.)
        ok = await _admin.isAdmin(refresh: false).timeout(const Duration(seconds: 6));
      }
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      setState(() {
        _isAdmin = ok;
        _ownerLoggedIn = _admin.canBootstrap;
        _signedIn = user != null && !user.isAnonymous;
        _loading = false;
      });
    } catch (e) {
      // Both attempts failed (offline / token endpoint down) → retryable screen
      // instead of a misleading 404 or an endless spinner.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _checkError = adminErrorMessage(e);
      });
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootstrapping = true;
      _error = null;
    });
    try {
      await _admin.bootstrapAdmin();
      await _evaluate();
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
    if (_checkError != null) {
      return _GateErrorScreen(message: _checkError!, onRetry: _evaluate);
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

/// Shown when the admin check itself couldn't complete (offline / token endpoint
/// stalled). Retryable, so a transient hiccup never strands the owner.
class _GateErrorScreen extends StatelessWidget {
  const _GateErrorScreen({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text('Verbindung prüfen',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
    );
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
