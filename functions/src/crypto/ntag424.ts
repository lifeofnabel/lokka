/**
 * NTAG 424 DNA — SUN / SDM verification (NXP AN12196) + per-tag key
 * diversification.
 *
 * The physical "stamp stick" carries a passive NTAG 424 DNA chip. On every tap
 * the chip emits a fresh URL of the shape:
 *
 *     https://<app>/stamp?picc=<32 hex>&cmac=<16 hex>
 *
 * where `picc` is the AES-CBC-encrypted PICCData (UID + monotonic read counter)
 * and `cmac` is the truncated SDM CMAC over the message. This module:
 *
 *   1. Derives the per-chip AES keys from a single master key (held in Secret
 *      Manager) so one leaked stick key never compromises the others.
 *   2. Decrypts PICCData → recovers the tag UID and read counter.
 *   3. Verifies the SDM CMAC → proves "real tag, this tap".
 *
 * The counter check (replay protection) lives in the caller, which compares the
 * recovered counter against the last stored value for that stick.
 *
 * ── Required chip SDM configuration (program with this exactly) ──────────────
 *   • SDMMetaRead  key (PICCData encryption) = deriveMetaKey(master)        (app-wide)
 *   • SDMFileRead  key (CMAC)                = deriveFileKey(master, uid)    (per chip)
 *   • Mirror: encrypted PICCData (UID + SDMReadCtr) ON, no plaintext file data
 *   • URL template: .../stamp?picc={PICCEncryptedData}&cmac={SDMMAC}
 *   Use `npm run derive-keys -- <UID_HEX>` to print both keys for programming.
 */
import { createDecipheriv } from 'crypto';
import { aesCmac } from './aesCmac';

export interface SunResult {
  uid: string; // hex, lower-case, no separators
  counter: number; // SDM read counter (monotonic per chip)
}

/** App-wide key that decrypts PICCData. Diversified from master, not per-tag. */
export function deriveMetaKey(master: Buffer): Buffer {
  return aesCmac(master, Buffer.from('LOKKA-SDM-META-v1'));
}

/**
 * Per-chip CMAC key, diversified from master + UID (AN10922-style: CMAC of a
 * fixed label || UID). A leak of one stick's file key cannot derive another's.
 */
export function deriveFileKey(master: Buffer, uidHex: string): Buffer {
  const uid = Buffer.from(uidHex, 'hex');
  return aesCmac(master, Buffer.concat([Buffer.from('LOKKA-SDM-FILE-v1'), uid]));
}

/**
 * Decrypt the 16-byte encrypted PICCData blob and extract UID + read counter.
 * AES-128-CBC, IV = 0 (per AN12196 SDM encrypted PICCData).
 */
function decryptPiccData(metaKey: Buffer, piccHex: string): SunResult {
  const enc = Buffer.from(piccHex, 'hex');
  if (enc.length !== 16) throw new Error('picc must be 16 bytes (32 hex chars)');

  const iv = Buffer.alloc(16, 0x00);
  const decipher = createDecipheriv('aes-128-cbc', metaKey, iv);
  decipher.setAutoPadding(false);
  const dec = Buffer.concat([decipher.update(enc), decipher.final()]);

  const tag = dec[0]; // PICCDataTag: b7 UID present, b6 ctr present, b0..3 UID len
  const uidLen = (tag & 0x0f) || 7;
  const uidPresent = (tag & 0x80) !== 0;
  const ctrPresent = (tag & 0x40) !== 0;
  if (!uidPresent) throw new Error('PICCData has no UID mirror');

  const uid = dec.subarray(1, 1 + uidLen);
  let counter = 0;
  if (ctrPresent) {
    const c = dec.subarray(1 + uidLen, 1 + uidLen + 3);
    counter = c[0] | (c[1] << 8) | (c[2] << 16); // SDMReadCtr is LSB-first
  }
  return { uid: uid.toString('hex').toLowerCase(), counter };
}

/**
 * Compute the expected truncated SDM CMAC for a given file key, UID and counter.
 * AN12196: session key = CMAC(Kfile, SV2); MAC = CMAC(sessionKey, macInput);
 * the URL value is the 8 odd-indexed bytes of that MAC.
 *
 * `macInput` is empty for the standard "encrypted PICCData, no plaintext file
 * data" template used here.
 */
function expectedCmac(
  fileKey: Buffer,
  uidHex: string,
  counter: number,
  macInput: Buffer,
): Buffer {
  const uid = Buffer.from(uidHex, 'hex');
  const ctr = Buffer.from([
    counter & 0xff,
    (counter >> 8) & 0xff,
    (counter >> 16) & 0xff,
  ]);
  const sv2 = Buffer.concat([
    Buffer.from([0x3c, 0xc3, 0x00, 0x01, 0x00, 0x80]),
    uid,
    ctr,
  ]);
  const sessionKey = aesCmac(fileKey, sv2);
  const full = aesCmac(sessionKey, macInput);

  const truncated = Buffer.alloc(8);
  for (let i = 0; i < 8; i++) truncated[i] = full[2 * i + 1]; // odd indices
  return truncated;
}

/** Constant-time comparison to avoid timing side-channels on the MAC. */
function timingSafeEqualHex(aHex: string, b: Buffer): boolean {
  let a: Buffer;
  try {
    a = Buffer.from(aHex, 'hex');
  } catch {
    return false;
  }
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export interface VerifyInput {
  picc: string; // encrypted PICCData hex (32 chars)
  cmac: string; // truncated SDM CMAC hex (16 chars)
  /** Optional plaintext mirrored data the CMAC covers (default: none). */
  macInputHex?: string;
}

/**
 * Verify a SUN URL end-to-end. Returns the UID + counter on success, or throws
 * with a stable, client-safe message on any failure. CMAC verification proves
 * authenticity; the caller still enforces the monotonic counter (anti-replay).
 */
export function verifySun(master: Buffer, input: VerifyInput): SunResult {
  const metaKey = deriveMetaKey(master);
  const { uid, counter } = decryptPiccData(metaKey, input.picc);

  const fileKey = deriveFileKey(master, uid);
  const macInput = input.macInputHex
    ? Buffer.from(input.macInputHex, 'hex')
    : Buffer.alloc(0);
  const expected = expectedCmac(fileKey, uid, counter, macInput);

  if (!timingSafeEqualHex(input.cmac, expected)) {
    throw new Error('cmac-mismatch');
  }
  return { uid, counter };
}
