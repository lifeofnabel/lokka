/**
 * migrateMerchantsToPublic.js
 *
 * Reads all active merchants from `merchants` and writes a clean,
 * normalised document into `publicMerchants/{merchantId}`.
 *
 * Usage:
 *   cd scripts
 *   npm install          (first time only — installs firebase-admin)
 *   node migrateMerchantsToPublic.js
 *
 * The script looks for a service-account key at:
 *   - $GOOGLE_APPLICATION_CREDENTIALS  (env var path)
 *   - ../serviceAccountKey.json        (repo root fallback)
 *
 * Safe to run multiple times — uses `set(..., {merge:true})` so only
 * changed fields are overwritten and sub-collections are untouched.
 */

'use strict';

const admin = require('firebase-admin');
const path = require('path');

// ── Initialise ────────────────────────────────────────────────────────────────

const keyPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, '../serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ── Field mapping helpers ─────────────────────────────────────────────────────

/**
 * Resolves shopName from various legacy field names.
 */
function resolveShopName(d) {
  return (
    d.shopName ||
    d.merchantName ||
    d.name ||
    d.businessName ||
    d.storeName ||
    ''
  ).trim();
}

/**
 * Resolves the shopTypes array and primary shopType string.
 * Legacy sources: shopTypes[], shopType, category, businessType.
 */
function resolveShopTypes(d) {
  let types = [];
  if (Array.isArray(d.shopTypes) && d.shopTypes.length) {
    types = d.shopTypes.filter(Boolean);
  } else if (typeof d.shopType === 'string' && d.shopType) {
    types = [d.shopType];
  } else if (typeof d.category === 'string' && d.category) {
    types = [d.category];
  } else if (typeof d.businessType === 'string' && d.businessType) {
    types = [d.businessType];
  }
  return types;
}

/**
 * Resolves address/location fields from flat and nested structures.
 * Legacy: address (string|object), location{}, fullAddress, city, postalCode.
 */
function resolveAddress(d) {
  const loc = (typeof d.location === 'object' && d.location) ? d.location : {};

  // fullAddress
  const fullAddress =
    d.fullAddress ||
    loc.fullAddress ||
    (typeof d.address === 'string' ? d.address : '') ||
    loc.street ||
    '';

  // short address (street + house number)
  const address =
    (typeof d.address === 'string' ? d.address : '') ||
    loc.address ||
    loc.street ||
    fullAddress;

  // city
  const city =
    d.city ||
    loc.city ||
    loc.locality ||
    '';

  // postalCode
  const postalCode =
    String(d.postalCode || loc.postalCode || loc.zip || '').trim();

  // area (neighbourhood / Stadtteil)
  const area =
    d.area ||
    loc.area ||
    loc.district ||
    city ||
    '';

  // coordinates
  let lat = null;
  let lng = null;

  const latSrc = d.lat ?? loc.lat ?? d.latitude ?? loc.latitude;
  const lngSrc = d.lng ?? loc.lng ?? d.longitude ?? loc.longitude;

  // Firestore GeoPoint support
  if (d.location && typeof d.location.toJSON === 'function') {
    const gp = d.location.toJSON();
    lat = gp.latitude ?? null;
    lng = gp.longitude ?? null;
  } else {
    if (latSrc != null) lat = Number(latSrc);
    if (lngSrc != null) lng = Number(lngSrc);
  }

  return { fullAddress, address, city, postalCode, area, lat, lng };
}

/**
 * Builds the featuresPublic string array from legacy boolean flags.
 * Maps: stampsEnabled→stampCards, pointsEnabled→points,
 *       dealsEnabled→deals, vouchersEnabled→coupons,
 *       catalogEnabled→catalog, ordersEnabled→orders,
 *       deliveryEnabled→delivery.
 */
function resolveFeaturesPublic(d) {
  const feats = [];
  const yes = (key) => d[key] === true;

  if (yes('stampsEnabled') || yes('hasStamps') || yes('stampCardsEnabled'))
    feats.push('stampCards');
  if (yes('pointsEnabled') || yes('hasPoints'))
    feats.push('points');
  if (yes('dealsEnabled') || yes('hasDeals'))
    feats.push('deals');
  if (yes('vouchersEnabled') || yes('hasCoupons') || yes('couponsEnabled'))
    feats.push('coupons');
  if (yes('catalogEnabled') || yes('hasCatalog') || yes('menuEnabled'))
    feats.push('catalog');
  if (yes('ordersEnabled') || yes('hasOrders'))
    feats.push('orders');
  if (yes('deliveryEnabled'))
    feats.push('delivery');

  // Also accept an existing featuresPublic array
  if (Array.isArray(d.featuresPublic)) {
    for (const f of d.featuresPublic) {
      if (!feats.includes(f)) feats.push(f);
    }
  }

  return feats;
}

