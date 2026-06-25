import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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
import '../features/merchant/catalog/pages/merchantCatalogPage.dart';
import '../features/merchant/comingSoon/pages/merchantComingSoonPage.dart';
import '../features/merchant/coupons/pages/merchantCouponsPage.dart';
import '../features/merchant/customers/pages/merchantCustomersPage.dart';
import '../features/merchant/dashboard/pages/merchantDashboardPage.dart';
import '../features/merchant/features/pages/merchantFeaturesPage.dart';
import '../features/merchant/feedManager/pages/merchantFeedManagePage.dart';
import '../features/merchant/feedManager/pages/merchantPostComposePage.dart';
import '../features/merchant/feedManager/pages/merchantStampAdCreatePage.dart';
import '../features/invite/pages/merchantInvitePage.dart';
import '../features/merchant/catalog/pages/merchantCategoriesPage.dart';
import '../features/merchant/catalog/pages/merchantItemTagsPage.dart';
import '../features/merchant/catalog/pages/merchantItemsPage.dart';
import '../features/merchant/catalog/pages/merchantMenuDesignPage.dart';
import '../features/merchant/catalog/pages/merchantQrCodesPage.dart';
import '../features/merchant/catalog/pages/merchantRunnersPage.dart';
import '../features/merchant/coupons/pages/merchantCouponEditPage.dart';
import '../features/merchant/orders/pages/merchantFinancePage.dart';
import '../features/merchant/orders/pages/merchantOrderDetailPage.dart';
import '../features/merchant/orders/pages/merchantOrderTablesPage.dart';
import '../features/merchant/orders/pages/merchantOrdersPage.dart';
import '../features/merchant/points/pages/merchantPointRewardEditPage.dart';
import '../features/merchant/points/pages/merchantPointSystemEditPage.dart';
import '../features/merchant/points/pages/merchantPointsPage.dart';
import '../features/merchant/shopSettings/pages/merchantMenuSettingsPage.dart';
import '../features/merchant/shopSettings/pages/merchantShopSettingsPage.dart';
import '../features/merchant/stamps/pages/merchantStampEditPage.dart';
import '../features/merchant/stamps/pages/merchantStampsPage.dart';
import '../features/stamps/pages/stampTapPage.dart';
import '../features/merchant/tables/pages/merchantTablesPage.dart';
import '../features/support/pages/merchantSupportPage.dart';
import '../features/placeholder/pages/foundationPlaceholderPage.dart';
import '../features/public/shop/pages/publicShopPage.dart';
import '../core/services/authService.dart';
import '../core/services/firestoreService.dart';
import '../core/theme/appTheme.dart';
import '../features/user/discover/models/publicMerchantUserModel.dart';
import '../features/user/feed/models/feedPostModel.dart';
import '../features/user/feed/pages/userFeedDetailPage.dart';
import '../features/user/feed/services/userFeedService.dart';
import '../features/user/partners/pages/userPartnerDetailPage.dart';
import '../features/user/partners/pages/userPartnerStampsPage.dart';
import '../features/user/partners/services/userPartnersService.dart';
import '../features/user/shell/userShellPage.dart';

/// Legt das Google-Home-Dark Merchant-Theme über eine Route, damit alle
/// Material-Widgets (Eingaben, Dialoge, Sheets) im Merchant-Bereich dunkel
/// rendern. Nur für Merchant- und Merchant-Auth-Routen verwenden.
Widget _merchantDark(Widget child) {
  return Theme(data: AppTheme.merchantDark, child: child);
}

/// Gecachte Rolle + Merchant-Freigabestatus des eingeloggten Accounts, damit
/// der Router-Guard /merchant/* prüfen kann, ohne bei jeder Navigation erneut
/// Firestore zu lesen. Wird bei jedem Auth-Wechsel invalidiert.
class _MerchantAccess {
  const _MerchantAccess(this.role, this.status);
  final String? role; // 'user' | 'merchant' | null (unbekannt)
  final String? status; // 'approved' | 'pending' | 'rejected' | …
}

final Map<String, _MerchantAccess> _accessCache = {};

/// Lässt GoRouter.redirect bei Login/Logout erneut laufen und leert dabei den
/// Access-Cache, damit ein neuer Account neu bewertet wird.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.listen((_) {
      _accessCache.clear();
      notifyListeners();
    });
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authRefresh = _AuthRefresh(FirebaseAuth.instance.authStateChanges());

