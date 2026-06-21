const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, '../serviceAccountKey.json');

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const auth = admin.auth();

const Timestamp = admin.firestore.Timestamp;

const demoMerchantId = 'demoMerchantLokka001';
const demoUserId = 'demoUserLokka001';

const now = new Date();
const todayKey = now.toISOString().slice(0, 10);
const threeMonthsLater = new Date(now);
threeMonthsLater.setMonth(threeMonthsLater.getMonth() + 3);

const weekStart = new Date(now);
weekStart.setDate(now.getDate() - now.getDay() + 1);
weekStart.setHours(0, 0, 0, 0);

const weekEnd = new Date(weekStart);
weekEnd.setDate(weekStart.getDate() + 7);

const weekId = `${weekStart.getFullYear()}-W${Math.ceil(
  ((weekStart - new Date(weekStart.getFullYear(), 0, 1)) / 86400000 +
    new Date(weekStart.getFullYear(), 0, 1).getDay() +
    1) /
    7,
)}`;

function ts(date = new Date()) {
  return Timestamp.fromDate(date);
}

function doc(pathValue) {
  return db.doc(pathValue);
}

async function upsertAuthUser({ uid, email, password, displayName }) {
  try {
    await auth.getUser(uid);
    await auth.updateUser(uid, {
      email,
      password,
      displayName,
      disabled: false,
    });
    console.log(`Auth user updated: ${email}`);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;

    await auth.createUser({
      uid,
      email,
      password,
      displayName,
      emailVerified: true,
      disabled: false,
    });

    console.log(`Auth user created: ${email}`);
  }
}

