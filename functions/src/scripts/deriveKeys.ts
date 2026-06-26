/**
 * Offline key-derivation tool for provisioning physical stamp sticks.
 *
 * For a given chip UID it prints the three values you need:
 *   • SDMMetaRead key  (program into the chip — app-wide, same for all chips)
 *   • SDMFileRead key  (program into the chip — diversified per UID)
 *   • provToken        (encode into the printed QR: "lokka-stick:UID:provToken")
 *
 * Run locally (never on a server log!) with the master key in the environment:
 *
 *   STAMP_MASTER_KEY=<32 hex chars> npm run derive-keys -- <UID_HEX>
 *
 * The master key must match the STAMP_MASTER_KEY secret deployed to Functions.
 */
import { deriveMetaKey, deriveFileKey } from '../crypto/ntag424';
import { provSecret } from '../crypto/provisioning';

function main(): void {
  const hex = process.env.STAMP_MASTER_KEY;
  const uid = (process.argv[2] ?? '').toLowerCase().replace(/[^0-9a-f]/g, '');

  if (!hex || hex.length !== 32) {
    console.error('Set STAMP_MASTER_KEY to 32 hex chars (16-byte AES-128 key).');
    process.exit(1);
  }
  if (uid.length < 8) {
    console.error('Usage: STAMP_MASTER_KEY=... npm run derive-keys -- <UID_HEX>');
    process.exit(1);
  }

  const master = Buffer.from(hex, 'hex');
  const metaKey = deriveMetaKey(master).toString('hex');
  const fileKey = deriveFileKey(master, uid).toString('hex');
  const provToken = provSecret(master, uid);

  console.log(JSON.stringify(
    {
      uid,
      sdmMetaReadKey: metaKey,
      sdmFileReadKey: fileKey,
      provToken,
      qr: `lokka-stick:${uid}:${provToken}`,
    },
    null,
    2,
  ));
}

main();
