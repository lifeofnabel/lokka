/**
 * AES-CMAC (RFC 4493) over AES-128.
 *
 * Pure Node `crypto` implementation — no third-party dependency, so the stamp
 * security core has no supply-chain surface beyond firebase-admin/functions.
 * Used both for NTAG 424 DNA SUN/SDM verification (AN12196) and for our own
 * key diversification.
 */
import { createCipheriv } from 'crypto';

const BLOCK = 16;
const ZERO = Buffer.alloc(BLOCK, 0x00);
const RB = 0x87; // constant for the 128-bit block size (RFC 4493 §2.3)

/** Single-block AES-128 ECB encryption of exactly 16 bytes. */
function aesEcbBlock(key: Buffer, block: Buffer): Buffer {
  if (block.length !== BLOCK) throw new Error('aesEcbBlock: input must be 16 bytes');
  const cipher = createCipheriv('aes-128-ecb', key, null);
  cipher.setAutoPadding(false);
  // Copy into an alloc-backed buffer so the concrete element type stays uniform
  // across @types/node versions (newer typings make Buffer generic).
  const out = Buffer.alloc(BLOCK);
  Buffer.concat([cipher.update(block), cipher.final()]).copy(out);
  return out;
}

function xor(a: Buffer, b: Buffer): Buffer {
  const out = Buffer.alloc(a.length);
  for (let i = 0; i < a.length; i++) out[i] = a[i] ^ b[i];
  return out;
}

/** Left-shift a 16-byte buffer by one bit (big-endian). */
function shiftLeft(input: Buffer): Buffer {
  const out = Buffer.alloc(input.length);
  let overflow = 0;
  for (let i = input.length - 1; i >= 0; i--) {
    const v = (input[i] << 1) | overflow;
    out[i] = v & 0xff;
    overflow = (input[i] & 0x80) ? 1 : 0;
  }
  return out;
}

/** Derive the two CMAC subkeys K1, K2 from the AES key (RFC 4493 §2.3). */
function generateSubkeys(key: Buffer): { k1: Buffer; k2: Buffer } {
  const l = aesEcbBlock(key, ZERO);

  let k1 = shiftLeft(l);
  if (l[0] & 0x80) k1[k1.length - 1] ^= RB;

  let k2 = shiftLeft(k1);
  if (k1[0] & 0x80) k2[k2.length - 1] ^= RB;

  return { k1, k2 };
}

/**
 * Compute the full 16-byte AES-128-CMAC of `message` under `key`.
 */
export function aesCmac(key: Buffer, message: Buffer): Buffer {
  if (key.length !== 16) throw new Error('aesCmac: key must be 16 bytes (AES-128)');
  const { k1, k2 } = generateSubkeys(key);

  const n = Math.ceil(message.length / BLOCK);
  let lastComplete = false;
  let blocks = n;
  if (n === 0) {
    blocks = 1;
  } else {
    lastComplete = message.length % BLOCK === 0;
  }

  // Last block: either XOR with K1 (complete) or pad (10*) then XOR with K2.
  let lastBlock: Buffer;
  if (lastComplete) {
    lastBlock = xor(message.subarray((blocks - 1) * BLOCK, blocks * BLOCK), k1);
  } else {
    const rest = message.subarray((blocks - 1) * BLOCK);
    const padded = Buffer.alloc(BLOCK, 0x00);
    rest.copy(padded);
    padded[rest.length] = 0x80; // 10* padding
    lastBlock = xor(padded, k2);
  }

  let x = Buffer.from(ZERO);
  for (let i = 0; i < blocks - 1; i++) {
    const mi = message.subarray(i * BLOCK, (i + 1) * BLOCK);
    x = aesEcbBlock(key, xor(x, mi));
  }
  return aesEcbBlock(key, xor(x, lastBlock));
}
