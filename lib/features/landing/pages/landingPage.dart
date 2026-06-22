import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../../../core/theme/appColors.dart';
import '../services/landingCookieStorage.dart';

/// Landing (Page 1) – Google-Home / Material 3. Zentriert, ruhig, eine klare
/// Primäraktion. Marke: Lokka (Produkt von Jajehelp).
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _showCookieBox = false;

  @override
  void initState() {
    super.initState();
    _loadCookieChoice();
  }

  Future<void> _loadCookieChoice() async {
    final hasChoice = await LandingCookieStorage.hasChoice();
    if (!mounted) return;
    setState(() => _showCookieBox = !hasChoice);
  }

  void _openHowItWorksSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HowItWorksSheet(),
    );
  }

  void _openAboutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AboutSheet(),
    );
  }

  Future<void> _saveCookieChoice(String choice) async {
    await LandingCookieStorage.saveChoice(choice);
    if (!mounted) return;
    setState(() => _showCookieBox = false);
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.read<LanguageService>();

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 720;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _BrandHeader(appName: texts.text('app.name')),
                              SizedBox(height: compact ? 26 : 40),
                              const _Hero(),
                              SizedBox(height: compact ? 24 : 36),
                              _PrimaryActions(
                                loginText: texts.text('landing.login'),
                                onRegister: () =>
                                    context.go('/auth/userRegister'),
                                onLogin: () => context.go('/auth/userLogin'),
                              ),
                              SizedBox(height: compact ? 24 : 32),
                              const _SectionLabel('Mehr erfahren'),
                              const SizedBox(height: 10),
                              _LinkTile(
                                title: 'So funktioniert Lokka',
                                subtitle:
                                    'Deals, Stempel und Punkte in einer Wallet.',
                                icon: Icons.auto_awesome_rounded,
                                onTap: _openHowItWorksSheet,
                              ),
                              const SizedBox(height: 8),
                              _LinkTile(
                                title: 'Über Lokka',
                                subtitle:
                                    'Gebaut für lokale Shops und echte Nähe.',
                                icon: Icons.favorite_outline_rounded,
                                onTap: _openAboutSheet,
                              ),
                              SizedBox(height: compact ? 22 : 30),
                              const _PlatformLine(),
                              SizedBox(height: compact ? 20 : 36),
                              _BusinessLink(
                                onTap: () => context.go('/auth/merchantLogin'),
                              ),
                              const SizedBox(height: 4),
                              const _Footer(),
                              const SizedBox(height: 96),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_showCookieBox)
              _CookieBox(
                onAccept: () => _saveCookieChoice('accepted'),
                onReject: () => _saveCookieChoice('rejected'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Brand header (zentriert: Logo + Lokka + von Jajehelp) ────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Jajehelp-Logo, grün getintet als Marken-Glyph.
            Image.asset(
              'assets/logo.png',
              height: 40,
              color: cs.primary,
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (_, __, ___) => Icon(
                Icons.local_activity_rounded,
                color: cs.primary,
                size: 36,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              appName.isEmpty ? 'Lokka' : appName,
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'von Jajehelp',
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Hero (zentriert) ─────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            'Lokal · Digital · Kostenlos',
            style: tt.labelMedium?.copyWith(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Lokale Deals,\ndirekt in deiner Wallet.',
          textAlign: TextAlign.center,
          style: tt.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.08,
            letterSpacing: -0.5,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Entdecke Shops in deiner Nähe, sammle Stempel und sichere dir Vorteile – alles an einem Ort.',
          textAlign: TextAlign.center,
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

// ── Primary actions ──────────────────────────────────────────────────────────

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.loginText,
    required this.onRegister,
    required this.onLogin,
  });

  final String loginText;
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onRegister,
          child: const Text('Konto erstellen'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onLogin,
          child: Text(loginText.isEmpty ? 'Anmelden' : loginText),
        ),
      ],
    );
  }
}

// ── Section label (zentriert) ────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: tt.labelLarge?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Link tile ────────────────────────────────────────────────────────────────

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: cs.onSecondaryContainer, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Platform chips (App Store / Play Store öffnen Hinweis-Sheet) ─────────────

