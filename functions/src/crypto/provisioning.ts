/**
 * Shared stick-provisioning secrets, all derived from the single master key so
 * the values are computed identically everywhere they are produced or checked
 * (index.ts, admin.ts, scripts/deriveKeys.ts). Never log these.
 */
import { createHmac } from 'crypto';
import { aesCmac } from './aesCmac';

/**
 * Path B (NTAG 424): provisioning secret = AES-CMAC(master, label || uid)[:8].
 * Encoded into the printed QR `lokka-stick:UID:provToken`; proves possession of
 * a genuine printed stick at setup time (setupStick / verifyStickBinding).
 */
export function provSecret(master: Buffer, uidHex: string): string {
  return aesCmac(
    master,
    Buffer.concat([Buffer.from('LOKKA-STICK-PROV-v1'), Buffer.from(uidHex, 'hex')]),
  )
    .subarray(0, 8)
    .toString('hex');
}

/**
 * Path A inventory: claim token = HMAC-SHA256(master, label | stickId)[:8].
 * Encoded into `lokka-stick-a:STICKID:CLAIM`. A merchant who physically holds a
 * (still unbound, admin-minted) static stick scans this to bind it to one of
 * their cards (claimStaticStick) and receive the real signed redeem link.
 */
export function claimToken(master: Buffer, stickId: string): string {
  return createHmac('sha256', master)
    .update(`LOKKA-STICK-CLAIM-v1|${stickId}`)
    .digest()
    .subarray(0, 8)
    .toString('hex');
}
