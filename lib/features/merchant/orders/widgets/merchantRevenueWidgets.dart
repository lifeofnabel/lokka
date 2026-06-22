import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../../public/shop/services/publicShopService.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../services/merchantOrdersService.dart';

/// Kompakter Tagesumsatz-Indikator auf der Katalog-Seite.
///
/// Nur im Runner-Modus sichtbar (sonst rendert das Widget nichts). Zeigt den
/// heutigen Umsatz (≈ – bezahlte Bestellungen ohne die während einer Pause
/// abgeschlossenen), erlaubt das Pausieren des Tageszählers und führt per Tipp
/// zur Finanzseite.
class MerchantTagesumsatz extends StatefulWidget {
  const MerchantTagesumsatz({super.key});

  @override
  State<MerchantTagesumsatz> createState() => _MerchantTagesumsatzState();
}

class _MerchantTagesumsatzState extends State<MerchantTagesumsatz> {
  bool _loading = true;
  bool _visible = false; // nur Runner-Modus
  bool _paused = false;
  bool _busy = false;
  num _total = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Services vor dem ersten await greifen (Context danach evtl. ungültig).
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final config = await PublicShopService(firestoreService: firestore)
          .loadCatalogConfig(uid);
      if (!config.modeRunner) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final service = MerchantOrdersService(
        authService: auth,
        firestoreService: firestore,
      );
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final paid = await service.loadPaidOrdersBetween(startOfDay, null);
      final counted = paid.where((order) => !order.excludeFromDaily).toList();
      final paused = await service.loadRevenuePaused();
      if (!mounted) return;
      setState(() {
        _visible = true;
        _paused = paused;
        _total = counted.fold<num>(0, (acc, order) => acc + order.totalPrice);
        _count = counted.length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePause() async {
    if (_busy) return;
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final service = MerchantOrdersService(
      authService: auth,
      firestoreService: context.read<FirestoreService>(),
    );
    setState(() => _busy = true);
    final next = !_paused;
    try {
      await service.setRevenuePaused(next);
      if (mounted) setState(() => _paused = next);
    } catch (_) {
      // Pause ist unkritisch – Fehler still verschlucken.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_visible) return const SizedBox.shrink();
    final texts = context.watch<LanguageService>();
    final euro = texts.text('common.euro');
    final amount = '${_total.toStringAsFixed(2).replaceAll('.', ',')} $euro';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MerchantPremiumCard(
        onTap: () => context.push('/merchant/finance'),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const MerchantPremiumIconBox(
              icon: Icons.payments_rounded,
              size: 50,
              iconSize: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.text('merchant.finance.dailyTitle'),
                    style: const TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    amount,
                    style: const TextStyle(
                      color: MerchantPremiumColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _paused
                        ? texts.text('merchant.finance.paused')
                        : '$_count ${texts.text('merchant.finance.orders')}',
                    style: TextStyle(
                      color: _paused
                          ? MerchantPremiumColors.warning
                          : MerchantPremiumColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _PauseButton(
              paused: _paused,
              busy: _busy,
              onTap: _togglePause,
              tooltip: texts.text(
                _paused ? 'merchant.finance.resume' : 'merchant.finance.pause',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pause/Weiter-Schaltfläche für den Tageszähler (umschließt seinen eigenen
/// Tap, damit der Karten-Tap zur Finanzseite nicht ausgelöst wird).
class _PauseButton extends StatelessWidget {
  const _PauseButton({
    required this.paused,
    required this.busy,
    required this.onTap,
    required this.tooltip,
  });

  final bool paused;
  final bool busy;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final color =
        paused ? MerchantPremiumColors.warning : MerchantPremiumColors.muted;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: color,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}
