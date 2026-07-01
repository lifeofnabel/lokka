/**
 * Self-test for the stamp crypto core. Runs:
 *   1. RFC 4493 AES-CMAC test vectors (proves the CMAC implementation).
 *   2. A full NTAG 424 DNA SUN round-trip: encrypt PICCData + compute the SDM
 *      CMAC exactly as a real chip would, then verifySun() must recover the
 *      UID + counter. Proves decrypt + diversification + CMAC verify agree.
 *
 * Run after `npm run build`:  node test/selfTest.js
 */
const assert = require('assert');
const crypto = require('crypto');
const { aesCmac } = require('../lib/crypto/aesCmac');
const {
  verifySun,
  deriveMetaKey,
  deriveFileKey,
} = require('../lib/crypto/ntag424');
const {
  newStickId,
  signStaticToken,
  signStickLink,
  parseStaticToken,
  verifyStaticToken,
} = require('../lib/crypto/staticToken');

let pass = 0;
function check(name, cond) {
  assert.ok(cond, 'FAILED: ' + name);
  pass++;
  console.log('  ok -', name);
}

// ── 1. RFC 4493 vectors ─────────────────────────────────────────────────────
const K = Buffer.from('2b7e151628aed2a6abf7158809cf4f3c', 'hex');
const M = Buffer.from(
  '6bc1bee22e409f96e93d7e117393172a' +
    'ae2d8a571e03ac9c9eb76fac45af8e51' +
    '30c81c46a35ce411e5fbc1191a0a52ef' +
    'f69f2445df4f9b17ad2b417be66c3710',
  'hex',
);
check('CMAC empty', aesCmac(K, Buffer.alloc(0)).toString('hex') === 'bb1d6929e95937287fa37d129b756746');
check('CMAC 16',   aesCmac(K, M.subarray(0, 16)).toString('hex') === '070a16b46b4d4144f79bdd9dd04a287c');
check('CMAC 40',   aesCmac(K, M.subarray(0, 40)).toString('hex') === 'dfa66747de9ae63030ca32611497c827');
check('CMAC 64',   aesCmac(K, M).toString('hex') === '51f0bebf7e3b9d92fc49741779363cfe');

// ── 2. SUN round-trip ───────────────────────────────────────────────────────
const master = crypto.randomBytes(16);
const uid = '04a1b2c3d4e580'; // 7-byte UID hex
const counter = 42;

// Build decrypted PICCData: tag 0xC7 (UID+ctr present, len 7) + UID + ctr(LE) + pad
const piccPlain = Buffer.alloc(16, 0);
piccPlain[0] = 0xc7;
Buffer.from(uid, 'hex').copy(piccPlain, 1);
piccPlain[8] = counter & 0xff;
piccPlain[9] = (counter >> 8) & 0xff;
piccPlain[10] = (counter >> 16) & 0xff;

const metaKey = deriveMetaKey(master);
const iv = Buffer.alloc(16, 0);
const cipher = crypto.createCipheriv('aes-128-cbc', metaKey, iv);
cipher.setAutoPadding(false);
const piccEnc = Buffer.concat([cipher.update(piccPlain), cipher.final()]);

// Compute the SDM CMAC the chip would emit (SV2 + session key + truncation).
const fileKey = deriveFileKey(master, uid);
const ctr3 = Buffer.from([counter & 0xff, (counter >> 8) & 0xff, (counter >> 16) & 0xff]);
const sv2 = Buffer.concat([
  Buffer.from([0x3c, 0xc3, 0x00, 0x01, 0x00, 0x80]),
  Buffer.from(uid, 'hex'),
  ctr3,
]);
const sessionKey = aesCmac(fileKey, sv2);
const macFull = aesCmac(sessionKey, Buffer.alloc(0));
const macTrunc = Buffer.alloc(8);
for (let i = 0; i < 8; i++) macTrunc[i] = macFull[2 * i + 1];

const res = verifySun(master, {
  picc: piccEnc.toString('hex'),
  cmac: macTrunc.toString('hex'),
});
check('SUN recovers UID', res.uid === uid);
check('SUN recovers counter', res.counter === counter);

// Tamper → must reject.
let rejected = false;
try {
  verifySun(master, { picc: piccEnc.toString('hex'), cmac: '00'.repeat(8) });
} catch (_) {
  rejected = true;
}
check('SUN rejects bad CMAC', rejected);

// Different UID → different file key (diversification).
check('key diversification', deriveFileKey(master, uid).toString('hex') !==
  deriveFileKey(master, '04ffffffffffff').toString('hex'));

// ── 3. Static token (Path A) round-trip ─────────────────────────────────────
const sid = newStickId();
check('stickId is fresh + prefixed', sid.startsWith('s') && sid.length > 10);
const tok = signStaticToken(master, sid, 'merchantA', 'card1');
const parsedTok = parseStaticToken(tok);
check('static token parses', parsedTok && parsedTok.stickId === sid);
check('static token verifies', verifyStaticToken(master, sid, 'merchantA', 'card1', parsedTok.sig));
// Identity model: the token binds ONLY to the stick id, NOT to a card — it must
// verify for the SAME stick regardless of merchant/card (the card binding lives
// server-side in sticks/<id> and can change without rewriting the tag).
check('static token is card-agnostic',
  verifyStaticToken(master, sid, 'merchantB', 'card2', parsedTok.sig));
// signStickLink is exactly the identity token (what the owner writes on the tag).
check('signStickLink == identity token', signStickLink(master, sid) === tok);
// A token for a DIFFERENT stick must NOT verify (stick identity is enforced).
const otherSid = newStickId();
check('static token rejects wrong stick',
  !verifyStaticToken(master, otherSid, 'merchantA', 'card1', parsedTok.sig));
// Tampered signature must NOT verify.
check('static token rejects tampered sig', !verifyStaticToken(master, sid, 'merchantA', 'card1', '00'.repeat(16)));
// Malformed token → null.
check('static token rejects malformed', parseStaticToken('not-a-token') === null);

console.log('\nAll ' + pass + ' checks passed.');
