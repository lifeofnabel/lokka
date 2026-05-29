import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/features/user/discover/pages/userDiscoverPage.dart';
import 'package:lokka/features/user/discover/providers/userDiscoverProvider.dart';
import 'package:lokka/features/user/discover/services/userDiscoverService.dart';
import 'package:lokka/features/user/feed/pages/userFeedPage.dart';
import 'package:lokka/features/user/feed/providers/userFeedProvider.dart';
import 'package:lokka/features/user/feed/services/userFeedService.dart';
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
  const UserShellPage({super.key});

  @override
  State<UserShellPage> createState() => _UserShellPageState();
}

class _UserShellPageState extends State<UserShellPage> {
  int _index = 0;

  static const _tabs = [
    (label: 'Entdecken', icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded),
    (label: 'Feed', icon: Icons.newspaper_outlined, activeIcon: Icons.newspaper_rounded),
    (label: 'Partner', icon: Icons.store_outlined, activeIcon: Icons.store_rounded),
    (label: 'Wallet', icon: Icons.wallet_outlined, activeIcon: Icons.wallet_rounded),
    (label: 'Profil', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserDiscoverProvider>(
          create: (_) => UserDiscoverProvider(
            service: UserDiscoverService(firestoreService: firestoreService),
          ),
        ),
        ChangeNotifierProvider<UserFeedProvider>(
          create: (_) => UserFeedProvider(
            service: UserFeedService(
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
          body: IndexedStack(
            index: _index,
            children: const [
              UserDiscoverPage(),
              UserFeedPage(),
              UserPartnersPage(),
              UserWalletPage(),
              UserProfilePage(),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(ctx),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
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
                  onTap: () => setState(() => _index = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? tab.activeIcon : tab.icon,
                        size: 24,
                        color: isActive ? AppColors.black : AppColors.gray300,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive ? AppColors.black : AppColors.gray300,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
