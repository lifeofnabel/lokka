import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/alert/orderAlert.dart';
import '../../../../core/cache/localCacheStorage.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/services/languageService.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';
import '../models/orderModel.dart';
import '../providers/merchantOrdersProvider.dart';
import '../services/merchantOrdersService.dart';
import '../widgets/orderCard.dart';
import '../widgets/orderDetailPanel.dart';

/// Ab dieser Breite zeigt die Seite Liste links + Detail rechts (Split-View).
const double kOrdersSplitWidth = 900;

class MerchantOrdersPage extends StatelessWidget {
  const MerchantOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MerchantOrdersProvider(
        service: MerchantOrdersService(
          authService: context.read<AuthService>(),
          firestoreService: context.read<FirestoreService>(),
        ),
      )..watch(),
      child: const _MerchantOrdersView(),
    );
  }
}

class _MerchantOrdersView extends StatefulWidget {
  const _MerchantOrdersView();

  @override
  State<_MerchantOrdersView> createState() => _MerchantOrdersViewState();
}

class _MerchantOrdersViewState extends State<_MerchantOrdersView> {
  String? _selectedId;

  // Neue-Bestellung-Alarm (Ton + Banner). Einstellungen pro Gerät.
  bool _muted = false;
  bool _ringLoop = true; // true = klingeln bis berührt, false = einmal
  bool _alerting = false;
  int _lastSignal = 0;
  Timer? _beepTimer;

  // Sound-Einstellungen: 1=einmal, 2=zweimal, 3=dreimal; Lautstärke 1–3.
  int _soundType = 1; // 1=Glocke, 2=Doppel, 3=Alarm
  int _volumeLevel = 2; // 1=Leise, 2=Mittel, 3=Laut

  static const _muteKey = 'lokka_orders_muted';
  static const _ringLoopKey = 'lokka_orders_ringloop';
  static const _soundTypeKey = 'lokka_orders_soundtype';
  static const _volumeKey = 'lokka_orders_volume';

  @override
  void initState() {
    super.initState();
    _loadAlertPrefs();
  }

  Future<void> _loadAlertPrefs() async {
    final muted = await LocalCacheStorage.read(_muteKey);
    final loop = await LocalCacheStorage.read(_ringLoopKey);
    final soundType = await LocalCacheStorage.read(_soundTypeKey);
    final volume = await LocalCacheStorage.read(_volumeKey);
    if (!mounted) return;
    setState(() {
      _muted = muted == '1';
      _ringLoop = loop == null ? true : loop == '1';
      _soundType = int.tryParse(soundType ?? '1') ?? 1;
      _volumeLevel = int.tryParse(volume ?? '2') ?? 2;
    });
    _applyVolume();
  }

  void _applyVolume() {
    const volumes = [0.2, 0.5, 1.0];
    OrderAlert.setVolume(volumes[(_volumeLevel - 1).clamp(0, 2)]);
  }

  @override
  void dispose() {
    _beepTimer?.cancel();
    super.dispose();
  }

  void _playSound() {
    OrderAlert.playTone();
    if (_soundType >= 2) {
      Future.delayed(const Duration(milliseconds: 180), OrderAlert.playTone);
    }
    if (_soundType >= 3) {
      Future.delayed(const Duration(milliseconds: 360), OrderAlert.playTone);
    }
  }