/// Lädt (gecacht) Rolle + Freigabestatus für [uid].
Future<_MerchantAccess> _resolveMerchantAccess(
  BuildContext context,
  String uid,
) async {
  final cached = _accessCache[uid];
  if (cached != null) return cached;
  final firestore = context.read<FirestoreService>();
  try {
    final profile = await firestore.getUserProfile(uid);
    final role = profile?['role'] as String?;
    String? status;
    if (role == 'merchant') {
      final merchant = await firestore.getMerchantProfile(uid);
      status = merchant?['verificationStatus'] as String? ?? 'pending';
    }
    final access = _MerchantAccess(role, status);
    // Nur finalen Zustand cachen – „pending" muss neu geprüft werden, damit
    // eine frische Freigabe (approved) sofort greift (nicht hängen bleibt).
    if (role == 'user' || status == 'approved') {
      _accessCache[uid] = access;
    }
    return access;
  } catch (_) {
    // Lesefehler (offline/Rules): als unbekannt behandeln, NICHT cachen.
    return const _MerchantAccess(null, null);
  }
}

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
    refreshListenable: _authRefresh,
    redirect: (context, state) async {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      final loc = state.matchedLocation;

      // Ein anonymer Account (z. B. aus dem NFC-/QR-Stempel-Flow via
      // signInAnonymously) zählt NICHT als „eingeloggt" für geschützte Bereiche.
      final isRealUser = user != null && !user.isAnonymous;

      // Landing → Rollen-Weiche (nur für echte Accounts).
      if (loc == '/' && isRealUser) {
        return '/auth/roleGate';
      }

      // Guard: /user/* nur für echte, eingeloggte Nutzer. AUSNAHME: teilbare
      // Inhalts-Deep-Links — ein Beitrag, ein Merchant-Profil und die
      // Merchant-Stempelseite — bleiben ohne Login sichtbar.
      if (loc.startsWith('/user/') && !isRealUser) {
        const publicUserPrefixes = [
          '/user/feed/', // einzelner Beitrag
          '/user/partners/', // Merchant-Profil
          '/user/stamps/', // Merchant-Stempelseite (aus Werbe-Deep-Link)
        ];
        final isPublic = publicUserPrefixes.any((p) => loc.startsWith(p));
        if (!isPublic) return '/auth/userLogin';
      }

      // Guard: /merchant/* nur für eingeloggte, freigegebene Merchants.
      // (Merchant-Auth-Routen liegen unter /auth/merchant* und sind NICHT
      // betroffen, damit Login/Registrierung erreichbar bleiben.)
      if (loc.startsWith('/merchant')) {
        if (!isRealUser) return '/auth/merchantLogin';
        final access = await _resolveMerchantAccess(context, user.uid);
        if (access.role != 'merchant') {
          // Eingeloggt, aber kein Merchant → an die richtige Stelle leiten.
          return access.role == 'user' ? '/user/discover' : '/auth/chooseRole';
        }
        if (access.status != 'approved') {
          return '/auth/merchantPending?status=${access.status ?? 'pending'}';
        }
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
        redirect: (_, _) => '/auth/userLogin',
      ),
      GoRoute(
        path: '/auth/register',
        redirect: (_, _) => '/auth/userRegister',
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
        builder: (context, state) => _merchantDark(const MerchantLoginPage()),
      ),
      GoRoute(
        path: '/auth/merchantRegister',
        name: merchantRegister,
        builder: (context, state) =>
            _merchantDark(const MerchantRegisterPage()),
      ),
      GoRoute(
        path: '/auth/forgotPassword',
        name: forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/auth/merchantForgotPassword',
        name: merchantForgotPassword,
        builder: (context, state) =>
            _merchantDark(const MerchantForgotPasswordPage()),
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
        builder: (context, state) => _merchantDark(
          MerchantPendingPage(
            status: state.uri.queryParameters['status'],
          ),
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
        path: '/user/explore',
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
        // Deep link from a stamp-card ad / CTA: open this merchant's stamp
        // cards (add-to-wallet). Accepts a preloaded merchant via state.extra.
        path: '/user/stamps/:merchantId',
        builder: (context, state) {
          final merchant = state.extra;
          final merchantId = state.pathParameters['merchantId'] ?? '';
          if (merchant is PublicMerchantUserModel) {
            return UserPartnerStampsPage(
              merchantId: merchant.merchantId,
              shopName: merchant.shopName,
              merchant: merchant,
            );
          }
          return _PartnerStampsLoader(merchantId: merchantId);
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
        path: '/runner/:merchantId',
        builder: (context, state) => PublicShopPage(
          merchantId: state.pathParameters['merchantId'] ?? '',
          forceRunner: true,
        ),
      ),
      GoRoute(
        path: '/merchant/dashboard',
        name: merchantDashboard,
        builder: (context, state) => _merchantDark(const MerchantDashboardPage()),
      ),
      GoRoute(
        path: '/merchant/finance',
        builder: (context, state) => _merchantDark(const MerchantFinancePage()),
      ),
      GoRoute(
        path: '/merchant/features',
        builder: (context, state) => _merchantDark(const MerchantFeaturesPage()),
      ),
      GoRoute(
        path: '/merchant/shop',
        builder: (context, state) =>
            _merchantDark(const MerchantShopSettingsPage()),
      ),
      GoRoute(
        path: '/merchant/menu',
        builder: (context, state) =>
            _merchantDark(const MerchantMenuSettingsPage()),
      ),
      GoRoute(
        path: '/merchant/customers',
        builder: (context, state) =>
            _merchantDark(const MerchantCustomersPage()),
      ),
      GoRoute(
        path: '/merchant/stamps',
        builder: (context, state) => _merchantDark(const MerchantStampsPage()),
      ),
      GoRoute(
        path: '/merchant/stamps/edit',
        builder: (context, state) => _merchantDark(
          MerchantStampEditPage(
            stampCardId: state.uri.queryParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/stamps/edit/:stampCardId',
        builder: (context, state) => _merchantDark(
          MerchantStampEditPage(
            stampCardId: state.pathParameters['stampCardId'],
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/points',
        builder: (context, state) => _merchantDark(const MerchantPointsPage()),
      ),
      GoRoute(
        path: '/merchant/points/system/edit',
        builder: (context, state) => _merchantDark(
          MerchantPointSystemEditPage(
            systemId: state.uri.queryParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/points/system/edit/:systemId',
        builder: (context, state) => _merchantDark(
          MerchantPointSystemEditPage(
            systemId: state.pathParameters['systemId'],
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/points/rewards/edit',
        builder: (context, state) => _merchantDark(
          MerchantPointRewardEditPage(
            rewardId: state.uri.queryParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/points/rewards/edit/:rewardId',
        builder: (context, state) => _merchantDark(
          MerchantPointRewardEditPage(
            rewardId: state.pathParameters['rewardId'],
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/catalog',
        builder: (context, state) => _merchantDark(const MerchantCatalogPage()),
      ),
      GoRoute(
        path: '/merchant/catalog/design',
        builder: (context, state) =>
            _merchantDark(const MerchantMenuDesignPage()),
      ),
      GoRoute(
        path: '/merchant/catalog/qr',
        builder: (context, state) => _merchantDark(const MerchantQrCodesPage()),
      ),
      GoRoute(
        path: '/merchant/catalog/runners',
        builder: (context, state) => _merchantDark(const MerchantRunnersPage()),
      ),
      GoRoute(
        path: '/merchant/catalog/demo',
        redirect: (_, _) => '/merchant/catalog',
      ),
      // Coupons (#36): vollständig gebaut, aber bewusst NOCH NICHT live – kein
      // Dashboard-/Feature-Einstieg (merchantFeatureModule coupons = comingSoon).
      // Nur per Deep-Link erreichbar; die Schreibpfade sind durch den
      // /merchant/*-Route-Guard (#3) + die Firestore-Rules geschützt.
      // Aktivieren = Feature-Toggle aktiv schalten + Dashboard-Modul ergänzen.
      GoRoute(
        path: '/merchant/coupons',
        builder: (context, state) => _merchantDark(const MerchantCouponsPage()),
      ),
      GoRoute(
        path: '/merchant/coupons/edit',
        builder: (context, state) => _merchantDark(
          MerchantCouponEditPage(
            couponId: state.uri.queryParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/coupons/edit/:couponId',
        builder: (context, state) => _merchantDark(
          MerchantCouponEditPage(
            couponId: state.pathParameters['couponId'],
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/orders',
        builder: (context, state) => _merchantDark(const MerchantOrdersPage()),
      ),
      // Tisch-Routen VOR ':orderId', sonst matcht "tables" als orderId.
      GoRoute(
        path: '/merchant/orders/tables',
        builder: (context, state) =>
            _merchantDark(const MerchantOrderTablesPage()),
      ),
      GoRoute(
        path: '/merchant/orders/tables/:tableKey',
        builder: (context, state) => _merchantDark(
          MerchantTableOrdersPage(
            tableKey: state.pathParameters['tableKey'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/orders/:orderId',
        builder: (context, state) => _merchantDark(
          MerchantOrderDetailPage(
            orderId: state.pathParameters['orderId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/campaigns',
        builder: (context, state) => _merchantDark(
          const MerchantComingSoonPage(
            titleKey: 'merchant.campaigns.title',
            subtitleKey: 'merchant.campaigns.subtitle',
            tooltipKey: 'merchant.campaigns.tooltip',
            icon: Icons.emoji_events_rounded,
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/shifts',
        builder: (context, state) => _merchantDark(
          const MerchantComingSoonPage(
            titleKey: 'merchant.shifts.title',
            subtitleKey: 'merchant.shifts.subtitle',
            tooltipKey: 'merchant.shifts.tooltip',
            icon: Icons.calendar_month_rounded,
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/delivery',
        builder: (context, state) => _merchantDark(
          const MerchantComingSoonPage(
            titleKey: 'merchant.delivery.title',
            subtitleKey: 'merchant.delivery.subtitle',
            tooltipKey: 'merchant.delivery.tooltip',
            icon: Icons.delivery_dining_rounded,
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/reservations',
        builder: (context, state) => _merchantDark(
          const MerchantComingSoonPage(
            titleKey: 'merchant.reservations.title',
            subtitleKey: 'merchant.reservations.subtitle',
            tooltipKey: 'merchant.reservations.tooltip',
            icon: Icons.event_seat_rounded,
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/feed/create',
        builder: (context, state) => _merchantDark(
          MerchantPostComposePage(
            initialType: state.uri.queryParameters['type'],
          ),
        ),
      ),
      GoRoute(
        path: '/merchant/feed/manage',
        builder: (context, state) =>
            _merchantDark(const MerchantFeedManagePage()),
      ),
      GoRoute(
        path: '/merchant/feed/stamp-ad',
        builder: (context, state) =>
            _merchantDark(const MerchantStampAdCreatePage()),
      ),
      GoRoute(
        path: '/merchant/tools/categories',
        builder: (context, state) =>
            _merchantDark(const MerchantCategoriesPage()),
      ),
      GoRoute(
        path: '/merchant/tools/items',
        builder: (context, state) => _merchantDark(const MerchantItemsPage()),
      ),
      GoRoute(
        path: '/merchant/tools/itemTags',
        builder: (context, state) => _merchantDark(const MerchantItemTagsPage()),
      ),
      GoRoute(
        path: '/merchant/tools/shop',
        redirect: (_, _) => '/merchant/shop',
      ),
      GoRoute(
        path: '/merchant/tools/support',
        builder: (context, state) => _merchantDark(const MerchantSupportPage()),
      ),
      GoRoute(
        path: '/merchant/tools/invite',
        builder: (context, state) => _merchantDark(const MerchantInvitePage()),
      ),
      GoRoute(
        path: '/merchant/tools/feedManage',
        builder: (context, state) =>
            _merchantDark(const MerchantFeedManagePage()),
      ),
      GoRoute(
        path: '/merchant/tools/tables',
        builder: (context, state) => _merchantDark(const MerchantTablesPage()),
      ),
      // NFC stamp tap (and QR fallback). The chip's SUN URL points here:
      // /stamp?picc=…&cmac=…  → verified server-side by redeemStampTap.
      GoRoute(
        path: '/stamp',
        builder: (context, state) => StampTapPage(
          picc: state.uri.queryParameters['picc'] ?? '',
          cmac: state.uri.queryParameters['cmac'] ?? '',
        ),
      ),
      // /s/<token>  → Path A static stick, verified by redeemStaticStamp.
      GoRoute(
        path: '/s/:token',
        builder: (context, state) => StampTapPage(
          token: state.pathParameters['token'] ?? '',
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
      // MUST stay last: a top-level custom merchant handle (Insta-style link
      // <origin>/<handle>). Single-segment paths that match no route above land
      // here and resolve to that merchant's public profile.
      GoRoute(
        path: '/:handle',
        builder: (context, state) =>
            _HandleLoader(handle: state.pathParameters['handle'] ?? ''),
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

class _PartnerStampsLoader extends StatelessWidget {
  const _PartnerStampsLoader({required this.merchantId});

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
        return UserPartnerStampsPage(
          merchantId: merchant.merchantId,
          shopName: merchant.shopName,
          merchant: merchant,
        );
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

/// Resolves a custom merchant handle (slug) → that merchant's public profile.
class _HandleLoader extends StatelessWidget {
  const _HandleLoader({required this.handle});

  final String handle;

  @override
  Widget build(BuildContext context) {
    final service = UserPartnersService(
      firestoreService: context.read<FirestoreService>(),
    );
    return FutureBuilder<PublicMerchantUserModel?>(
      future: service.fetchPartnerByHandle(handle),
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
