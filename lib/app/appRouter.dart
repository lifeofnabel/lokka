import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/pages/authChooseRolePage.dart';
import '../features/auth/pages/authRoleGatePage.dart';
import '../features/auth/pages/demoComingSoonPage.dart';
import '../features/auth/pages/emailVerificationPage.dart';
import '../features/auth/pages/forgotPasswordPage.dart';
import '../features/auth/pages/merchantLoginPage.dart';
import '../features/auth/pages/merchantForgotPasswordPage.dart';
import '../features/auth/pages/merchantPendingPage.dart';
import '../features/auth/pages/merchantRegisterPage.dart';
import '../features/auth/pages/userLoginPage.dart';
import '../features/auth/pages/userRegisterPage.dart';
import '../features/dev/pages/devFoundationPage.dart';
import '../features/landing/pages/landingPage.dart';
import '../features/merchant/billing/pages/merchantBillingPage.dart';
import '../features/merchant/catalog/pages/merchantCatalogDemoPage.dart';
import '../features/merchant/catalog/pages/merchantCatalogPage.dart';
import '../features/merchant/comingSoon/pages/merchantComingSoonPage.dart';
import '../features/merchant/coupons/pages/merchantCouponsPage.dart';
import '../features/merchant/customers/pages/merchantCustomersPage.dart';
import '../features/merchant/dashboard/pages/merchantDashboardPage.dart';
import '../features/merchant/features/pages/merchantFeaturesPage.dart';
import '../features/merchant/feedManager/pages/merchantFeedCreatePage.dart';
import '../features/merchant/feedManager/pages/merchantFeedManagePage.dart';
import '../features/invite/pages/merchantInvitePage.dart';
import '../features/merchant/catalog/pages/merchantCategoriesPage.dart';
import '../features/merchant/catalog/pages/merchantItemsPage.dart';
import '../features/merchant/coupons/pages/merchantCouponEditPage.dart';
import '../features/merchant/orders/pages/merchantOrderDetailPage.dart';
import '../features/merchant/orders/pages/merchantOrdersPage.dart';
import '../features/merchant/points/pages/merchantPointRewardEditPage.dart';
import '../features/merchant/points/pages/merchantPointSystemEditPage.dart';
import '../features/merchant/points/pages/merchantPointsPage.dart';
import '../features/merchant/shopSettings/pages/merchantShopSettingsPage.dart';
import '../features/merchant/stamps/pages/merchantStampEditPage.dart';
import '../features/merchant/stamps/pages/merchantStampsPage.dart';
import '../features/merchant/tables/pages/merchantTablesPage.dart';
import '../features/support/pages/merchantSupportPage.dart';
import '../features/placeholder/pages/foundationPlaceholderPage.dart';
import '../features/public/shop/pages/publicShopPage.dart';
import '../core/services/authService.dart';
import '../core/services/firestoreService.dart';
import '../features/user/discover/models/publicMerchantUserModel.dart';
import '../features/user/feed/models/feedPostModel.dart';
import '../features/user/feed/pages/userFeedDetailPage.dart';
import '../features/user/feed/services/userFeedService.dart';
import '../features/user/partners/pages/userPartnerDetailPage.dart';
import '../features/user/partners/services/userPartnersService.dart';
import '../features/user/shell/userShellPage.dart';

class AppRouter {
  const AppRouter._();

