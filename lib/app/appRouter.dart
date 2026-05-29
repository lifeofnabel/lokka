import 'package:go_router/go_router.dart';

import '../features/landing/pages/landingPage.dart';

class AppRouter {
  const AppRouter._();

  static const landing = 'landing';
  static const login = 'login';
  static const register = 'register';
  static const forgotPassword = 'forgotPassword';
  static const authLoading = 'authLoading';
  static const authRoleGate = 'authRoleGate';
  static const merchantPending = 'merchantPending';
  static const userShell = 'userShell';
  static const merchantShell = 'merchantShell';
  static const claim = 'claim';
  static const publicShop = 'publicShop';

  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: landing,
        builder: (context, state) => const LandingPage(),
      ),
    ],
  );
}