class _PlatformLine extends StatelessWidget {
  const _PlatformLine();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        const _PlatformChip(icon: Icons.language_rounded, text: 'Web'),
        _PlatformChip(
          icon: Icons.apple_rounded,
          text: 'App Store',
          onTap: () => _showStoreSheet(context),
        ),
        _PlatformChip(
          icon: Icons.android_rounded,
          text: 'Play Store',
          onTap: () => _showStoreSheet(context),
        ),
      ],
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: cs.onSurfaceVariant),
      label: Text(text),
      backgroundColor: AppColors.surfaceGray,
      side: BorderSide(color: cs.outlineVariant),
      visualDensity: VisualDensity.compact,
      onPressed: onTap ?? () {},
    );
  }
}

// ── Business link + footer ───────────────────────────────────────────────────

class _BusinessLink extends StatelessWidget {
  const _BusinessLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            children: [
              const TextSpan(text: 'Geschäftlich?  '),
              TextSpan(
                text: 'Für Händler einloggen',
                style: tt.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Text(
        'powered by Jajehelp',
        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ── Store-Hinweis-Sheet ──────────────────────────────────────────────────────

void _showStoreSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _StoreSheet(),
  );
}

class _StoreSheet extends StatelessWidget {
  const _StoreSheet();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return _SheetScaffold(
      title: 'Bald in den Stores',
      subtitle: 'Ende 2026 offiziell im App Store & Play Store.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceGray,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Bis dahin läuft Lokka als Web-App auf jedem Gerät – ganz ohne Installation. Für ein App-Gefühl kannst du Lokka zum Startbildschirm hinzufügen:',
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          const _HowToRow(
            icon: Icons.ios_share_rounded,
            title: 'iPhone (Safari)',
            body: 'Teilen-Symbol antippen → „Zum Home-Bildschirm".',
          ),
          const SizedBox(height: 10),
          const _HowToRow(
            icon: Icons.more_vert_rounded,
            title: 'Android (Chrome)',
            body: 'Menü ⋮ → „Zum Startbildschirm hinzufügen".',
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  const _HowToRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: cs.onSecondaryContainer, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tt.titleSmall),
              const SizedBox(height: 2),
              Text(body,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bottom sheets (hell, Material 3) ─────────────────────────────────────────

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: tt.headlineSmall),
            const SizedBox(height: 6),
            Text(subtitle,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet();

  static const _live = [
    ('Lokale Deals & Feed', Icons.local_fire_department_rounded),
    ('Digitale Stempelkarten', Icons.confirmation_number_rounded),
    ('Punkte & Prämien', Icons.stars_rounded),
    ('Wallet – alles an einem Ort', Icons.account_balance_wallet_rounded),
    ('Partner folgen & bewerten', Icons.storefront_rounded),
    ('Favoriten speichern', Icons.favorite_rounded),
  ];

  static const _soon = [
    ('Native Apps (App Store & Play Store)', Icons.phone_iphone_rounded),
    ('Speisekarten & Tischwahl', Icons.restaurant_menu_rounded),
    ('Catering-Anfragen', Icons.room_service_rounded),
    ('Mehrsprachigkeit', Icons.translate_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'So läuft Lokka',
      subtitle: 'Ein QR, eine Wallet, echte lokale Vorteile.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FeatureGroup(
            label: 'Jetzt verfügbar',
            items: _live,
            available: true,
          ),
          const SizedBox(height: 18),
          const _FeatureGroup(
            label: 'Bald · bis Ende 2026',
            items: _soon,
            available: false,
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}

class _FeatureGroup extends StatelessWidget {
  const _FeatureGroup({
    required this.label,
    required this.items,
    required this.available,
  });

  final String label;
  final List<(String, IconData)> items;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = available ? cs.primary : cs.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.labelLarge?.copyWith(
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (it) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  available ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  size: 20,
                  color: accent,
                ),
                const SizedBox(width: 12),
                Icon(it.$2, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(it.$1, style: tt.bodyMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return _SheetScaffold(
      title: 'Über Lokka',
      subtitle: 'Für kleine Läden, die sichtbar bleiben wollen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.storefront_rounded,
                  color: cs.onSecondaryContainer, size: 38),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Lokka verbindet Kunden mit lokalen Shops – ohne Papierkarten, ohne Chaos, ohne Umwege. Mehr Wiederkommen, mehr Nähe. Ein Produkt von Jajehelp.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}

// ── Cookie consent ───────────────────────────────────────────────────────────

class _CookieBox extends StatelessWidget {
  const _CookieBox({required this.onAccept, required this.onReject});

  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cookie_rounded, color: cs.primary, size: 22),
                    const SizedBox(width: 10),
                    Text('Cookies', style: tt.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Wir nutzen Cookies, damit Lokka sauber läuft und besser wird.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Ablehnen'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: onAccept,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Akzeptieren'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
