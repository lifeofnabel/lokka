import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../../../core/theme/appSpacing.dart';
import '../../merchant/shared/widgets/merchantPremiumUi.dart';

/// Outcome of processing a scanned/typed value. [message] is shown to the user;
/// on [ok] the scanner shows a success card, otherwise an error card that lets
/// them try again.
class StampScanOutcome {
  const StampScanOutcome.ok([this.message = '']) : ok = true;
  const StampScanOutcome.fail(this.message) : ok = false;
  final bool ok;
  final String message;
}

/// Generic full-screen QR scanner used by the stamp feature (stick setup +
/// customer wallet scan). Reads a QR, hands the raw value to [onConfirm], and
/// renders success/error. Manual entry is always available as a fallback for
/// devices without a camera or when permission is denied (Edge: camera error).
Future<void> showStampScanner(
  BuildContext context, {
  required String title,
  required String hint,
  required String manualLabel,
  required Future<StampScanOutcome> Function(String code) onConfirm,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Provider<LanguageService>.value(
        value: context.read<LanguageService>(),
        child: _StampScannerScreen(
          title: title,
          hint: hint,
          manualLabel: manualLabel,
          onConfirm: onConfirm,
        ),
      ),
    ),
  );
}

enum _S { scanning, checking, success, failed, cameraError }

class _StampScannerScreen extends StatefulWidget {
  const _StampScannerScreen({
    required this.title,
    required this.hint,
    required this.manualLabel,
    required this.onConfirm,
  });

  final String title;
  final String hint;
  final String manualLabel;
  final Future<StampScanOutcome> Function(String code) onConfirm;

  @override
  State<_StampScannerScreen> createState() => _StampScannerScreenState();
}

class _StampScannerScreenState extends State<_StampScannerScreen> {
  MobileScannerController? _controller;
  final TextEditingController _manual = TextEditingController();
  _S _state = _S.scanning;
  String _message = '';
  bool _torch = false;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    } catch (_) {
      _state = _S.cameraError;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || _state != _S.scanning) return;
    for (final b in capture.barcodes) {
      final raw = (b.rawValue ?? '').trim();
      if (raw.isNotEmpty) {
        await _confirm(raw);
        return;
      }
    }
  }

  Future<void> _confirm(String code) async {
    if (_handling) return;
    _handling = true;
    setState(() => _state = _S.checking);
    StampScanOutcome outcome;
    try {
      outcome = await widget.onConfirm(code);
    } catch (_) {
      outcome = const StampScanOutcome.fail('');
    }
    if (!mounted) return;
    setState(() {
      _state = outcome.ok ? _S.success : _S.failed;
      _message = outcome.message;
    });
    _handling = false;
  }

  void _reset() {
    _manual.clear();
    setState(() {
      _state = _S.scanning;
      _message = '';
    });
  }

  Future<void> _toggleTorch() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Scaffold(
      backgroundColor: MerchantPremiumColors.base,
      appBar: AppBar(
        backgroundColor: MerchantPremiumColors.base,
        foregroundColor: MerchantPremiumColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title,
            style: const TextStyle(
                color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900)),
        actions: [
          if (_controller != null && _state == _S.scanning)
            IconButton(
              onPressed: _toggleTorch,
              icon: Icon(
                _torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _torch
                    ? MerchantPremiumColors.gold
                    : MerchantPremiumColors.muted,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _camera(texts),
            const SizedBox(height: AppSpacing.md),
            _result(texts),
            const SizedBox(height: AppSpacing.lg),
            _manualEntry(texts),
          ],
        ),
      ),
    );
  }

  Widget _camera(LanguageService texts) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: Colors.black,
          child: _controller == null
              ? _unavailable(texts)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _state == _S.scanning) {
                            setState(() => _state = _S.cameraError);
                          }
                        });
                        return _unavailable(texts);
                      },
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: MerchantPremiumColors.gold, width: 3),
                          ),
                        ),
                      ),
                    ),
                    if (_state == _S.scanning)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: _pill(widget.hint),
                      ),
                    if (_state == _S.checking)
                      const ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: MerchantPremiumColors.gold),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _result(LanguageService texts) {
    switch (_state) {
      case _S.success:
        return _card(
          icon: Icons.check_circle_rounded,
          color: MerchantPremiumColors.gold,
          title: texts.text('common.done'),
          body: _message,
          actionLabel: texts.text('merchant.scan.close'),
          onAction: () => Navigator.of(context).maybePop(),
        );
      case _S.failed:
        return _card(
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFE5736B),
          title: texts.text('merchant.scan.notFound'),
          body: _message,
          actionLabel: texts.text('merchant.scan.scanAgain'),
          onAction: _reset,
        );
      case _S.cameraError:
        return _card(
          icon: Icons.no_photography_rounded,
          color: MerchantPremiumColors.muted,
          title: texts.text('merchant.scan.cameraError'),
          body: texts.text('merchant.scan.cameraErrorBody'),
        );
      case _S.checking:
        return _hint(texts.text('merchant.scan.checking'));
      case _S.scanning:
        return _hint(widget.hint);
    }
  }

  Widget _manualEntry(LanguageService texts) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.manualLabel,
              style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _manual,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _confirm(v.trim());
            },
            style: const TextStyle(
                color: MerchantPremiumColors.ink, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: widget.manualLabel,
              hintStyle: TextStyle(
                  color: MerchantPremiumColors.muted.withValues(alpha: 0.8)),
              filled: true,
              fillColor: MerchantPremiumColors.surfaceAlt,
              prefixIcon: const Icon(Icons.keyboard_rounded,
                  color: MerchantPremiumColors.muted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MerchantPremiumColors.line),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _handling
                ? null
                : () {
                    final v = _manual.text.trim();
                    if (v.isNotEmpty) _confirm(v);
                  },
            icon: const Icon(Icons.check_rounded),
            label: Text(texts.text('merchant.scan.confirm')),
            style: FilledButton.styleFrom(
              backgroundColor: MerchantPremiumColors.gold,
              foregroundColor: MerchantPremiumColors.base,
              minimumSize: const Size.fromHeight(50),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unavailable(LanguageService texts) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_rounded,
                  color: Colors.white54, size: 44),
              const SizedBox(height: 12),
              Text(
                texts.text('merchant.scan.cameraErrorBody'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12.5)),
      );

  Widget _hint(String text) => Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: MerchantPremiumColors.muted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ],
      );

  Widget _card({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 17)),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.35)),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: MerchantPremiumColors.gold,
                  foregroundColor: MerchantPremiumColors.base,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(actionLabel ?? ''),
              ),
            ],
          ],
        ),
      );
}
