import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/services/uploadService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/profile/providers/userProfileProvider.dart';
import 'package:lokka/features/user/profile/services/userProfileService.dart';
import 'package:lokka/features/user/profile/pages/meineFavoritenPage.dart';
import 'package:lokka/features/user/profile/pages/meineRezensionenPage.dart';
import 'package:lokka/features/user/profile/pages/meinePartnerPage.dart';
import 'package:lokka/features/user/profile/pages/meinProtokollPage.dart';
import 'package:lokka/features/user/profile/pages/meineBestellungenPage.dart';
import 'package:lokka/features/user/profile/pages/profilePersonalDataPage.dart';
import 'package:lokka/features/user/profile/pages/profilePhoneVerifyPage.dart';
import 'package:lokka/features/user/profile/pages/profileChangePasswordPage.dart';

// 6 gradient presets (index 0–5)
final _kGradients = <List<Color>>[
  const [Color(0xFF1C1C2E), Color(0xFF2C2C44)], // default dark
  const [Color(0xFF0F2027), Color(0xFF203A43)], // dark teal
  const [Color(0xFF1A1A2E), Color(0xFF16213E)], // deep navy
  const [Color(0xFF2C1654), Color(0xFF1A0533)], // deep purple
  const [Color(0xFF1B4332), Color(0xFF081C15)], // forest
  const [Color(0xFF7B2D00), Color(0xFF3D1600)], // ember
];

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = provider.user;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroSection(user: user),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('Mein Bereich'),
                      const SizedBox(height: AppSpacing.sm),
                      _NavCard(
                        icon: Icons.favorite_rounded,
                        color: Colors.redAccent,
                        title: 'Favoriten',
                        subtitle: 'Beiträge, die dir gefallen haben',
                        tooltip: 'Hier findest du Beiträge, die dir gefallen haben.',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MeineFavoritenPage()),
                        ),
                      ),
                      _NavCard(
                        icon: Icons.star_rounded,
                        color: Colors.amber,
                        title: 'Rezensionen',
                        subtitle: 'Deine eigenen Bewertungen',
                        tooltip: 'Hier siehst du alle Bewertungen, die du geschrieben hast.',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MeineRezensionenPage()),
                        ),
                      ),
                      _NavCard(
                        icon: Icons.store_rounded,
                        color: AppColors.mintStrong,
                        title: 'Partner',
                        subtitle: 'Deine gespeicherten Händler',
                        tooltip: 'Alle Händler, bei denen du eine Kundenkarte hast.',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MeinePartnerPage()),
                        ),
                      ),
                      _NavCard(
                        icon: Icons.history_rounded,
                        color: Colors.blueAccent,
                        title: 'Protokoll',
                        subtitle: 'Deine Aktivitäten',
                        tooltip: 'Eine Übersicht deiner letzten Aktivitäten.',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MeinProtokollPage()),
                        ),
                      ),
                      _NavCard(
                        icon: Icons.receipt_long_rounded,
                        color: Colors.deepPurpleAccent,
                        title: 'Bestellungen',
                        subtitle: 'Deine Bestellhistorie',
                        tooltip: 'Hier siehst du alle deine bisherigen Bestellungen.',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MeineBestellungenPage()),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (user != null) ...[
                        const _SectionLabel('Persönliche Daten'),
                        const SizedBox(height: AppSpacing.sm),
                        _PersonalDataCard(user: user),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionLabel('Sicherheit'),
                        const SizedBox(height: AppSpacing.sm),
                        _SecurityCard(user: user),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionLabel('Datenschutz'),
                        const SizedBox(height: AppSpacing.sm),
                        _PrivacyCard(user: user),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _LogoutCard(
                        onLogout: () async {
                          try {
                            await provider.signOut();
                          } catch (_) {}
                        },
                      ),
                      // Extra bottom padding so logout/delete stays reachable
                      const SizedBox(height: 160),
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

// ── Hero ─────────────────────────────────────────────────────────────────────

class _HeroSection extends StatefulWidget {
  const _HeroSection({required this.user});

  final AppUserModel? user;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  bool _uploading = false;

  String get _initials {
    final u = widget.user;
    final first = u?.firstName.isNotEmpty == true ? u!.firstName[0] : '';
    final last = u?.lastName.isNotEmpty == true ? u!.lastName[0] : '';
    return (first + last).toUpperCase();
  }

  String get _name {
    if (widget.user == null) return '';
    return '${widget.user!.firstName} ${widget.user!.lastName}'.trim();
  }

  List<Color> get _gradient {
    final idx = (widget.user?.profileCoverGradient ?? 0).clamp(0, _kGradients.length - 1);
    return _kGradients[idx];
  }

  Future<void> _pickAndUpload() async {
    final uploadService = context.read<UploadService>();
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();

    final picked = await uploadService.pickImageWithImagePicker();
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final result = await uploadService.cloudinaryService.uploadBytes(
        bytes: picked.bytes,
        fileName: picked.fileName,
        folder: 'profile_images',
      );
      final profileService = UserProfileService(
        firestoreService: firestoreService,
        authService: authService,
        cacheService: context.read<LocalCacheService>(),
      );
      final imageUrl = result.secureUrl.isNotEmpty ? result.secureUrl : result.url;
      await profileService.updateProfileImage(imageUrl);
    } catch (_) {
      // silently ignore upload errors
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickGradient() async {
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();
    final profileService = UserProfileService(
      firestoreService: firestoreService,
      authService: authService,
      cacheService: context.read<LocalCacheService>(),
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Hintergrundfarbe wählen',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.black),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: List.generate(_kGradients.length, (i) {
                  final selected = (widget.user?.profileCoverGradient ?? 0) == i;
                  return GestureDetector(
                    onTap: () async {
                      await profileService.updateCoverGradient(i);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _kGradients[i],
                        ),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppColors.mintStrong, width: 3)
                            : Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: selected
                          ? const Center(
                              child: Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            )
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.user?.profileImageUrl;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradient,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            children: [
              // Avatar with upload button
              Stack(
                children: [
                  GestureDetector(
                    onTap: _uploading ? null : _pickAndUpload,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _initialsWidget(),
                              )
                            : _initialsWidget(),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _uploading ? null : _pickAndUpload,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.mintStrong,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: _uploading
                            ? const Padding(
                                padding: EdgeInsets.all(5),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt_rounded,
                                size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _name.isEmpty ? 'Kein Name' : _name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              if (widget.user != null && widget.user!.customerCode.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.user!.customerCode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 0.8,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              // Gradient picker dots
              GestureDetector(
                onTap: _pickGradient,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.palette_outlined,
                        size: 14, color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      'Hintergrund',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initialsWidget() {
    return Center(
      child: Text(
        _initials.isEmpty ? '?' : _initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

// ── Navigation cards ─────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.large),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Icon(icon, size: 22, color: color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.gray300,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Personal data card ────────────────────────────────────────────────────────

class _PersonalDataCard extends StatelessWidget {
  const _PersonalDataCard({required this.user});

  final AppUserModel user;

  String _fmtDate(DateTime? d) {
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      children: [
        _DataRow(label: 'Vorname', value: user.firstName.isEmpty ? '–' : user.firstName),
        _DataRow(label: 'Nachname', value: user.lastName.isEmpty ? '–' : user.lastName),
        _DataRow(label: 'PLZ', value: user.postalCode ?? '–'),
        _DataRow(label: 'Telefon', value: user.phone ?? '–'),
        _DataRow(label: 'Geburtstag', value: _fmtDate(user.birthday)),
        _SettingsTile(
          icon: Icons.edit_rounded,
          label: 'Daten bearbeiten',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProfilePersonalDataPage(user: user)),
          ),
        ),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Security card ─────────────────────────────────────────────────────────────

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.user});

  final AppUserModel user;

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      children: [
        _SettingsTile(
          icon: Icons.lock_outline_rounded,
          label: 'Passwort ändern',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ProfileChangePasswordPage()),
          ),
        ),
        Tooltip(
          message: user.phoneVerified
              ? 'Deine Telefonnummer ist verifiziert.'
              : 'Verifiziere deine Telefonnummer für mehr Sicherheit.',
          child: _SettingsTile(
            icon: Icons.phone_outlined,
            label: 'Telefon verifizieren',
            trailing: user.phoneVerified
                ? const Icon(Icons.verified_rounded,
                    size: 18, color: AppColors.mintStrong)
                : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProfilePhoneVerifyPage(user: user)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Privacy card ──────────────────────────────────────────────────────────────

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.user});

  final AppUserModel user;

  void _requestDeletion(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: const Text(
          'Konto löschen?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Deine Löschanfrage wird an unser Team weitergeleitet. '
          'Das Konto wird nach Prüfung innerhalb von 7 Tagen gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final firestoreService = context.read<FirestoreService>();
                final authService = context.read<AuthService>();
                final profileService = UserProfileService(
                  firestoreService: firestoreService,
                  authService: authService,
                  cacheService: context.read<LocalCacheService>(),
                );
                await profileService.createDeletionRequest();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Löschanfrage wurde gesendet.'),
                    ),
                  );
                }
              } catch (_) {}
            },
            child: const Text(
              'Löschen beantragen',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      children: [
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          label: 'Datenschutzerklärung',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.delete_outline_rounded,
          label: 'Konto löschen',
          destructive: true,
          onTap: () => _requestDeletion(context),
        ),
      ],
    );
  }
}

// ── Logout ────────────────────────────────────────────────────────────────────

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onLogout});

  final VoidCallback onLogout;

  void _confirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: const Text(
          'Abmelden?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('Möchtest du dich wirklich abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onLogout();
            },
            child: const Text(
              'Abmelden',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      children: [
        _SettingsTile(
          icon: Icons.logout_rounded,
          label: 'Abmelden',
          destructive: true,
          onTap: () => _confirm(context),
          trailing: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.gray500,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i < children.length - 1)
                const Divider(height: 0, indent: 52, color: AppColors.border),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: destructive ? Colors.redAccent : AppColors.gray700,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: destructive ? Colors.redAccent : AppColors.black,
                ),
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.gray300,
                ),
          ],
        ),
      ),
    );
  }
}
