import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/profile/providers/userProfileProvider.dart';
import 'package:lokka/features/user/profile/widgets/userProfileHeader.dart';

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

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                expandedHeight: 60,
                flexibleSpace: const FlexibleSpaceBar(
                  titlePadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(
                    'Profil',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (provider.user != null) ...[
                        UserProfileHeader(
                          user: provider.user!,
                          walletCount: provider.walletCount,
                          rewardsCount: provider.rewardsCount,
                          couponsCount: provider.couponsCount,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ] else
                        const _GuestView(),
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionTitle('Einstellungen'),
                      const SizedBox(height: AppSpacing.sm),
                      _SettingsGroup(
                        items: [
                          _SettingsTile(
                            icon: Icons.notifications_outlined,
                            label: 'Benachrichtigungen',
                            onTap: () {},
                          ),
                          _SettingsTile(
                            icon: Icons.language_outlined,
                            label: 'Sprache',
                            onTap: () {},
                          ),
                          _SettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Datenschutz',
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _SectionTitle('Support'),
                      const SizedBox(height: AppSpacing.sm),
                      _SettingsGroup(
                        items: [
                          _SettingsTile(
                            icon: Icons.help_outline_rounded,
                            label: 'Hilfe & FAQ',
                            onTap: () {},
                          ),
                          _SettingsTile(
                            icon: Icons.mail_outline_rounded,
                            label: 'Kontakt',
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _LogoutButton(
                        onLogout: () async {
                          try {
                            await provider.signOut();
                          } catch (_) {}
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),
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

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.person_outline_rounded, size: 56, color: AppColors.gray300),
          SizedBox(height: AppSpacing.md),
          Text(
            'Kein Profil geladen',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.gray500,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              items[i],
              if (i < items.length - 1)
                const Divider(
                    height: 0, indent: 52, color: AppColors.border),
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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      items: [
        _SettingsTile(
          icon: Icons.logout_rounded,
          label: 'Abmelden',
          onTap: () => _confirm(context),
          destructive: true,
          trailing: const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _confirm(BuildContext context) {
    showDialog(
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
}
