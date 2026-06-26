import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/firebasePaths.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/theme/appSpacing.dart';
import '../../merchant/shared/widgets/merchantPremiumUi.dart';
import '../../merchant/stamps/models/stampCardModel.dart';
import '../../merchant/tools/widgets/merchantToolUi.dart';
import '../services/appLinkBase.dart';
import '../services/nfcService.dart';
import '../services/stampFunctionsService.dart';
import 'stampScanner.dart';

/// "Stempelstift einrichten" for the currently visible card. Opens a guided
/// sheet that picks the right path for the device:
///   • Path A (Android Chrome / Web NFC): write a signed static link onto a
///     blank tag in the browser, then a Test-Tap verifies it.
///   • Path B (iPhone / desktop / no Web NFC): bind a pre-provisioned NTAG 424
///     stick by scanning its printed QR, then a Test-Tap (NFC read or QR
///     re-scan) verifies it.
/// The badge flips to "Stift verbunden ✓" only after a successful Test-Tap.
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

enum _Step { intro, testTap, done }

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
  final NfcService _nfc = createNfcService();

  _Step _step = _Step.intro;
  bool _busy = false;
  String? _error;
  String? _status;

  // Which path bound the stick — drives the Test-Tap UI (Path B also offers a
  // QR re-scan verification for devices without Web NFC).
  String _path = ''; // 'static' | 'ntag'

  // Cached static deep link for the copy affordance — the exact URL that would
  // be written onto the tag. Created lazily on first copy and reused.
  String _copyUrl = '';
  bool _copying = false;

  StampCardModel get _card => widget.card;
  bool get _nfcSupported => _nfc.isSupported;

  // ── Path A — write a static link in the browser ────────────────────────────
  Future<void> _writeStatic() async {
    final texts = context.read<LanguageService>();
    setState(() {
      _busy = true;
      _error = null;
      _status = texts.text('merchant.stick.creating');
    });
    try {
      final stick = await widget.functions.createStaticStick(cardId: _card.id);
      if (stick.token.isEmpty) throw Exception('empty-token');
      final url = _deepLink('/s/${stick.token}');
      if (!mounted) return;
      setState(() => _status = texts.text('merchant.stick.holdToWrite'));
      await _nfc.writeUrl(url);
      if (!mounted) return;
      setState(() {
        _path = 'static';
        _busy = false;
        _status = null;
        _step = _Step.testTap;
      });
    } on NfcError catch (e) {
      _fail(texts.text(e.textKey));
    } catch (e) {
      _fail(texts.text(stampErrorKey(e)));
    }
  }

  // ── Path B — bind a pre-provisioned stick via its printed QR ───────────────
  Future<void> _bindDelivered() async {
    final texts = context.read<LanguageService>();
    var boundUid = '';
    await showStampScanner(
      context,
      title: texts.text('merchant.stick.setupTitle'),
      hint: texts.text('merchant.stick.scanHint'),
      manualLabel: texts.text('merchant.stick.manualLabel'),
      onConfirm: (raw) async {
        final parsed = _parseStickQr(raw);
        if (parsed == null) {
          return StampScanOutcome.fail(texts.text('merchant.stick.invalidQr'));
        }
        try {
          await widget.functions.setupStick(
            tagUid: parsed.$1,
            provToken: parsed.$2,
            cardId: _card.id,
          );
          boundUid = parsed.$1;
          return StampScanOutcome.ok(
            texts.text('merchant.stick.boundReady'),
          );
        } catch (e) {
          return StampScanOutcome.fail(texts.text(stampErrorKey(e)));
        }
      },
    );
    if (!mounted || boundUid.isEmpty) return;
    setState(() {
      _path = 'ntag';
      _error = null;
      _step = _Step.testTap;
    });
  }

  // ── Workshop claim — bind an admin-minted static stick via its claim QR ─────
  Future<void> _claimWorkshopStick() async {
    final texts = context.read<LanguageService>();
    StaticStick? claimed;
    await showStampScanner(
      context,
      title: 'Werkstatt-Stift einlösen',
      hint: 'Scanne den Claim-QR (lokka-stick-a:…) vom vorbereiteten Stift.',
      manualLabel: texts.text('merchant.stick.manualLabel'),
      onConfirm: (raw) async {
        final parsed = _parseClaimQr(raw);
        if (parsed == null) {
          return StampScanOutcome.fail(texts.text('merchant.stick.invalidQr'));
        }
        try {
          final stick = await widget.functions.claimStaticStick(
            stickId: parsed.$1,
            claimToken: parsed.$2,
            cardId: _card.id,
          );
          if (stick.token.isEmpty) {
            return StampScanOutcome.fail(
                texts.text('merchant.stampScan.err.unreachable'));
          }
          claimed = stick;
          return const StampScanOutcome.ok(
              'Stift verbunden – jetzt aufschreiben.');
        } catch (e) {
          return StampScanOutcome.fail(texts.text(stampErrorKey(e)));
        }
      },
    );
    final stick = claimed;
    if (!mounted || stick == null) return;
    final url = _deepLink('/s/${stick.token}');
    if (_nfcSupported) {
      setState(() {
        _path = 'static';
        _busy = true;
        _error = null;
        _status = texts.text('merchant.stick.holdToWrite');
      });
      try {
        await _nfc.writeUrl(url);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = null;
          _step = _Step.testTap;
        });
      } on NfcError catch (e) {
        _fail(texts.text(e.textKey));
      } catch (e) {
        _fail(texts.text(stampErrorKey(e)));
      }
    } else {
      // No Web NFC: hand over the signed link to write with any NFC-writer app.
      _copyUrl = url;
      setState(() => _path = 'static');
      await _showLinkDialog(url);
    }
  }

  // ── Test-Tap — read the tag (Web NFC) and verify it points at THIS card ─────
  Future<void> _testTapNfc() async {
    final texts = context.read<LanguageService>();
    setState(() {
      _busy = true;
      _error = null;
      _status = texts.text('merchant.stick.holdToTest');
    });
    try {
      final url = await _nfc.readUrl();
      if (url == null) {
        _fail(texts.text('merchant.stick.nfc.errNotFound'));
        return;
      }
      final ok = await _verifyFromUrl(url);
      if (!mounted) return;
      if (ok) {
        _succeed();
      } else {
        _fail(texts.text('merchant.stampScan.err.wrong-card'));
      }
    } on NfcError catch (e) {
      _fail(texts.text(e.textKey));
    } catch (e) {
      _fail(texts.text(stampErrorKey(e)));
    }
  }

  /// Path B fallback (no Web NFC): re-scan the printed QR to verify the binding.
  Future<void> _testTapQr() async {
    final texts = context.read<LanguageService>();
    var ok = false;
    await showStampScanner(
      context,
      title: texts.text('merchant.stick.testTitle'),
      hint: texts.text('merchant.stick.testQrHint'),
      manualLabel: texts.text('merchant.stick.manualLabel'),
      onConfirm: (raw) async {
        final parsed = _parseStickQr(raw);
        if (parsed == null) {
          return StampScanOutcome.fail(texts.text('merchant.stick.invalidQr'));
        }
        try {
          ok = await widget.functions.verifyStickBinding(
            cardId: _card.id,
            tagUid: parsed.$1,
            provToken: parsed.$2,
          );
          return ok
              ? StampScanOutcome.ok(texts.text('merchant.stick.verified'))
              : StampScanOutcome.fail(texts.text('merchant.stampScan.err.wrong-card'));
        } catch (e) {
          return StampScanOutcome.fail(texts.text(stampErrorKey(e)));
        }
      },
    );
    if (!mounted) return;
    if (ok) _succeed();
  }

  Future<bool> _verifyFromUrl(String url) async {
    var uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    // Hash URL strategy: the real route lives in the fragment
    // (`…/#/s/<token>` or `…/#/stamp?picc=…&cmac=…`). Re-parse it as the route
    // so token/query land where we read them. Non-hash links fall through.
    if (uri.fragment.isNotEmpty) {
      final frag = uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
      final fragUri = Uri.tryParse(frag);
      if (fragUri != null) uri = fragUri;
    }
    // Path A — …/s/<token>
    final segs = uri.pathSegments;
    final sIdx = segs.indexOf('s');
    if (sIdx >= 0 && sIdx + 1 < segs.length) {
      return widget.functions
          .verifyStickBinding(cardId: _card.id, token: segs[sIdx + 1]);
    }
    // Path B — ?picc=…&cmac=…
    final picc = uri.queryParameters['picc'];
    final cmac = uri.queryParameters['cmac'];
    if ((picc ?? '').isNotEmpty && (cmac ?? '').isNotEmpty) {
      return widget.functions
          .verifyStickBinding(cardId: _card.id, picc: picc, cmac: cmac);
    }
    return false;
  }

  /// Copies the signed stick link to the clipboard. Creates a static stick on
  /// first use (cached afterwards) so the copied URL is the same one a tap would
  /// open. Works regardless of Web NFC support.
  /// Builds the signed link (server round-trip), then opens a dialog showing it.
  /// The copy happens inside the dialog button's own gesture (reliable even in
  /// Incognito), and the link is always selectable for manual copy — so this
  /// never silently fails.
  Future<void> _copyLink() async {
    if (_copying) return;
    final texts = context.read<LanguageService>();
    final messenger = ScaffoldMessenger.of(context);
    final firestore = context.read<FirestoreService>();
    setState(() => _copying = true);
    String? errorKey;
    try {
      if (_copyUrl.isEmpty) {
        // Fast path: the link was already prepared at publish — build it locally,
        // no server call, no clipboard-timing issue.
        if (_card.staticToken.isNotEmpty) {
          _copyUrl = _deepLink('/s/${_card.staticToken}');
        } else {
          // Older card without a prepared link: fetch once, then persist so it's
          // instant from now on.
          final stick = await widget.functions.createStaticStick(cardId: _card.id);
          if (stick.token.isEmpty) {
            errorKey = 'merchant.stampScan.err.unreachable';
          } else {
            _copyUrl = _deepLink('/s/${stick.token}');
            await _persistToken(firestore, stick.token);
          }
        }
      }
    } catch (e) {
      errorKey = stampErrorKey(e);
    } finally {
      if (mounted) setState(() => _copying = false);
    }
    if (!mounted) return;
    if (errorKey != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(texts.text(errorKey)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await _showLinkDialog(_copyUrl);
  }

  /// Persists the prepared token on the card so the next copy is instant.
  Future<void> _persistToken(FirestoreService firestore, String token) async {
    try {
      await firestore.setDocument(
        FirebasePaths.merchantStampCard(_card.merchantId, _card.id),
        {'staticToken': token},
        merge: true,
      );
      widget.onChanged();
    } catch (_) {}
  }

  /// Shows the signed link with a Copy button + selectable text (manual copy
  /// fallback). Writing to NFC happens via any NFC-writer app.
  Future<void> _showLinkDialog(String url) {
    final texts = context.read<LanguageService>();
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MerchantPremiumColors.surface,
        title: Text(texts.text('merchant.stick.copyLink'),
            style: const TextStyle(color: MerchantPremiumColors.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texts.text('merchant.stick.copyManual'),
                style: const TextStyle(
                    color: MerchantPremiumColors.muted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MerchantPremiumColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MerchantPremiumColors.line),
              ),
              child: SelectableText(url,
                  style: const TextStyle(
                      color: MerchantPremiumColors.ink, fontSize: 13)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(texts.text('common.done')),
          ),
          FilledButton.icon(
            onPressed: () async {
              final ok = await _safeClipboard(url);
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text(texts.text(ok
                    ? 'merchant.stick.linkCopied'
                    : 'merchant.stick.copyManual')),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ));
            },
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: Text(texts.text('merchant.stick.copyLink')),
          ),
        ],
      ),
    );
  }

  Future<bool> _safeClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Absolute deep link for an in-app route, built from the document `<base href>`
  /// so it respects the deployed sub-folder (`/lokka/`) and the **path** URL
  /// strategy (routes have no `#`). e.g. `https://jajehelp.com/lokka/s/<token>`.
  String _deepLink(String route) {
    final r = route.startsWith('/') ? route.substring(1) : route;
    final base = appLinkBase();
    if (base.isNotEmpty) {
      return base.endsWith('/') ? '$base$r' : '$base/$r';
    }
    // Fallback (no base href available): same-origin absolute path.
    return '${Uri.base.origin}/$r';
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = null;
      _error = message;
    });
  }

  void _succeed() {
    widget.onChanged();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = null;
      _error = null;
      _step = _Step.done;
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
            // Target card — unambiguous which card the stick binds to. The mini
            // copy icon copies the exact signed link a tap would open.
            _TargetHeader(
              card: _card,
              texts: texts,
              onCopy: _step == _Step.done ? null : _copyLink,
              copying: _copying,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_busy) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: MerchantPremiumColors.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status ?? texts.text('common.loading'),
                      style: const TextStyle(
                          color: MerchantPremiumColors.ink,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            ...switch (_step) {
              _Step.intro => _introChildren(texts),
              _Step.testTap => _testChildren(texts),
              _Step.done => _doneChildren(texts),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _introChildren(LanguageService texts) {
    return [
      if (_nfcSupported) ...[
        _PathCard(
          icon: Icons.nfc_rounded,
          title: texts.text('merchant.stick.pathA.title'),
          body: texts.text('merchant.stick.pathA.body'),
          actionLabel: texts.text('merchant.stick.write'),
          onAction: _busy ? null : _writeStatic,
          primary: true,
        ),
        const SizedBox(height: AppSpacing.md),
        _PathCard(
          icon: Icons.local_shipping_rounded,
          title: texts.text('merchant.stick.pathB.title'),
          body: texts.text('merchant.stick.pathB.body'),
          actionLabel: texts.text('merchant.stick.bindDelivered'),
          onAction: _busy ? null : _bindDelivered,
        ),
      ] else ...[
        _InfoBanner(
          icon: Icons.info_outline_rounded,
          message: texts.text('merchant.stick.nfcUnavailable'),
        ),
        const SizedBox(height: AppSpacing.md),
        _PathCard(
          icon: Icons.local_shipping_rounded,
          title: texts.text('merchant.stick.pathB.title'),
          body: texts.text('merchant.stick.pathB.body'),
          actionLabel: texts.text('merchant.stick.bindDelivered'),
          onAction: _busy ? null : _bindDelivered,
          primary: true,
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      _PathCard(
        icon: Icons.inventory_2_rounded,
        title: 'Aus Lokka-Werkstatt',
        body: 'Vorbereiteter Stift mit Claim-QR? Hier scannen und mit dieser '
            'Karte verbinden.',
        actionLabel: 'Werkstatt-Stift scannen',
        onAction: _busy ? null : _claimWorkshopStick,
      ),
    ];
  }

  List<Widget> _testChildren(LanguageService texts) {
    return [
      _InfoBanner(
        icon: Icons.touch_app_rounded,
        message: texts.text('merchant.stick.testIntro'),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_nfcSupported)
        MerchantPrimaryButton(
          label: texts.text('merchant.stick.testNow'),
          icon: Icons.nfc_rounded,
          onPressed: _busy ? null : _testTapNfc,
        ),
      // Path B always offers the QR re-scan verification (works without NFC).
      if (_path == 'ntag') ...[
        if (_nfcSupported) const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _busy ? null : _testTapQr,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
          label: Text(texts.text('merchant.stick.testViaQr')),
          style: OutlinedButton.styleFrom(
            foregroundColor: MerchantPremiumColors.ink,
            side: const BorderSide(color: MerchantPremiumColors.line),
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
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
  const _TargetHeader({
    required this.card,
    required this.texts,
    this.onCopy,
    this.copying = false,
  });
  final StampCardModel card;
  final LanguageService texts;
  final VoidCallback? onCopy;
  final bool copying;

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
        if (onCopy != null)
          IconButton(
            onPressed: copying ? null : onCopy,
            tooltip: texts.text('merchant.stick.copyLink'),
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: copying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: MerchantPremiumColors.muted),
                  )
                : const Icon(Icons.content_copy_rounded,
                    color: MerchantPremiumColors.muted),
          ),
      ],
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primary ? MerchantPremiumColors.gold : MerchantPremiumColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: MerchantPremiumColors.gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
                color: MerchantPremiumColors.muted,
                fontWeight: FontWeight.w700,
                height: 1.3),
          ),
          const SizedBox(height: AppSpacing.md),
          if (primary)
            MerchantPrimaryButton(
              label: actionLabel,
              icon: icon,
              onPressed: onAction,
            )
          else
            OutlinedButton.icon(
              onPressed: onAction,
              icon: Icon(icon, size: 18),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: MerchantPremiumColors.ink,
                side: const BorderSide(color: MerchantPremiumColors.line),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
      ),
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
        border: Border.all(color: MerchantPremiumColors.danger.withValues(alpha: 0.5)),
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

/// Parses `lokka-stick:{uidHex}:{provTokenHex}` (also tolerates a wrapping URL
/// with the same value in an `s` query param). Returns (uid, token) or null.
(String, String)? _parseStickQr(String raw) {
  var value = raw.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && uri.queryParameters['s'] != null) {
    value = uri.queryParameters['s']!;
  }
  if (!value.startsWith('lokka-stick:')) return null;
  final parts = value.substring('lokka-stick:'.length).split(':');
  if (parts.length != 2) return null;
  final uid = parts[0].toLowerCase().replaceAll(RegExp('[^0-9a-f]'), '');
  final token = parts[1].toLowerCase().replaceAll(RegExp('[^0-9a-f]'), '');
  if (uid.length < 8 || token.length < 8) return null;
  return (uid, token);
}

/// Parses an admin-minted Path-A claim code `lokka-stick-a:{stickId}:{claim}`
/// (also tolerates a wrapping URL with the value in an `s` query param).
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
