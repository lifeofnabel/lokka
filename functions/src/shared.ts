/**
 * Shared server-side stamp logic: the single source of truth for mutating a
 * customer's stamp progress and earned rewards. Every door (NFC tap, merchant
 * QR scan, customer claim) funnels through these helpers so there is exactly
 * one code path — no drift between flows.
 */
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

export const COOLDOWN_SECONDS = 120; // anti-farming: 1 stamp / 2 min per user×card
export const MAX_BATCH = 10; // long-press "+N" upper bound
export const GEOFENCE_METERS = 300; // accept tap only if within ~this of store
export const HISTORY_CAP = 20; // keep the per-card history light

export interface RewardTier {
  atStamp: number;
  type: string; // item | custom | discount | free
  label: string;
  itemId?: string;
  itemName?: string;
}

export interface StampCard {
  id: string;
  merchantId: string;
  title: string;
  status: string;
  isActive: boolean;
  isArchived: boolean;
  requiredStamps: number;
  rewardTiers: RewardTier[];
  rewardType: string;
  rewardTitle: string;
  rewardItemId: string;
  rewardItemName: string;
  rewardDescription: string;
  claimLimits: Record<string, unknown>;
}

/** Read a live stamp card or throw a stable, client-safe error. */
export async function loadLiveCard(
  merchantId: string,
  cardId: string,
): Promise<StampCard> {
  const db = getFirestore();
  const snap = await db
    .doc(`merchants/${merchantId}/stampCards/${cardId}`)
    .get();
  if (!snap.exists) throw new HttpsError('not-found', 'stamp/card-not-found');
  const card = normaliseCard(cardId, merchantId, snap.data() ?? {});
  if (card.isArchived || card.status === 'archived') {
    throw new HttpsError('failed-precondition', 'stamp/card-archived');
  }
  if (card.status !== 'active' || !card.isActive) {
    throw new HttpsError('failed-precondition', 'stamp/card-inactive');
  }
  return card;
}

export function normaliseCard(
  id: string,
  merchantId: string,
  data: FirebaseFirestore.DocumentData,
): StampCard {
  const tiers: RewardTier[] = Array.isArray(data.rewardTiers)
    ? data.rewardTiers.map((t: Record<string, unknown>) => ({
        atStamp: Number(t.atStamp) || 1,
        type: String(t.type ?? 'custom'),
        label: String(t.label ?? ''),
        itemId: String(t.itemId ?? ''),
        itemName: String(t.itemName ?? ''),
      }))
    : [];
  return {
    id,
    merchantId,
    title: String(data.title ?? ''),
    status: String(data.status ?? 'draft'),
    isActive: data.isActive === true,
    isArchived: data.isArchived === true,
    requiredStamps: Number(data.requiredStamps) || 10,
    rewardTiers: tiers,
    rewardType: String(data.rewardType ?? 'custom'),
    rewardTitle: String(data.rewardTitle ?? ''),
    rewardItemId: String(data.rewardItemId ?? ''),
    rewardItemName: String(data.rewardItemName ?? ''),
    rewardDescription: String(data.rewardDescription ?? ''),
    claimLimits: (data.claimLimits as Record<string, unknown>) ?? {},
  };
}

/** Normalised, ascending reward milestones (single reward = one tier). */
export function effectiveTiers(card: StampCard): RewardTier[] {
  if (card.rewardTiers.length > 0) {
    return [...card.rewardTiers].sort((a, b) => a.atStamp - b.atStamp);
  }
  return [
    {
      atStamp: card.requiredStamps,
      type: card.rewardType,
      label:
        card.rewardTitle ||
        card.rewardItemName ||
        card.rewardDescription ||
        card.title,
      itemId: card.rewardItemId,
      itemName: card.rewardItemName,
    },
  ];
}

export function maxStamps(card: StampCard): number {
  const tiers = effectiveTiers(card);
  const tierMax = tiers.length ? tiers[tiers.length - 1].atStamp : 0;
  return Math.max(tierMax, card.requiredStamps);
}

