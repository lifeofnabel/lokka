import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lokka/core/config/appConfig.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/services/uploadService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
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
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            children: [
              // Mini activity entry — small, low-priority, top-right of the hero.
              Align(
                alignment: Alignment.centerRight,
                child: Tooltip(
                  message: 'Meine Aktivität',
                  child: Material(
                    color: onHero.withValues(alpha: 0.16),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MeinProtokollPage()),
                      ),
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(Icons.timeline_rounded,
                            size: 19, color: onHero),
                      ),
                    ),
                  ),
                ),
              ),
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
        // Four compact shortcuts in one row — like the merchant's quick actions.
        Row(
          children: [
            Expanded(
              child: _Shortcut(
                icon: Icons.favorite_rounded,
                label: 'Likes',
                onTap: () => _push(context, const MeineFavoritenPage()),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Shortcut(
                icon: Icons.storefront_rounded,
                label: 'Partner',
                onTap: () => _push(context, const MeinePartnerPage()),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Shortcut(
                icon: Icons.reviews_rounded,
                label: 'Rezensionen',
                onTap: () => _push(context, const MeineRezensionenPage()),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Shortcut(
                icon: Icons.tune_rounded,
                label: 'Interessen',
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
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

/// Compact profile shortcut — icon tile + short label, sized to fit four in a
/// single row (mirrors the merchant's quick-action chips).
class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
          padding:
              const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: cs.onSecondaryContainer),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      children: [
        _LinkTile(
          icon: Icons.badge_outlined,
          label: 'Persönliche Daten',
          subtitle: 'Name, Kontakt & Adresse',
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

  // Step 1: warn about the consequences.
  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: cs.error),
          title: const Text('Konto wirklich löschen?'),
          content: const Text(
            'Wenn du dein Konto löschst, verlierst du dauerhaft den Zugang zu '
            'deiner Wallet, deinen Stempeln, Punkten, Likes und Bewertungen. '
            'Diese Aktion kann nicht rückgängig gemacht werden.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeleteFinal(context);
              },
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('Weiter'),
            ),
          ],
        );
      },
    );
  }

  // Step 2: final, explicit confirmation before sending the request.
  void _confirmDeleteFinal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Bist du ganz sicher?'),
          content: const Text(
            'Deine Löschanfrage wird an unser Team weitergeleitet und das Konto '
            'wird nach Prüfung innerhalb von 7 Tagen endgültig gelöscht.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            FilledButton(
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
              style: FilledButton.styleFrom(
                  backgroundColor: cs.error, foregroundColor: cs.onError),
              child: const Text('Endgültig löschen'),
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
        // Logout — clear presence.
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Ausloggen'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Delete — quiet, thin, at the very bottom.
        Center(
          child: TextButton(
            onPressed: () => _confirmDelete(context),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              minimumSize: const Size(0, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Konto löschen',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
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
