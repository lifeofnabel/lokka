import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/firebasePaths.dart';
import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/theme/appRadius.dart';
import '../../../../core/theme/appSpacing.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../../tools/widgets/merchantToolUi.dart';

/// „Speisekarte" – Merchant steuert, ob/wie Kunden seine Karte auf der
/// Partner-Seite sehen: externer Link und/oder integrierte Lokka-Karte.
class MerchantMenuSettingsPage extends StatefulWidget {
  const MerchantMenuSettingsPage({super.key});

  @override
  State<MerchantMenuSettingsPage> createState() =>
      _MerchantMenuSettingsPageState();
}

class _MerchantMenuSettingsPageState extends State<MerchantMenuSettingsPage> {
  final _urlController = TextEditingController();
  bool _externalEnabled = false;
  bool _integratedEnabled = false;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? get _uid => context.read<AuthService>().currentUser?.uid;

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Nicht angemeldet.';
      });
      return;
    }
    try {
      final data = await context
          .read<FirestoreService>()
          .readDocument(FirebasePaths.publicMerchant(uid));
      if (!mounted) return;
      setState(() {
        _urlController.text = (data?['menuExternalUrl'] as String?) ?? '';
        _externalEnabled = data?['menuExternalEnabled'] as bool? ?? false;
        _integratedEnabled = data?['menuIntegratedEnabled'] as bool? ?? false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;
    final url = _urlController.text.trim();
    if (_externalEnabled && url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Link eingeben oder externen Link ausschalten.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<FirestoreService>().setDocument(
        FirebasePaths.publicMerchant(uid),
        {
          'menuExternalUrl': url,
          'menuExternalEnabled': _externalEnabled,
          'menuIntegratedEnabled': _integratedEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speisekarte gespeichert.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MerchantToolScaffold(
      title: 'Speisekarte',
      subtitle: 'Wie Kunden deine Karte sehen',
      backPath: '/merchant/features',
      trailing: const MerchantInfoTooltip(
        message:
            'Kunden sehen deine Speisekarte nur auf deiner Partner-Seite. '
            'Du kannst einen externen Link verlinken und/oder die in Lokka '
            'integrierte Karte aus deinem Katalog aktivieren.',
      ),
      child: _loading
          ? const MerchantLoadingCards(count: 3)
          : _error != null
              ? MerchantErrorState(message: _error!, onRetry: _load)
              : _form(),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Externer Link
        MerchantPremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SwitchRow(
                icon: Icons.link_rounded,
                title: 'Externer Speisekarten-Link',
                subtitle: 'Eigene Website oder PDF verlinken',
                value: _externalEnabled,
                onChanged: (v) => setState(() => _externalEnabled = v),
              ),
              if (_externalEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'https://…',
                    filled: true,
                    fillColor: MerchantPremiumColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.public_rounded),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Integrierte Lokka-Karte
        MerchantPremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SwitchRow(
                icon: Icons.restaurant_menu_rounded,
                title: 'Integrierte Lokka-Karte',
                subtitle: 'Aus deinem Katalog – direkt in der App',
                value: _integratedEnabled,
                onChanged: (v) => setState(() => _integratedEnabled = v),
              ),
              if (_integratedEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MerchantPremiumColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(color: MerchantPremiumColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deine Karte wird aus dem Katalog zusammengestellt. '
                        'Nur aktive, öffentliche Artikel & Kategorien erscheinen. '
                        'Auf „privat" gestellte Einträge bleiben verborgen.',
                        style: TextStyle(
                          color: MerchantPremiumColors.muted,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: () => context.go('/merchant/catalog'),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Karte im Katalog zusammenstellen'),
                        style: TextButton.styleFrom(
                          foregroundColor: MerchantPremiumColors.ink,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        MerchantPrimaryButton(
          label: 'Speichern',
          icon: Icons.save_rounded,
          isLoading: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Tipp: Wenn beide aus sind, sehen Kunden keine Speisekarte auf deiner Seite.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MerchantPremiumColors.muted,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: MerchantPremiumColors.goldSoft,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, color: MerchantPremiumColors.ink),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MerchantPremiumColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: MerchantPremiumColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
