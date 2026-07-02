import 'package:flutter/material.dart';

/// A clearly visible, continuously-pulsing, TAPPABLE swipe-direction hint — a
/// dark circular badge (the same floating-button treatment used elsewhere in
/// the app for controls over photos/cover images), so it always reads with
/// strong contrast regardless of what's behind it.
///
/// Used anywhere a carousel/pager needs to teach its swipe gesture — the user
/// Wallet's store deck and the Merchant's stamp-card carousel alike.
///
/// Tapping it does the same thing the swipe gesture would ([onTap]) — a
/// fallback for anyone who doesn't discover the swipe itself. The gentle
/// scale/opacity breathing loop runs for as long as the widget is mounted, so
/// it stays noticeable rather than a one-time flash that's easy to miss.
class SwipeHint extends StatefulWidget {
  const SwipeHint({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 34,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  State<SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Opacity(
          opacity: 0.55 + t * 0.35,
          child: Transform.scale(scale: 1.0 + t * 0.12, child: child),
        );
      },
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Icon(widget.icon,
                size: widget.size * 0.55, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
