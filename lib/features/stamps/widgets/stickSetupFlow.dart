import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../../../core/theme/appSpacing.dart';
import '../../merchant/shared/widgets/merchantPremiumUi.dart';
import '../../merchant/stamps/models/stampCardModel.dart';
import '../../merchant/tools/widgets/merchantToolUi.dart';
import '../services/stampFunctionsService.dart';
import 'stampScanner.dart';

/// „Stempelstift verbinden" für die sichtbare Karte.
///
/// Der Stift wird in der Godmode-Werkstatt fertig beschrieben und kommt mit
/// einem Bind-QR (`lokka-stick-a:<id>:<claim>`). Verbinden = Kamera auf, QR
/// scannen, fertig. Ist noch kein Stift verbunden, öffnet sich die Kamera
/// **direkt**. Ist schon einer verbunden, zeigt das Sheet dessen Daten
/// (Serien-Nr., Typ, Status) in einfacher Form.
Future<void> startStickSetup(
  BuildContext context, {
  required StampCardModel card,
  required StampFunctionsService functions,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MerchantPremiumColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        _StickSetupSheet(card: card, functions: functions, onChanged: onChanged),
  );
}

class _StickSetupSheet extends StatefulWidget {
  const _StickSetupSheet({
    required this.card,
    required this.functions,
    required this.onChanged,
  });

  final StampCardModel card;
  final StampFunctionsService functions;
  final VoidCallback onChanged;

  @override
  State<_StickSetupSheet> createState() => _StickSetupSheetState();
}

class _StickSetupSheetState extends State<_StickSetupSheet> {
  // Lokaler, veränderbarer Karten-Stand — nach erfolgreichem Bind sofort
  // aktualisiert, damit die „verbunden"-Ansicht direkt erscheint.
  late StampCardModel _card = widget.card;

  bool _busy = false;
  String? _error;
  bool _rebinding = false; // „Anderen Stift verbinden" gedrückt
  bool _autoOpened = false;

  bool get _connected => _card.hasStick && !_rebinding;

