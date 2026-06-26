/**
 * Lokka Cloud Functions — Stempelkarten (stamp cards) security core.
 *
 * All stamp/redeem mutations are server-authored here (Admin SDK bypasses the
 * Firestore rules, which deny client writes to loyalty state). Two doors, one
 * backend: NFC tap (`redeemStampTap`) and merchant QR scan (`merchantStampCustomer`)
 * both resolve to the same `applyStamps` logic.
 *
 * Region: europe-west1 (matches the eur3 Firestore multi-region).
 * Secret:  STAMP_MASTER_KEY — 16-byte AES-128 master key as 32 hex chars.
 *          Set with: firebase functions:secrets:set STAMP_MASTER_KEY
 *
 * Rev: 2026-06-24a — force a fresh build of every function after granting the
 * build service account roles/cloudbuild.builds.builder (the first deploy's
 * build had failed, leaving non-serving revisions that the next deploy skipped).
 */
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { setGlobalOptions, logger } from 'firebase-functions/v2';
import { defineSecret } from 'firebase-functions/params';

import { verifySun } from './crypto/ntag424';
import { provSecret } from './crypto/provisioning';
import {
  newStickId,
  signStaticToken,
  parseStaticToken,
  verifyStaticToken,
} from './crypto/staticToken';
import {
  applyStamps,
  claimRewards,
  ensureStampCard,
  removeOneStamp,
  loadLiveCard,
  normaliseCard,
  effectiveTiers,
  maxStamps,
  assertWithinStore,
  assertWithinOpeningHours,
  MAX_BATCH,
} from './shared';

initializeApp();
setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });

const masterKeySecret = defineSecret('STAMP_MASTER_KEY');

function masterKey(): Buffer {
  const hex = masterKeySecret.value();
  if (!hex || hex.length !== 32) {
    throw new HttpsError('failed-precondition', 'stamp/master-key-missing');
  }
  return Buffer.from(hex, 'hex');
}

function requireAuth(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'stamp/login-required');
  return uid;
}

