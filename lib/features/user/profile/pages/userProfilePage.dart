import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lokka/core/config/appConfig.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/services/uploadService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/gamification/pages/meineErfolgePage.dart';
import 'package:lokka/features/user/gamification/providers/userGamificationProvider.dart';
import 'package:lokka/features/user/gamification/widgets/celebration.dart';
import 'package:lokka/features/user/onboarding/pages/onboardingSurveyPage.dart';
import 'package:lokka/features/user/profile/pages/meineFavoritenPage.dart';
import 'package:lokka/features/user/profile/pages/meinePartnerPage.dart';
import 'package:lokka/features/user/profile/pages/meinProtokollPage.dart';
import 'package:lokka/features/user/profile/pages/meineRezensionenPage.dart';
import 'package:lokka/features/user/profile/pages/profileChangePasswordPage.dart';
import 'package:lokka/features/user/profile/pages/profilePersonalDataPage.dart';
import 'package:lokka/features/user/profile/pages/profilePhoneVerifyPage.dart';
import 'package:lokka/features/user/profile/providers/userProfileProvider.dart';

/// Profil-Hauptseite — Chromium Experience / Material 3.
/// Grüne Markenidentität über cs.primary, ruhige Hierarchie, M3-Flächen.
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.surfaceBg,
            body: AppLoadingState(),
          );
        }

        final user = provider.user;
        return Scaffold(
          backgroundColor: AppColors.surfaceBg,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Hero(user: user)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuickActions(user: user),
                      const SizedBox(height: AppSpacing.xl),
                      if (user != null) ...[
                        const _SectionLabel('Konto'),
                        const SizedBox(height: AppSpacing.md),
                        _AccountCard(user: user),
                        const SizedBox(height: AppSpacing.xl),
                        const _CelebrationToggleCard(),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      _BottomLinks(
                        onLogout: () async {
                          try {
                            await provider.signOut();
                          } catch (_) {}
                          if (context.mounted) context.go('/');
                        },
                      ),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Hero (grüne Markenfläche, M3) ─────────────────────────────────────────────

class _Hero extends StatefulWidget {
  const _Hero({required this.user});
  final AppUserModel? user;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  bool _uploading = false;

  String get _initials {
    final u = widget.user;
    final first = u?.firstName.isNotEmpty == true ? u!.firstName[0] : '';
    final last = u?.lastName.isNotEmpty == true ? u!.lastName[0] : '';
    return (first + last).toUpperCase();
  }

  String get _name => widget.user == null
      ? ''
      : '${widget.user!.firstName} ${widget.user!.lastName}'.trim();

  Future<void> _pickAndUpload() async {
    final uploadService = context.read<UploadService>();
    final profileService = context.read<UserProfileProvider>().service;
    final picked = await uploadService.pickImageWithImagePicker();
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final media = await uploadService.uploadOptimizedImageBytes(
        bytes: picked.bytes,
        fileName: picked.fileName,
        type: UploadImageType.userProfile,
      );
      await profileService.updateProfileImage(media.displayUrl);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final user = widget.user;
    final imageUrl = user?.profileImageUrl;
    final verified = user?.phoneVerified ?? false;
    final onHero = cs.onPrimary;

    return Container(
      decoration: BoxDecoration(color: cs.primary),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            children: [
              Stack(
                children: [
                  Material(
                    color: onHero.withValues(alpha: 0.16),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _uploading ? null : _pickAndUpload,
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    _initialsWidget(),
                              )
                            : _initialsWidget(),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: cs.surface,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _uploading ? null : _pickAndUpload,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: _uploading
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: cs.primary),
                                )
                              : Icon(Icons.camera_alt_rounded,
                                  size: 14, color: cs.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _name.isEmpty ? 'Kein Name' : _name,
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onHero,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user != null && user.customerCode.isNotEmpty)
                    _chip(
                      icon: Icons.tag_rounded,
                      text: user.customerCode,
                      mono: true,
                    ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    _chip(
                      icon: Icons.verified_rounded,
                      text: 'verifiziert',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _HeroGamification(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
      {required IconData icon, required String text, bool mono = false}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final onHero = cs.onPrimary;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: onHero.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: onHero.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            text,
            style: tt.labelMedium?.copyWith(
              color: onHero,
              fontWeight: FontWeight.w600,
              letterSpacing: mono ? 0.8 : 0,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialsWidget() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Text(
        _initials.isEmpty ? '?' : _initials,
        style: tt.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onPrimary,
        ),
      ),
    );
  }
}

/// Antippbarer Gamification-Block → öffnet „Meine Erfolge".
class _HeroGamification extends StatelessWidget {
  const _HeroGamification();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final onHero = cs.onPrimary;
    final stats = context.watch<UserGamificationProvider>().stats;
    return Material(
      color: onHero.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadius.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MeineErfolgePage()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.military_tech_rounded, size: 16, color: onHero),
                  const SizedBox(width: 5),
                  Text('Level ${stats.level}',
                      style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700, color: onHero)),
                  if (stats.streakWeeks > 0) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.local_fire_department_rounded,
                        size: 16, color: Color(0xFFFFD27A)),
                    const SizedBox(width: 3),
                    Text('${stats.streakWeeks} Wo.',
                        style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600, color: onHero)),
                  ],
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: onHero.withValues(alpha: 0.8)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: stats.levelProgress,
                    minHeight: 6,
                    backgroundColor: onHero.withValues(alpha: 0.22),
                    valueColor: AlwaysStoppedAnimation<Color>(onHero),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick-Actions (2×2 + breite Aktivität) ────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.user});
  final AppUserModel? user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Mein Bereich'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                icon: Icons.favorite_rounded,
                title: 'Meine Favoriten',
                onTap: () => _push(context, const MeineFavoritenPage()),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickCard(
                icon: Icons.storefront_rounded,
                title: 'Meine Partner',
                info: 'Alle Händler, bei denen du eine Kundenkarte hast.',
                onTap: () => _push(context, const MeinePartnerPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                icon: Icons.star_rounded,
                title: 'Meine Bewertungen',
                info: 'Alle Bewertungen, die du geschrieben hast.',
                onTap: () => _push(context, const MeineRezensionenPage()),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickCard(
                icon: Icons.tune_rounded,
                title: 'Meine Interessen',
                info:
                    'Kategorien & Orte, nach denen dein Feed personalisiert wird.',
                onTap: () => _push(
                  context,
                  OnboardingSurveyPage(
                    isEditMode: true,
                    initialCategories: user?.interestCategories ?? const [],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _WideActionCard(
          icon: Icons.timeline_rounded,
          title: 'Meine Aktivität',
          info: 'Deine letzten Aktivitäten — Likes, Stempel & Kundenkarten.',
          onTap: () => _push(context, const MeinProtokollPage()),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.info,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 124,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Icon(icon,
                        size: 21, color: cs.onSecondaryContainer),
                  ),
                  const Spacer(),
                  if (info != null)
                    _InfoButton(onTap: () => _showInfo(context, title, info!)),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideActionCard extends StatelessWidget {
  const _WideActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.info,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceBg,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child:
                    Icon(icon, size: 22, color: cs.onSecondaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (info != null)
                _InfoButton(onTap: () => _showInfo(context, title, info!)),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text('?',
            style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSecondaryContainer)),
      ),
    );
  }
}

void _showInfo(BuildContext context, String title, String text) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final tt = Theme.of(ctx).textTheme;
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title, style: tt.titleLarge),
        content: Text(text,
            style: tt.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Verstanden'),
          ),
        ],
      );
    },
  );
}

