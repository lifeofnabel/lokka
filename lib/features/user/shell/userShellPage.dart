import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/discover/pages/userDiscoverPage.dart';
import 'package:lokka/features/user/discover/providers/userDiscoverProvider.dart';
import 'package:lokka/features/user/discover/services/userDiscoverService.dart';
import 'package:lokka/features/user/explore/pages/userExplorePage.dart';
import 'package:lokka/features/user/onboarding/pages/onboardingSurveyPage.dart';
import 'package:lokka/features/user/partners/providers/userPartnersProvider.dart';
import 'package:lokka/features/user/partners/services/userPartnersService.dart';
import 'package:lokka/features/user/profile/pages/userProfilePage.dart';
import 'package:lokka/features/user/profile/providers/userProfileProvider.dart';
import 'package:lokka/features/user/profile/services/userProfileService.dart';
import 'package:lokka/features/user/wallet/pages/userWalletPage.dart';
import 'package:lokka/features/user/wallet/providers/userWalletProvider.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';
import 'package:lokka/features/user/notifications/providers/userNotificationProvider.dart';
import 'package:lokka/features/user/notifications/services/userNotificationService.dart';
import 'package:lokka/features/user/notifications/services/userPushService.dart';
import 'package:lokka/features/user/gamification/providers/userGamificationProvider.dart';
import 'package:lokka/features/user/gamification/services/userGamificationService.dart';

class UserShellPage extends StatefulWidget {
  const UserShellPage({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<UserShellPage> createState() => _UserShellPageState();
}

class _UserShellPageState extends State<UserShellPage> {
  late int _index = widget.initialIndex;
  bool _showToolbar = true;
  UserPushService? _pushService;
  bool _pushInited = false;

  @override
  void initState() {
    super.initState();
    _pushService = UserPushService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
    );
  }

  void _initPushOnce() {
    if (_pushInited) return;
    _pushInited = true;
    _pushService?.init(
      onForeground: (title, body) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body.isEmpty ? title : '$title — $body'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onOpen: (route) {
        if (!mounted || route == null || route.isEmpty) return;
        context.go(route);
      },
    );
  }

  static const _tabs = [
    (label: 'Feed', icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded),
    (label: 'Suche', icon: Icons.search_rounded, activeIcon: Icons.search_rounded),
    (label: 'Wallet', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
    (label: 'Profil', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
  ];

  static const _paths = [
    '/user/discover',
    '/user/explore',
    '/user/wallet',
    '/user/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();
    final cacheService = context.read<LocalCacheService>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserDiscoverProvider>(
          create: (_) => UserDiscoverProvider(
            service: UserDiscoverService(
              firestoreService: firestoreService,
              authService: authService,
              cacheService: cacheService,
            ),
          ),
        ),
        ChangeNotifierProvider<UserPartnersProvider>(
          create: (_) => UserPartnersProvider(
            service: UserPartnersService(firestoreService: firestoreService),
          ),
        ),
        ChangeNotifierProvider<UserWalletProvider>(
          create: (_) => UserWalletProvider(
            service: UserWalletService(
              firestoreService: firestoreService,
              authService: authService,
              cacheService: cacheService,
            ),
          ),
        ),
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => UserProfileProvider(
            service: UserProfileService(
              firestoreService: firestoreService,
              authService: authService,
              cacheService: cacheService,
            ),
          ),
        ),
        ChangeNotifierProvider<UserNotificationProvider>(
          create: (_) => UserNotificationProvider(
            service: UserNotificationService(
              firestoreService: firestoreService,
              authService: authService,
            ),
          ),
        ),
        ChangeNotifierProvider<UserGamificationProvider>(
          create: (_) => UserGamificationProvider(
            service: UserGamificationService(
              firestoreService: firestoreService,
              authService: authService,
            ),
          ),
        ),
      ],
      child: Builder(
        builder: (ctx) => Consumer<UserProfileProvider>(
          builder: (context, profile, _) {
            final user = profile.user;
            // Profil lädt noch → kurzer Ladezustand statt Tab-Flackern.
            if (profile.isLoading && user == null) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: AppLoadingState(),
              );
            }
            // Onboarding-Gate: einmalig Pflicht, bis Interessen gespeichert sind.
            if (user != null && !user.onboardingCompleted) {
              return const OnboardingSurveyPage();
            }
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _initPushOnce());
            return Scaffold(
              backgroundColor: AppColors.background,
              extendBody: true,
              body: NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  final show =
                      notification.direction != ScrollDirection.reverse;
                  if (show != _showToolbar) setState(() => _showToolbar = show);
                  return false;
                },
                child: IndexedStack(
                  index: _index,
                  children: const [
                    UserDiscoverPage(),
                    UserExplorePage(),
                    UserWalletPage(),
                    UserProfilePage(),
                  ],
                ),
              ),
              // Beim Runterscrollen schrumpft die Toolbar (verschwindet nicht),
              // beim Hochscrollen wird sie wieder normal groß.
              bottomNavigationBar: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.bottomCenter,
                scale: _showToolbar ? 1.0 : 0.7,
                child: _buildBottomNav(ctx),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Google/Pixel-Style: helle, schwebende Pille mit grünem Aktiv-Indicator.
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Material(
        color: AppColors.surfaceBg,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final tab = _tabs[i];
                    final isActive = _index == i;
                    return Expanded(
                      flex: isActive ? 2 : 1,
                      child: _NavTab(
                        tab: tab,
                        isActive: isActive,
                        onTap: () {
                          setState(() => _index = i);
                          context.go(_paths[i]);
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final ({String label, IconData icon, IconData activeIcon}) tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? 16 : 10,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: isActive ? cs.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? tab.activeIcon : tab.icon,
                  size: 22,
                  color: isActive
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
