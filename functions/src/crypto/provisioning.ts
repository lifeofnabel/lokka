/**
 * Shared stick secret, derived from the single master key so the value is
 * computed identically wherever it is produced or checked (admin.ts). Never log.
 */
import { createHmac } from 'crypto';

/**
 * Inventory claim token = HMAC-SHA256(master, label | stickId)[:8].
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
