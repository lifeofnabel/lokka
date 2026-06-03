class FirebasePaths {
  const FirebasePaths._();

  static const system = 'system';
  static const chooser = 'chooser';
  static const areas = 'areas';
  static const shopTypes = 'shopTypes';
  static const users = 'users';
  static const merchants = 'merchants';
  static const publicMerchants = 'publicMerchants';
  static const feed = 'feed';
  static const stampClaims = 'stampClaims';
  static const pointsEvents = 'pointsEvents';
  static const couponClaims = 'couponClaims';
  static const campaignEntries = 'campaignEntries';
  static const claimLinks = 'claimLinks';
  static const dailyClaimKeys = 'dailyClaimKeys';
  static const walletEvents = 'walletEvents';
  static const billingEvents = 'billingEvents';
  static const auditLogs = 'auditLogs';
  static const riskEvents = 'riskEvents';
  static const supportTickets = 'supportTickets';
  static const merchantInvites = 'merchantInvites';
  static const aiUsage = 'aiUsage';
  static const devChecks = 'devChecks';

  static const openingHours = 'openingHours';
  static const featureConfigs = 'featureConfigs';
  static const customers = 'customers';
  static const feedPosts = 'feedPosts';
  static const walletCards = 'walletCards';
  static const stampCards = 'stampCards';
  static const pointsSystems = 'pointsSystems';
  static const pointsRewards = 'pointsRewards';
  static const coupons = 'coupons';
  static const campaigns = 'campaigns';
  static const orders = 'orders';
  static const items = 'items';
  static const itemTags = 'itemTags';
  static const itemCategories = 'itemCategories';
  static const tables = 'tables';
  static const tableAreas = 'tableAreas';
  static const billingWeeks = 'billingWeeks';
  static const appointments = 'appointments';
  static const shifts = 'shifts';

  static const likedPosts = 'likedPosts';
  static const postInteractions = 'postInteractions';
  static const availableRewards = 'availableRewards';
  static const stampProgress = 'stampProgress';
  static const pointsProgress = 'pointsProgress';

  static const likes = 'likes';
  static const views = 'views';
  static const clicks = 'clicks';
  static const reviews = 'reviews';
  static const messages = 'messages';
  static const accountDeletionRequests = 'accountDeletionRequests';

  static String user(String uid) => '$users/$uid';
  static String merchant(String merchantId) => '$merchants/$merchantId';
  static String publicMerchant(String merchantId) =>
      '$publicMerchants/$merchantId';
  static String feedPost(String postId) => '$feed/$postId';
  static String billingEvent(String eventId) => '$billingEvents/$eventId';
  static String supportTicket(String ticketId) => '$supportTickets/$ticketId';
  static String merchantInvite(String inviteId) => '$merchantInvites/$inviteId';
  static String aiUsageEntry(String usageId) => '$aiUsage/$usageId';
  static String accountDeletionRequest(String requestId) =>
      '$accountDeletionRequests/$requestId';
  static String devCheck(String checkId) => '$devChecks/$checkId';
  static String chooserDocument(String documentId) => '$chooser/$documentId';

  static String userWalletCards(String uid) => '${user(uid)}/$walletCards';
  static String userWalletCard(String uid, String cardId) =>
      '${userWalletCards(uid)}/$cardId';
  static String userLikedPosts(String uid) => '${user(uid)}/$likedPosts';
  static String userLikedPost(String uid, String postId) =>
      '${userLikedPosts(uid)}/$postId';
  static String userPostInteractions(String uid) =>
      '${user(uid)}/$postInteractions';
  static String userPostInteraction(String uid, String postId) =>
      '${userPostInteractions(uid)}/$postId';
  static String userStampProgress(String uid) => '${user(uid)}/$stampProgress';
  static String userStampProgressEntry(String uid, String progressId) =>
      '${userStampProgress(uid)}/$progressId';
  static String userPointsProgress(String uid) => '${user(uid)}/$pointsProgress';
  static String userPointsProgressEntry(String uid, String progressId) =>
      '${userPointsProgress(uid)}/$progressId';
  static String userCoupons(String uid) => '${user(uid)}/$coupons';
  static String userAvailableRewards(String uid) =>
      '${user(uid)}/$availableRewards';
  static String userOrders(String uid) => '${user(uid)}/$orders';

  static String merchantFeatureConfigs(String merchantId) =>
      '${merchant(merchantId)}/$featureConfigs';
  static String merchantFeatureConfig(String merchantId, String module) =>
      '${merchantFeatureConfigs(merchantId)}/$module';
  static String merchantCustomers(String merchantId) =>
      '${merchant(merchantId)}/$customers';
  static String merchantFeedPosts(String merchantId) =>
      '${merchant(merchantId)}/$feedPosts';
  static String merchantFeedPost(String merchantId, String postId) =>
      '${merchantFeedPosts(merchantId)}/$postId';
  static String merchantStampCards(String merchantId) =>
      '${merchant(merchantId)}/$stampCards';
  static String merchantStampCard(String merchantId, String stampCardId) =>
      '${merchantStampCards(merchantId)}/$stampCardId';
  static String merchantPointsSystems(String merchantId) =>
      '${merchant(merchantId)}/$pointsSystems';
  static String merchantPointsSystem(String merchantId, String pointsSystemId) =>
      '${merchantPointsSystems(merchantId)}/$pointsSystemId';
  static String merchantPointsRewards(String merchantId) =>
      '${merchant(merchantId)}/$pointsRewards';
  static String merchantPointsReward(String merchantId, String rewardId) =>
      '${merchantPointsRewards(merchantId)}/$rewardId';
  static String merchantCoupons(String merchantId) =>
      '${merchant(merchantId)}/$coupons';
  static String merchantCoupon(String merchantId, String couponId) =>
      '${merchantCoupons(merchantId)}/$couponId';
  static String merchantCampaigns(String merchantId) =>
      '${merchant(merchantId)}/$campaigns';
  static String merchantCampaign(String merchantId, String campaignId) =>
      '${merchantCampaigns(merchantId)}/$campaignId';
  static String merchantOrders(String merchantId) =>
      '${merchant(merchantId)}/$orders';
  static String merchantOrder(String merchantId, String orderId) =>
      '${merchantOrders(merchantId)}/$orderId';
  static String merchantItemCategories(String merchantId) =>
      '${merchant(merchantId)}/$itemCategories';
  static String merchantItemCategory(String merchantId, String categoryId) =>
      '${merchantItemCategories(merchantId)}/$categoryId';
  static String merchantItems(String merchantId) =>
      '${merchant(merchantId)}/$items';
  static String merchantItem(String merchantId, String itemId) =>
      '${merchantItems(merchantId)}/$itemId';
  static String merchantItemTags(String merchantId) =>
      '${merchant(merchantId)}/$itemTags';
  static String merchantItemTag(String merchantId, String tagId) =>
      '${merchantItemTags(merchantId)}/$tagId';
  static String merchantTables(String merchantId) =>
      '${merchant(merchantId)}/$tables';
  static String merchantTable(String merchantId, String tableId) =>
      '${merchantTables(merchantId)}/$tableId';
  static String merchantTableAreas(String merchantId) =>
      '${merchant(merchantId)}/$tableAreas';
  static String merchantTableArea(String merchantId, String areaId) =>
      '${merchantTableAreas(merchantId)}/$areaId';
  static String merchantBillingWeeks(String merchantId) =>
      '${merchant(merchantId)}/$billingWeeks';
  static String merchantBillingWeek(String merchantId, String weekId) =>
      '${merchantBillingWeeks(merchantId)}/$weekId';
  static String merchantOpeningHours(String merchantId) =>
      '${merchant(merchantId)}/$openingHours';
  static String merchantAppointments(String merchantId) =>
      '${merchant(merchantId)}/$appointments';
  static String merchantShifts(String merchantId) =>
      '${merchant(merchantId)}/$shifts';

  // Display Studio
  static const displayStudio = 'displayStudio';
  static const displayStudioMain = 'main';
  static const displayLayouts = 'displayLayouts';
  static const displayDevices = 'displayDevices';
  static const displayRoutines = 'displayRoutines';
  static const displayLogs = 'displayLogs';

  static String merchantDisplayStudio(String merchantId) =>
      '${merchant(merchantId)}/$displayStudio';
  static String merchantDisplayStudioMain(String merchantId) =>
      '${merchantDisplayStudio(merchantId)}/$displayStudioMain';
  static String merchantDisplayLayouts(String merchantId) =>
      '${merchantDisplayStudioMain(merchantId)}/$displayLayouts';
  static String merchantDisplayLayout(String merchantId, String layoutId) =>
      '${merchantDisplayLayouts(merchantId)}/$layoutId';
  static String merchantDisplayDevices(String merchantId) =>
      '${merchantDisplayStudioMain(merchantId)}/$displayDevices';
  static String merchantDisplayDevice(String merchantId, String deviceId) =>
      '${merchantDisplayDevices(merchantId)}/$deviceId';
  static String merchantDisplayRoutines(String merchantId) =>
      '${merchantDisplayStudioMain(merchantId)}/$displayRoutines';
  static String merchantDisplayRoutine(String merchantId, String routineId) =>
      '${merchantDisplayRoutines(merchantId)}/$routineId';
  static String merchantDisplayLogs(String merchantId) =>
      '${merchantDisplayStudioMain(merchantId)}/$displayLogs';
  static String merchantDisplayLog(String merchantId, String logId) =>
      '${merchantDisplayLogs(merchantId)}/$logId';

  // Display Pairing Sessions (global root collection)
  static const displayPairingSessions = 'displayPairingSessions';
  static String displayPairingSession(String pairingId) =>
      '$displayPairingSessions/$pairingId';

  static String feedLikes(String postId) => '${feedPost(postId)}/$likes';
  static String feedLike(String postId, String uid) =>
      '${feedLikes(postId)}/$uid';
  static String feedReviews(String postId) => '${feedPost(postId)}/$reviews';
  static String feedReview(String postId, String reviewId) =>
      '${feedReviews(postId)}/$reviewId';
  static String feedViews(String postId) => '${feedPost(postId)}/$views';
  static String feedClicks(String postId) => '${feedPost(postId)}/$clicks';

  static String supportMessages(String ticketId) =>
      '${supportTicket(ticketId)}/$messages';
  static String supportMessage(String ticketId, String messageId) =>
      '${supportMessages(ticketId)}/$messageId';
}
