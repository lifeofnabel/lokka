class AppLimits {
  const AppLimits._();

  static const defaultPageSize = 20;

  /// Obergrenze für das Laden der Coupon-Liste (Schutz gegen unbegrenzte Reads,
  /// auch wenn sich archivierte Coupons ansammeln).
  static const couponsPageSize = 100;
  static const maxFeedPostsPerDay = 3;
  static const maxFeedPostsPerWeek = 14;
  static const maxStampCardsActivatedPerWeek = 4;
  static const auditLogRetentionMonths = 3;

  static const feedPostOnce = 3;
  static const stampCardWeekly = 2;
  static const pointsSystemWeekly = 1;
  static const menuCatalogWeekly = 3;
  static const couponCodes = 0;
  static const campaigns = 0;
  static const orders = 0;
}
