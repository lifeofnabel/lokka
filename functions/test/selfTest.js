/**
 * Self-test for the stamp crypto core (link-stick model). Proves the
 * identity-only static redeem token and the inventory claim token behave
 * correctly. Run after `npm run build`:  node test/selfTest.js
 */
const assert = require('assert');
const crypto = require('crypto');
const {
  newStickId,
  signStaticToken,
  signStickLink,
  parseStaticToken,
  verifyStaticToken,
} = require('../lib/crypto/staticToken');
const { claimToken } = require('../lib/crypto/provisioning');

let pass = 0;
function check(name, cond) {
  assert.ok(cond, 'FAILED: ' + name);
  pass++;
  console.log('  ok -', name);
}

const master = crypto.randomBytes(16);

// ── Static redeem token (identity-only) round-trip ──────────────────────────
const sid = newStickId();
check('stickId is fresh + prefixed', sid.startsWith('s') && sid.length > 10);

const tok = signStaticToken(master, sid, 'merchantA', 'card1');
const parsedTok = parseStaticToken(tok);
check('static token parses', parsedTok && parsedTok.stickId === sid);
check('static token verifies',
  verifyStaticToken(master, sid, 'merchantA', 'card1', parsedTok.sig));

// Identity model: the token binds ONLY to the stick id, NOT to a card — it must
// verify for the SAME stick regardless of merchant/card. The card binding lives
// server-side in sticks/<id> and can change WITHOUT rewriting the tag.
check('static token is card-agnostic',
  verifyStaticToken(master, sid, 'merchantB', 'card2', parsedTok.sig));

// signStickLink is exactly the identity token the owner writes onto the tag.
check('signStickLink == identity token', signStickLink(master, sid) === tok);

// A token for a DIFFERENT stick must NOT verify (stick identity is enforced).
const otherSid = newStickId();
check('static token rejects wrong stick',
  !verifyStaticToken(master, otherSid, 'merchantA', 'card1', parsedTok.sig));

// Tampered signature must NOT verify. Malformed token → null.
check('static token rejects tampered sig',
  !verifyStaticToken(master, sid, 'merchantA', 'card1', '00'.repeat(16)));
check('static token rejects malformed', parseStaticToken('not-a-token') === null);

// ── Inventory claim token (the bind-QR the merchant scans) ──────────────────
const claim = claimToken(master, sid);
check('claim token is 16 hex', /^[0-9a-f]{16}$/.test(claim));
check('claim token is deterministic', claimToken(master, sid) === claim);
check('claim token is stick-specific', claimToken(master, otherSid) !== claim);

console.log('\nAll ' + pass + ' checks passed.');
