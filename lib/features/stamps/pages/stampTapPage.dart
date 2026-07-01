import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/authService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/theme/appSpacing.dart';
import '../services/stampFunctionsService.dart';

/// Landing page for a stamp-stick tap. The tag holds `/s/<token>` — the fixed,
/// owner-written link. The page signs the customer in (anonymous if needed),
/// calls `redeemStaticStamp` and celebrates the new stamp.
class StampTapPage extends StatefulWidget {
  const StampTapPage({super.key, required this.token});

  /// Static-stick token from `/s/:token`.
  final String token;

  @override
  State<StampTapPage> createState() => _StampTapPageState();
}

enum _TapState { working, success, queued, error }

class _StampTapPageState extends State<StampTapPage> {
  final StampFunctionsService _fn = StampFunctionsService();
  _TapState _state = _TapState.working;
  StampTapResult? _result;
  String _errorKey = '';
  String _errorCode = '';
  // Set by "update location & retry" on the geofence error → forwarded to the
  // next redeem call so a fresh fix overrides the stale one.
  (double, double)? _forcedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() => _state = _TapState.working);
    final auth = context.read<AuthService>();

    if (widget.token.isEmpty) {
      setState(() {
        _state = _TapState.error;
        _errorKey = 'merchant.stampScan.err.invalid-tag';
      });
      return;
    }

    try {
      await auth.ensureSignedIn();
    } catch (_) {
      setState(() {
        _state = _TapState.error;
        _errorKey = 'merchant.stampScan.err.login-required';
      });
      return;
    }

    try {
      final res = await _fn.redeemStaticStamp(
          token: widget.token, location: _forcedLocation);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _result = res;
        _state = _TapState.success;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _TapState.error;
        _errorKey = stampErrorKey(e);
        _errorCode = stampErrorCode(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _TapState.error;
        _errorKey = 'merchant.stampScan.err.offline';
        _errorCode = e.runtimeType.toString();
      });
    }
  }

  /// "Too far" error → grab a FRESH device location (prompting permission if
  /// needed) and retry immediately. Lets a merchant who just stepped into range
  /// re-stamp without reloading.
  Future<void> _updateLocationAndRetry() async {
    if (!mounted) return;
    setState(() => _state = _TapState.working);
    final loc = await _fn.requestFreshLocation();
    if (!mounted) return;
    _forcedLocation = loc; // may be null (denied) → server then skips geofence
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final texts = context.watch<LanguageService>();
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: switch (_state) {
                _TapState.working => _Working(texts: texts),
                _TapState.success => _Success(result: _result!, texts: texts),
                _TapState.queued => _Queued(texts: texts, onWallet: _goWallet),
                _TapState.error =>
                  _Error(
                      texts: texts,
                      messageKey: _errorKey,
                      code: _errorCode,
                      onRetry: _run,
                      onUpdateLocation:
                          _errorKey == 'merchant.stampScan.err.too-far'
                              ? _updateLocationAndRetry
                              : null),
              },
            ),
          ),
        ),
      ),
    );
  }

  void _goWallet() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/user/wallet');
    }
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.texts});
  final LanguageService texts;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.lg),
        Text(texts.text('stampTap.working'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

/// Success card with a satisfying fill animation up to the new stamp count.
class _Success extends StatelessWidget {
  const _Success({required this.result, required this.texts});
  final StampTapResult result;
  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = (result.maxStamps - result.currentStamps).clamp(0, 9999);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(result.completed ? Icons.celebration_rounded : Icons.check_circle_rounded,
            color: cs.primary, size: 64),
        const SizedBox(height: AppSpacing.md),
        Text(
          result.completed
              ? texts.text('stampTap.completeTitle')
              : texts.text('stampTap.successTitle'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.lg),
        _StampFill(
          filled: result.currentStamps,
          total: result.maxStamps,
          color: cs.primary,
          trackColor: cs.surfaceContainerHighest,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          result.completed
              ? texts.text('stampTap.completeBody')
              : texts
                  .text('stampTap.remaining')
                  .replaceFirst('{n}', '$remaining'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/user/wallet'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(texts.text('stampTap.toWallet')),
        ),
      ],
    );
  }
}

/// Animated grid of stamp dots filling up to [filled].
class _StampFill extends StatefulWidget {
  const _StampFill({
    required this.filled,
    required this.total,
    required this.color,
    required this.trackColor,
  });
  final int filled;
  final int total;
  final Color color;
  final Color trackColor;

  @override
  State<_StampFill> createState() => _StampFillState();
}

class _StampFillState extends State<_StampFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.total.clamp(1, 30);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final animatedFilled = (widget.filled * _c.value).round();
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: List.generate(total, (i) {
            final on = i < animatedFilled;
            final isNew = i == animatedFilled - 1;
            return AnimatedScale(
              scale: isNew ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: on ? widget.color : widget.trackColor,
                  shape: BoxShape.circle,
                ),
                child: on
                    ? const Icon(Icons.star_rounded,
                        color: Colors.white, size: 18)
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}

class _Queued extends StatelessWidget {
  const _Queued({required this.texts, required this.onWallet});
  final LanguageService texts;
  final VoidCallback onWallet;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_rounded, color: cs.primary, size: 56),
        const SizedBox(height: AppSpacing.md),
        Text(texts.text('stampTap.queuedTitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.sm),
        Text(texts.text('stampTap.queuedBody'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: onWallet,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(texts.text('stampTap.toWallet')),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({
    required this.texts,
    required this.messageKey,
    required this.onRetry,
    this.code = '',
    this.onUpdateLocation,
  });
  final LanguageService texts;
  final String messageKey;
  final String code;
  final VoidCallback onRetry;
  final VoidCallback? onUpdateLocation;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, color: cs.error, size: 56),
        const SizedBox(height: AppSpacing.md),
        Text(texts.text('stampTap.errorTitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.sm),
        Text(texts.text(messageKey),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        if (code.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant)),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (onUpdateLocation != null) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onUpdateLocation,
              icon: const Icon(Icons.my_location_rounded),
              label: Text(texts.text('stampTap.updateLocation')),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/user/wallet'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: Text(texts.text('stampTap.toWallet')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: Text(texts.text('common.retry')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
