import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../../services/display_studio_service.dart';
import 'display_pairing_setup_page.dart';

class DisplayScannerPage extends StatefulWidget {
  const DisplayScannerPage({super.key, required this.service});
  final DisplayStudioService service;

  @override
  State<DisplayScannerPage> createState() => _DisplayScannerPageState();
}

class _DisplayScannerPageState extends State<DisplayScannerPage> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _processing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('TV-QR scannen',
            style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: AppColors.white),
            onPressed: () => _ctrl.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_rounded, color: AppColors.white),
            tooltip: 'Code eingeben',
            onPressed: () => _showManualInput(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),
          // Viewfinder overlay
          Positioned.fill(
            child: CustomPaint(painter: _ViewfinderPainter()),
          ),
          // Hint text
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_processing)
                    const CircularProgressIndicator(color: AppColors.mint)
                  else if (_errorMessage != null)
                    _ErrorCard(message: _errorMessage!, onRetry: _retry)
                  else
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Richte die Kamera auf den QR-Code am Fernseher.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Der QR-Code am Fernseher wechselt regelmäßig.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() => _errorMessage = null);
    _ctrl.start();
  }

  void _showManualInput(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 22, right: 22, top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Code manuell eingeben',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                    color: AppColors.white)),
            const SizedBox(height: 6),
            const Text('Gib den vollständigen Lokka-Code oder die URL ein.',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: 'lokka://display?id=…  oder nur die ID',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                final raw = ctrl.text.trim();
                if (raw.isEmpty) return;
                Navigator.of(ctx).pop();
                // Normalize: if user typed just the pairingId, build URL
                final payload = raw.startsWith('lokka://')
                    ? raw
                    : 'lokka://display?id=$raw&t=';
                _processPayload(payload);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mint,
                foregroundColor: AppColors.black,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Bestätigen',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    if (!raw.startsWith('lokka://display')) {
      setState(() => _errorMessage = 'Ungültiger QR-Code. Bitte einen Lokka TV-QR scannen.');
      await _ctrl.stop();
      return;
    }

    await _ctrl.stop();
    await _processPayload(raw);
  }

  Future<void> _processPayload(String raw) async {
    if (_processing) return;
    setState(() { _processing = true; _errorMessage = null; });

    try {
      final uri = Uri.parse(raw.replaceFirst('lokka://', 'https://lokka.app/'));
      final pairingId = uri.queryParameters['id'] ?? '';
      final token = uri.queryParameters['t'] ?? '';

      if (pairingId.isEmpty) {
        throw Exception('Code ist unvollständig oder ungültig.');
      }

      final session = await widget.service.getPairingSession(pairingId);

      if (session == null) {
        throw Exception('Pairing-Session nicht gefunden. Code abgelaufen oder ungültig.');
      }

      final claimed = session['claimed'] as bool? ?? false;
      if (claimed) {
        throw Exception('Dieser Code wurde bereits verwendet.');
      }

      final expiresAt = session['expiresAt'];
      if (expiresAt != null) {
        DateTime? expiry;
        try { expiry = (expiresAt as dynamic).toDate() as DateTime?; } catch (_) {}
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          throw Exception('Code ist abgelaufen. Bitte am Fernseher einen neuen QR anzeigen.');
        }
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DisplayPairingSetupPage(
            service: widget.service,
            pairingId: pairingId,
            token: token,
            sessionData: session,
          ),
        ),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5A1A1A)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 28),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Erneut versuchen',
                style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// Simple viewfinder overlay
class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black54;
    final side = size.width * 0.68;
    final left = (size.width - side) / 2;
    final top = (size.height - side) / 2;
    final rect = Rect.fromLTWH(left, top, side, side);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16))),
      ),
      overlay,
    );

    final border = Paint()
      ..color = AppColors.mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const cornerLen = 24.0;
    final r = rect;

    for (final (dx, dy) in [
      (0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)
    ]) {
      final cx = r.left + dx * r.width;
      final cy = r.top + dy * r.height;
      final sx = dx == 0 ? 1 : -1;
      final sy = dy == 0 ? 1 : -1;
      canvas.drawLine(
          Offset(cx, cy), Offset(cx + sx * cornerLen, cy), border);
      canvas.drawLine(
          Offset(cx, cy), Offset(cx, cy + sy * cornerLen), border);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
