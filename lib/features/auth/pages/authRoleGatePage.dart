import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/appRouter.dart' show seedMerchantAccess;
import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/services/sessionService.dart';
import '../../../core/theme/appColors.dart';

/// „Rolle prüfen" – die Weiche direkt nach dem Login. Sie liest nur das absolut
/// Nötige (Rolle, ggf. Freigabestatus) und leitet weiter. Cache-first + Timeout,
/// damit sie weder auf den Server-Roundtrip wartet noch bei flakigem Netz
/// endlos hängt; nicht-kritische Schreibvorgänge laufen außerhalb des Pfads.
class AuthRoleGatePage extends StatefulWidget {
  const AuthRoleGatePage({super.key});

  @override
  State<AuthRoleGatePage> createState() => _AuthRoleGatePageState();
}

enum _GateStage { working, failed }

class _AuthRoleGatePageState extends State<AuthRoleGatePage>
    with SingleTickerProviderStateMixin {
  _GateStage _stage = _GateStage.working;
  bool _slow = false;
  Timer? _slowTimer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _armSlowHint() {
    _slowTimer?.cancel();
    _slow = false;
    // Nach kurzer Wartezeit ein beruhigender Hinweis – noch kein Fehler.
    _slowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _stage == _GateStage.working) {
        setState(() => _slow = true);
      }
    });
  }

  Future<void> _route() async {
    setState(() {
      _stage = _GateStage.working;
      _slow = false;
    });
    _armSlowHint();

    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final session = context.read<SessionService>();

    try {
      final user = auth.currentUser;
      if (user == null) {
        _go('/auth/userLogin');
        return;
      }

      final profile = await firestore.getUserProfileResilient(user.uid);
      if (!mounted) return;

      if (profile == null) {
        _go('/auth/chooseRole');
        return;
      }

      final role = profile['role'] as String?;

      // „Zuletzt gesehen" ist Telemetrie, kein Routing-Kriterium: bewusst
      // fire-and-forget, damit ein hängender Write die Weiterleitung nie blockt.
      unawaited(session.markLastSeenIfNeeded().catchError((_) {}));

      if (role == 'user') {
        seedMerchantAccess(user.uid, 'user', null);
        _go('/user/discover');
        return;
      }

      if (role == 'merchant') {
        final merchant = await firestore.getMerchantProfileResilient(user.uid);
        if (!mounted) return;
        final status =
            merchant?['verificationStatus'] as String? ?? 'pending';
        seedMerchantAccess(user.uid, 'merchant', status);
        if (status == 'approved') {
          _go('/merchant/dashboard');
        } else {
          _go('/auth/merchantPending?status=$status');
        }
        return;
      }

      _go('/auth/chooseRole');
    } catch (_) {
      // Timeout / Lesefehler: kein endloser Spinner, sondern ein klarer
      // Wiederholen-Zustand mit Ausweg zur Startseite.
      if (mounted) {
        _slowTimer?.cancel();
        setState(() => _stage = _GateStage.failed);
      }
    }
  }

  void _go(String location) {
    _slowTimer?.cancel();
    if (mounted) context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _stage == _GateStage.failed
                ? _FailedView(onRetry: _route, onHome: () => _go('/'))
                : _WorkingView(pulse: _pulse, slow: _slow),
          ),
        ),
      ),
    );
  }
}

/// Ruhiges, markentreues Ladebild: pulsierender Lokka-Glyph + Titel. Nach
/// kurzer Wartezeit ein beiläufiger „dauert etwas länger"-Hinweis.
class _WorkingView extends StatelessWidget {
  const _WorkingView({required this.pulse, required this.slow});

  final Animation<double> pulse;
  final bool slow;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.06).animate(
            CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
          ),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Image.asset(
                'assets/logo.png',
                height: 40,
                color: cs.primary,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, _, _) => Icon(
                  Icons.local_activity_rounded,
                  color: cs.primary,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          texts.text('auth.roleGate.title'),
          textAlign: TextAlign.center,
          style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        AnimatedOpacity(
          opacity: slow ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Verbindung dauert gerade etwas länger …',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

/// Klar lesbarer Fehlzustand mit Wiederholen + Ausweg, statt endlosem Spinner.
class _FailedView extends StatelessWidget {
  const _FailedView({required this.onRetry, required this.onHome});

  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_rounded, size: 40, color: cs.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          'Keine stabile Verbindung',
          textAlign: TextAlign.center,
          style: tt.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Wir konnten dein Konto gerade nicht laden. Prüfe kurz dein Netz.',
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onRetry,
            child: const Text('Erneut versuchen'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onHome,
          child: const Text('Zur Startseite'),
        ),
      ],
    );
  }
}
