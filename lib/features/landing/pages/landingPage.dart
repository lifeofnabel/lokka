import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/languageService.dart';
import '../../../core/theme/appColors.dart';
import '../../../core/theme/appShadows.dart';
import '../services/landingCookieStorage.dart';

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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _HowItWorksSheet(),
    );
  }

  void _openAboutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 720;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                          child: Column(
                            children: [
                              _TopBar(
                                appName: texts.text('app.name'),
                                onDevTap: () => context.go('/dev/foundation'),
                              ),
                              SizedBox(height: compact ? 22 : 34),
                              const _HeroText(),
                              SizedBox(height: compact ? 20 : 30),
                              _InfoBox(
                                title: 'So funktioniert Lokka',
                                subtitle: 'Deals, Stempel und Punkte in einer Wallet.',
                                icon: Icons.auto_awesome_rounded,
                                onTap: _openHowItWorksSheet,
                              ),
                              const SizedBox(height: 12),
                              _ActionBoxes(
                                loginText: texts.text('landing.login'),
                                onLogin: () => context.go('/auth/userLogin'),
                                onRegister: () => context.go('/auth/userRegister'),
                              ),
                              const SizedBox(height: 12),
                              _InfoBox(
                                title: 'Demo ansehen',
                                subtitle: 'Kurzer Blick auf das Lokka Gef\u00fchl.',
                                icon: Icons.play_circle_rounded,
                                onTap: () => context.go('/auth/demoComingSoon'),
                              ),
                              const SizedBox(height: 12),
                              _InfoBox(
                                title: '\u00dcber Lokka',
                                subtitle: 'Gebaut f\u00fcr lokale Shops und echte N\u00e4he.',
                                icon: Icons.groups_rounded,
                                onTap: _openAboutSheet,
                              ),
                              const SizedBox(height: 18),
                              const _PlatformLine(),
                              SizedBox(height: compact ? 20 : 46),
                              _BusinessLink(
                                onTap: () => context.go('/auth/merchantLogin'),
                              ),
                              const SizedBox(height: 8),
                              _Footer(
                                onTap: () => context.go('/dev/foundation'),
                              ),
                              const SizedBox(height: 116),
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.appName,
    required this.onDevTap,
  });

  final String appName;
  final VoidCallback onDevTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.local_activity_rounded,
            color: AppColors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          appName.isEmpty ? 'Lokka' : appName,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onDevTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 17,
              color: AppColors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'LOKALE DEALS.\nDIREKT IN DEINER\nWALLET.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.black,
            fontSize: 36,
            height: 0.98,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          'Entdecke Shops, sammle Stempel und sichere dir Vorteile in deiner N\u00e4he.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.black.withOpacity(0.54),
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.white, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.black.withOpacity(0.48),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.black.withOpacity(0.35),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBoxes extends StatelessWidget {
  const _ActionBoxes({
    required this.loginText,
    required this.onLogin,
    required this.onRegister,
  });

  final String loginText;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionBox(
            title: loginText,
            subtitle: 'Zur\u00fcck in deine Wallet',
            icon: Icons.login_rounded,
            isDark: true,
            onTap: onLogin,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionBox(
            title: 'Registrieren',
            subtitle: 'Noch kein Konto?',
            icon: Icons.person_add_alt_1_rounded,
            isDark: false,
            onTap: onRegister,
          ),
        ),
      ],
    );
  }
}

class _ActionBox extends StatelessWidget {
  const _ActionBox({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.black : AppColors.surface;
    final fg = isDark ? AppColors.white : AppColors.black;
    final sub = isDark
        ? AppColors.white.withOpacity(0.58)
        : AppColors.black.withOpacity(0.48);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 142,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isDark ? AppColors.black : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.16 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 27),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: sub,
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformLine extends StatelessWidget {
  const _PlatformLine();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _PlatformChip(icon: Icons.language_rounded, text: 'Web'),
        _PlatformChip(icon: Icons.apple_rounded, text: 'App Store'),
        _PlatformChip(icon: Icons.android_rounded, text: 'Play Store'),
      ],
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.black, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessLink extends StatelessWidget {
  const _BusinessLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            color: AppColors.black.withOpacity(0.45),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          children: const [
            TextSpan(text: 'Gesch\u00e4ftlich? '),
            TextSpan(
              text: 'F\u00fcr H\u00e4ndler einloggen',
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'powered by Jajehelp',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.black.withOpacity(0.36),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet();

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      title: 'So l\u00e4uft Lokka',
      subtitle: 'Ein QR, eine Wallet, echte lokale Vorteile.',
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: _MiniVisualStep(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Deals',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MiniVisualStep(
                  icon: Icons.confirmation_number_rounded,
                  title: 'Stempel',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MiniVisualStep(
                  icon: Icons.stars_rounded,
                  title: 'Punkte',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Lokka zeigt dir lokale Angebote aus deiner N\u00e4he. Du kannst Deals entdecken, digitale Stempelkarten nutzen und bei teilnehmenden Shops Vorteile sammeln.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white.withOpacity(0.62),
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _SheetCloseButton(
            text: 'Verstanden',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      title: '\u00dcber Lokka',
      subtitle: 'Gemacht f\u00fcr kleine L\u00e4den, die sichtbar bleiben wollen.',
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.black,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Lokka verbindet Kunden mit lokalen Shops. Ohne Papierkarten, ohne Chaos, ohne Umwege.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white.withOpacity(0.62),
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mehr Wiederkommen. Mehr N\u00e4he. Mehr Lokka.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _SheetCloseButton(
            text: 'Schlie\u00dfen',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _MiniVisualStep extends StatelessWidget {
  const _MiniVisualStep({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.white, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BaseSheet extends StatelessWidget {
  const _BaseSheet({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white.withOpacity(0.58),
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CookieBox extends StatelessWidget {
  const _CookieBox({
    required this.onAccept,
    required this.onReject,
  });

  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.26),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.cookie_rounded,
                        color: AppColors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Text(
                        'Cookies',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Wir nutzen Cookies, damit Lokka sauber l\u00e4uft und besser wird.',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.62),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _CookieButton(
                        text: 'Ablehnen',
                        isPrimary: false,
                        onTap: onReject,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _CookieButton(
                        text: 'Akzeptieren',
                        isPrimary: true,
                        onTap: onAccept,
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

class _CookieButton extends StatelessWidget {
  const _CookieButton({
    required this.text,
    required this.isPrimary,
    required this.onTap,
  });

  final String text;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? AppColors.white : AppColors.white.withOpacity(0.10);
    final fg = isPrimary ? AppColors.black : AppColors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.white.withOpacity(isPrimary ? 0 : 0.12),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
