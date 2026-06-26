/**
 * Lokka Godmode — admin-only Cloud Functions (Sprint 1: Stift-Werkstatt).
 *
 * Gate: every admin function requires the caller's Firebase custom claim
 * `admin === true` (see requireAdmin). The claim is granted exactly once, by
 * `bootstrapAdmin`, to the hard-coded owner email — so the hidden admin surface
 * can never be reached by a normal user even if they discover the route.
 *
 * Stick-Werkstatt — the owner mass-produces UNBOUND sticks centrally; merchants
 * bind them later themselves:
 *   • Path A (link sticks): adminMintStaticSticks → claim QR `lokka-stick-a:…`.
 *     The merchant scans it (claimStaticStick) to bind a card and receive the
 *     real signed `/s/<token>` redeem link to write onto the tag.
 *   • Path B (NTAG 424): adminDeriveNtagStick → chip keys + QR `lokka-stick:…`.
 *     The merchant binds via the existing setupStick flow.
 *
 * Region/secret are inherited from the global options + secret set in index.ts.
 */
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

import { deriveMetaKey, deriveFileKey } from './crypto/ntag424';
import { provSecret, claimToken } from './crypto/provisioning';
import { newStickId, signStaticToken } from './crypto/staticToken';

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

const toMillis = (v: unknown): number | null => {
  const t = v as { toMillis?: () => number } | undefined;
  return t && typeof t.toMillis === 'function' ? t.toMillis() : null;
};

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
    const sticks: { stickId: string; claim: string; code: string }[] = [];
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
      sticks.push({ stickId: id, claim, code: `lokka-stick-a:${id}:${claim}` });
    }
    await batch.commit();
    return { sticks };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
//  Stift-Werkstatt — Path B (NTAG 424 secure chips). For a given chip UID it
//  returns the two keys to program into the chip plus the printed-QR provToken.
//  Idempotent: re-running for the same UID just re-prints the keys and never
//  clobbers an existing merchant binding.
// ─────────────────────────────────────────────────────────────────────────────
export const adminDeriveNtagStick = onCall(
  { cors: true, secrets: [masterKeySecret] },
  async (req) => {
    requireAdmin(req);
    const uidHex = String(req.data?.tagUid ?? '')
      .toLowerCase()
      .replace(/[^0-9a-f]/g, '');
    if (uidHex.length < 8) {
      throw new HttpsError('invalid-argument', 'admin/invalid-uid');
    }
    const master = masterKey();
    const db = getFirestore();
    const stickRef = db.doc(`sticks/${uidHex}`);
    const snap = await stickRef.get();
    const existing = snap.exists ? snap.data() ?? {} : {};

    await stickRef.set(
      {
        tagUid: uidHex,
        type: 'ntag424',
        inventory: true,
        bound: existing.bound === true || (!!existing.boundMerchantId && !!existing.boundCardId),
        counterLast: Number(existing.counterLast) || 0,
        note: String(req.data?.note ?? existing.note ?? '').slice(0, 80),
        ...(snap.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const provToken = provSecret(master, uidHex);
    return {
      uid: uidHex,
      sdmMetaReadKey: deriveMetaKey(master).toString('hex'),
      sdmFileReadKey: deriveFileKey(master, uidHex).toString('hex'),
      provToken,
      qr: `lokka-stick:${uidHex}:${provToken}`,
    };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
//  Stick register — list the inventory (newest first) for the Godmode panel.
// ─────────────────────────────────────────────────────────────────────────────
export const adminListSticks = onCall({ cors: true }, async (req) => {
  requireAdmin(req);
  const limit = Math.max(1, Math.min(500, Math.floor(Number(req.data?.limit) || 200)));
  const db = getFirestore();
  const snap = await db
    .collection('sticks')
    .orderBy('updatedAt', 'desc')
    .limit(limit)
    .get();

  const sticks = snap.docs.map((d) => {
    const s = d.data();
    return {
      stickId: d.id,
      type: String(s.type ?? ''),
      bound: s.bound === true || (!!s.boundMerchantId && !!s.boundCardId),
      boundMerchantId: s.boundMerchantId ? String(s.boundMerchantId) : '',
      boundCardId: s.boundCardId ? String(s.boundCardId) : '',
      note: String(s.note ?? ''),
      verified: !!s.verifiedAt,
      createdAt: toMillis(s.createdAt),
      lastTapAt: toMillis(s.lastTapAt),
    };
  });
  return { sticks };
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
      // Mirror onto the client-readable card. stickVerifiedAt resets so the
      // "Stift verbunden ✓" badge only appears after a fresh Test-Tap.
      tx.set(
        cardRef,
        {
          boundStickId: stickId,
          stickType: 'static',
          stickVerifiedAt: null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    return { stickId, token: signStaticToken(master, stickId, merchantId, cardId) };
  },
);
