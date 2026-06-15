import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';

/// Feier-Moment: Konfetti + Haptik als kurzer Overlay. Respektiert den
/// Nutzer-Schalter (lokal gespeichert, kein Server).
class Celebration {
  const Celebration._();

  static const _prefKey = 'gamification.celebrations';
  static const _prefTtl = Duration(days: 365000); // praktisch nie ablaufen

  static Future<bool> isEnabled(LocalCacheService cache) async {
    final m = await cache.readMap(_prefKey, ttl: _prefTtl);
    return (m?['enabled'] as bool?) ?? true;
  }

  static Future<void> setEnabled(LocalCacheService cache, bool value) {
    return cache.writeMap(_prefKey, {'enabled': value});
  }

  static Future<void> maybeShow(
    BuildContext context,
    LocalCacheService cache, {
    required String title,
    String? subtitle,
  }) async {
    if (!await isEnabled(cache)) return;
    if (!context.mounted) return;
    show(context, title: title, subtitle: subtitle);
  }

  static void show(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) {
    HapticFeedback.heavyImpact();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationOverlay(
        title: title,
        subtitle: subtitle,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _CelebrationOverlay extends StatefulWidget {
  const _CelebrationOverlay({
    required this.title,
    this.subtitle,
    required this.onDone,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onDone;

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    const colors = [
      AppColors.seedGreen,
      Color(0xFFFFC83D),
      Color(0xFFFF6B6B),
      Color(0xFF4D96FF),
      Color(0xFFB983FF),
    ];
    _particles = List.generate(36, (i) {
      return _Particle(
        angle: rnd.nextDouble() * 2 * pi,
        speed: 0.6 + rnd.nextDouble() * 0.9,
        color: colors[i % colors.length],
        size: 6 + rnd.nextDouble() * 6,
        rotation: rnd.nextDouble() * 2 * pi,
      );
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _ConfettiPainter(_particles, t)),
              ),
              Center(
                child: _Banner(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  t: t,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.title, this.subtitle, required this.t});

  final String title;
  final String? subtitle;
  final double t;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final scale = t < 0.2 ? Curves.easeOutBack.transform(t / 0.2) : 1.0;
    final opacity = t > 0.85 ? (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0) : 1.0;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, color: cs.primary, size: 32),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style:
                      tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.rotation,
  });

  final double angle;
  final double speed;
  final double size;
  final double rotation;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint();
    final opacity = (1 - t).clamp(0.0, 1.0);
    for (final p in particles) {
      final dist = p.speed * size.width * 0.55 * t;
      final dx = origin.dx + cos(p.angle) * dist;
      final dy = origin.dy + sin(p.angle) * dist + 220 * t * t;
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotation + t * 6);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
