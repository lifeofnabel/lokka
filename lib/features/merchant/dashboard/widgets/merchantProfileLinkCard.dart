import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firestoreService.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../services/merchantHandleService.dart';

/// Public host the app is served from — share links always start here so a
/// merchant sees a clean, memorable address regardless of where the app runs.
const String _kPublicHost = 'jajehelp.com';

/// Absolute base for a working public link (host + deployed sub-path). Path URL
/// strategy is on (no `#`), so a route appends directly.
const String _kPublicBase = 'https://$_kPublicHost/lokka/';

/// Opens the profile-link popout (loaded on demand). Triggered from the hero's
/// top-left symbol. Offers: open the public profile, open the catalog, copy the
/// link, or change the handle.
Future<void> showProfileLinkSheet(
  BuildContext context, {
  required String merchantId,
}) async {
  final service = MerchantHandleService(context.read<FirestoreService>());
  var handle = '';
  try {
    handle = await service.handleFor(merchantId);
  } catch (_) {
    // No handle yet / read failed → the sheet still offers "Link festlegen".
  }
  if (!context.mounted) return;

  final hasHandle = handle.trim().isNotEmpty;
  final pretty = '$_kPublicHost/$handle';
  final fullLink = '$_kPublicBase$handle';

  await showModalBottomSheet<void>(
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
                hasHandle ? pretty : 'Dein Profil-Link',
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
                context.push('/user/partners/$merchantId');
              },
            ),
            _ActionRow(
              icon: Icons.menu_book_rounded,
              label: 'Katalog öffnen',
              subtitle: 'Deine Speisekarte / dein Angebot.',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/shop/$merchantId');
              },
            ),
            _ActionRow(
              icon: Icons.content_copy_rounded,
              label: 'Link kopieren',
              subtitle: hasHandle ? pretty : 'Erst Link festlegen',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _copyLink(context, hasHandle: hasHandle, fullLink: fullLink);
              },
            ),
            _ActionRow(
              icon: hasHandle ? Icons.edit_rounded : Icons.add_link_rounded,
              label: hasHandle ? 'Link ändern' : 'Link festlegen',
              subtitle: 'Wähle deine persönliche Adresse.',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _editHandle(context, service, merchantId, handle);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _copyLink(
  BuildContext context, {
  required bool hasHandle,
  required String fullLink,
}) async {
  if (!hasHandle) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lege zuerst deinen Profil-Link fest.')),
    );
    return;
  }
  await Clipboard.setData(ClipboardData(text: fullLink));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Link kopiert')));
}

Future<void> _editHandle(
  BuildContext context,
  MerchantHandleService service,
  String merchantId,
  String initial,
) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _HandleDialog(
      service: service,
      merchantId: merchantId,
      initial: initial,
      base: _kPublicHost,
    ),
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profil-Link gespeichert')));
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