/// Wraps a callable handler so that (1) every uncaught error is LOGGED with full
/// detail (so `firebase functions:log` finally shows the real cause) and (2) the
/// real message is propagated to the client instead of an opaque "internal".
/// HttpsErrors (our intended, client-safe errors) pass through untouched.
function guard<T>(
  name: string,
  handler: (req: CallableRequest) => Promise<T>,
): (req: CallableRequest) => Promise<T> {
  return async (req: CallableRequest): Promise<T> => {
    try {
      return await handler(req);
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      const msg = e instanceof Error ? e.message : String(e);
      logger.error(`${name} crashed`, {
        message: msg,
        stack: e instanceof Error ? e.stack : undefined,
        uid: req.auth?.uid ?? null,
      });
      throw new HttpsError('internal', `stamp/server-error: ${msg.slice(0, 180)}`);
    }
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Door 1 — NFC tap (the physical stamp stick). The chip's SUN URL opens the web
//  app at /stamp; the app (with the logged-in customer) forwards the SUN params
//  here. CMAC + counter prove "real tag, fresh tap"; geofence is best-effort.
// ─────────────────────────────────────────────────────────────────────────────
export const redeemStampTap = onCall(
  { cors: true, secrets: [masterKeySecret] },
  async (req) => {
    const uid = requireAuth(req);
    const { picc, cmac, lat, lng } = req.data ?? {};
    if (typeof picc !== 'string' || typeof cmac !== 'string') {
      throw new HttpsError('invalid-argument', 'stamp/invalid-tag');
    }

    // 1. Verify the tag signature (CMAC) and recover UID + tap counter.
    let uidHex: string;
    let counter: number;
    try {
      const r = verifySun(masterKey(), { picc, cmac });
      uidHex = r.uid;
      counter = r.counter;
    } catch {
      throw new HttpsError('permission-denied', 'stamp/invalid-tag');
    }

    const db = getFirestore();
    const stickRef = db.doc(`sticks/${uidHex}`);

    // 2. Counter dedup + binding check (transaction → kills replay/copied URLs).
    const binding = await db.runTransaction(async (tx) => {
      const snap = await tx.get(stickRef);
      if (!snap.exists) throw new HttpsError('not-found', 'stamp/stick-unknown');
      const s = snap.data() ?? {};
      const merchantId = s.boundMerchantId as string | undefined;
      const cardId = s.boundCardId as string | undefined;
      if (!merchantId || !cardId) {
        throw new HttpsError('failed-precondition', 'stamp/stick-unbound');
      }
      const last = Number(s.counterLast) || 0;
      if (counter <= last) {
        throw new HttpsError('already-exists', 'stamp/replay');
      }
      tx.update(stickRef, {
        counterLast: counter,
        lastTapAt: FieldValue.serverTimestamp(),
      });
      return { merchantId, cardId };
    });

    // 3. Card must be live; geofence + opening-hours best-effort; then stamp.
    const card = await loadLiveCard(binding.merchantId, binding.cardId);
    await assertWithinStore(binding.merchantId, lat, lng);
    await assertWithinOpeningHours(binding.merchantId);
    const result = await applyStamps(uid, card, 1, 'nfc');
    return { ...result, merchantId: binding.merchantId, cardId: binding.cardId };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
//  Door 2 — Merchant scans the customer's wallet QR and adds stamps.
// ─────────────────────────────────────────────────────────────────────────────
export const merchantStampCustomer = onCall({ cors: true }, async (req) => {
  const merchantId = requireAuth(req);
  const { customerUid, cardId, delta } = req.data ?? {};
  if (typeof customerUid !== 'string' || typeof cardId !== 'string') {
    throw new HttpsError('invalid-argument', 'stamp/invalid-request');
  }
  if (customerUid === merchantId) {
    throw new HttpsError('failed-precondition', 'stamp/cannot-self-stamp');
  }
  const n = Math.max(1, Math.min(MAX_BATCH, Math.floor(Number(delta) || 1)));
  const card = await loadLiveCard(merchantId, cardId); // ownership = path scope
  await assertWithinOpeningHours(merchantId);
  const result = await applyStamps(customerUid, card, n, `merchant:${merchantId}`);
  return { ...result, cardId };
});

// ─────────────────────────────────────────────────────────────────────────────
//  Merchant marks an earned reward as used ("verbraucht").
// ─────────────────────────────────────────────────────────────────────────────
export const merchantRedeemReward = onCall({ cors: true }, async (req) => {
  const merchantId = requireAuth(req);
  const { customerUid, rewardId } = req.data ?? {};
  if (typeof customerUid !== 'string' || typeof rewardId !== 'string') {
    throw new HttpsError('invalid-argument', 'stamp/invalid-request');
  }
  const db = getFirestore();
  const ref = db.doc(`users/${customerUid}/earnedRewards/${rewardId}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'stamp/reward-not-found');
    const r = snap.data() ?? {};
    if (r.merchantId !== merchantId) {
      throw new HttpsError('permission-denied', 'stamp/not-your-reward');
    }
    if (r.status === 'redeemed') {
      throw new HttpsError('already-exists', 'stamp/already-redeemed');
    }
    tx.update(ref, {
      status: 'redeemed',
      redeemedAt: FieldValue.serverTimestamp(),
      redeemedBy: merchantId,
    });
  });
  return { ok: true };
});

// ─────────────────────────────────────────────────────────────────────────────
//  Customer converts a full card into earned reward(s).
// ─────────────────────────────────────────────────────────────────────────────
export const claimReward = onCall({ cors: true }, async (req) => {
  const uid = requireAuth(req);
  const { merchantId, cardId } = req.data ?? {};
  if (typeof merchantId !== 'string' || typeof cardId !== 'string') {
    throw new HttpsError('invalid-argument', 'stamp/invalid-request');
  }
  const db = getFirestore();
  const snap = await db.doc(`merchants/${merchantId}/stampCards/${cardId}`).get();
  if (!snap.exists) throw new HttpsError('not-found', 'stamp/card-not-found');
  const card = normaliseCard(cardId, merchantId, snap.data() ?? {});
  return claimRewards(uid, card);
});

// ─────────────────────────────────────────────────────────────────────────────
//  Customer adds one of a store's stamp cards to their own wallet at zero
//  progress ("Stempelkarte hinzufügen"). Idempotent — adding twice never resets.
// ─────────────────────────────────────────────────────────────────────────────
export const userAddStampCard = onCall({ cors: true }, async (req) => {
  const uid = requireAuth(req);
  const { merchantId, cardId } = req.data ?? {};
  if (typeof merchantId !== 'string' || typeof cardId !== 'string') {
    throw new HttpsError('invalid-argument', 'stamp/invalid-request');
  }
  const card = await loadLiveCard(merchantId, cardId); // must be a live card
  const result = await ensureStampCard(uid, card);
  return { ...result, cardId };
});

// ─────────────────────────────────────────────────────────────────────────────
//  Customer removes ONE of their own stamps (decrement, never below 0). Earned
//  rewards are never clawed back. Works on paused cards too (self-cleanup), so it
//  uses normaliseCard rather than loadLiveCard.
// ─────────────────────────────────────────────────────────────────────────────
export const userRemoveStamp = onCall({ cors: true }, async (req) => {
  const uid = requireAuth(req);
  const { merchantId, cardId } = req.data ?? {};
  if (typeof merchantId !== 'string' || typeof cardId !== 'string') {
    throw new HttpsError('invalid-argument', 'stamp/invalid-request');
  }
  const db = getFirestore();
  const snap = await db.doc(`merchants/${merchantId}/stampCards/${cardId}`).get();
  if (!snap.exists) throw new HttpsError('not-found', 'stamp/card-not-found');
  const card = normaliseCard(cardId, merchantId, snap.data() ?? {});
  const result = await removeOneStamp(uid, card);
  return { ...result, cardId };
});

// ─────────────────────────────────────────────────────────────────────────────
//  Stick setup — merchant scans the stick's printed QR ("lokka-stick:UID:TOKEN")
//  and binds it to one of their cards. provToken is derived from master+UID, so
//  only the holder of a genuine printed stick can register it; no pre-provision
//  Firestore write is required.
// ─────────────────────────────────────────────────────────────────────────────
export const setupStick = onCall({ cors: true, secrets: [masterKeySecret] }, async (req) => {
  const merchantId = requireAuth(req);
  const { tagUid, provToken, cardId } = req.data ?? {};
  if (
    typeof tagUid !== 'string' ||
    typeof provToken !== 'string' ||
    typeof cardId !== 'string'
  ) {
    throw new HttpsError('invalid-argument', 'stamp/invalid-request');
  }
  const uidHex = tagUid.toLowerCase().replace(/[^0-9a-f]/g, '');
  if (uidHex.length < 8) throw new HttpsError('invalid-argument', 'stamp/invalid-stick');

  // Authenticate the physical stick via the derived provisioning secret.
  if (provSecret(masterKey(), uidHex) !== provToken.toLowerCase()) {
    throw new HttpsError('permission-denied', 'stamp/invalid-stick');
  }

  // The card must belong to the caller and exist.
  const db = getFirestore();
  const cardRef = db.doc(`merchants/${merchantId}/stampCards/${cardId}`);
  const stickRef = db.doc(`sticks/${uidHex}`);

  await db.runTransaction(async (tx) => {
    const cardSnap = await tx.get(cardRef);
    if (!cardSnap.exists) throw new HttpsError('not-found', 'stamp/card-not-found');

    const stickSnap = await tx.get(stickRef);
    const existing = stickSnap.exists ? stickSnap.data() ?? {} : {};
    const owner = existing.boundMerchantId as string | undefined;
    if (owner && owner !== merchantId) {
      // Cross-merchant transfer is blocked (physical theft protection).
      throw new HttpsError('permission-denied', 'stamp/stick-owned-by-other');
    }

    // If this merchant had the stick on another card, detach that card's badge.
    const prevCardId = existing.boundCardId as string | undefined;
    if (prevCardId && prevCardId !== cardId) {
      tx.set(
        db.doc(`merchants/${merchantId}/stampCards/${prevCardId}`),
        { boundStickId: '', updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    }

    tx.set(
      stickRef,
      {
        tagUid: uidHex,
        type: 'ntag424',
        boundMerchantId: merchantId,
        boundCardId: cardId,
        counterLast: Number(existing.counterLast) || 0,
        verifiedAt: existing.verifiedAt ?? null,
        createdAt: existing.createdAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    // Mirror badge state onto the client-readable card. stickVerifiedAt resets on
    // every (re)bind so the "Stift verbunden ✓" badge only appears after a fresh
    // successful Test-Tap (verifyStickBinding).
    tx.set(
      cardRef,
      {
        boundStickId: uidHex,
        stickType: 'ntag424',
        stickVerifiedAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  return { ok: true, stickId: uidHex };
});

// ─────────────────────────────────────────────────────────────────────────────
//  Path A — create a static (browser-written) stick for a card. Returns a signed
//  token the merchant writes onto a blank NFC tag via Web NFC as
//  `https://<app>/s/<token>`. Reuses the card's existing static stick so running
//  setup twice yields the same token (no orphan sticks).
// ─────────────────────────────────────────────────────────────────────────────
export const createStaticStick = onCall(
  { cors: true, secrets: [masterKeySecret] },
  async (req) => {
    const merchantId = requireAuth(req);
    const { cardId } = req.data ?? {};
    if (typeof cardId !== 'string' || !cardId) {
      throw new HttpsError('invalid-argument', 'stamp/invalid-request');
    }
    const db = getFirestore();
    const master = masterKey();
    const cardRef = db.doc(`merchants/${merchantId}/stampCards/${cardId}`);

    const stickId = await db.runTransaction(async (tx) => {
      const cardSnap = await tx.get(cardRef);
      if (!cardSnap.exists) throw new HttpsError('not-found', 'stamp/card-not-found');
      const cardData = cardSnap.data() ?? {};

      let id = '';
      const prevId = String(cardData.boundStickId ?? '');
      if (prevId) {
        const prevSnap = await tx.get(db.doc(`sticks/${prevId}`));
        const prev = prevSnap.exists ? prevSnap.data() ?? {} : {};
        if (prev.type === 'static' && prev.boundMerchantId === merchantId) {
          id = prevId; // reuse → same token
        }
      }
      const reused = id !== '';
      if (!id) id = newStickId();

      tx.set(
        db.doc(`sticks/${id}`),
        {
          tagUid: id,
          type: 'static',
          boundMerchantId: merchantId,
          boundCardId: cardId,
          counterLast: null,
          verifiedAt: null,
          ...(reused ? {} : { createdAt: FieldValue.serverTimestamp() }),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.set(
        cardRef,
        {
          boundStickId: id,
          stickType: 'static',
          stickVerifiedAt: null, // flips only after a successful Test-Tap
          // Server-authored share link — stored on the (publicly readable) card
          // so the merchant can copy it instantly, no extra client write needed.
          staticToken: signStaticToken(master, id, merchantId, cardId),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return id;
    });

    return {
      stickId,
      token: signStaticToken(master, stickId, merchantId, cardId),
    };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
//  Path A tap — a customer opens https://<app>/s/<token>. Verify the HMAC, then
//  the same gate as the NTAG door: live card, optional geofence, silent cooldown
//  (the static path's main replay defence), +1 stamp. Login-bound.
// ─────────────────────────────────────────────────────────────────────────────
export const redeemStaticStamp = onCall(
  { cors: true, secrets: [masterKeySecret] },
  async (req) => {
    const uid = requireAuth(req);
    const { token, lat, lng } = req.data ?? {};
    if (typeof token !== 'string') {
      throw new HttpsError('invalid-argument', 'stamp/invalid-tag');
    }
    const parsed = parseStaticToken(token);
    if (!parsed) throw new HttpsError('permission-denied', 'stamp/invalid-tag');

    const db = getFirestore();
    const stickRef = db.doc(`sticks/${parsed.stickId}`);
    const snap = await stickRef.get();
    if (!snap.exists) throw new HttpsError('not-found', 'stamp/stick-unknown');
    const s = snap.data() ?? {};
    if (s.type !== 'static') {
      throw new HttpsError('permission-denied', 'stamp/invalid-tag');
    }
    const merchantId = String(s.boundMerchantId ?? '');
    const cardId = String(s.boundCardId ?? '');
    if (!merchantId || !cardId) {
      throw new HttpsError('failed-precondition', 'stamp/stick-unbound');
    }
    if (!verifyStaticToken(masterKey(), parsed.stickId, merchantId, cardId, parsed.sig)) {
      throw new HttpsError('permission-denied', 'stamp/invalid-tag');
    }

    const card = await loadLiveCard(merchantId, cardId);
    await assertWithinStore(merchantId, lat, lng);
    await assertWithinOpeningHours(merchantId);
    const result = await applyStamps(uid, card, 1, 'nfc-static');
    await stickRef.set({ lastTapAt: FieldValue.serverTimestamp() }, { merge: true });
    return { ...result, merchantId, cardId };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
//  Test-Tap — the merchant taps the just-written/bound stick. Resolve the token
//  (static) or SUN params (ntag424), confirm it points at THIS merchant's THIS
//  card, then mark it verified (badge flips to "Stift verbunden ✓").
// ─────────────────────────────────────────────────────────────────────────────
export const verifyStickBinding = onCall(
  { cors: true, secrets: [masterKeySecret] },
  async (req) => {
    const merchantId = requireAuth(req);
    const { cardId, token, picc, cmac, tagUid, provToken } = req.data ?? {};
    if (typeof cardId !== 'string' || !cardId) {
      throw new HttpsError('invalid-argument', 'stamp/invalid-request');
    }
    const db = getFirestore();
    const master = masterKey();

    let stickId = '';
    let type = '';
    if (typeof token === 'string' && token) {
      // Path A — static link token (read from the tag via Web NFC).
      const parsed = parseStaticToken(token);
      if (!parsed) throw new HttpsError('permission-denied', 'stamp/invalid-tag');
      if (!verifyStaticToken(master, parsed.stickId, merchantId, cardId, parsed.sig)) {
        throw new HttpsError('failed-precondition', 'stamp/wrong-card');
      }
      stickId = parsed.stickId;
      type = 'static';
    } else if (typeof picc === 'string' && typeof cmac === 'string') {
      // Path B — a live NTAG SUN tap (read from the tag via Web NFC).
      try {
        stickId = verifySun(master, { picc, cmac }).uid;
      } catch {
        throw new HttpsError('permission-denied', 'stamp/invalid-tag');
      }
      type = 'ntag424';
    } else if (typeof tagUid === 'string' && typeof provToken === 'string') {
      // Path B fallback — re-scan the stick's printed QR (no Web NFC, e.g.
      // iPhone/desktop). Proves the physical stick ↔ card binding via provToken.
      const uidHex = tagUid.toLowerCase().replace(/[^0-9a-f]/g, '');
      if (uidHex.length < 8 || provSecret(master, uidHex) !== provToken.toLowerCase()) {
        throw new HttpsError('permission-denied', 'stamp/invalid-stick');
      }
      stickId = uidHex;
      type = 'ntag424';
    } else {
      throw new HttpsError('invalid-argument', 'stamp/invalid-request');
    }

    const stickRef = db.doc(`sticks/${stickId}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(stickRef);
      if (!snap.exists) throw new HttpsError('not-found', 'stamp/stick-unknown');
      const s = snap.data() ?? {};
      if (s.boundMerchantId !== merchantId || s.boundCardId !== cardId) {
        // The stick resolves, but it is bound to a different card (or merchant).
        throw new HttpsError('failed-precondition', 'stamp/wrong-card');
      }
      tx.set(
        stickRef,
        {
          verifiedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.set(
        db.doc(`merchants/${merchantId}/stampCards/${cardId}`),
        {
          stickVerifiedAt: FieldValue.serverTimestamp(),
          stickType: type,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    return { ok: true, type, cardId };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
//  Merchant loads a scanned customer's cards, progress and earned rewards.
//  (Merchants cannot read users/* directly — this is the only window in.)
// ─────────────────────────────────────────────────────────────────────────────
export const merchantLoadCustomer = onCall(
    { cors: true },
    guard('merchantLoadCustomer', async (req) => {
  const merchantId = requireAuth(req);
  const { customerUid } = req.data ?? {};
  if (typeof customerUid !== 'string') {
    throw new HttpsError('invalid-argument', 'stamp/invalid-request');
  }
  const db = getFirestore();

  const [cardsSnap, progressSnap, rewardsSnap, walletSnap, custSnap] =
      await Promise.all([
    db.collection(`merchants/${merchantId}/stampCards`).limit(50).get(),
    db
      .collection(`users/${customerUid}/stampProgress`)
      .where('merchantId', '==', merchantId)
      .get(),
    // Single equality filter only (auto-indexed). Filtering by status as well
    // would need a composite index — we filter status in code below instead.
    db
      .collection(`users/${customerUid}/earnedRewards`)
      .where('merchantId', '==', merchantId)
      .get(),
    db.doc(`users/${customerUid}/walletCards/${merchantId}`).get(),
    db.doc(`merchants/${merchantId}/customers/${customerUid}`).get(),
  ]);

  const wallet = walletSnap.exists ? walletSnap.data() ?? {} : {};
  const cust = custSnap.exists ? custSnap.data() ?? {} : {};
  // Only the cards the customer actually ADDED to their wallet — not every card
  // the store offers.
  const addedIds = Array.isArray(wallet.addedStampCardIds)
    ? (wallet.addedStampCardIds as unknown[]).map((e) => String(e))
    : [];

  const cards = cardsSnap.docs
    .map((d) => normaliseCard(d.id, merchantId, d.data()))
    .filter((c) =>
      c.status === 'active' &&
      c.isActive &&
      !c.isArchived &&
      addedIds.includes(c.id))
    .map((c) => ({
      id: c.id,
      title: c.title,
      maxStamps: maxStamps(c),
      tiers: effectiveTiers(c),
    }));

  const progress = progressSnap.docs.map((d) => {
    const p = d.data();
    return {
      cardId: String(p.stampCardId ?? d.id),
      currentStamps: Number(p.currentStamps) || 0,
      stampsRequired: Number(p.stampsRequired) || 0,
      status: String(p.status ?? 'active'),
    };
  });

  const rewards = rewardsSnap.docs
    .filter((d) => String(d.data().status ?? '') === 'earned')
    .map((d) => {
      const r = d.data();
      return {
        id: d.id,
        cardId: String(r.cardId ?? ''),
        label: String(r.label ?? ''),
        type: String(r.type ?? 'custom'),
      };
    });

  const strList = (v: unknown): string[] =>
    Array.isArray(v) ? v.map((e) => String(e)).filter((e) => e.length > 0) : [];
  const interests = [
    ...strList(cust.interestOrigins),
    ...strList(cust.interestCategories),
  ].filter((v, i, a) => a.indexOf(v) === i);
  const fa = cust.followedAt as { toMillis?: () => number } | undefined;
  const followedAt = fa && typeof fa.toMillis === 'function' ? fa.toMillis() : null;

  return {
    customer: {
      name: String(cust.name ?? wallet.userName ?? wallet.merchantName ?? ''),
      walletCode: String(wallet.walletCode ?? cust.walletCode ?? ''),
      photoUrl: String(cust.profileImageUrl ?? ''),
      postalCode: String(cust.postalCode ?? ''),
      followedAt,
      interests,
    },
    cards,
    progress,
    rewards,
  };
}));

// ─────────────────────────────────────────────────────────────────────────────
//  Customer unfollows a merchant → ALL of their data for that store is wiped:
//  wallet card, stamp progress, points progress, earned rewards, and the
//  merchant-side follower record. Server-authored because loyalty docs are
//  client-write-denied. Re-following starts fresh (new wallet code). The UI
//  warns the user before calling this.
// ─────────────────────────────────────────────────────────────────────────────
export const userUnfollowMerchant = onCall({ cors: true }, async (req) => {
  const uid = requireAuth(req);
  const { merchantId } = req.data ?? {};
  if (typeof merchantId !== 'string' || !merchantId) {
    throw new HttpsError('invalid-argument', 'stamp/invalid-request');
  }
  const db = getFirestore();

  // Collect every doc that belongs to this user×merchant.
  const [stampProgress, pointsProgress, earnedRewards] = await Promise.all([
    db.collection(`users/${uid}/stampProgress`).where('merchantId', '==', merchantId).get(),
    db.collection(`users/${uid}/pointsProgress`).where('merchantId', '==', merchantId).get(),
    db.collection(`users/${uid}/earnedRewards`).where('merchantId', '==', merchantId).get(),
  ]);

  let deleted = 0;
  // Batch in chunks of 400 to stay under the 500-write limit even for heavy users.
  let batch = db.batch();
  let ops = 0;
  const flushIfNeeded = async () => {
    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  };
  const del = async (ref: FirebaseFirestore.DocumentReference) => {
    batch.delete(ref);
    ops++;
    deleted++;
    await flushIfNeeded();
  };

  await del(db.doc(`users/${uid}/walletCards/${merchantId}`));
  await del(db.doc(`merchants/${merchantId}/customers/${uid}`));
  for (const d of stampProgress.docs) await del(d.ref);
  for (const d of pointsProgress.docs) await del(d.ref);
  for (const d of earnedRewards.docs) await del(d.ref);
  if (ops > 0) await batch.commit();

  return { ok: true, deleted };
});

// ─────────────────────────────────────────────────────────────────────────────
//  Godmode — admin-only functions (Stift-Werkstatt + bootstrap). Defined in
//  admin.ts; re-exported here so the Functions deploy picks them up.
// ─────────────────────────────────────────────────────────────────────────────
export {
  bootstrapAdmin,
  adminMintStaticSticks,
  adminDeriveNtagStick,
  adminListSticks,
  claimStaticStick,
} from './admin';
