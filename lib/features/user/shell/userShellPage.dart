import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/features/user/discover/pages/userDiscoverPage.dart';
import 'package:lokka/features/user/discover/providers/userDiscoverProvider.dart';
import 'package:lokka/features/user/discover/services/userDiscoverService.dart';
import 'package:lokka/features/user/partners/pages/userPartnersPage.dart';
import 'package:lokka/features/user/partners/providers/userPartnersProvider.dart';
import 'package:lokka/features/user/partners/services/userPartnersService.dart';
import 'package:lokka/features/user/profile/pages/userProfilePage.dart';
import 'package:lokka/features/user/profile/providers/userProfileProvider.dart';
import 'package:lokka/features/user/profile/services/userProfileService.dart';
import 'package:lokka/features/user/wallet/pages/userWalletPage.dart';
import 'package:lokka/features/user/wallet/providers/userWalletProvider.dart';
import 'package:lokka/features/user/wallet/services/userWalletService.dart';

class UserShellPage extends StatefulWidget {
  const UserShellPage({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<UserShellPage> createState() => _UserShellPageState();
}

class _UserShellPageState extends State<UserShellPage> {
  late int _index = widget.initialIndex;
  bool _showToolbar = true;

  static const _tabs = [
    (label: 'Entdecken', icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded),
    (label: 'Partner', icon: Icons.store_outlined, activeIcon: Icons.store_rounded),
    (label: 'Wallet', icon: Icons.wallet_outlined, activeIcon: Icons.wallet_rounded),
    (label: 'Profil', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
  ];

  static const _paths = [
    '/user/discover',
    '/user/partners',
    '/user/wallet',
    '/user/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserDiscoverProvider>(
          create: (_) => UserDiscoverProvider(
            service: UserDiscoverService(
              firestoreService: firestoreService,
              authService: authService,
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
            ),
          ),
        ),
        ChangeNotifierProvider<UserProfileProvider>(
          create: (_) => UserProfileProvider(
            service: UserProfileService(
              firestoreService: firestoreService,
              authService: authService,
            ),
          ),
        ),
      ],
      child: Builder(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.background,
          extendBody: true,
          body: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              final show = notification.direction != ScrollDirection.reverse;
              if (show != _showToolbar) setState(() => _showToolbar = show);
              return false;
            },
            child: IndexedStack(
              index: _index,
              children: const [
                UserDiscoverPage(),
                UserPartnersPage(),
                UserWalletPage(),
                UserProfilePage(),
              ],
            ),
          ),
          bottomNavigationBar: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: _showToolbar ? Offset.zero : const Offset(0, 1.4),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: _showToolbar ? 1 : 0,
              child: _buildBottomNav(ctx),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isActive = _index == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _index = i);
                    context.go(_paths[i]);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(
                        horizontal: isActive ? 12 : 8,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.mintSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? tab.activeIcon : tab.icon,
                            size: 22,
                            color: isActive ? AppColors.black : AppColors.gray500,
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Text(
                              tab.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      ),
    );
  }
}