  void _triggerAlert() {
    if (_muted || !mounted) return;
    final texts = context.read<LanguageService>();
    OrderAlert.prime();
    if (OrderAlert.isPageHidden()) {
      OrderAlert.showNotification(
        texts.text('merchant.orders.alertTitle'),
        texts.text('merchant.orders.alertBody'),
      );
    }
    _playSound();
    setState(() => _alerting = true);
    _beepTimer?.cancel();
    if (_ringLoop) {
      _beepTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        if (_muted || !mounted) {
          _acknowledge();
          return;
        }
        _playSound();
      });
    } else {
      Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _alerting = false);
      });
    }
  }

  void _acknowledge() {
    _beepTimer?.cancel();
    _beepTimer = null;
    if (_alerting && mounted) setState(() => _alerting = false);
  }

  void _toggleMute() {
    // Geste nutzen, um Audio/Benachrichtigungen scharf zu machen (Autoplay).
    OrderAlert.prime();
    OrderAlert.ensurePermission();
    setState(() => _muted = !_muted);
    LocalCacheStorage.write(_muteKey, _muted ? '1' : '0');
    if (_muted) _acknowledge();
  }

  Future<void> _openRingModeSheet() async {
    final texts = context.read<LanguageService>();
    final choice = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: MerchantPremiumColors.baseElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(
              texts.text('merchant.orders.alertModeTitle'),
              style: const TextStyle(
                color: MerchantPremiumColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.notifications_active_rounded,
                  color: MerchantPremiumColors.gold),
              title: Text(
                texts.text('merchant.orders.alertModeLoop'),
                style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w800),
              ),
              trailing: _ringLoop
                  ? const Icon(Icons.check_rounded,
                      color: MerchantPremiumColors.gold)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none_rounded,
                  color: MerchantPremiumColors.muted),
              title: Text(
                texts.text('merchant.orders.alertModeOnce'),
                style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontWeight: FontWeight.w800),
              ),
              trailing: !_ringLoop
                  ? const Icon(Icons.check_rounded,
                      color: MerchantPremiumColors.gold)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _ringLoop = choice);
    LocalCacheStorage.write(_ringLoopKey, choice ? '1' : '0');
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<MerchantOrdersProvider>();

    // Neue Bestellung erkannt → Alarm nach dem Frame auslösen.
    final signal = provider.newOrderSignal;
    if (signal != _lastSignal) {
      _lastSignal = signal;
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerAlert());
    }

    return MerchantToolScaffold(
      title: texts.text('merchant.orders.title'),
      subtitle: texts.text('merchant.orders.subtitle'),
      backPath: '/merchant/catalog',
      // Glocke (stummschalten) + Tisch-Einsicht + Info, oben rechts.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MuteBell(
            muted: _muted,
            onTap: _toggleMute,
            onLongPress: _openRingModeSheet,
            tooltip: texts.text(_muted
                ? 'merchant.orders.alertUnmute'
                : 'merchant.orders.alertMute'),
          ),
          const SizedBox(width: 8),
          _TableViewAction(count: provider.tableGroups.length),
          const SizedBox(width: 8),
          MerchantInfoTooltip(message: texts.text('merchant.orders.tooltip')),
        ],
      ),
      child: Listener(
        // Jede Berührung stoppt den (wiederholenden) Alarm.
        onPointerDown: (_) {
          OrderAlert.prime();
          if (_alerting) _acknowledge();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_alerting) ...[
              _AlertBanner(texts: texts, onTap: _acknowledge),
              const SizedBox(height: AppSpacing.md),
            ],
            _ControlBox(provider: provider),
            const SizedBox(height: AppSpacing.sm),
            _SoundBar(
              soundType: _soundType,
              volumeLevel: _volumeLevel,
              onSoundType: (v) {
                setState(() => _soundType = v);
                LocalCacheStorage.write(_soundTypeKey, v.toString());
              },
              onVolumeLevel: (v) {
                setState(() => _volumeLevel = v);
                LocalCacheStorage.write(_volumeKey, v.toString());
                _applyVolume();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _ordersArea(context, provider, texts),
          ],
        ),
      ),
    );
  }

  Widget _ordersArea(
    BuildContext context,
    MerchantOrdersProvider provider,
    LanguageService texts,
  ) {
    if (provider.isLoading) return const MerchantLoadingCards(count: 5);
    if (provider.error != null) {
      return MerchantErrorState(
          message: provider.error!, onRetry: () => provider.watch());
    }
    if (provider.visibleOrders.isEmpty) {
      return MerchantEmptyState(
        title: texts.text('merchant.orders.emptyTitle'),
        message: texts.text('merchant.orders.emptyMessage'),
        actionLabel: texts.text('merchant.catalog.title'),
        onAction: () => context.push('/merchant/catalog'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kOrdersSplitWidth;
        final cards = [
          for (final order in provider.visibleOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OrderCard(
                order: order,
                runnerName: provider.runnerNameOf(order.runnerId),
                onTap: wide
                    ? () => setState(() => _selectedId = order.id)
                    : () => context.push('/merchant/orders/${order.id}'),
                onAccept: order.status == 'new'
                    ? () => provider.updateStatus(order.id, 'preparing')
                    : null,
                onDone: order.status == 'preparing'
                    ? () => provider.updateStatus(order.id, 'done')
                    : null,
                onCancel: order.status == 'done' || order.status == 'cancelled'
                    ? null
                    : () => provider.updateStatus(order.id, 'cancelled'),
              ),
            ),
        ];
        if (!wide) return Column(children: cards);

        OrderModel? selected;
        for (final order in provider.orders) {
          if (order.id == _selectedId) {
            selected = order;
            break;
          }
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: Column(children: cards)),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: selected == null
                  ? _SelectHint(texts: texts)
                  : OrderDetailPanel(
                      order: selected,
                      isSaving: provider.isSaving,
                      onAccept: () => provider.updateStatus(selected!.id, 'preparing'),
                      onDone: () => provider.updateStatus(selected!.id, 'done'),
                      onCancel: () => provider.updateStatus(selected!.id, 'cancelled'),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Platzhalter im Detail-Panel, solange keine Bestellung ausgewählt ist.
class _SelectHint extends StatelessWidget {
  const _SelectHint({required this.texts});

  final LanguageService texts;

  @override
  Widget build(BuildContext context) {
    return MerchantPremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          const MerchantPremiumIconBox(
            icon: Icons.touch_app_rounded,
            size: 52,
            iconSize: 24,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            texts.text('merchant.orders.selectHint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MerchantPremiumColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tisch-Einsicht als kompakte Aktion oben rechts (neben dem Info-Tooltip):
/// rundes Icon im Tooltip-Stil + kleine Anzahl-Badge; öffnet die Tisch-Einsicht.
class _TableViewAction extends StatelessWidget {
  const _TableViewAction({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    return Tooltip(
      message: texts.text('merchant.orders.tableView'),
      triggerMode: TooltipTriggerMode.tap,
      child: InkWell(
        onTap: () => context.push('/merchant/orders/tables'),
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: MerchantPremiumColors.line),
              ),
              child: const Icon(
                Icons.table_restaurant_rounded,
                color: MerchantPremiumColors.ink,
                size: 18,
              ),
            ),
            if (count > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MerchantPremiumColors.gold,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: MerchantPremiumColors.base, width: 1.5),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: MerchantPremiumColors.base,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Suche + Datum-Filter + Status-Filter (Qoucher-Kontrollbox im Dark-Theme).
class _ControlBox extends StatelessWidget {
  const _ControlBox({required this.provider});

  final MerchantOrdersProvider provider;

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    // Reine Status-Filter (keine Datums-Filter mehr). „Alle" zeigt nur die
    // aktiven Bestellungen (Neue + In Bearbeitung).
    final statusOptions = {
      'all': texts.text('common.all'),
      'new': texts.text('merchant.orders.filter.new'),
      'preparing': texts.text('merchant.orders.filter.preparing'),
      'done': texts.text('merchant.orders.filter.done'),
      'cancelled': texts.text('merchant.orders.filter.cancelled'),
    };

    return MerchantPremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: provider.setSearch,
            style: const TextStyle(
              color: MerchantPremiumColors.ink,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: texts.text('merchant.orders.searchHint'),
              hintStyle: TextStyle(
                color: MerchantPremiumColors.muted.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: MerchantPremiumColors.muted),
              filled: true,
              fillColor: MerchantPremiumColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MerchantPremiumColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MerchantPremiumColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: MerchantPremiumColors.gold, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in statusOptions.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: entry.value,
                      selected: provider.filter == entry.key,
                      onTap: () => provider.setFilter(entry.key),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Glocke oben rechts: Tippen = stummschalten, lang drücken = Klingel-Modus.
class _MuteBell extends StatelessWidget {
  const _MuteBell({
    required this.muted,
    required this.onTap,
    required this.onLongPress,
    required this.tooltip,
  });

  final bool muted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: muted
                ? MerchantPremiumColors.surfaceAlt
                : MerchantPremiumColors.goldSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: MerchantPremiumColors.line),
          ),
          child: Icon(
            muted
                ? Icons.notifications_off_rounded
                : Icons.notifications_active_rounded,
            size: 18,
            color: muted ? MerchantPremiumColors.muted : MerchantPremiumColors.gold,
          ),
        ),
      ),
    );
  }
}

/// Auffälliges Banner bei neuer Bestellung – tippen stoppt den Alarm.
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.texts, required this.onTap});

  final LanguageService texts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MerchantPremiumColors.gold,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  color: MerchantPremiumColors.base),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texts.text('merchant.orders.alertTitle'),
                      style: const TextStyle(
                        color: MerchantPremiumColors.base,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      texts.text('merchant.orders.alertTapToStop'),
                      style: TextStyle(
                        color: MerchantPremiumColors.base.withValues(alpha: 0.8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.close_rounded, color: MerchantPremiumColors.base),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? MerchantPremiumColors.gold
          : MerchantPremiumColors.surfaceAlt,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? MerchantPremiumColors.gold
                  : MerchantPremiumColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? MerchantPremiumColors.base
                  : MerchantPremiumColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimale Sound-Einstellungsleiste: 3 Tonstile + 3 Lautstärken.
class _SoundBar extends StatelessWidget {
  const _SoundBar({
    required this.soundType,
    required this.volumeLevel,
    required this.onSoundType,
    required this.onVolumeLevel,
  });

  final int soundType;
  final int volumeLevel;
  final ValueChanged<int> onSoundType;
  final ValueChanged<int> onVolumeLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MerchantPremiumColors.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded,
              size: 16, color: MerchantPremiumColors.muted),
          const SizedBox(width: 8),
          _SoundChip(
            icon: Icons.notifications_rounded,
            selected: soundType == 1,
            tooltip: 'Einmal',
            onTap: () => onSoundType(1),
          ),
          const SizedBox(width: 6),
          _SoundChip(
            icon: Icons.notifications_active_rounded,
            selected: soundType == 2,
            tooltip: 'Zweimal',
            onTap: () => onSoundType(2),
          ),
          const SizedBox(width: 6),
          _SoundChip(
            icon: Icons.graphic_eq_rounded,
            selected: soundType == 3,
            tooltip: 'Dreimal',
            onTap: () => onSoundType(3),
          ),
          const Spacer(),
          const Icon(Icons.volume_up_rounded,
              size: 16, color: MerchantPremiumColors.muted),
          const SizedBox(width: 8),
          _SoundChip(
            icon: Icons.volume_mute_rounded,
            selected: volumeLevel == 1,
            tooltip: 'Leise',
            onTap: () => onVolumeLevel(1),
          ),
          const SizedBox(width: 6),
          _SoundChip(
            icon: Icons.volume_down_rounded,
            selected: volumeLevel == 2,
            tooltip: 'Mittel',
            onTap: () => onVolumeLevel(2),
          ),
          const SizedBox(width: 6),
          _SoundChip(
            icon: Icons.volume_up_rounded,
            selected: volumeLevel == 3,
            tooltip: 'Laut',
            onTap: () => onVolumeLevel(3),
          ),
        ],
      ),
    );
  }
}

class _SoundChip extends StatelessWidget {
  const _SoundChip({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? MerchantPremiumColors.goldSoft
                : MerchantPremiumColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? MerchantPremiumColors.gold.withValues(alpha: 0.5)
                  : MerchantPremiumColors.glassBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected
                ? MerchantPremiumColors.gold
                : MerchantPremiumColors.muted,
          ),
        ),
      ),
    );
  }
}