async function seed() {
  await upsertAuthUser({
    uid: demoUserId,
    email: 'user@lokka.demo',
    password: 'Demo123456!',
    displayName: 'Sam Mas',
  });

  await upsertAuthUser({
    uid: demoMerchantId,
    email: 'merchant@lokka.demo',
    password: 'Demo123456!',
    displayName: 'Babel Imbiss',
  });

  const batch = db.batch();

  const merchantPrefix = 'BA';
  const walletNumber = '48291';
  const walletCode = `${merchantPrefix}-${walletNumber}`;

  const stampCardId = 'stampCardDemo001';
  const pointsSystemId = 'pointsSystemDemo001';
  const pointsRewardId = 'pointsRewardDemo001';
  const couponId = 'couponDemo001';
  const campaignId = 'campaignDemo001';
  const feedPostId = 'feedPostDemo001';
  const orderId = 'orderDemo001';
  const tableId = 'tableDemo001';
  const claimId = 'stampClaimDemo001';
  const pointEventId = 'pointsEventDemo001';
  const couponClaimId = 'couponClaimDemo001';
  const campaignEntryId = 'campaignEntryDemo001';

  // SYSTEM
  batch.set(doc('system/config'), {
    appName: 'Lokka',
    environment: 'demo',
    isMaintenanceMode: false,
    defaultCity: 'Frankfurt',
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  batch.set(doc('system/creditRules'), {
    creditValueEuroMax: 1,
    feedPostOnce: 3,
    stampCardWeekly: 2,
    pointsSystemWeekly: 1,
    couponCodes: 0,
    campaigns: 0,
    menuCatalogWeekly: 3,
    orders: 0,
    appointments: null,
    shiftPlanner: null,
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  batch.set(doc('system/globalLimits'), {
    maxFeedPostsPerDay: 3,
    maxFeedPostsPerWeek: 14,
    maxStampCardsActivatedPerWeek: 4,
    maxActivePointsSystems: 1,
    auditLogRetentionMonths: 3,
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  batch.set(doc('system/postTypes'), {
    names: [
      'offer',
      'onePlusOneFree',
      'buyOneGetOneFree',
      'twoPlusOneFree',
      'buyTwoGetOneFree',
      'categoryDiscountPercent',
      'categoryDiscountFixed',
      'happyHour',
      'quickSell',
      'rescueMe',
      'news',
      'newProduct',
      'info',
      'communityEvent',
      'hiring',
      'sponsoredSpot',
    ],
    merchantVisibleNames: [
      'offer',
      'onePlusOneFree',
      'buyOneGetOneFree',
      'twoPlusOneFree',
      'buyTwoGetOneFree',
      'categoryDiscountPercent',
      'categoryDiscountFixed',
      'happyHour',
      'quickSell',
      'rescueMe',
      'news',
      'newProduct',
      'info',
      'communityEvent',
      'hiring',
    ],
    internalOnlyNames: ['sponsoredSpot'],
    createdAt: ts(now),
  });

  batch.set(doc('system/featureCatalog'), {
    features: {
      feed: { title: 'Feed Beiträge', creditCost: 3, billingType: 'once' },
      stamps: { title: 'Stempelkarten', creditCost: 2, billingType: 'weekly' },
      points: { title: 'Punkte-System', creditCost: 1, billingType: 'weekly' },
      coupons: { title: 'Gutscheine', creditCost: 0, billingType: 'free' },
      campaigns: { title: 'Gewinnspiele', creditCost: 0, billingType: 'free' },
      menu: { title: 'Speisekarte', creditCost: 3, billingType: 'weekly' },
      orders: { title: 'Bestellungen', creditCost: 0, billingType: 'free' },
      appointments: { title: 'Termine', status: 'comingSoon' },
      shiftPlanner: { title: 'Schichtplaner', status: 'comingSoon' },
    },
    createdAt: ts(now),
  });

  // CHOOSER
  batch.set(doc('chooser/shopTypes'), {
    name: ['Food', 'Kiosk', 'Cafe', 'Restaurant', 'Beauty', 'Barber', 'Fitness', 'Retail', 'Service'],
  });

  batch.set(doc('chooser/couponTypes'), {
    name: ['percent', 'fixedAmount'],
  });

  batch.set(doc('chooser/campaignTypes'), {
    name: ['giveaway', 'socialTask', 'visitReward', 'custom'],
  });

  batch.set(doc('chooser/rewardTypes'), {
    name: ['freeProduct', 'discount', 'gift', 'custom'],
  });

  // USERS
  batch.set(doc(`users/${demoUserId}`), {
    uid: demoUserId,
    role: 'user',
    firstName: 'Sam',
    lastName: 'Mas',
    email: 'user@lokka.demo',
    emailLowercase: 'user@lokka.demo',
    customerCode: 'LK-48291',
    isActive: true,
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  batch.set(doc(`users/${demoMerchantId}`), {
    uid: demoMerchantId,
    role: 'merchant',
    firstName: 'Demo',
    lastName: 'Merchant',
    email: 'merchant@lokka.demo',
    emailLowercase: 'merchant@lokka.demo',
    customerCode: null,
    isActive: true,
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  // MERCHANT
  const merchantBase = {
    merchantId: demoMerchantId,
    ownerUid: demoMerchantId,
    role: 'merchant',
    verificationStatus: 'approved',
    shopName: 'Babel Imbiss',
    businessName: 'Babel Imbiss Demo',
    description: 'Wraps, Bowls und lokale Angebote.',
    email: 'merchant@lokka.demo',
    phone: '+491771816751',
    address: 'Rüster Str. 2, 60325 Frankfurt',
    city: 'Frankfurt',
    country: 'Deutschland',
    shopType: 'Food',
    logoUrl: 'https://placehold.co/400x400?text=Babel',
    coverUrl: 'https://placehold.co/1200x700?text=Babel+Imbiss',
    isPublic: true,
    isActive: true,
    createdAt: ts(now),
    updatedAt: ts(now),
  };

  batch.set(doc(`merchants/${demoMerchantId}`), merchantBase);

  batch.set(doc(`publicMerchants/${demoMerchantId}`), {
    merchantId: demoMerchantId,
    shopName: merchantBase.shopName,
    description: merchantBase.description,
    shopType: merchantBase.shopType,
    address: merchantBase.address,
    phone: merchantBase.phone,
    logoUrl: merchantBase.logoUrl,
    coverUrl: merchantBase.coverUrl,
    featuresPublic: {
      feed: true,
      stamps: true,
      points: true,
      coupons: true,
      menu: true,
      campaigns: true,
      orders: true,
    },
    isPublic: true,
    isActive: true,
    updatedAt: ts(now),
  });

  batch.set(doc(`merchants/${demoMerchantId}/openingHours/config`), {
    monday: { open: '09:00', close: '22:00', closed: false },
    tuesday: { open: '09:00', close: '22:00', closed: false },
    wednesday: { open: '09:00', close: '22:00', closed: false },
    thursday: { open: '09:00', close: '22:00', closed: false },
    friday: { open: '09:00', close: '23:00', closed: false },
    saturday: { open: '10:00', close: '23:00', closed: false },
    sunday: { open: '12:00', close: '21:00', closed: false },
    allowClaimsOnlyDuringOpeningHours: true,
    updatedAt: ts(now),
  });

  // FEATURE CONFIGS
  const featureConfigs = {
    feed: { isEnabled: true, isActive: true, creditCost: 3, billingType: 'once' },
    stamps: { isEnabled: true, isActive: true, creditCost: 2, billingType: 'weekly' },
    points: { isEnabled: true, isActive: true, creditCost: 1, billingType: 'weekly' },
    coupons: { isEnabled: true, isActive: true, creditCost: 0, billingType: 'free' },
    menu: { isEnabled: true, isActive: true, creditCost: 3, billingType: 'weekly' },
    orders: { isEnabled: true, isActive: true, creditCost: 0, billingType: 'free' },
    campaigns: { isEnabled: true, isActive: true, creditCost: 0, billingType: 'free' },
  };

  for (const [key, value] of Object.entries(featureConfigs)) {
    batch.set(doc(`merchants/${demoMerchantId}/featureConfigs/${key}`), {
      ...value,
      activatedAt: ts(now),
      deactivatedAt: null,
      updatedAt: ts(now),
    });
  }

  // WALLET + MERCHANT CUSTOMER
  batch.set(doc(`users/${demoUserId}/walletCards/${demoMerchantId}`), {
    merchantId: demoMerchantId,
    merchantName: 'Babel Imbiss',
    merchantLogoUrl: merchantBase.logoUrl,
    merchantShopType: merchantBase.shopType,
    walletCode,
    walletNumber,
    prefix: merchantPrefix,
    joinedAt: ts(now),
    status: 'active',
    hasStampCards: true,
    hasPoints: true,
    hasCoupons: true,
    lastActivityAt: ts(now),
  });

  batch.set(doc(`merchants/${demoMerchantId}/customers/${demoUserId}`), {
    userId: demoUserId,
    firstName: 'Sam',
    lastName: 'Mas',
    customerCode: 'LK-48291',
    walletCode,
    status: 'active',
    joinedAt: ts(now),
    lastActivityAt: ts(now),
    stampCardsCount: 1,
    pointsTotal: 64,
    availableRewardsCount: 0,
    usedCouponsCount: 1,
  });

  // FEED
  const feedPost = {
    postId: feedPostId,
    merchantId: demoMerchantId,
    merchantName: 'Babel Imbiss',
    merchantLogoUrl: merchantBase.logoUrl,
    merchantShopType: merchantBase.shopType,
    type: 'offer',
    title: 'Shawarma Deal heute',
    subtitle: 'Nur heute im Laden',
    description: 'Hol dir einen frischen Shawarma Wrap zum Demo-Preis.',
    imageUrl: 'https://placehold.co/900x1200?text=Shawarma+Deal',
    oldPrice: 7.5,
    newPrice: 5.9,
    discountPercent: 21,
    categoryId: 'wraps',
    isActive: true,
    isArchived: false,
    isPrivate: false,
    likesCount: 1,
    viewsCount: 3,
    opensCount: 1,
    clicksCount: 1,
    createdAt: ts(now),
    updatedAt: ts(now),
    publishedAt: ts(now),
  };

  batch.set(doc(`merchants/${demoMerchantId}/feedPosts/${feedPostId}`), feedPost);
  batch.set(doc(`feed/${feedPostId}`), feedPost);

  batch.set(doc(`feed/${feedPostId}/likes/${demoUserId}`), {
    userId: demoUserId,
    merchantId: demoMerchantId,
    likedAt: ts(now),
  });

  batch.set(doc(`users/${demoUserId}/likedPosts/${feedPostId}`), {
    postId: feedPostId,
    merchantId: demoMerchantId,
    likedAt: ts(now),
  });

  batch.set(doc(`feed/${feedPostId}/views/viewDemo001`), {
    userId: demoUserId,
    merchantId: demoMerchantId,
    createdAt: ts(now),
  });

  batch.set(doc(`feed/${feedPostId}/clicks/clickDemo001`), {
    userId: demoUserId,
    merchantId: demoMerchantId,
    type: 'open',
    createdAt: ts(now),
  });

  batch.set(doc(`users/${demoUserId}/postInteractions/interactionDemo001`), {
    postId: feedPostId,
    merchantId: demoMerchantId,
    type: 'view',
    createdAt: ts(now),
  });

  // STAMPS
  batch.set(doc(`merchants/${demoMerchantId}/stampCards/${stampCardId}`), {
    stampCardId,
    merchantId: demoMerchantId,
    title: '10 Stempel = Gratis Wrap',
    description: 'Sammle Stempel und sichere dir eine Belohnung.',
    isActive: true,
    isArchived: false,
    creditCostPerWeek: 2,
    activatedAt: ts(now),
    billingStartsAt: ts(now),
    stampsRequired: 10,
    conditionType: 'amount',
    conditionText: 'Ab 8 € Einkauf',
    rewardTitle: 'Gratis Wrap',
    rewardDescription: 'Ein Wrap deiner Wahl.',
    rewardType: 'freeProduct',
    designConfig: {
      themeName: 'Mint Noir',
      lookMode: 'Premium',
      shape: 'circle',
      icon: 'star',
    },
    claimLimits: {
      maxPerUserPerDay: 1,
      maxPerUserPerHour: 1,
      maxPerCardPerDay: 60,
      maxPerXMinutes: 10,
      onlyDuringOpeningHours: true,
    },
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  batch.set(doc(`users/${demoUserId}/stampProgress/${stampCardId}`), {
    stampCardId,
    merchantId: demoMerchantId,
    currentStamps: 3,
    stampsRequired: 10,
    status: 'active',
    lastStampAt: ts(now),
    completedAt: null,
    claimedAt: null,
  });

  batch.set(
    doc(`merchants/${demoMerchantId}/customers/${demoUserId}/stampProgress/${stampCardId}`),
    {
      stampCardId,
      merchantId: demoMerchantId,
      currentStamps: 3,
      stampsRequired: 10,
      status: 'active',
      lastStampAt: ts(now),
      completedAt: null,
      claimedAt: null,
    },
  );

  batch.set(doc(`stampClaims/${claimId}`), {
    claimId,
    merchantId: demoMerchantId,
    userId: demoUserId,
    stampCardId,
    source: 'qrScan',
    status: 'approved',
    walletCode,
    createdAt: ts(now),
    createdBy: demoMerchantId,
    reason: 'Demo Stempel',
    deviceInfo: {
      platform: 'web',
      app: 'lokkaSeed',
    },
  });

  // POINTS
  batch.set(doc(`merchants/${demoMerchantId}/pointsSystems/${pointsSystemId}`), {
    systemId: pointsSystemId,
    merchantId: demoMerchantId,
    status: 'active',
    mode: 'spendBasedPoints',
    pointsPerEuro: 1,
    monthlyResetDay: 1,
    resetType: 'monthly',
    isArchived: false,
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  batch.set(doc(`merchants/${demoMerchantId}/pointsRewards/${pointsRewardId}`), {
    rewardId: pointsRewardId,
    pointsRequired: 100,
    title: 'Gratis Getränk',
    description: 'Ab 100 Punkten bekommst du ein Getränk gratis.',
    rewardType: 'freeProduct',
    imageUrl: 'https://placehold.co/600x600?text=Reward',
    isActive: true,
    sortOrder: 1,
    createdAt: ts(now),
  });

  batch.set(doc(`users/${demoUserId}/pointsProgress/${demoMerchantId}`), {
    merchantId: demoMerchantId,
    systemId: pointsSystemId,
    currentPoints: 64,
    lifetimePoints: 180,
    resetDay: 1,
    lastResetAt: null,
    status: 'active',
    updatedAt: ts(now),
  });

  batch.set(doc(`merchants/${demoMerchantId}/customers/${demoUserId}/pointsProgress/current`), {
    merchantId: demoMerchantId,
    systemId: pointsSystemId,
    currentPoints: 64,
    lifetimePoints: 180,
    resetDay: 1,
    lastResetAt: null,
    status: 'active',
    updatedAt: ts(now),
  });

  batch.set(doc(`pointsEvents/${pointEventId}`), {
    eventId: pointEventId,
    merchantId: demoMerchantId,
    userId: demoUserId,
    systemId: pointsSystemId,
    pointsDelta: 20,
    type: 'earn',
    reason: 'Demo Einkauf',
    createdAt: ts(now),
    createdBy: demoMerchantId,
  });

  // COUPONS
  batch.set(doc(`merchants/${demoMerchantId}/coupons/${couponId}`), {
    couponId,
    merchantId: demoMerchantId,
    type: 'percent',
    code: 'B7K-92P',
    preferredLetters: 'BA',
    value: 15,
    title: '15% Rabatt',
    description: '15% auf deinen nächsten Besuch.',
    isSingleUse: true,
    validFrom: ts(now),
    validUntil: ts(new Date(now.getTime() + 14 * 86400000)),
    isActive: true,
    isArchived: false,
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  batch.set(doc(`users/${demoUserId}/coupons/${couponId}`), {
    couponId,
    merchantId: demoMerchantId,
    code: 'B7K-92P',
    status: 'used',
    usedAt: ts(now),
    createdAt: ts(now),
  });

  batch.set(doc(`couponClaims/${couponClaimId}`), {
    claimId: couponClaimId,
    merchantId: demoMerchantId,
    userId: demoUserId,
    couponId,
    code: 'B7K-92P',
    status: 'used',
    usedAt: ts(now),
    confirmedByMerchantId: demoMerchantId,
    walletCode,
  });

  // CAMPAIGNS
  batch.set(doc(`merchants/${demoMerchantId}/campaigns/${campaignId}`), {
    campaignId,
    merchantId: demoMerchantId,
    type: 'giveaway',
    title: 'Instagram Gewinnspiel',
    description: 'Folge uns und nimm am Gewinnspiel teil.',
    taskText: 'Folge dem Shop auf Instagram und lade optional einen Screenshot hoch.',
    rewardType: 'custom',
    rewardTitle: 'Chance auf Gratis Menü',
    startsAt: ts(now),
    endsAt: ts(new Date(now.getTime() + 7 * 86400000)),
    isActive: true,
    isArchived: false,
    imageUrl: 'https://placehold.co/900x1200?text=Giveaway',
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  batch.set(doc(`campaignEntries/${campaignEntryId}`), {
    entryId: campaignEntryId,
    campaignId,
    merchantId: demoMerchantId,
    userId: demoUserId,
    status: 'pending',
    proofImageUrl: '',
    instagramName: '@demoUser',
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  // MENU
  batch.set(doc(`merchants/${demoMerchantId}/itemCategories/wraps`), {
    categoryId: 'wraps',
    title: 'Wraps',
    sortOrder: 1,
    isActive: true,
  });

  batch.set(doc(`merchants/${demoMerchantId}/menuItems/shawarmaWrap`), {
    itemId: 'shawarmaWrap',
    title: 'Shawarma Wrap',
    description: 'Hähnchen, Knoblauchcreme, Rotkohl und Tomate.',
    price: 7.5,
    imageUrl: 'https://placehold.co/800x800?text=Shawarma',
    categoryId: 'wraps',
    isAvailable: true,
    isActive: true,
    isArchived: false,
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  // ORDERS
  batch.set(doc(`merchants/${demoMerchantId}/orders/${orderId}`), {
    orderId,
    userId: demoUserId,
    items: [
      {
        itemId: 'shawarmaWrap',
        title: 'Shawarma Wrap',
        quantity: 1,
        price: 7.5,
      },
    ],
    totalPrice: 7.5,
    status: 'new',
    createdAt: ts(now),
    updatedAt: ts(now),
  });

  // TABLES
  batch.set(doc(`merchants/${demoMerchantId}/tables/${tableId}`), {
    tableId,
    label: 'Tisch 1',
    qrCode: `LOKKA-TABLE-${demoMerchantId}-1`,
    isActive: true,
    createdAt: ts(now),
  });

  // CLAIM LINKS
  batch.set(doc('claimLinks/demoStampLinkLevel1'), {
    linkId: 'demoStampLinkLevel1',
    merchantId: demoMerchantId,
    type: 'stamp',
    targetId: stampCardId,
    maskLevel: 1,
    nextLinkId: 'demoStampLinkLevel2',
    isActive: true,
    validFrom: ts(now),
    validUntil: null,
    dailyKey: null,
    createdAt: ts(now),
  });

  batch.set(doc('claimLinks/demoStampLinkLevel2'), {
    linkId: 'demoStampLinkLevel2',
    merchantId: demoMerchantId,
    type: 'stamp',
    targetId: stampCardId,
    maskLevel: 2,
    nextLinkId: 'demoStampLinkFinal',
    isActive: true,
    validFrom: ts(now),
    validUntil: ts(new Date(now.getTime() + 86400000)),
    dailyKey: `demoDailyKey-${todayKey}`,
    createdAt: ts(now),
  });

  batch.set(doc('claimLinks/demoStampLinkFinal'), {
    linkId: 'demoStampLinkFinal',
    merchantId: demoMerchantId,
    type: 'stamp',
    targetId: stampCardId,
    maskLevel: 3,
    nextLinkId: null,
    isActive: true,
    validFrom: ts(now),
    validUntil: ts(new Date(now.getTime() + 86400000)),
    dailyKey: `demoDailyKey-${todayKey}`,
    createdAt: ts(now),
  });

  batch.set(doc(`dailyClaimKeys/${demoMerchantId}_${todayKey}`), {
    merchantId: demoMerchantId,
    date: todayKey,
    dailyKey: `demoDailyKey-${todayKey}`,
    expiresAt: ts(new Date(now.getTime() + 86400000)),
    createdAt: ts(now),
  });

  // WALLET EVENTS
  batch.set(doc('walletEvents/walletEventDemo001'), {
    eventId: 'walletEventDemo001',
    merchantId: demoMerchantId,
    userId: demoUserId,
    type: 'walletAdded',
    createdAt: ts(now),
  });

  // BILLING
  batch.set(doc(`merchants/${demoMerchantId}/billingWeeks/${weekId}`), {
    merchantId: demoMerchantId,
    weekStart: ts(weekStart),
    weekEnd: ts(weekEnd),
    usedCredits: 9,
    committedCredits: 9,
    feedPostCredits: 3,
    stampCardCredits: 2,
    pointsCredits: 1,
    menuCredits: 3,
    status: 'open',
    updatedAt: ts(now),
  });

  const billingEvents = [
    ['billingFeedDemo001', 'feed', 'feedPostPublished', 3, 'once'],
    ['billingStampDemo001', 'stamps', 'stampCardActivated', 2, 'weekly'],
    ['billingPointsDemo001', 'points', 'pointsSystemActivated', 1, 'weekly'],
    ['billingMenuDemo001', 'menu', 'menuActivated', 3, 'weekly'],
  ];

  for (const [eventId, featureType, actionType, creditAmount, billingType] of billingEvents) {
    batch.set(doc(`billingEvents/${eventId}`), {
      eventId,
      merchantId: demoMerchantId,
      featureType,
      actionType,
      creditAmount,
      billingType,
      committedAt: ts(now),
      periodStart: ts(weekStart),
      periodEnd: ts(weekEnd),
      status: 'committed',
      description: `${actionType} demo billing event`,
      createdAt: ts(now),
    });
  }

  // AUDIT / RISK / SUPPORT
  batch.set(doc('auditLogs/auditDemo001'), {
    logId: 'auditDemo001',
    merchantId: demoMerchantId,
    userId: demoUserId,
    actorId: demoMerchantId,
    actorRole: 'merchant',
    action: 'seedDemoDataCreated',
    targetType: 'system',
    targetId: 'demoSeed',
    before: null,
    after: { status: 'created' },
    createdAt: ts(now),
    expiresAt: ts(threeMonthsLater),
  });

  batch.set(doc('riskEvents/riskDemo001'), {
    eventId: 'riskDemo001',
    merchantId: demoMerchantId,
    userId: demoUserId,
    type: 'tooManyClaims',
    severity: 'low',
    createdAt: ts(now),
    resolvedAt: null,
  });

  batch.set(doc('supportTickets/supportDemo001'), {
    ticketId: 'supportDemo001',
    merchantId: demoMerchantId,
    userId: null,
    type: 'setupQuestion',
    message: 'Demo Support Ticket für Merchant Setup.',
    status: 'open',
    createdAt: ts(now),
  });

  // FUTURE FEATURES
  batch.set(doc(`merchants/${demoMerchantId}/appointments/comingSoon`), {
    status: 'comingSoon',
    title: 'Termine Buchungssystem',
    createdAt: ts(now),
  });

  batch.set(doc(`merchants/${demoMerchantId}/shifts/comingSoon`), {
    status: 'comingSoon',
    title: 'Schichtplaner',
    createdAt: ts(now),
  });

  await batch.commit();

  console.log('----------------------------------');
  console.log('Lokka demo seed completed.');
  console.log('Demo User: user@lokka.demo / Demo123456!');
  console.log('Demo Merchant: merchant@lokka.demo / Demo123456!');
  console.log('Merchant ID:', demoMerchantId);
  console.log('User ID:', demoUserId);
  console.log('Wallet Code:', walletCode);
  console.log('----------------------------------');
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exit(1);
  });