function cooldownSecondsFor(card: StampCard): number {
  const raw = card.claimLimits?.cooldownSeconds;
  const n = typeof raw === 'number' ? raw : Number(raw);
  // 0 is a valid value → no dead time (shops handing out several stamps per
  // purchase). Only fall back to the default when unset/invalid.
  return Number.isFinite(n) && n >= 0 ? n : COOLDOWN_SECONDS;
}

export interface ApplyResult {
  currentStamps: number;
  maxStamps: number;
  completed: boolean;
  added: number;
}

/**
 * Apply `delta` stamps to (uid, card) inside a transaction. Enforces cooldown,
 * clamps at the card maximum (never overflows — edge case "card full"), appends
 * a capped history entry and flips status to `completed` at the top.
 *
 * Rewards are NOT created here — conversion to an earned reward is a separate,
 * customer-initiated step (`claimReward`) so a full card is converted on
 * purpose, matching the product's redeem asymmetry.
 */
export async function applyStamps(
  uid: string,
  card: StampCard,
  delta: number,
  source: string,
): Promise<ApplyResult> {
  const db = getFirestore();
  const ref = db.doc(`users/${uid}/stampProgress/${card.id}`);
  const max = maxStamps(card);
  const cooldown = cooldownSecondsFor(card);
  const safeDelta = Math.max(1, Math.min(MAX_BATCH, Math.floor(delta)));

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() ?? {} : {};
    const prev = Number(data.currentStamps) || 0;

    if (prev >= max) {
      // Full card: tapping must not overflow — prompt the customer to convert.
      throw new HttpsError('failed-precondition', 'stamp/card-full');
    }

    const lastAt = data.lastStampAt as Timestamp | undefined;
    if (lastAt) {
      const elapsed = (Date.now() - lastAt.toMillis()) / 1000;
      if (elapsed < cooldown) {
        throw new HttpsError('resource-exhausted', 'stamp/cooldown');
      }
    }

    const next = Math.min(max, prev + safeDelta);
    const completed = next >= max;
    const history = Array.isArray(data.history) ? data.history : [];
    history.push({ at: Timestamp.now(), by: source, delta: next - prev });
    while (history.length > HISTORY_CAP) history.shift();

    tx.set(
      ref,
      {
        stampCardId: card.id,
        merchantId: card.merchantId,
        currentStamps: next,
        stampsRequired: max,
        status: completed ? 'completed' : 'active',
        lastStampAt: FieldValue.serverTimestamp(),
        completedAt: completed ? FieldValue.serverTimestamp() : null,
        cycle: Number(data.cycle) || 0,
        awardedTiers: Array.isArray(data.awardedTiers) ? data.awardedTiers : [],
        history,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    // Surface the "reward ready" moment in-app the moment the card fills (the
    // client reads users/{uid}/notifications). True push needs FCM (see README).
    const wasComplete = prev >= max;
    if (completed && !wasComplete) {
      const notifRef = db.collection(`users/${uid}/notifications`).doc();
      tx.set(notifRef, {
        type: 'stampCardComplete',
        title: 'Karte voll! 🎉',
        body: `Deine Stempelkarte „${card.title}" ist voll – Belohnung wartet.`,
        merchantId: card.merchantId,
        cardId: card.id,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return { currentStamps: next, maxStamps: max, completed, added: next - prev };
  });
}

export interface ClaimResult {
  rewards: { id: string; label: string; type: string }[];
  reset: boolean;
}

/**
 * Convert a completed card into earned reward(s). Awards every reached, not-yet
 * awarded tier for the current cycle, then resets the card for the next cycle.
 * Deterministic reward ids make double-submits idempotent.
 */
export async function claimRewards(
  uid: string,
  card: StampCard,
): Promise<ClaimResult> {
  const db = getFirestore();
  const progressRef = db.doc(`users/${uid}/stampProgress/${card.id}`);
  const tiers = effectiveTiers(card);
  const max = maxStamps(card);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(progressRef);
    if (!snap.exists) {
      throw new HttpsError('failed-precondition', 'stamp/not-completed');
    }
    const data = snap.data() ?? {};
    const current = Number(data.currentStamps) || 0;
    if (current < max) {
      throw new HttpsError('failed-precondition', 'stamp/not-completed');
    }
    const cycle = Number(data.cycle) || 0;
    const awarded: number[] = Array.isArray(data.awardedTiers)
      ? data.awardedTiers
      : [];

    const created: { id: string; label: string; type: string }[] = [];
    for (const tier of tiers) {
      if (tier.atStamp <= current && !awarded.includes(tier.atStamp)) {
        const rewardId = `${card.id}_c${cycle}_t${tier.atStamp}`;
        const rewardRef = db.doc(`users/${uid}/earnedRewards/${rewardId}`);
        tx.set(rewardRef, {
          id: rewardId,
          userId: uid,
          merchantId: card.merchantId,
          cardId: card.id,
          cardTitle: card.title,
          atStamp: tier.atStamp,
          label: tier.label,
          type: tier.type,
          itemId: tier.itemId ?? '',
          itemName: tier.itemName ?? '',
          status: 'earned',
          earnedAt: FieldValue.serverTimestamp(),
          redeemedAt: null,
          redeemedBy: null,
        });
        created.push({ id: rewardId, label: tier.label, type: tier.type });
      }
    }

    // Reset the card for the next cycle.
    tx.set(
      progressRef,
      {
        currentStamps: 0,
        status: 'active',
        completedAt: null,
        cycle: cycle + 1,
        awardedTiers: [],
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { rewards: created, reset: true };
  });
}

/**
 * Idempotently put a store's stamp card into the customer's wallet at zero
 * progress. Used by the "Stempelkarte hinzufügen" buttons (wallet detail page
 * and merchant profile). If the card is already in the wallet it is a no-op and
 * the current state is returned — so tapping twice never resets a real card.
 */
export async function ensureStampCard(
  uid: string,
  card: StampCard,
): Promise<ApplyResult> {
  const db = getFirestore();
  const ref = db.doc(`users/${uid}/stampProgress/${card.id}`);
  const max = maxStamps(card);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      const d = snap.data() ?? {};
      const current = Number(d.currentStamps) || 0;
      return { currentStamps: current, maxStamps: max, completed: current >= max, added: 0 };
    }
    tx.set(ref, {
      stampCardId: card.id,
      merchantId: card.merchantId,
      currentStamps: 0,
      stampsRequired: max,
      status: 'active',
      lastStampAt: null,
      completedAt: null,
      cycle: 0,
      awardedTiers: [],
      history: [],
      addedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { currentStamps: 0, maxStamps: max, completed: false, added: 0 };
  });
}

/**
 * The customer removes ONE of their own stamps. Clamped at 0 (never negative)
 * and it never touches `earnedRewards` — already-earned/redeemed rewards live in
 * a separate collection and are not clawed back (edge case #5). A full card that
 * is decremented drops back to `active`.
 */
export async function removeOneStamp(
  uid: string,
  card: StampCard,
): Promise<ApplyResult> {
  const db = getFirestore();
  const ref = db.doc(`users/${uid}/stampProgress/${card.id}`);
  const max = maxStamps(card);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      return { currentStamps: 0, maxStamps: max, completed: false, added: 0 };
    }
    const data = snap.data() ?? {};
    const prev = Number(data.currentStamps) || 0;
    const next = Math.max(0, prev - 1);
    const history = Array.isArray(data.history) ? data.history : [];
    if (next !== prev) {
      history.push({ at: Timestamp.now(), by: 'user:remove', delta: -1 });
      while (history.length > HISTORY_CAP) history.shift();
    }
    const completed = next >= max;
    tx.set(
      ref,
      {
        stampCardId: card.id,
        merchantId: card.merchantId,
        currentStamps: next,
        stampsRequired: max,
        status: completed ? 'completed' : 'active',
        completedAt: completed ? data.completedAt ?? null : null,
        history,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { currentStamps: next, maxStamps: max, completed, added: next - prev };
  });
}

/** Haversine distance in metres between two lat/lng points. */
export function distanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/**
 * Optional geofence. Skipped entirely when the customer did not share location
 * or the merchant has no stored coordinates — never blocks in those cases.
 * Throws only when location IS available and the customer is clearly too far.
 */
export async function assertWithinStore(
  merchantId: string,
  lat: number | undefined,
  lng: number | undefined,
): Promise<void> {
  if (typeof lat !== 'number' || typeof lng !== 'number') return; // not shared
  const db = getFirestore();
  const snap = await db.doc(`merchants/${merchantId}`).get();
  const data = snap.data() ?? {};
  const mLat = typeof data.lat === 'number' ? data.lat : undefined;
  const mLng = typeof data.lng === 'number' ? data.lng : undefined;
  if (typeof mLat !== 'number' || typeof mLng !== 'number') return; // no store geo
  const dist = distanceMeters(lat, lng, mLat, mLng);
  if (dist > GEOFENCE_METERS) {
    throw new HttpsError('failed-precondition', 'stamp/too-far');
  }
}

/** Minutes of grace around the opening window so prep/clean-up time near
 *  open/close never wrongly blocks a stamp. */
export const OPENING_GRACE_MINUTES = 30;

/**
 * Extra anti-abuse layer: only allow a stamp while the store is (roughly) open.
 * FAIL-OPEN by design — if opening hours aren't configured, today has no entry,
 * or anything can't be parsed, it NEVER blocks (it sits on top of CMAC/counter/
 * cooldown/geofence). Uses Europe/Berlin local time (the app's market).
 *
 * `openingHours` shape (as written by the merchant tools):
 *   { monday: {open:"09:00", close:"18:00"} | {closed:true} | {slots:[{open,close}]}, … }
 */
export async function assertWithinOpeningHours(merchantId: string): Promise<void> {
  const db = getFirestore();
  let hours: Record<string, unknown> | undefined;
  try {
    const snap = await db.doc(`merchants/${merchantId}`).get();
    hours = (snap.data() ?? {}).openingHours as Record<string, unknown> | undefined;
  } catch {
    return; // can't read → don't block
  }
  if (!hours || typeof hours !== 'object') return; // not configured → don't block

  let weekday = '';
  let minutes = -1;
  try {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Europe/Berlin',
      weekday: 'long',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).formatToParts(new Date());
    const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '';
    weekday = get('weekday').toLowerCase();
    minutes = parseInt(get('hour'), 10) * 60 + parseInt(get('minute'), 10);
  } catch {
    return;
  }
  if (!weekday || !Number.isFinite(minutes) || minutes < 0) return;

  const day = hours[weekday];
  if (!day || typeof day !== 'object') return; // no entry today → don't block
  const d = day as Record<string, unknown>;
  if (d.closed === true) {
    throw new HttpsError('failed-precondition', 'stamp/closed');
  }

  const toMin = (v: unknown): number | null => {
    const m = /^(\d{1,2}):(\d{2})$/.exec(String(v ?? ''));
    return m ? parseInt(m[1], 10) * 60 + parseInt(m[2], 10) : null;
  };
  const windows: Array<[number, number]> = [];
  if (Array.isArray(d.slots)) {
    for (const s of d.slots) {
      if (s && typeof s === 'object') {
        const o = toMin((s as Record<string, unknown>).open);
        const c = toMin((s as Record<string, unknown>).close);
        if (o != null && c != null) windows.push([o, c]);
      }
    }
  } else {
    const o = toMin(d.open);
    const c = toMin(d.close);
    if (o != null && c != null) windows.push([o, c]);
  }
  if (windows.length === 0) return; // unparseable → fail open

  const g = OPENING_GRACE_MINUTES;
  const isOpen = windows.some(([o, c]) =>
    c < o
      ? minutes >= o - g || minutes <= c + g // overnight window (e.g. 18:00–02:00)
      : minutes >= o - g && minutes <= c + g,
  );
  if (!isOpen) throw new HttpsError('failed-precondition', 'stamp/closed');
}
