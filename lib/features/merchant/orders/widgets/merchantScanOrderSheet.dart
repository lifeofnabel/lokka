import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';

/// Öffnet den Kassen-Scanner als Vollbild-Dialog. [onConfirm] bekommt den
/// gescannten/eingegebenen Code und gibt `true` zurück, wenn eine passende
/// offene Vor-Kasse-Bestellung gefunden und bestätigt wurde.
///
/// Modus „Order & Show at Register": Der Gast zeigt seinen Bestell-QR (er
/// kodiert den Bestellcode `LK-XXXXXX`); das Personal scannt ihn hier, wodurch
/// die zuvor verborgene Bestellung in „Bestellungen" sichtbar wird.
Future<void> showOrderScanner(
  BuildContext context, {
  required Future<bool> Function(String code) onConfirm,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Provider<LanguageService>.value(
        value: context.read<LanguageService>(),
        child: _ScanOrderScreen(onConfirm: onConfirm),
      ),
    ),
  );
}

enum _ScanState { scanning, checking, success, notFound, cameraError }

class _ScanOrderScreen extends StatefulWidget {
  const _ScanOrderScreen({required this.onConfirm});

  final Future<bool> Function(String code) onConfirm;

  @override
  State<_ScanOrderScreen> createState() => _ScanOrderScreenState();
}

class _ScanOrderScreenState extends State<_ScanOrderScreen> {
  MobileScannerController? _controller;
  final TextEditingController _manualController = TextEditingController();

  _ScanState _state = _ScanState.scanning;
  String _lastCode = '';
  bool _torchOn = false;
  // Verhindert, dass dasselbe Detektions-Event mehrfach verarbeitet wird,
  // während die Bestätigung (async) noch läuft (Edge-Case Doppel-Scan).
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  void _initCamera() {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128],
      );
    } catch (_) {
      // Gerät ohne Kamera o. Ä. → manuelle Eingabe bleibt nutzbar.
      _state = _ScanState.cameraError;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  /// Normalisiert einen gescannten Wert zu einem Bestellcode. Akzeptiert sowohl
  /// den reinen Code („LK-AB12CD") als auch eine evtl. umschließende URL.
  String _extractCode(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';
    // Falls der QR doch eine URL/Query trägt: letztes Pfadsegment / Query-Wert.
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.hasScheme || value.contains('/'))) {
      if (uri.queryParameters['code'] != null) {
        value = uri.queryParameters['code']!;
      } else if (uri.pathSegments.isNotEmpty) {
        value = uri.pathSegments.last;
      }
    }
    return value.trim();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_handling || _state != _ScanState.scanning) return;
    String raw = '';
    for (final barcode in capture.barcodes) {
      if ((barcode.rawValue ?? '').trim().isNotEmpty) {
        raw = barcode.rawValue!.trim();
        break;
      }
    }
    final code = _extractCode(raw);
    if (code.isEmpty) return; // unlesbar → einfach weiter scannen
    await _confirm(code);
  }

  Future<void> _submitManual() async {
    final code = _extractCode(_manualController.text);
    if (code.isEmpty) return;
    await _confirm(code);
  }

  Future<void> _confirm(String code) async {
    if (_handling) return;
    _handling = true;
    setState(() {
      _state = _ScanState.checking;
      _lastCode = code;
    });
    bool ok = false;
    try {
      ok = await widget.onConfirm(code);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _state = ok ? _ScanState.success : _ScanState.notFound);
    _handling = false;
  }

  void _resetToScanning() {
    _manualController.clear();
    setState(() {
      _state = _ScanState.scanning;
      _lastCode = '';
    });
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {/* manche Geräte/Web ohne Blitz – ignorieren */}
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
        title: Text(
          texts.text('merchant.scan.title'),
          style: const TextStyle(
              color: MerchantPremiumColors.ink, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_controller != null && _state == _ScanState.scanning)
            IconButton(
              tooltip: texts.text('merchant.scan.torch'),
              onPressed: _toggleTorch,
              icon: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _torchOn
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
            _cameraArea(texts),
            const SizedBox(height: AppSpacing.md),
            _resultArea(texts),
            const SizedBox(height: AppSpacing.lg),
            _manualEntry(texts),
          ],
        ),
      ),
    );
  }

  Widget _cameraArea(LanguageService texts) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: Colors.black,
          child: _controller == null
              ? _CameraUnavailable(texts: texts)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _handleDetection,
                      errorBuilder: (context, error) {
                        // Permission denied / kein Gerät → manuelle Eingabe.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _state == _ScanState.scanning) {
                            setState(() => _state = _ScanState.cameraError);
                          }
                        });
                        return _CameraUnavailable(texts: texts, error: error);
                      },
                      placeholderBuilder: (context) => const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: MerchantPremiumColors.gold),
                        ),
                      ),
                    ),
                    // Scan-Rahmen-Overlay (rein dekorativ).
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: MerchantPremiumColors.gold, width: 3),
                          ),
                        ),
                      ),
                    ),
                    if (_state == _ScanState.scanning)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: _Pill(text: texts.text('merchant.scan.hint')),
                      ),
                    if (_state == _ScanState.checking)
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

  Widget _resultArea(LanguageService texts) {
    switch (_state) {
      case _ScanState.success:
        return _ResultCard(
          icon: Icons.check_circle_rounded,
          color: MerchantPremiumColors.gold,
          title: texts.text('merchant.scan.success'),
          body: '${texts.text('merchant.scan.successBody')}\n$_lastCode',
          actionLabel: texts.text('merchant.scan.scanAgain'),
          onAction: _resetToScanning,
          secondaryLabel: texts.text('merchant.scan.close'),
          onSecondary: () => Navigator.of(context).maybePop(),
        );
      case _ScanState.notFound:
        return _ResultCard(
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFE5736B),
          title: texts.text('merchant.scan.notFound'),
          body: '${texts.text('merchant.scan.notFoundBody')}\n$_lastCode',
          actionLabel: texts.text('merchant.scan.scanAgain'),
          onAction: _resetToScanning,
        );
      case _ScanState.cameraError:
        return _ResultCard(
          icon: Icons.no_photography_rounded,
          color: MerchantPremiumColors.muted,
          title: texts.text('merchant.scan.cameraError'),
          body: texts.text('merchant.scan.cameraErrorBody'),
        );
      case _ScanState.checking:
        return _HintRow(text: texts.text('merchant.scan.checking'));
      case _ScanState.scanning:
        return _HintRow(text: texts.text('merchant.scan.subtitle'));
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
          Text(
            texts.text('merchant.scan.manualLabel'),
            style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _manualController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitManual(),
            style: const TextStyle(
                color: MerchantPremiumColors.ink, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: texts.text('merchant.scan.manualPlaceholder'),
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
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MerchantPremiumColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: MerchantPremiumColors.gold, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _handling ? null : _submitManual,
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
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.texts, this.error});

  final LanguageService texts;
  final MobileScannerException? error;

  @override
  Widget build(BuildContext context) {
    return Center(
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
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded,
            color: MerchantPremiumColors.muted, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(actionLabel ?? ''),
              style: FilledButton.styleFrom(
                backgroundColor: MerchantPremiumColors.gold,
                foregroundColor: MerchantPremiumColors.base,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
          if (onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel ?? '',
                style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
