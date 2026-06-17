import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/languageService.dart';
import 'publicShopTheme.dart';

/// Kontakt-Leiste am unteren Rand des Cover-Bilds (Hero): Öffnungszeiten,
/// Anrufen, Website, Karte und Social-Links – als frostige Pillen über dem
/// Bild. Öffnungszeiten öffnen ein Popup statt einen großen Block.
class PublicShopContactRail extends StatelessWidget {
  const PublicShopContactRail({
    super.key,
    required this.merchant,
    required this.palette,
  });

  final Map<String, dynamic> merchant;
  final PublicShopPalette palette;

  String _str(String key) => (merchant[key] ?? '').toString().trim();

  Map<String, String> get _social {
    final raw = merchant['socialLinks'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return const {};
  }

  Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* kein Crash, nur kein Öffnen */}
  }

  void _call() {
    final phone = _str('phone').replaceAll(' ', '');
    if (phone.isEmpty) return;
    _open(Uri(scheme: 'tel', path: phone));
  }

  void _maps() {
    final lat = merchant['lat'];
    final lng = merchant['lng'];
    final address = _str('fullAddress').isNotEmpty ? _str('fullAddress') : _str('address');
    final query = (lat is num && lng is num) ? '$lat,$lng' : Uri.encodeComponent(address);
    if (query.isEmpty) return;
    _open(Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'));
  }

  void _openUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri != null) _open(uri);
  }

  void _openSocial(String key, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    if (v.startsWith('http')) {
      _openUrl(v);
      return;
    }
    final handle = v.replaceAll('@', '').replaceAll('/', '').trim();
    switch (key) {
      case 'instagram':
        _openUrl('https://www.instagram.com/$handle');
        break;
      case 'tiktok':
        _openUrl('https://www.tiktok.com/@$handle');
        break;
      case 'facebook':
        _openUrl('https://www.facebook.com/$handle');
        break;
      default:
        _openUrl(v);
    }
  }

  void _showHours(BuildContext context, Map<String, dynamic> hours) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _HoursSheet(palette: palette, hours: hours),
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final social = _social;
    final phone = _str('phone');
    final website = (social['website'] ?? '').trim();
    final hasAddress = _str('address').isNotEmpty ||
        _str('fullAddress').isNotEmpty ||
        (merchant['lat'] is num && merchant['lng'] is num);
    final hoursRaw = merchant['openingHours'];
    final hasHours = hoursRaw is Map && hoursRaw.isNotEmpty;

    final pills = <Widget>[
      if (hasHours)
        _RailPill(
          icon: Icons.schedule_rounded,
          label: texts.text('public.shop.hoursTitle'),
          onTap: () => _showHours(context, Map<String, dynamic>.from(hoursRaw)),
        ),
      if (phone.isNotEmpty)
        _RailPill(icon: Icons.call_rounded, label: texts.text('public.shop.call'), onTap: _call),
      if (website.isNotEmpty)
        _RailPill(
            icon: Icons.language_rounded,
            label: texts.text('public.shop.website'),
            onTap: () => _openUrl(website)),
      if (hasAddress)
        _RailPill(icon: Icons.map_outlined, label: texts.text('public.shop.directions'), onTap: _maps),
      if ((social['instagram'] ?? '').trim().isNotEmpty)
        _RailPill(
            icon: Icons.camera_alt_rounded,
            label: 'Instagram',
            onTap: () => _openSocial('instagram', social['instagram']!)),
      if ((social['tiktok'] ?? '').trim().isNotEmpty)
        _RailPill(
            icon: Icons.music_note_rounded,
            label: 'TikTok',
            onTap: () => _openSocial('tiktok', social['tiktok']!)),
      if ((social['facebook'] ?? '').trim().isNotEmpty)
        _RailPill(
            icon: Icons.facebook_rounded,
            label: 'Facebook',
            onTap: () => _openSocial('facebook', social['facebook']!)),
    ];

    if (pills.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: pills.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => pills[index],
      ),
    );
  }
}

class _RailPill extends StatelessWidget {
  const _RailPill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoursSheet extends StatelessWidget {
  const _HoursSheet({required this.palette, required this.hours});

  final PublicShopPalette palette;
  final Map<String, dynamic> hours;

  static const _days = [
    ('monday', 'Montag'),
    ('tuesday', 'Dienstag'),
    ('wednesday', 'Mittwoch'),
    ('thursday', 'Donnerstag'),
    ('friday', 'Freitag'),
    ('saturday', 'Samstag'),
    ('sunday', 'Sonntag'),
  ];

  String _format(dynamic value, String closedLabel) {
    if (value is Map) {
      if (value['closed'] == true) return closedLabel;
      final slots = value['slots'];
      if (slots is List && slots.isNotEmpty) {
        return slots.whereType<Map>().map((s) => '${s['open']} – ${s['close']}').join(', ');
      }
      final open = value['open']?.toString();
      final close = value['close']?.toString();
      if (open != null && open.isNotEmpty && close != null && close.isNotEmpty) {
        return '$open – $close';
      }
    }
    return closedLabel;
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final closedLabel = texts.text('public.shop.closed');
    final todayIdx = DateTime.now().weekday - 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 20, color: palette.accent),
                const SizedBox(width: 8),
                Text(
                  texts.text('public.shop.hoursTitle'),
                  style: TextStyle(color: palette.ink, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _days.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(
                      _days[i].$2,
                      style: TextStyle(
                        color: i == todayIdx ? palette.accent : palette.ink,
                        fontWeight: i == todayIdx ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _format(hours[_days[i].$1], closedLabel),
                      style: TextStyle(
                        color: i == todayIdx ? palette.accent : palette.muted,
                        fontWeight: i == todayIdx ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