  @override
  void initState() {
    super.initState();
    // Kamera direkt öffnen, wenn noch kein Stift verbunden ist.
    if (!widget.card.hasStick) {
      _autoOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scanAndBind();
      });
    }
  }

  /// Bind-QR (`lokka-stick-a:<id>:<claim>`) scannen und mit DIESER Karte
  /// verbinden. Der Tag ist bereits beschrieben, ein erfolgreicher Scan genügt.
  Future<void> _scanAndBind() async {
    final texts = context.read<LanguageService>();
    var serial = '';
    setState(() {
      _busy = true;
      _error = null;
    });
    await showStampScanner(
      context,
      title: 'Stempelstift scannen',
      hint: 'Halte den QR-Code auf dem Stift vor die Kamera.',
      manualLabel: texts.text('merchant.stick.manualLabel'),
      onConfirm: (raw) async {
        final parsed = _parseClaimQr(raw);
        if (parsed == null) {
          return StampScanOutcome.fail(texts.text('merchant.stick.invalidQr'));
        }
        try {
          await widget.functions.claimStaticStick(
            stickId: parsed.$1,
            claimToken: parsed.$2,
            cardId: _card.id,
          );
          serial = parsed.$1;
          return const StampScanOutcome.ok('Stift verbunden ✓');
        } catch (e) {
          return StampScanOutcome.fail(texts.text(stampErrorKey(e)));
        }
      },
    );
    if (!mounted) return;
    if (serial.isEmpty) {
      // Scanner ohne Bind geschlossen (abgebrochen) — zurück zur Startansicht.
      setState(() => _busy = false);
      return;
    }
    widget.onChanged();
    setState(() {
      _card = _card.copyWith(
        boundStickId: serial,
        stickType: 'static',
        stickVerifiedAt: DateTime.now(),
      );
      _rebinding = false;
      _busy = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(cardTitle: _card.title),
              const SizedBox(height: AppSpacing.md),
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_busy) ...[
                const _BusyRow(),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_connected)
                ..._connectedChildren()
              else
                ..._connectChildren(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ansicht: verbinden (Schritte + Kamera zuerst) ───────────────────────────
  List<Widget> _connectChildren() {
    return [
      const _MiniStepper(),
      const SizedBox(height: AppSpacing.md),
      const _InfoBanner(
        icon: Icons.qr_code_scanner_rounded,
        message: 'Dein Stift kam mit einem QR-Code. Halte ihn vor die Kamera — '
            'der Stift verbindet sich dann mit dieser Stempelkarte.',
      ),
      const SizedBox(height: AppSpacing.md),
      MerchantPrimaryButton(
        label: _autoOpened ? 'Kamera erneut öffnen' : 'Kamera öffnen & scannen',
        icon: Icons.qr_code_scanner_rounded,
        onPressed: _busy ? null : _scanAndBind,
      ),
    ];
  }

  // ── Ansicht: verbunden (Stift-Daten einfach zeigen) ─────────────────────────
  List<Widget> _connectedChildren() {
    return [
      const Column(
        children: [
          Icon(Icons.verified_rounded,
              color: MerchantPremiumColors.gold, size: 50),
          SizedBox(height: 8),
          Text(
            'Stempelstift verbunden',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MerchantPremiumColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.tag_rounded,
              label: 'Serien-Nr.',
              value: _serial(_card.boundStickId),
            ),
            const _RowGap(),
            _InfoRow(
              icon: Icons.nfc_rounded,
              label: 'Typ',
              value: _typeLabel(_card.stickType),
            ),
            const _RowGap(),
            const _InfoRow(
              icon: Icons.check_circle_rounded,
              label: 'Status',
              value: 'Aktiv',
              valueColor: MerchantPremiumColors.gold,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      MerchantSecondaryButton(
        label: 'Anderen Stift verbinden',
        icon: Icons.autorenew_rounded,
        onPressed: _busy
            ? null
            : () => setState(() {
                  _rebinding = true;
                  _error = null;
                }),
      ),
      const SizedBox(height: AppSpacing.sm),
      FilledButton(
        onPressed: () => Navigator.of(context).maybePop(),
        style: FilledButton.styleFrom(
          backgroundColor: MerchantPremiumColors.ink,
          foregroundColor: MerchantPremiumColors.base,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: const Text('Fertig'),
      ),
    ];
  }

  String _serial(String raw) {
    if (raw.isEmpty) return '—';
    final up = raw.toUpperCase();
    return up.length <= 20 ? up : '${up.substring(0, 20)}…';
  }

  String _typeLabel(String type) {
    return switch (type) {
      'ntag424' || 'ntag' => 'NFC-Stift (NTAG 424)',
      'static' => 'Lokka-Stift',
      _ => 'Stempelstift',
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cardTitle});
  final String cardTitle;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final name =
        cardTitle.isEmpty ? texts.text('merchant.stamps.untitled') : cardTitle;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: MerchantPremiumColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MerchantPremiumColors.line),
          ),
          child: const Icon(Icons.nfc_rounded, color: MerchantPremiumColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stempelstift verbinden',
                style: TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                'Für: $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kleiner Schritt-Indikator „① Stift scannen · ② Fertig".
class _MiniStepper extends StatelessWidget {
  const _MiniStepper();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _StepDot(number: '1', label: 'Stift scannen', active: true),
        _StepConnector(),
        _StepDot(number: '2', label: 'Fertig', active: false),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot(
      {required this.number, required this.label, required this.active});
  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? MerchantPremiumColors.gold : MerchantPremiumColors.muted;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? MerchantPremiumColors.goldSoft
                : MerchantPremiumColors.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Text(number,
              style: TextStyle(
                  color: active ? MerchantPremiumColors.mint : color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: MerchantPremiumColors.line,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = MerchantPremiumColors.ink,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: MerchantPremiumColors.muted),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w800)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _RowGap extends StatelessWidget {
  const _RowGap();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, color: MerchantPremiumColors.line),
    );
  }
}

class _BusyRow extends StatelessWidget {
  const _BusyRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: MerchantPremiumColors.gold),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text('Kamera wird geöffnet …',
              style: TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: MerchantPremiumColors.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: MerchantPremiumColors.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: MerchantPremiumColors.danger, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontWeight: FontWeight.w800,
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parses an admin-minted bind code `lokka-stick-a:{stickId}:{claim}` (also
/// tolerates a wrapping URL with the value in an `s` query param).
/// Returns (stickId, claimToken) or null.
(String, String)? _parseClaimQr(String raw) {
  var value = raw.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && uri.queryParameters['s'] != null) {
    value = uri.queryParameters['s']!;
  }
  if (!value.startsWith('lokka-stick-a:')) return null;
  final parts = value.substring('lokka-stick-a:'.length).split(':');
  if (parts.length != 2) return null;
  final id = parts[0].toLowerCase().replaceAll(RegExp('[^0-9a-z]'), '');
  final claim = parts[1].toLowerCase().replaceAll(RegExp('[^0-9a-f]'), '');
  if (id.length < 4 || claim.length < 8) return null;
  return (id, claim);
}
