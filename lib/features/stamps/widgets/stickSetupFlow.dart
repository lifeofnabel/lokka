import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../../../core/theme/appSpacing.dart';
import '../../merchant/shared/widgets/merchantPremiumUi.dart';
import '../../merchant/stamps/models/stampCardModel.dart';
import '../../merchant/tools/widgets/merchantToolUi.dart';
import '../services/stampFunctionsService.dart';
import 'stampScanner.dart';

/// "Stempelstift verbinden" — the merchant scans the bind-QR that shipped with
/// the (owner-provisioned) stick and links it to [card]. No NFC writing, no
/// test-tap: the owner already wrote the fixed link onto the tag in the Godmode
/// workshop, so a successful scan means the stick is ready to use immediately.
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
  bool _done = false;
  String? _error;

  StampCardModel get _card => widget.card;

  /// Scan the delivered bind-QR (`lokka-stick-a:<id>:<claim>`) and bind the
  /// stick to THIS card. The tag is already written, so a successful bind is all
  /// that's needed — the badge flips to "Stift verbunden ✓" right away.
  Future<void> _scanAndBind() async {
    final texts = context.read<LanguageService>();
    var bound = false;
    await showStampScanner(
      context,
      title: 'Stift verbinden',
      hint: 'Scanne den mitgelieferten QR-Code (lokka-stick-a:…).',
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
          bound = true;
          return const StampScanOutcome.ok('Stift verbunden ✓');
        } catch (e) {
          return StampScanOutcome.fail(texts.text(stampErrorKey(e)));
        }
      },
    );
    if (!mounted || !bound) return;
    widget.onChanged();
    setState(() {
      _done = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TargetHeader(card: _card, texts: texts),
            const SizedBox(height: AppSpacing.md),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_done) ..._doneChildren(texts) else ..._introChildren(texts),
          ],
        ),
      ),
    );
  }

  List<Widget> _introChildren(LanguageService texts) {
    return [
      const _InfoBanner(
        icon: Icons.qr_code_scanner_rounded,
        message: 'Dein Stift kam mit einem QR-Code. Scanne ihn, um den Stift mit '
            'dieser Stempelkarte zu verbinden — fertig.',
      ),
      const SizedBox(height: AppSpacing.md),
      MerchantPrimaryButton(
        label: 'QR-Code scannen',
        icon: Icons.qr_code_scanner_rounded,
        onPressed: _scanAndBind,
      ),
    ];
  }

  List<Widget> _doneChildren(LanguageService texts) {
    return [
      Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: MerchantPremiumColors.gold, size: 52),
          const SizedBox(height: 10),
          Text(
            texts.text('merchant.stick.doneTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            texts.text('merchant.stick.doneBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.35),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        onPressed: () => Navigator.of(context).maybePop(),
        style: FilledButton.styleFrom(
          backgroundColor: MerchantPremiumColors.ink,
          foregroundColor: MerchantPremiumColors.base,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: Text(texts.text('common.done')),
      ),
    ];
  }
}

class _TargetHeader extends StatelessWidget {
  const _TargetHeader({required this.card, required this.texts});
  final StampCardModel card;
  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
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
              Text(
                texts.text('merchant.stick.setup'),
                style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                '${texts.text('merchant.stick.forCard')}: ${card.title.isEmpty ? texts.text('merchant.stamps.untitled') : card.title}',
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
