/**
 * Static (browser-written) stick token.
 *
 * Web NFC (`NDEFReader.write`) can only write a STATIC NDEF record, so the chip
 * itself adds no rotation/counter. Security therefore lives entirely server-side:
 * the link carries an HMAC-SHA256 of `{stickId, merchantId, cardId}` under the
 * master key. The token is unguessable and tamper-proof (forging it needs the
 * secret); replay of a copied link is killed at the `/stamp` gate by the silent
 * server cooldown — plus login binding and the optional geofence.
 *
 * Token wire format:  `<stickId>.<sigHex>`   e.g.  s1a2b3….<32 hex>
 * The merchant writes  https://<app>/s/<token>  onto the tag.
 */
import { createHmac, timingSafeEqual, randomBytes } from 'crypto';

const SIG_BYTES = 16; // 128-bit truncated HMAC tag

/** Fresh random stick id. Prefixed 's' + 22 hex → never collides with the
 *  14-hex NTAG 424 UIDs used by the pre-provisioned (Path B) sticks. */
export function newStickId(): string {
  return 's' + randomBytes(11).toString('hex');
}

// Identity-only tag: binds ONLY to the stick id, never to a card. The link is
// written ONCE (by the owner, in the Godmode workshop) and stays valid forever;
// the card a stick stamps lives server-side in `sticks/<id>.boundCardId` and can
// be re-pointed by the merchant (re-scanning the bind-QR) WITHOUT rewriting the
// tag. `merchantId`/`cardId` are accepted for call-site compatibility but are
// intentionally NOT part of the signature anymore.
function tag(
  master: Buffer,
  stickId: string,
  _merchantId?: string,
  _cardId?: string,
): Buffer {
  return createHmac('sha256', master)
    .update(`LOKKA-STICK-ID-v1|${stickId}`)
    .digest()
    .subarray(0, SIG_BYTES);
}

/** Build the signed (identity-only) token for a stick. */
export function signStaticToken(
  master: Buffer,
  stickId: string,
  merchantId?: string,
  cardId?: string,
): string {
  return `${stickId}.${tag(master, stickId, merchantId, cardId).toString('hex')}`;
}

/** The stick's permanent redeem token — the value written onto the NFC tag as
 *  `https://<app>/s/<token>`. Stable across (re-)binding because it is
 *  identity-only. Produced at mint time in the workshop, before any card exists. */
export function signStickLink(master: Buffer, stickId: string): string {
  return signStaticToken(master, stickId);
}

/** Split a token into its stickId + signature, or null if malformed. */
export function parseStaticToken(
  token: string,
): { stickId: string; sig: string } | null {
  const t = (token || '').trim();
  const dot = t.indexOf('.');
  if (dot <= 0) return null;
  const stickId = t.substring(0, dot).toLowerCase().replace(/[^0-9a-z]/g, '');
  const sig = t
    .substring(dot + 1)
    .toLowerCase()
    .replace(/[^0-9a-f]/g, '');
  if (stickId.length < 4 || sig.length !== SIG_BYTES * 2) return null;
  return { stickId, sig };
}

/** Constant-time verify of a token's signature against {stickId,merchantId,cardId}. */
export function verifyStaticToken(
  master: Buffer,
  stickId: string,
  merchantId: string,
  cardId: string,
  sigHex: string,
): boolean {
  const expected = tag(master, stickId, merchantId, cardId);
  let provided: Buffer;
  try {
    provided = Buffer.from(sigHex, 'hex');
  } catch {
    return false;
  }
  if (provided.length !== expected.length) return false;
  return timingSafeEqual(provided, expected);
}