/**
 * Resolves merchantId: prefer explicit field, fall back to doc.id.
 */
function resolveMerchantId(d, docId) {
  return (d.merchantId || d.uid || d.id || docId || '').trim() || docId;
}

/**
 * Maps a raw merchant document to the clean publicMerchants schema.
 */
function mapToPublic(data, docId) {
  const shopName = resolveShopName(data);
  const shopTypes = resolveShopTypes(data);
  const shopTypePrimary = shopTypes[0] || '';
  const shopType = shopTypePrimary; // backward-compat single field
  const addr = resolveAddress(data);
  const featuresPublic = resolveFeaturesPublic(data);
  const merchantId = resolveMerchantId(data, docId);

  return {
    // Identity
    merchantId,

    // Name & category
    shopName,
    shopTypes,
    shopTypePrimary,
    shopType, // kept for legacy client reads

    // Description & contact
    description: (data.description || data.about || '').trim(),
    phone: (data.phone || data.phoneNumber || '').trim(),
    email: (data.email || data.contactEmail || '').trim(),
    website: (data.website || data.websiteUrl || '').trim(),

    // Media
    logoUrl: (data.logoUrl || data.logo || '').trim(),
    coverUrl: (data.coverUrl || data.cover || data.bannerUrl || '').trim(),

    // Address
    address: addr.address,
    fullAddress: addr.fullAddress,
    city: addr.city,
    postalCode: addr.postalCode,
    area: addr.area,
    lat: addr.lat,
    lng: addr.lng,

    // Features
    featuresPublic,

    // Opening hours (pass through as-is)
    openingHours: data.openingHours || null,

    // Flags
    isActive: data.isActive === true,
    isPublic: data.isPublic !== false,     // default true
    isApproved: data.isApproved === true,

    // Timestamps
    createdAt: data.createdAt || FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    migratedAt: FieldValue.serverTimestamp(),
    migratedFrom: 'merchants',
  };
}

// ── Migration runner ──────────────────────────────────────────────────────────

async function migrate() {
  console.log('=== Lokka: merchants → publicMerchants migration ===\n');

  // 1. Read all active merchants
  console.log('Reading merchants where isActive == true …');
  const merchantsSnap = await db
    .collection('merchants')
    .where('isActive', '==', true)
    .get();

  if (merchantsSnap.empty) {
    console.log('No active merchants found. Exiting.');
    return;
  }

  console.log(`Found ${merchantsSnap.size} active merchant(s).\n`);

  // 2. Filter: exclude records where isPublic is explicitly false
  const docs = merchantsSnap.docs.filter(
    (d) => d.data().isPublic !== false,
  );
  console.log(`${docs.length} merchant(s) eligible for public listing.\n`);

  // 3. Process in batches (Firestore batch limit = 500 writes)
  const BATCH_SIZE = 400; // conservative
  let batchCount = 0;
  let totalWritten = 0;
  let currentBatch = db.batch();
  let opCount = 0;

  for (const doc of docs) {
    const raw = doc.data();
    const mapped = mapToPublic(raw, doc.id);

    // Write to publicMerchants/{docId}
    const ref = db.collection('publicMerchants').doc(doc.id);
    currentBatch.set(ref, mapped, { merge: true });
    opCount++;
    totalWritten++;

    console.log(
      `  [${totalWritten}/${docs.length}] ${mapped.shopName || doc.id}` +
      (mapped.area ? ` · ${mapped.area}` : '') +
      (mapped.shopType ? ` · ${mapped.shopType}` : '') +
      (mapped.featuresPublic.length ? ` [${mapped.featuresPublic.join(', ')}]` : ''),
    );

    if (opCount >= BATCH_SIZE) {
      await currentBatch.commit();
      batchCount++;
      console.log(`\n  ✓ Batch ${batchCount} committed (${opCount} writes)\n`);
      currentBatch = db.batch();
      opCount = 0;
    }
  }

  // Commit remaining
  if (opCount > 0) {
    await currentBatch.commit();
    batchCount++;
    console.log(`\n  ✓ Batch ${batchCount} committed (${opCount} writes)`);
  }

  console.log(`\n✅ Migration complete — ${totalWritten} document(s) written to publicMerchants.`);
  console.log('\nNext steps:');
  console.log('  1. Check the Firebase Console → Firestore → publicMerchants');
  console.log('  2. Verify shopName, shopType, area, and featuresPublic look correct');
  console.log('  3. Open the Lokka app and confirm the Partner page loads merchants');
}

migrate().catch((err) => {
  console.error('\n❌ Migration failed:', err.message || err);
  process.exit(1);
});
