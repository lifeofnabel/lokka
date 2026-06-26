import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firestoreService.dart';
import '../../shared/widgets/merchantPremiumUi.dart';
import '../services/merchantHandleService.dart';

/// Dashboard card: shows the merchant's shareable public profile link
/// (`<origin>/<handle>`), lets them copy it, and set/change the custom handle.
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

  /// Origin for sharing (scheme://host[:port]); falls back gracefully.
  String get _origin => Uri.base.origin;

  /// Host[:port] only — for a compact on-screen display.
  String get _prettyBase {
    final u = Uri.base;
    final showPort = u.hasPort && u.port != 80 && u.port != 443;
    return '${u.host}${showPort ? ':${u.port}' : ''}';
  }

  String get _fullLink => '$_origin/${_handle ?? ''}';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _fullLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link kopiert')),
    );
  }

  Future<void> _edit() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _HandleDialog(
        service: _service,
        merchantId: widget.merchantId,
        initial: _handle ?? '',
        base: _prettyBase,
      ),
    );
    if (result != null && mounted) {
      setState(() => _handle = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil-Link gespeichert')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasHandle = (_handle ?? '').isNotEmpty;
    return Container(
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
                      style: TextStyle(color: MerchantPremiumColors.mutedLight))
                else
                  Text(
                    hasHandle ? '$_prettyBase/$_handle' : 'Noch nicht festgelegt',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasHandle
                          ? MerchantPremiumColors.ink
                          : MerchantPremiumColors.mutedLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          if (!_loading) ...[
            if (hasHandle)
              IconButton(
                tooltip: 'Link kopieren',
                onPressed: _copy,
                icon: const Icon(Icons.copy_rounded,
                    color: MerchantPremiumColors.gold, size: 20),
              ),
            IconButton(
              tooltip: hasHandle ? 'Link ändern' : 'Link festlegen',
              onPressed: _edit,
              icon: Icon(
                hasHandle ? Icons.edit_rounded : Icons.add_link_rounded,
                color: MerchantPremiumColors.mutedLight,
                size: 20,
              ),
            ),
          ],
        ],
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
