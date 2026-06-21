class AppLimits {
  const AppLimits._();

  static const defaultPageSize = 20;

  /// Obergrenze für das Laden der Coupon-Liste (Schutz gegen unbegrenzte Reads,
  /// auch wenn sich archivierte Coupons ansammeln).
  static const couponsPageSize = 100;

  /// Obergrenzen für die Punkte-Collections (Systeme/Belohnungen) und den
  /// Artikel-Picker – Schutz gegen unbegrenzte Reads (#64).
  static const pointsSystemsPageSize = 50;
  static const pointsRewardsPageSize = 100;
  static const pointsItemsPageSize = 300;
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
