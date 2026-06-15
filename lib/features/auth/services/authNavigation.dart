import '../providers/authProvider.dart';

String pathForAuthDestination(AuthDestination destination) {
  return switch (destination) {
    AuthDestination.userDiscover => '/user/discover',
    AuthDestination.merchantDashboard => '/merchant/dashboard',
    AuthDestination.merchantPending => '/auth/merchantPending',
    AuthDestination.chooseRole => '/auth/chooseRole',
    AuthDestination.emailVerificationUser => '/auth/emailVerification?next=user',
    AuthDestination.emailVerificationMerchant => '/auth/emailVerification?next=merchant',
  };
}
