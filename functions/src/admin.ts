/**
 * Lokka Godmode — admin-only Cloud Functions (Sprint 1: Stift-Werkstatt).
 *
 * Gate: every admin function requires the caller's Firebase custom claim
 * `admin === true` (see requireAdmin). The claim is granted exactly once, by
 * `bootstrapAdmin`, to the hard-coded owner email — so the hidden admin surface
 * can never be reached by a normal user even if they discover the route.
 *
 * Stick-Werkstatt — the owner mass-produces link sticks centrally. Each mint
 * (adminMintStaticSticks) yields a permanent redeem token (the owner writes
 * `https://<app>/s/<token>` onto the blank tag ONCE) plus a bind-QR
 * `lokka-stick-a:<id>:<claim>`. A merchant scans that QR (claimStaticStick) to
 * bind the stick to one of their cards; the NFC link never changes, so
 * re-pointing to another card needs no rewrite.
 *
 * Region/secret are inherited from the global options + secret set in index.ts.
 */
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

import { claimToken } from './crypto/provisioning';
import { newStickId, signStickLink } from './crypto/staticToken';

const masterKeySecret = defineSecret('STAMP_MASTER_KEY');

/** The single email allowed to bootstrap itself into the admin role. */
const BOOTSTRAP_ADMIN_EMAIL = 'nabell.321@gmail.com';

function masterKey(): Buffer {
  const hex = masterKeySecret.value();
  if (!hex || hex.length !== 32) {
    throw new HttpsError('failed-precondition', 'stamp/master-key-missing');
  }
  return Buffer.from(hex, 'hex');
}

function requireAuth(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'admin/login-required');
  return uid;
}

