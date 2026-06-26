# Lokka Cloud Functions — Stempelkarten (stamp cards)

Server-authored security core for digital stamp cards. The Firestore rules deny
all client writes to loyalty state; every stamp/redeem mutation goes through a
callable here (Admin SDK), so the client is never trusted for stamp validity.

## Callables (region `europe-west1`)

| Function | Caller | Purpose |
|---|---|---|
| `redeemStampTap` | customer | NFC tap door. Verifies NTAG 424 DNA SUN (CMAC + counter), optional geofence, +1 stamp. |
| `merchantStampCustomer` | merchant | QR-scan door. Adds +N stamps to a scanned customer's card. |
| `merchantRedeemReward` | merchant | Marks an earned reward as used. |
| `claimReward` | customer | Converts a full card into earned reward(s) + resets the cycle. |
| `setupStick` | merchant | Binds a physical stick (via printed QR) to one card. |
| `merchantLoadCustomer` | merchant | Reads a scanned customer's cards/progress/rewards (merchants can't read `users/*`). |

## One-time setup (requires the Blaze plan)

```bash
cd functions
npm install
# 16-byte AES-128 master key as 32 hex chars (generate with: openssl rand -hex 16)
firebase functions:secrets:set STAMP_MASTER_KEY
firebase deploy --only functions
firebase deploy --only firestore:rules   # deploy the hardened rules too
```

## Provisioning a physical stick (NTAG 424 DNA)

1. Read the chip UID (7 bytes).
2. Compute its keys + QR token **locally** (never log the master key on a server):

   ```bash
   STAMP_MASTER_KEY=<same 32 hex> npm run derive-keys -- <UID_HEX>
   ```

3. Program the chip (e.g. NXP TagWriter / TagXplorer) with:
   - **SDMMetaRead key** = `sdmMetaReadKey` (same for all chips)
   - **SDMFileRead key** = `sdmFileReadKey` (per-UID)
   - SDM mirror: **encrypted PICCData (UID + SDMReadCtr) ON**, no plaintext file data
   - URL template: `https://<your-app>/stamp?picc={PICCEncryptedData}&cmac={SDMMAC}`
4. Print a QR encoding `qr` (`lokka-stick:<uid>:<provToken>`) on top of the stick.
   The merchant scans it once in **Stempelstift einrichten** to bind it to a card.

The NFC URL opens the web app at `/stamp`; the app forwards `picc`/`cmac` (plus
the customer's location if granted) to `redeemStampTap`.

## Security properties

- **CMAC** proves the tag is genuine and the tap is fresh (`stamp/invalid-tag` on mismatch).
- **Counter dedup** (`sticks/{uid}.counterLast`) kills replay / copied URLs (`stamp/replay`).
- **Login required** — the stamp attaches to the authenticated customer.
- **Cooldown** per user×card (`stamp/cooldown`, default 120 s, override via `claimLimits.cooldownSeconds`).
- **Key diversification** — each stick's file key is derived from master + UID; one leak ≠ all sticks.
- **Geofence** — optional, best-effort; only enforced when the customer shared location and the store has coordinates.
- The master key lives only in Secret Manager; clients and `sticks/*` are never readable.
