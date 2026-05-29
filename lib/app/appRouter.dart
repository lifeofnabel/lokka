import 'package:go_router/go_router.dart';

import '../features/auth/pages/authChooseRolePage.dart';
import '../features/auth/pages/authRoleGatePage.dart';
import '../features/auth/pages/demoComingSoonPage.dart';
import '../features/auth/pages/emailVerificationPage.dart';
import '../features/auth/pages/forgotPasswordPage.dart';
import '../features/auth/pages/merchantLoginPage.dart';
import '../features/auth/pages/merchantPendingPage.dart';
import '../features/auth/pages/merchantRegisterPage.dart';
import '../features/auth/pages/userLoginPage.dart';
import '../features/auth/pages/userRegisterPage.dart';
import '../features/dev/pages/devFoundationPage.dart';
import '../features/landing/pages/landingPage.dart';
import '../features/placeholder/pages/foundationPlaceholderPage.dart';

class AppRouter {
  const AppRouter._();

  static const landing = 'landing';
  static const userLogin = 'userLogin';
  static const userRegister = 'userRegister';
  static const merchantLogin = 'merchantLogin';
  static const merchantRegister = 'merchantRegister';
  static const forgotPassword = 'forgotPassword';
  static const emailVerification = 'emailVerification';
  static const authRoleGate = 'authRoleGate';
  static const chooseRole = 'chooseRole';
  static const merchantPending = 'merchantPending';
  static const demoComingSoon = 'demoComingSoon';
  static const userDiscover = 'userDiscover';
  static const merchantDashboard = 'merchantDashboard';
  static const claimStamp = 'claimStamp';
  static const claimCampaign = 'claimCampaign';
  static const claimCoupon = 'claimCoupon';
  static const claimWalletJoin = 'claimWalletJoin';
  static const devFoundation = 'devFoundation';

  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: landing,
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/auth/login',
        redirect: (_, __) => '/auth/userLogin',
      ),
      GoRoute(
        path: '/auth/register',
        redirect: (_, __) => '/auth/userRegister',
      ),
      GoRoute(
        path: '/auth/userLogin',
        name: userLogin,
        builder: (context, state) => const UserLoginPage(),
      ),
      GoRoute(
        path: '/auth/userRegister',
        name: userRegister,
        builder: (context, state) => const UserRegisterPage(),
      ),
      GoRoute(
        path: '/auth/merchantLogin',
        name: merchantLogin,
        builder: (context, state) => const MerchantLoginPage(),
      ),
      GoRoute(
        path: '/auth/merchantRegister',
        name: merchantRegister,
        builder: (context, state) => const MerchantRegisterPage(),
      ),
      GoRoute(
        path: '/auth/forgotPassword',
        name: forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/auth/emailVerification',
        name: emailVerification,
        builder: (context, state) => EmailVerificationPage(
          next: state.uri.queryParameters['next'] ?? 'user',
        ),
      ),
      GoRoute(
        path: '/auth/roleGate',
        name: authRoleGate,
        builder: (context, state) => const AuthRoleGatePage(),
      ),
      GoRoute(
        path: '/auth/chooseRole',
        name: chooseRole,
        builder: (context, state) => const AuthChooseRolePage(),
      ),
      GoRoute(
        path: '/auth/merchantPending',
        name: merchantPending,
        builder: (context, state) => MerchantPendingPage(
          status: state.uri.queryParameters['status'],
        ),
      ),
      GoRoute(
        path: '/auth/demoComingSoon',
        name: demoComingSoon,
        builder: (context, state) => const DemoComingSoonPage(),
      ),
      GoRoute(
        path: '/user/discover',
        name: userDiscover,
        builder: (context, state) => const FoundationPlaceholderPage(
          titleKey: 'user.discover.title',
        ),
      ),
      GoRoute(
        path: '/merchant/dashboard',
        name: merchantDashboard,
        builder: (context, state) => const FoundationPlaceholderPage(
          titleKey: 'merchant.dashboard.title',
        ),
      ),
      GoRoute(
        path: '/claim/stamp',
        name: claimStamp,
        builder: (context, state) => const FoundationPlaceholderPage(
          titleKey: 'claim.stamp.title',
        ),
      ),
      GoRoute(
        path: '/claim/campaign',
        name: claimCampaign,
        builder: (context, state) => const FoundationPlaceholderPage(
          titleKey: 'claim.campaign.title',
        ),
      ),
      GoRoute(
        path: '/claim/coupon',
        name: claimCoupon,
        builder: (context, state) => const FoundationPlaceholderPage(
          titleKey: 'claim.coupon.title',
        ),
      ),
      GoRoute(
        path: '/claim/walletJoin',
        name: claimWalletJoin,
        builder: (context, state) => const FoundationPlaceholderPage(
          titleKey: 'claim.walletJoin.title',
        ),
      ),
      GoRoute(
        path: '/dev/foundation',
        name: devFoundation,
        builder: (context, state) => const DevFoundationPage(),
      ),
    ],
  );
}