/** Gate for every admin surface: the caller must carry the `admin` claim. */
function requireAdmin(req: CallableRequest): string {
  const uid = requireAuth(req);
  if (req.auth?.token?.admin !== true) {
    throw new HttpsError('permission-denied', 'admin/forbidden');
  }
  return uid;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bootstrap — one-time, idempotent. The owner (signed in as the verified
//  BOOTSTRAP_ADMIN_EMAIL) grants themselves the admin custom claim. No password
//  is stored: Firebase Auth already proved the identity. The client refreshes
//  its ID token afterwards so the new claim takes effect immediately.
// ─────────────────────────────────────────────────────────────────────────────
export const bootstrapAdmin = onCall({ cors: true }, async (req) => {
  const uid = requireAuth(req);
  const email = String(req.auth?.token?.email ?? '').toLowerCase();
  const verified = req.auth?.token?.email_verified === true;
  if (email !== BOOTSTRAP_ADMIN_EMAIL.toLowerCase() || !verified) {
    throw new HttpsError('permission-denied', 'admin/not-owner');
  }
  await getAuth().setCustomUserClaims(uid, { admin: true });
  await getFirestore().doc(`admins/${uid}`).set(
    { email, grantedAt: FieldValue.serverTimestamp(), grantedVia: 'bootstrap' },
    { merge: true },
  );
  return { ok: true };
});

// ─────────────────────────────────────────────────────────────────────────────
//  Stift-Werkstatt — Path A (link sticks). Mints `count` unbound static sticks
//  and returns each one's claim code. No redeem token yet — that needs a card
//  binding (claimStaticStick).
// ─────────────────────────────────────────────────────────────────────────────
export const adminMintStaticSticks = onCall(
  { cors: true, secrets: [masterKeySecret] },
  async (req) => {
    requireAdmin(req);
    const count = Math.max(1, Math.min(100, Math.floor(Number(req.data?.count) || 1)));
    const note = String(req.data?.note ?? '').slice(0, 80);
    const db = getFirestore();
    const master = masterKey();

    const batch = db.batch();
    const sticks: {
      stickId: string;
      claim: string;
      code: string;
      redeemToken: string;
    }[] = [];
    for (let i = 0; i < count; i++) {
      const id = newStickId();
      const claim = claimToken(master, id);
      batch.set(db.doc(`sticks/${id}`), {
        tagUid: id,
        type: 'static',
        inventory: true,
        bound: false,
        boundMerchantId: null,
        boundCardId: null,
        counterLast: null,
        verifiedAt: null,
        note,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      sticks.push({
        stickId: id,
        claim,
        // Binde-QR — ships with the stick; the merchant scans it onto a card.
        code: `lokka-stick-a:${id}:${claim}`,
        // Permanent NFC redeem token — the owner writes https://<app>/s/<token>
        // onto the tag ONCE. Stable across (re-)binding.
        redeemToken: signStickLink(master, id),
      });
    }
    await batch.commit();
    return { sticks };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
//  Delete a stick from the register. If it was bound to a card, the badge is
//  detached first so the merchant's card no longer shows a connected stick.
// ─────────────────────────────────────────────────────────────────────────────
export const adminDeleteStick = onCall({ cors: true }, async (req) => {
  requireAdmin(req);
  const stickId = String(req.data?.stickId ?? '')
    .toLowerCase()
    .replace(/[^0-9a-z]/g, '');
  if (!stickId) throw new HttpsError('invalid-argument', 'stamp/invalid-request');
  const db = getFirestore();
  const ref = db.doc(`sticks/${stickId}`);
  const snap = await ref.get();
  if (snap.exists) {
    const s = snap.data() ?? {};
    const mid = s.boundMerchantId ? String(s.boundMerchantId) : '';
    const cardId = s.boundCardId ? String(s.boundCardId) : '';
    if (mid && cardId) {
      await db.doc(`merchants/${mid}/stampCards/${cardId}`).set(
        {
          boundStickId: '',
          stickVerifiedAt: null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    await ref.delete();
  }
  return { ok: true, stickId };
});

// ─────────────────────────────────────────────────────────────────────────────
//  Merchant claims an admin-minted static stick and binds it to one of their
//  cards. NOT admin-gated — any merchant may claim an unbound inventory stick
//  they physically hold (proven by the claim token). Returns the real signed
//  `/s/<token>` redeem link to write onto the tag. Mirrors setupStick semantics.
// ─────────────────────────────────────────────────────────────────────────────
export const claimStaticStick = onCall(
  { cors: true, secrets: [masterKeySecret] },
  async (req) => {
    const merchantId = requireAuth(req);
    const stickId = String(req.data?.stickId ?? '')
      .toLowerCase()
      .replace(/[^0-9a-z]/g, '');
    const claim = String(req.data?.claimToken ?? '')
      .toLowerCase()
      .replace(/[^0-9a-f]/g, '');
    const cardId = String(req.data?.cardId ?? '');
    if (!stickId || !claim || !cardId) {
      throw new HttpsError('invalid-argument', 'stamp/invalid-request');
    }
    const master = masterKey();
    if (claimToken(master, stickId) !== claim) {
      throw new HttpsError('permission-denied', 'stamp/invalid-stick');
    }

    const db = getFirestore();
    const stickRef = db.doc(`sticks/${stickId}`);
    const cardRef = db.doc(`merchants/${merchantId}/stampCards/${cardId}`);

    await db.runTransaction(async (tx) => {
      const cardSnap = await tx.get(cardRef);
      if (!cardSnap.exists) throw new HttpsError('not-found', 'stamp/card-not-found');
      const stickSnap = await tx.get(stickRef);
      if (!stickSnap.exists) throw new HttpsError('not-found', 'stamp/stick-unknown');
      const s = stickSnap.data() ?? {};
      if (s.type !== 'static') {
        throw new HttpsError('failed-precondition', 'stamp/invalid-tag');
      }
      const owner = s.boundMerchantId as string | undefined;
      if (owner && owner !== merchantId) {
        throw new HttpsError('permission-denied', 'stamp/stick-owned-by-other');
      }
      // If this merchant is re-pointing the stick to another card, detach the old.
      const prevCardId = s.boundCardId as string | undefined;
      if (owner === merchantId && prevCardId && prevCardId !== cardId) {
        tx.set(
          db.doc(`merchants/${merchantId}/stampCards/${prevCardId}`),
          { boundStickId: '', updatedAt: FieldValue.serverTimestamp() },
          { merge: true },
        );
      }
      tx.set(
        stickRef,
        {
          boundMerchantId: merchantId,
          boundCardId: cardId,
          bound: true,
          claimedAt: s.claimedAt ?? FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      // Mirror onto the client-readable card. The owner already wrote the NFC
      // link in the workshop, so a successful bind means the stick is ready —
      // the "Stift verbunden ✓" badge flips immediately (no Test-Tap needed).
      tx.set(
        cardRef,
        {
          boundStickId: stickId,
          stickType: 'static',
          stickVerifiedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    // The token is identity-only (stable across binding) and is normally already
    // written on the tag by the owner. Returned for the legacy merchant flow that
    // can still (re-)write it if a merchant provisions their own blank tag.
    return { stickId, token: signStickLink(master, stickId) };
  },
);
