import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firestoreService.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../services/merchantHandleService.dart';

/// Public host the app is served from — share links always start here so a
/// merchant sees a clean, memorable address regardless of where the app happens
/// to run (dev/localhost included).
const String _kPublicHost = 'jajehelp.com';

/// Absolute base for a working public link (host + deployed sub-path). Path URL
/// strategy is on (no `#`), so a route appends directly.
const String _kPublicBase = 'https://$_kPublicHost/lokka/';

/// Dashboard card: shows the merchant's shareable public link (short, always
/// `jajehelp.com/<handle>`). Tapping opens a sheet to open the profile page or
/// the catalog, copy the link, or change the handle.
class MerchantProfileLinkCard extends StatefulWidget {
  const MerchantProfileLinkCard({super.key, required this.merchantId});

  final String merchantId;

  @override
  State<MerchantProfileLinkCard> createState() =>
      _MerchantProfileLinkCardState();
}

class _MerchantProfileLinkCardState extends State<MerchantProfileLinkCard> {
  late final MerchantHandleService _service;
  String? _handle; // null = noch nicht geladen
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = MerchantHandleService(context.read<FirestoreService>());
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await _service.handleFor(widget.merchantId);
      if (mounted) {
        setState(() {
          _handle = h;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _handle = '';
          _loading = false;
        });
      }
    }
  }

  bool get _hasHandle => (_handle ?? '').isNotEmpty;

  /// Short, human-facing display — always starts with the public host.
  String get _prettyLink => '$_kPublicHost/${_handle ?? ''}';

  /// The full working URL to copy/share.
  String get _fullLink => '$_kPublicBase${_handle ?? ''}';

  Future<void> _copy() async {
    if (!_hasHandle) {
      _snack('Lege zuerst deinen Profil-Link fest.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _fullLink));
    _snack('Link kopiert');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _edit() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _HandleDialog(
        service: _service,
        merchantId: widget.merchantId,
        initial: _handle ?? '',
        base: _kPublicHost,
      ),
    );
    if (result != null && mounted) {
      setState(() => _handle = result);
      _snack('Profil-Link gespeichert');
    }
  }

  /// The popout: open the profile page or the catalog, copy, or change the link.
  void _openActions() {
    final mid = widget.merchantId;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: MerchantPremiumColors.baseElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Text(
                  _hasHandle ? _prettyLink : 'Dein Profil-Link',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MerchantPremiumColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _ActionRow(
                icon: Icons.storefront_rounded,
                label: 'Profilseite öffnen',
                subtitle: 'So sehen Kund:innen dein Profil.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/user/partners/$mid');
                },
              ),
              _ActionRow(
                icon: Icons.menu_book_rounded,
                label: 'Katalog öffnen',
                subtitle: 'Deine Speisekarte / dein Angebot.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/shop/$mid');
                },
              ),
              _ActionRow(
                icon: Icons.content_copy_rounded,
                label: 'Link kopieren',
                subtitle: _hasHandle ? _prettyLink : 'Erst Link festlegen',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _copy();
                },
              ),
              _ActionRow(
                icon: _hasHandle ? Icons.edit_rounded : Icons.add_link_rounded,
                label: _hasHandle ? 'Link ändern' : 'Link festlegen',
                subtitle: 'Wähle deine persönliche Adresse.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _edit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _loading ? null : _openActions,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MerchantPremiumColors.goldSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.link_rounded,
                  color: MerchantPremiumColors.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dein Profil-Link',
                    style: TextStyle(
                      color: MerchantPremiumColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_loading)
                    const Text('…',
                        style:
                            TextStyle(color: MerchantPremiumColors.mutedLight))
                  else
                    Text(
                      _hasHandle ? _prettyLink : 'Noch nicht festgelegt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _hasHandle
                            ? MerchantPremiumColors.ink
                            : MerchantPremiumColors.mutedLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (!_loading)
              const Icon(Icons.chevron_right_rounded,
                  color: MerchantPremiumColors.mutedLight),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: MerchantPremiumColors.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: MerchantPremiumColors.line),
        ),
        child: Icon(icon, color: MerchantPremiumColors.gold, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: MerchantPremiumColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: MerchantPremiumColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HandleDialog extends StatefulWidget {
  const _HandleDialog({
    required this.service,
    required this.merchantId,
    required this.initial,
    required this.base,
  });

  final MerchantHandleService service;
  final String merchantId;
  final String initial;
  final String base;

  @override
  State<_HandleDialog> createState() => _HandleDialogState();
}

class _HandleDialogState extends State<_HandleDialog> {
  late final TextEditingController _ctrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final slug = MerchantHandleService.normalize(raw);
    if (slug != raw) {
      _ctrl.value = TextEditingValue(
        text: slug,
        selection: TextSelection.collapsed(offset: slug.length),
      );
    }
    setState(() => _error = MerchantHandleService.validationError(slug));
  }

  Future<void> _save() async {
    final slug = MerchantHandleService.normalize(_ctrl.text);
    final localError = MerchantHandleService.validationError(slug);
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.setHandle(widget.merchantId, slug);
      if (mounted) Navigator.pop(context, slug);
    } on StateError catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Speichern fehlgeschlagen. Bitte erneut.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Profil-Link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wähle deinen persönlichen Link. So erreichen dich Kund:innen direkt.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saving ? null : _save(),
            decoration: InputDecoration(
              prefixText: '${widget.base}/',
              hintText: 'mein-laden',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Speichern'),
        ),
      ],
    );
  }
}