  static const landing = 'landing';
  static const userLogin = 'userLogin';
  static const userRegister = 'userRegister';
  static const merchantLogin = 'merchantLogin';
  static const merchantRegister = 'merchantRegister';
  static const forgotPassword = 'forgotPassword';
  static const merchantForgotPassword = 'merchantForgotPassword';
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
    redirect: (context, state) {
      final authService = context.read<AuthService>();
      final isLanding = state.matchedLocation == '/';
      if (isLanding && authService.currentUser != null) {
        return '/auth/roleGate';
      }
      return null;
    },
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
        path: '/auth/merchantForgotPassword',
        name: merchantForgotPassword,
        builder: (context, state) => const MerchantForgotPasswordPage(),
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
        builder: (context, state) => const UserShellPage(initialIndex: 0),
      ),
      GoRoute(
        path: '/user/partners',
        builder: (context, state) => const UserShellPage(initialIndex: 1),
      ),
      GoRoute(
        path: '/user/wallet',
        builder: (context, state) => const UserShellPage(initialIndex: 2),
      ),
      GoRoute(
        path: '/user/profile',
        builder: (context, state) => const UserShellPage(initialIndex: 3),
      ),
      GoRoute(
        path: '/user/partners/:merchantId',
        builder: (context, state) {
          final merchant = state.extra;
          if (merchant is PublicMerchantUserModel) {
            return UserPartnerDetailPage(merchant: merchant);
          }
          return _PartnerDetailLoader(
            merchantId: state.pathParameters['merchantId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/user/feed/:postId',
        builder: (context, state) {
          final post = state.extra;
          if (post is FeedPostModel) {
            return UserFeedDetailPage(
              post: post,
              feedService: UserFeedService(
                firestoreService: context.read<FirestoreService>(),
                authService: context.read<AuthService>(),
              ),
            );
          }
          return _FeedDetailLoader(postId: state.pathParameters['postId'] ?? '');
        },
      ),
      GoRoute(
        path: '/shop/:merchantId',
        builder: (context, state) => PublicShopPage(
          merchantId: state.pathParameters['merchantId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/shop/:merchantId/table/:tableId',
        builder: (context, state) => PublicShopPage(
          merchantId: state.pathParameters['merchantId'] ?? '',
          tableId: state.pathParameters['tableId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/merchant/dashboard',
        name: merchantDashboard,
        builder: (context, state) => const MerchantDashboardPage(),
      ),
      GoRoute(
        path: '/merchant/features',
        builder: (context, state) => const MerchantFeaturesPage(),
      ),
      GoRoute(
        path: '/merchant/shop',
        builder: (context, state) => const MerchantShopSettingsPage(),
      ),
      GoRoute(
        path: '/merchant/billing',
        builder: (context, state) => const MerchantBillingPage(),
      ),
      GoRoute(
        path: '/merchant/customers',
        builder: (context, state) => const MerchantCustomersPage(),
      ),
      GoRoute(
        path: '/merchant/stamps',
        builder: (context, state) => const MerchantStampsPage(),
      ),
      GoRoute(
        path: '/merchant/stamps/edit',
        builder: (context, state) => MerchantStampEditPage(
          stampCardId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/merchant/stamps/edit/:stampCardId',
        builder: (context, state) => MerchantStampEditPage(
          stampCardId: state.pathParameters['stampCardId'],
        ),
      ),
      GoRoute(
        path: '/merchant/points',
        builder: (context, state) => const MerchantPointsPage(),
      ),
      GoRoute(
        path: '/merchant/points/system/edit',
        builder: (context, state) => MerchantPointSystemEditPage(
          systemId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/merchant/points/system/edit/:systemId',
        builder: (context, state) => MerchantPointSystemEditPage(
          systemId: state.pathParameters['systemId'],
        ),
      ),
      GoRoute(
        path: '/merchant/points/rewards/edit',
        builder: (context, state) => MerchantPointRewardEditPage(
          rewardId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/merchant/points/rewards/edit/:rewardId',
        builder: (context, state) => MerchantPointRewardEditPage(
          rewardId: state.pathParameters['rewardId'],
        ),
      ),
      GoRoute(
        path: '/merchant/catalog',
        builder: (context, state) => const MerchantCatalogPage(),
      ),
      GoRoute(
        path: '/merchant/catalog/demo',
        builder: (context, state) => const MerchantCatalogDemoPage(),
      ),
      GoRoute(
        path: '/merchant/coupons',
        builder: (context, state) => const MerchantCouponsPage(),
      ),
      GoRoute(
        path: '/merchant/coupons/edit',
        builder: (context, state) => MerchantCouponEditPage(
          couponId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/merchant/coupons/edit/:couponId',
        builder: (context, state) => MerchantCouponEditPage(
          couponId: state.pathParameters['couponId'],
        ),
      ),
      GoRoute(
        path: '/merchant/orders',
        builder: (context, state) => const MerchantOrdersPage(),
      ),
      GoRoute(
        path: '/merchant/orders/:orderId',
        builder: (context, state) => MerchantOrderDetailPage(
          orderId: state.pathParameters['orderId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/merchant/campaigns',
        builder: (context, state) => const MerchantComingSoonPage(
          titleKey: 'merchant.campaigns.title',
          subtitleKey: 'merchant.campaigns.subtitle',
          tooltipKey: 'merchant.campaigns.tooltip',
          icon: Icons.emoji_events_rounded,
        ),
      ),
      GoRoute(
        path: '/merchant/shifts',
        builder: (context, state) => const MerchantComingSoonPage(
          titleKey: 'merchant.shifts.title',
          subtitleKey: 'merchant.shifts.subtitle',
          tooltipKey: 'merchant.shifts.tooltip',
          icon: Icons.calendar_month_rounded,
        ),
      ),
      GoRoute(
        path: '/merchant/feed/create',
        builder: (context, state) => const MerchantFeedCreatePage(),
      ),
      GoRoute(
        path: '/merchant/feed/manage',
        builder: (context, state) => const MerchantFeedManagePage(),
      ),
      GoRoute(
        path: '/merchant/tools/categories',
        builder: (context, state) => const MerchantCategoriesPage(),
      ),
      GoRoute(
        path: '/merchant/tools/items',
        builder: (context, state) => const MerchantItemsPage(),
      ),
      GoRoute(
        path: '/merchant/tools/shop',
        redirect: (_, __) => '/merchant/shop',
      ),
      GoRoute(
        path: '/merchant/tools/support',
        builder: (context, state) => const MerchantSupportPage(),
      ),
      GoRoute(
        path: '/merchant/tools/invite',
        builder: (context, state) => const MerchantInvitePage(),
      ),
      GoRoute(
        path: '/merchant/tools/feedManage',
        builder: (context, state) => const MerchantFeedManagePage(),
      ),
      GoRoute(
        path: '/merchant/tools/tables',
        builder: (context, state) => const MerchantTablesPage(),
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

class _PartnerDetailLoader extends StatelessWidget {
  const _PartnerDetailLoader({required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context) {
    final service = UserPartnersService(
      firestoreService: context.read<FirestoreService>(),
    );
    return FutureBuilder<PublicMerchantUserModel?>(
      future: service.fetchPartnerById(merchantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _RouteLoader();
        }
        final merchant = snapshot.data;
        if (merchant == null) {
          return const FoundationPlaceholderPage(
            titleKey: 'user.partner.detail.title',
          );
        }
        return UserPartnerDetailPage(merchant: merchant);
      },
    );
  }
}

class _FeedDetailLoader extends StatelessWidget {
  const _FeedDetailLoader({required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    final service = UserFeedService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
    );
    return FutureBuilder<FeedPostModel?>(
      future: service.fetchPostById(postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _RouteLoader();
        }
        final post = snapshot.data;
        if (post == null) {
          return const FoundationPlaceholderPage(
            titleKey: 'user.feed.detail.title',
          );
        }
        return UserFeedDetailPage(post: post, feedService: service);
      },
    );
  }
}

class _RouteLoader extends StatelessWidget {
  const _RouteLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