// ── Sektionen ─────────────────────────────────────────────────────────────────

/// Ein ruhiger Konto-Block: kompakte Daten-Vorschau (Details auf der
/// Unterseite) + zusammengefasste Sicherheits-/Datenschutz-Aktionen.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});
  final AppUserModel user;

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(AppConfig.privacyPolicyUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link konnte nicht geöffnet werden.')),
      );
    }
  }

  String get _summary {
    final parts = <String>[];
    if (user.postalCode != null && user.postalCode!.isNotEmpty) {
      parts.add(user.postalCode!);
    }
    if (user.phone != null && user.phone!.isNotEmpty) {
      parts.add(user.phone!);
    }
    return parts.isEmpty ? 'Tippe, um deine Daten zu ergänzen' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      children: [
        _LinkTile(
          icon: Icons.badge_outlined,
          label: 'Persönliche Daten',
          subtitle: _summary,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProfilePersonalDataPage(user: user))),
        ),
        _LinkTile(
          icon: Icons.lock_outline_rounded,
          label: 'Passwort ändern',
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ProfileChangePasswordPage())),
        ),
        _LinkTile(
          icon: Icons.phone_outlined,
          label: 'Telefon verifizieren',
          subtitle: user.phoneVerified ? 'Verifiziert' : null,
          trailing: user.phoneVerified
              ? Icon(Icons.verified_rounded, size: 18, color: cs.primary)
              : null,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProfilePhoneVerifyPage(user: user))),
        ),
        _LinkTile(
          icon: Icons.privacy_tip_outlined,
          label: 'Datenschutzerklärung',
          onTap: () => _openPrivacyPolicy(context),
        ),
      ],
    );
  }
}

class _CelebrationToggleCard extends StatefulWidget {
  const _CelebrationToggleCard();

  @override
  State<_CelebrationToggleCard> createState() => _CelebrationToggleCardState();
}

class _CelebrationToggleCardState extends State<_CelebrationToggleCard> {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await Celebration.isEnabled(context.read<LocalCacheService>());
    if (mounted) setState(() => _enabled = v);
  }

  Future<void> _set(bool value) async {
    setState(() => _enabled = value);
    await Celebration.setEnabled(context.read<LocalCacheService>(), value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return _Card(
      children: [
        SwitchListTile(
          value: _enabled,
          onChanged: _set,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          secondary: Icon(Icons.celebration_rounded, color: cs.primary, size: 20),
          title: Text('Feier-Effekte',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ── Bottom-Links ──────────────────────────────────────────────────────────────

class _BottomLinks extends StatelessWidget {
  const _BottomLinks({required this.onLogout});
  final VoidCallback onLogout;

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Abmelden?'),
          content: const Text('Möchtest du dich wirklich abmelden?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onLogout();
              },
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('Abmelden'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Konto löschen?'),
          content: const Text(
              'Deine Löschanfrage wird an unser Team weitergeleitet. Das Konto wird '
              'nach Prüfung innerhalb von 7 Tagen gelöscht.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final service = context.read<UserProfileProvider>().service;
                  await service.createDeletionRequest();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Löschanfrage wurde gesendet.')),
                    );
                  }
                } catch (_) {}
              },
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('Löschen beantragen'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Center(
          child: TextButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Ausloggen'),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => _confirmDelete(context),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('Konto löschen'),
          ),
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      text,
      style: tt.labelLarge?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i < children.length - 1)
                Divider(height: 0, indent: 72, color: cs.outlineVariant),
            ],
          );
        }),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(icon, size: 20, color: cs.onSecondaryContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
