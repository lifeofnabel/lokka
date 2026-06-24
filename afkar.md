# afkar.md — Migration Cloudinary → Firebase Storage

> Lebendes Arbeitsprotokoll. Wird während der gesamten Migration fortgeschrieben.
> Stand: 2026-06-21 · Branch: `claude/agitated-cerf-a815c6` · Projekt: `lokka-069`

---

## Ziel

Cloudinary **vollständig** entfernen. Bildspeicherung ausschließlich über **Firebase Storage**.
Produktionsreif, keine Cloudinary-Reste, keine TODOs, keine Dummies.

## Entscheidungen (vom Product Owner bestätigt)

1. **Bildvarianten:** Schlank — pro Bildtyp genau **ein** optimal zugeschnittenes Bild + automatisch ein **Thumbnail** für Listen/Feed. Rein clientseitig, kein Cloud-Function-/Blaze-Zwang.
2. **Alt-Daten:** **Frischstart (Pre-Launch)** — keine echten Produktionsbilder. Cloudinary-Referenzen dürfen entfernt werden; neue Uploads → Storage. Trotzdem **Lese-Fallback** für eventuell noch vorhandene alte URLs (kein Bruch).
3. **Seitenverhältnisse:** **Bestehende per-Typ-Ratios beibehalten** (Logo 1:1, Cover 16:9, Feed 1:1, …). Kein visuelles Regressionsrisiko.

## Ausgangsanalyse (Ist-Zustand vor Migration)

- Cloudinary war **nur „dummer" Speicher + CDN**: Upload via rohem `http`-Multipart gegen `api.cloudinary.com` (unsigned preset). **Keine** Transformation-URLs.
- **Bildaufbereitung lief bereits clientseitig** in `lib/core/services/uploadService.dart` (Crop auf Ratio, Resize, JPEG-Kompression mit Größenbudget) — pro `UploadImageType` (14 Typen) sauber spezifiziert.
- In Firestore liegen Bilder nur als **URL-String** (`media.secureUrl`). Die `thumb*`-Felder im Model waren faktisch ungenutzt.
- **Alle** Uploads laufen zentral über `UploadService` → genau **eine** Ausnahme: `userProfilePage` rief `uploadService.cloudinaryService.uploadBytes(...)` **direkt** auf (eigener Folder `profile_images`, ohne Optimierung).
- Storage SDK-seitig schon bereit: `storageBucket: 'lokka-069.firebasestorage.app'` in `firebase_options.dart`. Es fehlten nur: `firebase_storage`-Package, `storage.rules`, `firebase.json`-Eintrag.
- Nicht vorhanden: `functions/`-Verzeichnis (kein serverseitiges Resizing) → bestätigt die clientseitige Varianten-Strategie.

## Zielarchitektur

- **`StorageService`** (neu): zentrale Schicht — `uploadBytes`, `delete`, `deleteByDownloadUrl`, `replace`, `getDownloadUrl`, Metadaten, Pfad-Helper. Mobile + Web über `putData(Uint8List, SettableMetadata)`.
- **`UploadService`** (umgebaut): hält `StorageService` statt `CloudinaryService`. Pipeline: decode → **EXIF bakeOrientation** → center-crop (Ratio) → resize → JPEG-Kompression mit Budget → optional **Thumbnail** → Upload. Pfad/Scope wird aus `UploadImageType` + Auth-UID abgeleitet.
- **Ordnerstruktur** (owner-scoped, regelfreundlich):
  - `merchants/{uid}/profile|cover|offers|catalog|wallet|displayStudio/{uuid}.jpg`
  - `users/{uid}/profile|uploads/{uuid}.jpg`
  - Thumbnail jeweils `{uuid}_thumb.jpg` im selben Ordner.
- **`UploadedMediaModel`**: `url`/`secureUrl` = Firebase Download-URL, `publicId` = Storage-Pfad (für delete/replace), `thumb*` befüllt. Rückwärtskompatibel (alte Cloudinary-URLs werden weiter gelesen).
- **`storage.rules`**: public **read** auf Bild-Buckets, **write** nur `request.auth.uid == {ownerSegment}` + Size-/contentType-Validierung. Kein öffentlicher Schreibzugriff.

## Checkliste

- [x] StorageService
- [x] UploadService umgebaut (EXIF, Thumbnail, Pfade, userProfile-Typ, Fehler)
- [x] UploadedMediaModel angepasst
- [x] Provider + firebase.json + pubspec verdrahtet
- [x] storage.rules
- [x] Cloudinary entfernt (Code, Config, env, i18n, Docs, userProfilePage, devFoundationPage)
- [x] flutter analyze sauber (0 neue Issues aus der Migration)
- [x] Abschlussbericht

---

## Log

- **Start** — Repo analysiert, 3 Architekturfragen geklärt, Plan + Tasks angelegt. Beginne mit `StorageService`.
- `StorageService` (neu) — upload/delete/deleteByDownloadUrl/replace/getDownloadUrl/getMetadata + `StoragePaths` + Timeout/Cancel + freundliche Fehler. Cache-Header `immutable`.
- `UploadedMediaModel` — Doc + Getter (`displayUrl`/`previewUrl`/`storagePath`/`thumbStoragePath`), `fromMap` liest jetzt auch `imageUrl`/`downloadUrl` (Alt-/Forward-Kompat).
- `UploadService` — komplett auf `StorageService` umgebaut: EXIF `bakeOrientation`, Thumbnail-Variante, Pfad/Scope-Mapping je `UploadImageType`, neuer Typ `userProfile`, 25-MB-Input-Guard, ungültiges Format → freundlicher Fehler. Signaturen stabil.
- Verdrahtung — `firebase_storage` in pubspec; `StorageService`-Provider + `ProxyProvider<StorageService, UploadService>`; `CloudinaryService`-Provider raus; `firebase.json` → `storage.rules`.
- `storage.rules` (neu) — public read, owner-scoped write (uid == Segment), Image-/8-MB-Check, delete-safe (resource == null), Default-Deny.
- Cloudinary entfernt — `cloudinaryService.dart` + `cloudinaryConfig.dart` gelöscht; `environmentConfig` (3 Getter), `.env.example` (3 Keys), i18n de/en/ar (2 Keys → `dev.storage*`), Docs (GEO/MERCHANT_AUDIT) bereinigt; `userProfilePage` (direkter Cloudinary-Zugriff → optimierter Upload), `devFoundationPage` (Storage-Status), `merchantShopSettings` (Kommentar).
- `flutter pub get` — `firebase_storage 13.4.2` sauber aufgelöst (keine Konflikte).
- `flutter analyze` — 68 Issues bestehen, davon **0** aus Migrationsdateien. Die 7 Errors gehören zu einem vorbestehenden, unfertigen `merchant/orders`+`core/alert`-Feature (fehlende `merchantRevenueWidgets.dart` / `orderAlert.dart`) und sind unabhängig (per `git status` verifiziert: diese Dateien nicht angefasst).

---

# Abschlussbericht

## 1. Entfernte Cloudinary-Komponenten

| Element | Aktion |
|---|---|
| `lib/core/services/cloudinaryService.dart` | **gelöscht** (Upload via `http`-Multipart + `CloudinaryUploadException`) |
| `lib/core/config/cloudinaryConfig.dart` | **gelöscht** (uploadUri/cloudName/uploadPreset/folder) |
| `environmentConfig.dart` | Getter `cloudinaryCloudName`/`cloudinaryUploadPreset`/`cloudinaryFolder` entfernt |
| `appProviders.dart` | `Provider<CloudinaryService>` + Proxy-Dependency entfernt |
| `userProfilePage.dart` | direkter `uploadService.cloudinaryService.uploadBytes(...)` → optimierter Upload |
| `devFoundationPage.dart` | Cloudinary-Import/-Status/-Testkarte → Firebase-Storage-Status |
| `.env.example` | `CLOUDINARY_CLOUD_NAME`/`_UPLOAD_PRESET`/`_FOLDER` entfernt |
| i18n `de/en/ar.json` | `dev.cloudinary*` → `dev.storageBucket`/`dev.storageUpload` |
| `docs/GEO_MIGRATION_AUDIT.md`, `docs/MERCHANT_AUDIT.md` | Vendor-Erwähnungen bereinigt |
| Package `cloudinary` | war **nicht** vorhanden (nur rohes `http`) → nichts zu entfernen |

Verbliebene „Cloudinary"-Vorkommen sind **bewusst**: dieses Log, erklärende Doc-Kommentare und die snake_case-Lese-Fallbacks (`secure_url`) für Alt-Dokumente. **Keine** Code-Abhängigkeit mehr.

## 2. Neue Firebase-Storage-Struktur

```
merchants/{uid}/profile/{uuid}.jpg        ← logo
merchants/{uid}/cover/{uuid}.jpg          ← cover
merchants/{uid}/offers/{uuid}.jpg         ← feedPost, coupon
merchants/{uid}/catalog/{uuid}.jpg        ← item, itemWide, categoryIcon
merchants/{uid}/wallet/{uuid}.jpg         ← stampCard*, pointsReward
merchants/{uid}/displayStudio/{uuid}.jpg  ← displayLayout
users/{uid}/profile/{uuid}.jpg            ← userProfile
users/{uid}/uploads/{uuid}.jpg            ← general (z. B. Review-Fotos)
system/{category}/{file}                  ← Admin/Banner (nur Console)
```
Thumbnail jeweils `{uuid}_thumb.jpg` im selben Ordner. Eigentümer-Segment = Auth-UID → deckt sich mit den Security-Rules. Pfade ausschließlich über `StoragePaths` + `UploadService`.

## 3. Geänderte Firestore-Felder

**Keine Schema-Migration nötig.** Consumer speichern weiterhin einen URL-String (`media.secureUrl`/`displayUrl`) in ihren bestehenden Feldern (`logoUrl`, `imageUrl`, …). `UploadedMediaModel` behält die Feldnamen; neue Semantik:

| Feld | Bedeutung neu |
|---|---|
| `url` / `secureUrl` | Firebase-Storage-Download-URL (Hauptbild) |
| `publicId` | Storage-Objektpfad (für Delete/Replace) |
| `thumbUrl` / `thumbSecureUrl` | Download-URL des Thumbnails |
| `thumbPublicId` | Storage-Pfad des Thumbnails |

Neue Getter: `displayUrl`, `previewUrl` (Thumb→Voll-Fallback), `storagePath`, `thumbStoragePath`. `fromMap` liest zusätzlich `imageUrl`/`downloadUrl`/`secure_url` → alte Dokumente (inkl. evtl. Cloudinary-URLs) bleiben lesbar.

## 4. Migrationsstrategie (Frischstart, Pre-Launch)

- **Keine** Daten-Backfill nötig (Entscheidung: keine echten Produktionsbilder).
- Neue Uploads → Firebase Storage. Alte URLs in evtl. vorhandenen Dokumenten werden weiterhin **gelesen** (Fallback im Model + `CachedNetworkImage` lädt beliebige https-URL).
- `deleteByDownloadUrl`/`replace` ignorieren bewusst Fremd-URLs → Replace-Flows scheitern nicht an Alt-Links.
- **Manueller Schritt:** 3 `CLOUDINARY_*`-Zeilen aus der lokalen, gitignorierten `.env` entfernen (im Worktree nicht vorhanden).

## 5. Sicherheitsregeln (`storage.rules`)

- **Read:** öffentlich für `merchants/`, `users/`, `system/` (öffentliche Deals-App).
- **Write (create/update/delete):** nur `request.auth.uid == {ownerSegment}`; Upload zusätzlich `contentType image/*` + `< 8 MB`. Delete-sicher (`request.resource == null`).
- `system/` nur über Console/Backend beschreibbar. **Default-Deny** für alles Übrige. Kein öffentlicher Schreibzugriff.

## 6. Performance-Verbesserungen

- Upload setzt `Cache-Control: public, max-age=1y, immutable` (UUID-Namen → gefahrloses, aggressives CDN/Browser-Caching; spürbar im Web).
- **Thumbnails** für Listen/Feed → kleinere Transfers/Decodes, weniger Image-Memory.
- Avatar-Upload jetzt komprimiert/zugeschnitten (vorher Originalbild ungoptimiert).
- 25-MB-Input-Guard verhindert Decode von Riesenbildern (RAM-Schutz, v. a. Web).
- `CachedNetworkImage` bleibt projektweit (Disk-/Memory-Cache) — Storage-URLs sind normale https-URLs.

## 7. Offene Risiken

- **Pre-existing Build-Blocker (NICHT aus dieser Migration):** `merchant/catalog`+`merchant/orders` referenzieren fehlende `merchantRevenueWidgets.dart` / `core/alert/orderAlert.dart` (7 Analyzer-Errors). Blockiert `flutter build`, unabhängig von Storage.
- **Rules-Deploy nötig:** `storage.rules` müssen deployt werden (`firebase deploy --only storage`), sonst greifen die Default-Bucket-Regeln.
- **Alt-Bild-Bereinigung beim Replace** funktioniert nur, wenn der Storage-Pfad/-URL persistiert wird; Consumer, die nur den URL-String speichern, lassen alte Dateien beim Überschreiben verwaisen (unkritisch im Pre-Launch, aber Storage-Müll möglich).
- **`general`/`userProfile`-Scope = `users/`** — falls ein Merchant je den `general`-Typ nutzt, landet das Bild unter `users/{uid}/` (Rule trägt trotzdem, da uid == Owner). Aktuell nur User-Flows betroffen.

## 8. Empfohlene nächste Schritte

1. `storage.rules` deployen; CORS für Web-Bucket prüfen (`gsutil cors`), falls direkte `fetch`/Canvas-Zugriffe nötig.
2. Lokale `.env` bereinigen (Cloudinary-Keys) und Cloudinary-Account/Preset deaktivieren.
3. Optional `replace()` in Edit-Flows verdrahten (alte Datei via `previousUrl` aufräumen) + Storage-Pfad mitpersistieren.
4. Vorbestehende `orders/revenue/alert`-Errors separat fixen (außerhalb dieser Migration).
5. Optional Smoke-Test je Upload-Pfad (Merchant-Logo/Cover/Feed/Stamps/Points, User-Profil, Review-Foto) auf Mobile **und** Web.

---

# Nachtrag — Build-Blocker im `merchant/orders`-Feature behoben (separat von der Migration)

Beim Verifizieren fiel auf: ein committetes, aber unvollständiges „Orders + Finanzen"-Subsystem referenzierte **drei nie angelegte Dateien** → 7 Compile-Errors (blockierten `flutter build`, unabhängig von Cloudinary). Die Datenschicht (`merchantOrdersService`/`OrderModel`) war bereits vollständig; es fehlte nur UI/Utility. Nachgebaut (echt, keine Stubs):

| Datei (neu) | Symbol | Inhalt |
|---|---|---|
| `lib/core/alert/orderAlert.dart` (+ `orderAlertStub.dart` + `orderAlertWeb.dart`) | `OrderAlert` | Neu-Bestellung-Alarm. Web: WAV-Beep (Data-URI, kein Asset) + Notification + `document.hidden`; Mobile: `SystemSound.alert`, Browser-Teile No-Op. Conditional-Import-Muster wie `LocalCacheStorage`. |
| `lib/features/merchant/orders/widgets/merchantRevenueWidgets.dart` | `MerchantTagesumsatz` | Tagesumsatz-Kachel (nur Runner-Modus), heutiger Umsatz `paid && !excludeFromDaily` via `loadPaidOrdersBetween`, Pause-Toggle, Tap → `/merchant/finance`. |
| `lib/features/merchant/orders/pages/merchantFinancePage.dart` | `MerchantFinancePage` | Finanzseite (Route `/merchant/finance`): Range Heute/Woche/Monat, Summenkarte, Tagesumsatz-Pause-Schalter, Liste bezahlter Bestellungen (mit „ausgenommen"-Markierung). |

i18n: bestehende `merchant.finance.*`-Keys (de/en/ar) wiederverwendet, 6 fehlende ergänzt (`orders`, `emptyTitle`, `pauseTitle`, `pauseInfo`, `pauseActiveInfo`, `excluded`). Keine bestehende Datei editiert — die 3 `import`-Zeilen existierten bereits in den Consumern.

**Ergebnis:** `flutter analyze` = **0 Errors, 0 Warnings** (vorher 7 Errors). `flutter build` ist damit nicht mehr durch dieses Feature blockiert.

**Hinweis zum `qimport`-Typo:** Der von dir gemeldete `qimport`-Fehler in `merchantOrderDetailPage.dart` existiert in diesem Worktree **nicht** (Datei ist sauber) — vermutlich eine unkommittierte Tipp-Panne in deinem Haupt-Checkout. Dort einfach das führende `q` in Zeile 1 entfernen.

---

# Menükarte — Release-Hardening (4 Modi)

## Current Project State
- **Goal:** Menükarte release-ready in allen 4 Modi (Runner, Tisch-QR, Kasse-zeigen, Nur-Karte), fehlerfrei, Multi-Tenant.
- **Tech Stack:** Flutter Web + Firebase (Firestore/Auth/Storage). **State-Management bleibt Provider/ChangeNotifier** (bewusste Entscheidung — KEIN Riverpod-Mix, kein Rewrite; das Feature war bereits durchgängig Provider, ein Mix hätte „Beiträge" gefährdet).
- **Important Architecture:** Modi via `PublicCatalogConfig` (Flags, exklusiv durchgesetzt in `PublicShopService.loadCatalogConfig`). Bestellungen unter `merchants/{mid}/orders/{id}` (merchantId == Auth-UID → Multi-Tenant-Scoping). Vor-Kasse-Bestellung = `status:'qr_pending'` (verborgen) → wird per Code/QR-Scan auf `'new'` bestätigt (`confirmPendingByCode`).
- **Important Files:** `publicShopProvider/Service.dart`, `publicCartPage.dart`, `merchantOrdersPage.dart` + `widgets/merchantScanOrderSheet.dart` (neu), `core/services/connectivityService.dart` (neu), `firestore.rules`.
- **Current Bugs:** keine offenen aus dieser Runde (analyze 0 Errors, web build OK, 13 neue Tests grün).
- **Open Decisions:** `orders` `list` ist weiterhin öffentlich lesbar (Datenschutz-Abwägung; später anonymes Auth). Scanner ist scan-on-demand (zuverlässiger im Web als Dauer-Kamera).
- **Next Steps:** `firebase deploy --only firestore:rules`; Smoke-Test je Modus auf echtem Gerät; ggf. anonymes Auth für `orders.list`.

## Work Log

### 2026-06-22 — Claude (Opus 4.8)
**Prompt Summary:** Pre-Release-Hardening Menükarte, alle 4 Modi fehlerfrei + Kamera/QR-Flow bauen + Edge-Cases + Rules + Tests.
**Answer / Action Summary:**
- **Audit:** Runner/Tisch/Nur-Karte bereits E2E-fertig; einzige echte Lücke = Kamera-Scan für „Kasse-zeigen" (`mobile_scanner` im pubspec, nirgends verdrahtet; „Coming Soon"-Stub).
- **Riverpod NICHT migriert** (Begründung oben) — stattdessen bestehende Provider-Flows gehärtet.
- **Scanner gebaut:** `merchantScanOrderSheet.dart` (Live-Kamera via `mobile_scanner` 7.2.0 + Rahmen-Overlay + Blitz, Debounce gegen Doppel-Scan, **Manuelle-Code-Eingabe als Fallback**, Permission-/Kein-Gerät-/Unlesbar-Handling via `errorBuilder`). Verdrahtet in Orders-Toolbar (`_ScanAction`) und Dashboard-`ScannerCard` (`comingSoon` entfernt). Scan/Manuell → `confirmPendingByCode`.
- **Idempotenz (#1 Doppelbestellung):** `PublicShopService.newOrderId` + deterministischer `orderCodeFor(id)`; Provider hält `_pendingOrderId` (Wiederverwendung bei Retry) + **Recovery-Read** (`existingOrderCode`) — verhindert Duplikate auch bei Timeout-nach-Write. UI-Doppel-Tap-Guard (`_submitting`) im Cart.
- **Offline (#2):** `ConnectivityService` (connectivity_plus) — `placeOrder` blockt offline mit klarem Hinweis (`public.shop.offlineError`) statt hängendem Write; Idempotenz-ID bleibt → kein Duplikat bei spätem Retry.
- **Leerer Korb (#4):** war bereits geguarded (bestätigt + getestet).
- **Ungültiger QR (#3):** Scanner ignoriert Unlesbares, „nicht gefunden" sauber gemeldet; nie Crash/Fake-Order.
- **Rules gehärtet:** `validNewOrder(mid)` — Gast darf nur valide Eingangs-Bestellung anlegen (richtiger merchantId, status∈{new,qr_pending}, kein `paid`, totalPrice≥0); Update/Delete bleibt Merchant.
- **i18n:** `merchant.scan.*` + `public.shop.offlineError` in de/en/ar.
- **Tests:** `test/menu_modes_test.dart` (Modus-Gating + Code-Stabilität) + `test/order_idempotency_test.dart` (leerer Korb/offline/Retry-selbe-ID/Recovery) — 13/13 grün.
**Files Changed:** + `connectivityService.dart`, + `merchantScanOrderSheet.dart`, + 2 Tests; ~ `publicShopProvider.dart`, `publicShopService.dart`, `publicCartPage.dart`, `merchantOrdersPage.dart`, `merchantDashboardPage.dart`, `firestore.rules`, `assets/i18n/{de,en,ar}.json`.
**Important Decision:** Provider behalten (kein Riverpod), Scanner scan-on-demand, Idempotenz über stabile Doc-ID + Recovery-Read (rules-konform, da Gast-Retry sonst an der Update-Regel scheitert).
**Verification:** `flutter analyze lib test` = 0 Errors/Warnings (nur 56 vorbestehende `unnecessary_underscores`-Infos in fremden Dateien); `flutter build web` = √; 13/13 Tests grün.
**Next Useful Step:** `firebase deploy --only firestore:rules` + Geräte-Smoke-Test je Modus.

---

# Merchant Re-Skin (Deep-Green) + Web-Perf

## Work Log

### 2026-06-22 — Claude (Opus 4.8)
**Prompt Summary:** Optimieren (Web-Perf) + Merchant-Redesign (bold, dunkleres Grün aus User-Bereich). Entscheidung des Users: dark-only (KEIN Light/Dark-Toggle), Optimierung = Web-Perf-Fokus.
**Answer / Action Summary:**
- **Theme-Entscheidung:** Light/Dark-Toggle bewusst NICHT gebaut — `MerchantPremiumColors.*` wird ~1100× als `static const` referenziert (46 Dateien); ein echter Runtime-Toggle hieße ~1100 const-Stellen auf ThemeExtension migrieren = großer Refactor + Regressionsrisiko für die 4 Modi. Stattdessen elegant: nur Token-WERTE in EINER Datei geändert → ganze Merchant-Area re-skint, null Call-Site-Churn, null const-Bruch.
- **Re-Skin (Deep-Green):** `merchantPremiumUi.dart` (`MerchantPremiumColors`) + synchron `appTheme.dart` (`merchantDark`). Aus User-Grün abgeleitet (AppColors.green #1FA97E / mintStrong #45C9A4), aber tiefer/dunkler: accent #55D8B0→#2FB389, base #24272D→#181E1A (grün-getönt), surface #313640→#222B26, line→#3A463F, ink #F2F6F3, muted #A9B5AD (AA). Schatten braun→grün-schwarz (#050B08). Token-Namen unverändert.
- **Web-Perf:** `prefer_const_*`-Lints in analysis_options aktiviert + `dart fix --apply` (17 const-Fixes/11 Dateien — Codebase war schon const-stark). `memCacheWidth` an 4 Scroll-Listen-Bildern (publicShopItemCard 400, publicShopPage 600, merchantItems 240, cart 200) → kleinere Bitmaps. **Leak gefixt:** `merchantTablesPage` Area-/Tisch-Sheet erzeugte 4 `TextEditingController` ohne dispose → deferred dispose (400 ms, wie items-page). shopSettings-„Leak" war Fehlalarm (Loop-dispose).
- **Bundle:** main.dart.js 5.157.451 → 5.156.807 B (flach; war schon icon-tree-shaked + const-stark). Echte Wins = Bild-Decode-Caps + Leak, nicht Bundle.
**Files Changed:** ~ `merchantPremiumUi.dart`, `appTheme.dart`, `analysis_options.yaml`, `merchantTablesPage.dart`, `publicShopItemCard.dart`, `publicShopPage.dart`, `merchantItemsPage.dart`, `publicCartPage.dart` + 11 Dateien via `dart fix`.
**Important Decision:** Re-Skin über Token-Werte (kein Toggle). Light/Dark als sauberer Folge-PR (ThemeExtension), wenn gewünscht.
**Verification:** `flutter analyze lib test` = 0 Errors/0 Warnings (54 vorbestehende `unnecessary_underscores`-Infos). 13/13 eigene Tests grün; `test/widget_test.dart` (Default-Scaffold) schlägt VORBESTEHEND fehl (`[core/no-app]` — pumpt App() ohne Firebase.initializeApp, nicht von mir verursacht). `flutter build web --release` = √.
**Next Useful Step:** Optional Light/Dark-Toggle via ThemeExtension (großer Refactor); `widget_test.dart` ersetzen/entfernen (kaputtes Default-Scaffold).

---

# Stempelkarten (Stamp Cards) — Full Build (NFC + QR + Geo)

## Current Project State
- **Goal:** Stempelkarten release-ready: Builder + Manage-Carousel + Kassen-Scanner (Stempeln/Einlösen) + physischer Stempelstift (NTAG 424 DNA) mit serverseitigem `/stamp`-Core (CMAC + Counter + Cooldown), optionaler Geo-Check, Wallet-Delight, Offline-Queue, Edge-Cases.
- **Decisions (vom User bestätigt):** (1) State-Management bleibt **Provider/ChangeNotifier** (KEIN Riverpod). (2) **NFC-Cloud-Function-Core bauen** (User aktiviert Blaze, programmiert Chips, legt Master-Key in Secret Manager) — PLUS QR-Kassen-Scan-Flow. (3) **Geo-Check** nur wenn der Kunde Standort im Web erlaubt hat, sonst still überspringen.
- **Important Architecture:** Loyalty-Zustand ist **server-authored** — Firestore-Rules verbieten Client-Writes auf `users/{uid}/stampProgress|pointsProgress|earnedRewards` (Selbst-Stempel-Schutz). Mutationen nur via Callables (Admin SDK). „Zwei Türen, ein Backend": NFC-Tap (`redeemStampTap`) und Kassen-Scan (`merchantStampCustomer`) → dieselbe `applyStamps`-Logik.
- **Important Files (Backend):** `functions/` (TS, Node 20, region europe-west1): `src/crypto/aesCmac.ts` (RFC 4493), `src/crypto/ntag424.ts` (AN12196 SUN/SDM + Key-Diversifizierung), `src/shared.ts` (applyStamps/claimRewards/cooldown/geo), `src/index.ts` (6 Callables), `src/scripts/deriveKeys.ts` (Chip-Programmierung), `functions/README.md` (Setup/Provisioning). Secret: `STAMP_MASTER_KEY` (32 hex).
- **Important Files (Schema):** `firebasePaths.dart` (+sticks/+earnedRewards), `stampCardModel.dart` (+`rewardTiers`/`StampRewardTier`/`boundStickId`/`effectiveRewardTiers`/`maxStamps`), `firestore.rules` (users-Block neu strukturiert: rekursiver READ, explizite WRITE-Allowlist, server-only Loyalty; `sticks` server-only).
- **Backend / Firebase:** `merchants/{mid}/stampCards/{id}` (+boundStickId, +rewardTiers), `sticks/{tagUid}` (server-only: boundMerchantId/boundCardId/counterLast), `users/{uid}/stampProgress/{cardId}` (currentStamps/cycle/awardedTiers/history), `users/{uid}/earnedRewards/{id}` (status earned|redeemed). `firebase.json` → functions-Block ergänzt.
- **Current Bugs:** Client-Writes auf stampProgress in `userStampPage._markClaimed` + `userWalletDetailPage._markClaimed` brechen unter neuen Rules → müssen in Phase 7 auf `claimReward`-Callable migriert werden (sonst Runtime-Deny nach Rules-Deploy).
- **Open Decisions:** Cooldown-Default 120s (override via card.claimLimits.cooldownSeconds). Geofence 300m. Reward-Konvertierung: ganze volle Karte → alle erreichten Tiers als earnedRewards, dann Reset (cycle++).
- **Next Steps:** Phase 3 Stick-Setup-UI, Phase 4 Scanner→User-Page, Phase 5 Manage-Carousel, Phase 6 Builder (Templates/Wallet-Preview/Tiers), Phase 7 Wallet+/stamp-Route+Delight+Claim-Migration, Phase 8 Offline-Queue/Edge/i18n/Tests/GO-NOGO. Manuell: Blaze, `functions:secrets:set STAMP_MASTER_KEY`, deploy functions+rules, Chips programmieren.

## Work Log
### 2026-06-23 — Claude (Opus 4.8)
**Prompt Summary:** Stempelkarten end-to-end bauen (NFC-Core + QR-Scan + Geo), Provider behalten.
**Answer / Action Summary:** Audit: viel Merchant-/User-Stamp-UI existiert bereits (Builder, Manage-Liste, Wallet-Progress, Services — alles Provider). Fehlte: Security-Core, Sticks, Scanner-Stamp/Redeem, Carousel, Tiers, Offline, Delight. Phase 1 (Schema/Paths/Rules) + Phase 2 (Cloud Functions Security-Core) gebaut & `tsc` grün.
**Files Changed:** + `functions/**` (package.json/tsconfig/.gitignore/README + src/crypto/aesCmac.ts, src/crypto/ntag424.ts, src/shared.ts, src/index.ts, src/scripts/deriveKeys.ts); ~ `firebase.json`, `firestore.rules`, `lib/core/constants/firebasePaths.dart`, `lib/features/merchant/stamps/models/stampCardModel.dart`.
**Important Decision:** Server-authored Loyalty (Client kann Loyalty nur lesen). Stick-Provisioning ohne Vorab-Firestore-Doc: provToken = CMAC(master,"PROV"||uid) → nur echter gedruckter Stift registrierbar. Stick-Doc-ID == Chip-UID.
**Next Useful Step:** Phase 3 — Stempelstift-Einrichten-UI (QR scannen → setupStick).

### 2026-06-23 (Forts.) — Claude (Opus 4.8) — Phasen 3–8 FERTIG
**Answer / Action Summary:** Komplette Stempelkarten-Feature gebaut (Provider, kein Riverpod). Backend `tsc` grün + Crypto-Self-Test 8/8 (RFC4493 + SUN-Round-Trip + Tamper-Reject + Diversifizierung). Flutter analyze lib+test = 0 Errors/0 Warnings (55 vorbestehende Infos). 18/18 Dart-Tests grün. `flutter build web --release` = √.
- **Phase 3 Stick-Setup:** `stampFunctionsService.dart` (Callable-Gateway, region europe-west1, Best-Effort-Geo nur bei erteilter Permission), `stampScanner.dart` (generischer QR-Scanner + Manuell-Fallback), `stickSetupFlow.dart` (Karte wählen → QR `lokka-stick:UID:TOKEN` → setupStick).
- **Phase 4 Scanner→Kunde:** `merchantCustomerStampPage.dart` (Name/Initialen, Karten mit +1/Long-Press +N, verdiente Belohnungen „Verbraucht"), `customerScanFlow.dart` (Wallet-QR `lokka://wallet/{uid}/{mid}/{code}` parsen, Merchant-Check). Dashboard-Scanner → Chooser (Stempeln/Bestellung), Order-Scanner bleibt.
- **Phase 5 Manage-Carousel:** PageView 1-Karte/Screen + Pager 1/n + Dots, Stick-Badge pro Karte, Duplicate (service+provider), 3-Karten-Cap („X/3 aktiv", Block + Sheet), Top-Buttons Erstellen/Stift/Einstellungen.
- **Phase 6 Builder:** `stampBuilderExtras.dart` — Template-Galerie (4 Presets, kein Blankstart), Tiered-Rewards-Editor (Zwischenstufen; effektive Tiers = single fallback), Kunden-Wallet-Vorschau-Toggle (Karte/Wallet + Fortschritt). Builder verdrahtet (`_buildRewardTiers`, `_applyTemplate`, `_addRewardTier`, hydrate).
- **Phase 7 Wallet+Tap:** `/stamp`-Route + `stampTapPage.dart` (anonymer Login via `AuthService.ensureSignedIn`, redeemStampTap, Füll-Animation, Fortschritt, Offline→Queue), `stampQueueService.dart` (persistente Queue, idempotent via Counter, transient vs. permanent). Claim-Migration: `userStampPage`/`userWalletDetailPage` `_markClaimed` → `claimReward`-Callable (kein Client-Write mehr auf stampProgress). Server schreibt In-App-Notification bei voller Karte (echtes Push = FCM, manueller Schritt).
- **Phase 8:** 85 i18n-Keys × de/en/ar (`merchant.stamps.*`, `merchant.stick.*`, `merchant.stampScan.*` inkl. err.*, `stampTap.*`, common.done/add). Tests + Build verifiziert.
**Files Changed (Flutter, neu):** `features/stamps/services/{stampFunctionsService,stampQueueService}.dart`, `features/stamps/widgets/{stampScanner,stickSetupFlow,customerScanFlow}.dart`, `features/stamps/pages/stampTapPage.dart`, `features/merchant/stamps/pages/merchantCustomerStampPage.dart`, `features/merchant/stamps/widgets/stampBuilderExtras.dart`, `test/stamp_card_test.dart`. **(geändert):** `merchantStampsPage.dart`, `merchantStampEditPage.dart`, `merchantStampCard.dart`, `merchantStampsProvider.dart`, `merchantStampsService.dart`, `stampCardModel.dart`, `merchantDashboardPage.dart`, `authService.dart`, `appRouter.dart`, `userStampPage.dart`, `userWalletDetailPage.dart`, `pubspec.yaml` (+cloud_functions), `assets/i18n/{de,en,ar}.json`. **Backend:** `functions/test/selfTest.js`, `functions/package.json` (test-script).

## GO / NO-GO — Stempelkarten
**Verdikt: GO für Code-Merge; CONDITIONAL-GO für Produktion** (es fehlen nur EXTERNE, vom User zu erledigende Schritte — kein Code offen).

Vor Live unbedingt (manuell, kann Claude nicht):
1. **Blaze-Plan** aktivieren (Cloud Functions Pflicht).
2. `cd functions && npm install` → `firebase functions:secrets:set STAMP_MASTER_KEY` (32 hex, `openssl rand -hex 16`).
3. `firebase deploy --only functions,firestore:rules,storage` (Rules-Deploy ist KRITISCH — sonst greift Selbst-Stempel-Schutz nicht und Client-Claims schlagen fehl).
4. NTAG-424-DNA-Chips programmieren: `STAMP_MASTER_KEY=… npm run derive-keys -- <UID>` → SDMMetaRead/SDMFileRead-Keys + URL-Template `/stamp?picc={PICCEncryptedData}&cmac={SDMMAC}`, QR `lokka-stick:UID:TOKEN` aufdrucken (siehe functions/README.md).
5. Echtes **Push** = FCM (firebase_messaging + Web-Service-Worker) — aktuell In-App-Notification als Ersatz.

Checkliste: Manage-Carousel ✅ · Builder (Templates/Wallet-Preview/Tiers) ✅ · Scanner Stempeln/Einlösen ✅ · Stick-Setup ✅ · /stamp NFC-Core (CMAC+Counter+Cooldown+Geo) ✅ (verifiziert) · Edge-Cases (Doppel-Tap/Offline-Queue/forged/voll/paused/Cap/unbound) ✅ · Multi-Tenant-Rules ✅ · i18n ✅ · Tests ✅.

---

# User-Bereich: Feed · Post · Merchant-Profil (Shared Widgets + Kommentare)

## Current Project State
- **Goal:** Feed, Beitrag-Detail und Merchant-Profil (User-Sicht) release-reif über echte **Shared Widgets** + volle Kommentar-Funktion. Keine Stubs/Dead-UI.
- **Tech Stack:** Flutter Web + Firebase (Firestore/Auth/Storage). State: Provider/ChangeNotifier (kein Riverpod-Mix — bewusst beibehalten).
- **Entscheidungen (vom User in diesem Lauf bestätigt):** (1) **Bewertungen bleiben pro-Beitrag** (`feed/{postId}/reviews/{uid}`) — KEIN Wechsel auf Merchant-Level (frühere Entfernung bleibt). (2) **Kommentare voll bauen** (Modell + Service + UI + Rules).
- **Important Architecture:** Eine `PostCard` für Feed UND Profil (`enableProfileNavigation`-Flag). Eine `QuickActionBar` (config-driven, ausgegraut statt versteckt bei fehlenden Daten) für Post-Seite UND Profil. Eine `RatingSection` (self-contained, pro-Beitrag). Kommentare denormalisiert über `commentsCount` (Transaktion, in `onlyCounters()` erlaubt).
- **Important Files (neu):** `features/user/feed/widgets/postCard.dart`, `features/user/feed/widgets/commentsSheet.dart`, `features/user/feed/models/commentModel.dart`, `features/user/reviews/widgets/ratingSection.dart`, `features/user/shared/widgets/quickActionBar.dart`, `test/comment_model_test.dart`. **(geändert):** `userFeedPage.dart`, `userFeedDetailPage.dart`, `userPartnerDetailPage.dart`, `userFeedService.dart`, `feedPostModel.dart`, `firebasePaths.dart`, `firestore.rules`. **(gelöscht):** `feedDealCard.dart` (→ PostCard), tote `_PartnerPostCard/_SwipeCard*` im Profil.
- **Backend / Firebase:** Neu `feed/{postId}/comments/{commentId}` (Auto-ID, `userId`-Eigentum). Rule: read public, create wenn `userId==auth.uid`, update/delete nur Eigentümer. `commentsCount` zu Feed-Post-Zählern hinzugefügt.
- **Current Bugs:** keine offenen (analyze 0/0, build web ✅, Tests grün).
- **Open Decisions:** Bewertungen bleiben pro-Beitrag (siehe oben). Report-Flow NACHGEZOGEN: `showReportPostSheet` (reportSheet.dart) + `UserFeedService.reportPost` (Passthrough → contentReports), verdrahtet in Feed + Profil → „Beitrag melden" jetzt aktiv (Grund-Picker Spam/Unangemessen/Falsche Infos/Sonstiges + Bestätigungs-Snackbar).
- **Next Steps:** `firebase deploy --only firestore:rules` (Kommentar-Regeln + `commentsCount`-Counter). Optional: Report-Flow verdrahten, Like-Count auf Profil-Karten live (aktuell one-shot-Load).

## Work Log
### 2026-06-23 — Claude (Opus 4.8)
**Prompt Summary:** User-Bereich (Feed/Post/Profil) auf Release-Qualität — Shared Widgets (PostCard/QuickActionBar/RatingSection) zuerst, dann Interaktionen, Post-Redesign, Profil-Fixes, Datenmodell+Rules, Edge-Cases, GO/NO-GO. Audit+Build in einem Lauf, keine Stubs.
**Answer / Action Summary:**
- **Audit:** Codebase weit fertiger als angenommen — Doppel-Tap-Like + Heart-Burst, Like-Count, Single-Tap/Pfeil→Post, Logo/Name→Profil, Review-Sheet, Route/Zeiten/Anrufen/Social-Popouts, Loyalty-Tiles existierten bereits. Echte Lücken: keine echten Shared Widgets (Feed=`FeedDealCard`, Profil=`_PartnerPostCard` dupliziert), kein Kommentarsystem, Post-Titel als Overlay statt unter Bild, Profil-Quick-Actions links-bündig statt zentriert, Loyalty-Tiles nur sichtbar wenn vorhanden (kein dimmed-Zustand).
- **Shared Widgets:** `PostCard` (ersetzt beide Karten; `enableProfileNavigation`-Flag, Doppel-Tap-Like+Burst, Single-Tap+Mini-Pfeil→Öffnen, Bottom-Bar Like·Kommentar·Teilen, expired-Greyscale/Dim). `QuickActionBar` (zentriertes Wrap, fehlende Daten → ausgegraut+inert statt versteckt). `RatingSection` (extrahiert aus Detail-`_ReviewsSection`, self-contained, pro-Beitrag).
- **Feed:** nutzt jetzt `PostCard` + Kommentar-Sheet + `ShareUtils.shareFeedPost`.
- **Post-Seite:** komplett umgebaut → Bild-Hero (Back/Zoom, KEIN Titel-Overlay) → Titel/Untertitel UNTER dem Bild → Like·Kommentar·Teilen → Deal → Beschreibung → CTA → QuickActionBar (Route/Anrufen/Social, lädt Merchant) → Händler-Zeile → RatingSection.
- **Profil:** Quick-Actions zentriert via `QuickActionBar` (Route/Zeiten/Anrufen/[Karte]/Social); Posts = identische `PostCard` (`enableProfileNavigation:false`); Loyalty-Tiles IMMER sichtbar, aktiv/ausgegraut nach `featuresPublic`-Flags, Tap auf deaktiviert → klare Meldung („…keine Stempelkarten hinterlegt").
- **Kommentare (voll):** `CommentModel`, Service `commentsStream/addComment/deleteComment` (Counter atomar), `commentsSheet.dart` (Live-Liste, Composer, eigene löschen, leer/nicht-eingeloggt-Zustände), `commentsCount` im Modell + Rules.
- **Edge-Cases:** fehlende Kontaktdaten → Aktion ausgegraut (nie Crash/Lücke); Doppel-Tap likt nur, un-liked nie; broken/leeres Bild → Fallback-Icon; offline → optimistisches Like (vorhandener Pfad); leere Zustände für Posts/Reviews/Kommentare designt.
**Files Changed:** siehe „Important Files" oben.
**Important Decision:** Bewertungen pro-Beitrag (User-Wahl); Kommentare voll gebaut (User-Wahl); `FeedDealCard` durch `PostCard` ersetzt statt zwei Karten zu pflegen.
**Verification:** `flutter analyze lib` = **0 Errors / 0 Warnings** (51 vorbestehende `unnecessary_underscores`-Infos). `flutter test` (comment_model + stamp_card) grün. `flutter build web --release` ✅.
**Next Useful Step:** `firebase deploy --only firestore:rules` (Kommentar-Regeln scharf schalten).

## GO / NO-GO — User-Bereich
**Verdikt: GO für Code-Merge; CONDITIONAL-GO für Produktion** — einziger offener Schritt ist der Rules-Deploy (Kommentare schreiben sonst Default-Deny).

---

# Merchant: „Feed verwalten" Grid + Per-Post-CTA + Stempelkarten-Werbung (Stamp-Ad)

## Current Project State
- **Goal:** „Feed verwalten" professionell (Instagram-Grid + Status-Badges + Tile-Aktionen), pro Beitrag editierbarer CTA-Button (Profil / Link / Stempelkarte, mit Validierung), und fertiges **Stempelkarten-Werbe-Template** (Karte wählen → Titel/Untertitel → Auto-Visual aus echtem Karten-Design via RepaintBoundary→PNG→Storage). Keine Stubs.
- **Tech Stack:** Flutter Web + Firebase. State: **Provider/ChangeNotifier** (kein Riverpod — bewusst, wie der Rest der App).
- **Important Architecture:**
  - **EINE** Karten-Render-Quelle: neues `lib/features/stamps/widgets/stampCardVisual.dart` (`StampCardVisual`). Merchant-Carousel (`MerchantStampPreview` = jetzt dünner Wrapper), Builder-Vorschau, User-Wallet (`_StampCardCanvas` = Wrapper) UND der Stamp-Ad-Generator nutzen es. Die zwei früheren 1:1-Kopien sind entfernt. (Linter hat `StampCardVisual` zusätzlich um optionales `filledStamps` erweitert — echter Fortschritt im Wallet; default = alle gefüllt = Design-Vorschau.)
  - **Stamp-Ad-Visual** wird live gerendert und beim Veröffentlichen per `RepaintBoundary.toImage(pixelRatio:3)` → PNG → `UploadService.uploadOptimizedImageBytes(type: feedPost)` (square 1:1, passt zum Feed) hochgeladen. Fixe 360×360-Capture-Box (FittedBox skaliert nur die Anzeige) → konsistentes, scharfes Output unabhängig vom Screen.
  - **Status** = abgeleitet aus Flags (`MerchantPostStatus` getter), KEIN neues Feld — eine Wahrheit für Grid-Badge + Action-Buttons.
  - **CTA-Targets** erweitert: `profile` (→ `/user/partners/:mid`), `url` (extern, validiert), `stampCard` (→ neue Route `/user/stamps/:mid`). Legacy `shop/catalog/feedPost/external` bleiben lesbar/route-fähig. Route-Berechnung zentral in `MerchantFeedCreateService.ctaRouteFor` (static, getestet).
- **Important Files (neu):** `features/stamps/widgets/stampCardVisual.dart`, `features/merchant/feedManager/pages/merchantStampAdCreatePage.dart` (+ `_StampAdProvider`, `_AdVisual`), `test/feed_cta_stamp_ad_test.dart`. **(geändert):** `merchantFeedManagePage.dart` (komplett neu: Grid+Chooser+Tile-Actions+CTA-Editor), `merchantStampCard.dart` (Preview→Wrapper, Dup-Render raus), `userPartnerStampsPage.dart` (Canvas→Wrapper, `dart:math` raus), `feedPostModel.dart` (+linkedCardId), `merchantToolsService.dart` (MerchantFeedPostData +cta/+linkedCardId/+status/+isStampAd/+hasButton, +deleteFeedPost), `merchantToolsProvider.dart` (Manage-Provider +stampsService/+linkableCards/+deletePost/+merchantId), `merchantFeedCreateService.dart` (createPost +linkedCardId, `_ctaRoute`→static `ctaRouteFor`), `merchantFeedCreateProvider.dart` (+linkedCardId passthrough), `userFeedDetailPage.dart` (`_CtaButton` profile/stampCard/url), `appRouter.dart` (+`/user/stamps/:mid`+Loader, +`/merchant/feed/stamp-ad`), `assets/i18n/{de,en,ar}.json` (+~48 Keys).
- **Backend / Firebase:** Keine neue Collection, keine neue Zugriffsart → **kein firestore.rules-Deploy nötig**. Posts (inkl. neuer optionaler Felder `type`/`cta*`/`linkedCardId`) werden weiterhin nur vom Eigentümer geschrieben (`create: incoming().merchantId == auth.uid`, kein Field-Whitelist). `linkedCardId` referenziert zwangsläufig eine eigene Karte (Owner-Scope). URL-Validierung clientseitig (`_validateUrl`); Karten-Picker auf eigene Karten beschränkt. Stamp-Ad-PNG landet unter `merchants/{uid}/offers/` (bestehende storage.rule deckt es).
- **Current Bugs:** keine offenen (analyze lib = 0 Errors/0 Warnings, 51 vorbestehende `unnecessary_underscores`-Infos; 33 Tests grün + 11 neue; `flutter build web --release` √). `test/widget_test.dart` schlägt VORBESTEHEND fehl (Default-Scaffold ohne Firebase.init — nicht von mir).
- **Open Decisions:** Stamp-Ad-Visual = Snapshot zum Publish-Zeitpunkt (nicht live-rerender im Feed) + „Visual neu generieren"-Button im Create-Flow. CTA „Profil" = Partner-Detailseite (dort Loyalty→Wallet).
- **Next Steps (Minor/optional):** „Visual neu generieren" auch NACH dem Publish aus dem Grid (braucht Offscreen-Render der verlinkten Karte + Re-Upload + imageUrl-Update) — aktuell nur im Create-Flow. Sonst: nichts blockierend.

## Work Log
### 2026-06-23 — Claude (Opus 4.8)
**Prompt Summary:** „Feed verwalten" leveln (Instagram-Grid, Status, Tile-Actions) + pro-Post editierbarer CTA (Profil/URL/Stempelkarte, validiert) + fertiges Stempelkarten-Werbe-Template (Auto-Visual aus Karten-Design, RepaintBoundary→PNG→Storage, Regenerate) + Datenmodell rückwärtskompatibel + Edge-Cases + GO/NOGO. Audit+Build in einem Lauf, keine Stubs.
**Answer / Action Summary:**
- **Audit:** Feature war weit fertiger als der Prompt annahm — Manage-Page (Liste+Filter+Edit-Sheet), 6-Step-Create-Wizard, CTA-Felder (`ctaLabel/ctaLinkType/...`), User-`_CtaButton` mit shop/feedPost/external existierten bereits. Echte Lücken: Liste statt Grid, kein Profil/URL/Stempelkarte-Target + kein voller CTA-Editor in Manage, kein Stamp-Ad-Template, kein Image-Capture, ZWEI duplizierte Karten-Render-Widgets.
- **Shared Widget zuerst:** `StampCardVisual` extrahiert; `MerchantStampPreview` + Wallet-`_StampCardCanvas` zu dünnen Wrappern gemacht; Dup-Render (`_StampGrid/_StampSlot/_colorFromHex/_iconFor/_stampText` ×2 + `dart:math`) entfernt → eine Quelle für 4 Verwendungen.
- **Datenmodell (rückwärtskompatibel):** FeedPostModel +`linkedCardId`; MerchantFeedPostData +`ctaLinkType/ctaTargetId/ctaUrl/linkedCardId` + abgeleiteter `status`/`isStampAd`/`hasButton`. Alte Posts ohne Felder parsen weiter (null/leer).
- **Manage-Grid:** width-aware `Wrap` (2/3/4 Spalten, nistet sicher im Scaffold-Scroll), quadratische image-forward Tiles, Status-Punkt-Badge, Stamp-Ad/Link/Privat-Marker, Dim für pausiert/archiviert, leerer Zustand mit „+ Neuer Beitrag". Tap → Action-Sheet (Bearbeiten · Link · [Jetzt veröffentlichen] · Pause/Aktiv · Öffentlich/Privat · Archivieren · Löschen). „+ Neuer Beitrag" → Chooser (Standard → `/merchant/feed/create`, Stempelkarte bewerben → `/merchant/feed/stamp-ad`).
- **Per-Post-CTA-Editor:** im Edit-Sheet — Label + Ziel-Chips (Kein Button/Profil/Link/Stempelkarte) + bedingtes URL-Feld (validiert, https-normalisiert) + Karten-Dropdown (nur eigene, stale-id-sicher). Speichert label/linkType/targetId/url/route (route via `ctaRouteFor`).
- **Stamp-Ad-Template:** neue Seite + Provider. Karte wählen (max 3 eigene) → Titel/Untertitel (einzige Pflicht; Beschreibung+CTA vorausgefüllt, editierbar) → Live-WYSIWYG `_AdVisual` (Titel/Untertitel + echtes `StampCardVisual`, brand-getönter quadratischer Hintergrund) → „Visual neu generieren" → Publish: Capture→PNG→Upload→`createPost(type:'stampAd', linkedCardId, ctaLinkType:'profile')`. CTA öffnet Profil (Wallet-Add).
- **User-Seite:** `_CtaButton` routet `profile`→Partner, `stampCard`→`/user/stamps/:mid` (neue Route+Loader), `url`/`external`→Extern-Warnung. Icons ergänzt.
- **Edge-Cases:** keine Karten→designter Zustand + „Karte erstellen"; Karte später geändert→Snapshot bleibt + Regenerate; Karte gelöscht→Ad rendert weiter, CTA(Profil) bleibt gültig, Picker fängt stale id; ungültige URL→Fehler, kein Broken-Link; Capture-Fehler→graceful Toast+Retry, kein Crash; lange Texte→maxLines/ellipsis; Status-Wechsel→sofort im Badge (load()).
**Files Changed:** siehe „Important Files" oben.
**Important Decision:** Status abgeleitet (kein redundantes Feld); EINE Karten-Render-Quelle; Stamp-Ad = Publish-Snapshot (square, via bestehendem Upload-Funnel statt separatem postAssets-Pfad); kein Rules-Deploy nötig (Owner-Scope deckt neue Felder).
**Verification:** `flutter analyze lib` = 0 Errors/0 Warnings (51 vorbestehende Infos). `flutter test` = 33 grün + 11 neue (`feed_cta_stamp_ad_test.dart`); nur vorbestehender `widget_test.dart` rot (Firebase-init). `flutter build web --release` = √.
**Next Useful Step:** Optional Post-Publish-Regenerate aus dem Grid; sonst Geräte-Smoke-Test (Stamp-Ad-Capture auf echtem Web + Mobile).

## GO / NO-GO — Feed verwalten + Stamp-Ad
**Verdikt: GO** (Code-Merge **und** Produktion — kein offener Pflicht-Schritt, kein Rules-/Functions-Deploy nötig).
Checkliste: Manage-Grid (image-forward, Status-Badges, Tile-Actions) ✅ · Per-Post-CTA (Label + Profil/URL/Stempelkarte + Validierung, gerendert auf User-PostCard/Post-Seite) ✅ · Stamp-Ad-Template (Karten-Picker max 3, Auto-Beschreibung+Profil-CTA, Live-Vorschau) ✅ · Image-Generierung (RepaintBoundary→PNG→Storage + Regenerate) ✅ · Edge-Cases (alle 8) ✅ · Backward-Compat ✅ · i18n de/en/ar ✅ · Tests ✅.
Blocker: keine. Major: keine. Minor: Post-Publish-Regenerate nur im Create-Flow (Snapshot-Semantik dokumentiert).


---

# User Wallet — Liste (Credit-Card) + Store-Detailseite (QR · Switch · Stempeln · Punkte-Placeholder)

## Current Project State
- **Goal:** User-Wallet auf Kreditkarten-Niveau, kinderleicht: premium Kartenliste (1 Karte pro gefolgtem Laden) + Store-Detailseite (QR oben → Vollbild, System-Switch Stempeln↔Punkte, Stempeln-Pager mit Fortschritt/Hinzufügen/Entfernen/Einlösen/verdiente Belohnungen, Punkte = reservierter Placeholder). Audit+Build in einem Lauf, keine Stubs.
- **Tech Stack:** Flutter Web + Firebase. State: Provider/ChangeNotifier (kein Riverpod). Loyalty server-authored (Cloud Functions, europe-west1).
- **Important Architecture / Entscheidungen (in diesem Lauf):**
  1. **`userStoreLinks` NICHT als neue Top-Level-Collection** gebaut — `users/{uid}/walletCards/{merchantId}` IST das (user,merchant)-Link-Doc. Begründung: der Merchant-Scanner löst den Kunden bereits über `uid`+`mid` im QR-Pfad auf; eine Parallel-Collection hätte Doppel-State + neue Rules + neuen Scan-Lookup gebraucht → Risiko für DO-NOT-BREAK-Scanner. Pragmatisch & non-breaking.
  2. **Code-Format** auf diktierbares `A123B456` (Buchstabe+3Ziffern+Buchstabe+3Ziffern, **ohne I/O**), Anzeige `A123-B456`. QR-Payload-Struktur UNVERÄNDERT (`lokka://wallet/{uid}/{mid}/{code}`) → bestehender Scanner funktioniert weiter (er nutzt uid+mid, ignoriert den Code). Deterministisch aus `uid|mid`; Kollision wird **pro Nutzer-Wallet** mit Salt neu erzeugt (globale Eindeutigkeit nicht nötig, da Auflösung über uid+mid).
  3. **Zwei neue Callables** (Loyalty bleibt server-authored): `userAddStampCard` (legt stampProgress@0 idempotent an → „Stempelkarte hinzufügen") und `userRemoveStamp` (−1, nie <0, **klaut keine** earnedRewards). Beide nutzen `req.auth.uid` → Nutzer kann nur EIGENEN Fortschritt ändern. **Keine Rules-Änderung nötig** (Admin SDK umgeht die schon vorhandenen write:false-Sperren).
  4. **`StampCardVisual` um optionales `filledStamps` erweitert** = echte Fortschrittsanzeige (gefüllt vs. hohl) im Wallet, bei `null` weiter Voll-Vorschau (Merchant). Single source of truth bleibt EINE Render-Quelle.
  5. Switch-Logik aus **Merchant-Flags**: Stempeln = ≥1 aktive `stampCards`; Punkte = `featureConfigs/pointsSystems` enabled (Punkte-Logik kommt später → Placeholder). beide→Switch, eins→direkt, keins→freundlicher Hinweis.
- **Important Files (neu):** `features/user/wallet/utils/walletCode.dart`, `features/user/wallet/models/earnedRewardModel.dart`, `features/user/wallet/widgets/walletStampSection.dart`, `test/wallet_code_test.dart`. **(geändert):** `functions/src/{index,shared}.ts` (+2 Callables + ensureStampCard/removeOneStamp), `features/stamps/services/stampFunctionsService.dart` (+userAddStampCard/+userRemoveStamp), `features/stamps/widgets/stampCardVisual.dart` (+filledStamps), `features/user/wallet/widgets/walletCard.dart` (→ premium Credit-Card), `features/user/wallet/pages/userWalletDetailPage.dart` (komplett neu), `features/user/wallet/services/userWalletService.dart` (Code-Gen+Kollision, loadActiveStampCards, loadPointsEnabled, earnedRewardsByMerchantStream, Perks aus features), `features/user/wallet/models/walletCardModel.dart` (+merchantOrigin), `features/user/partners/pages/userPartnerStampsPage.dart` (per-Karte „Stempelkarte hinzufügen" → folgt Laden + userAddStampCard). **(gelöscht):** `features/user/wallet/widgets/walletDetailHeader.dart` (verwaist nach Detail-Redesign).
- **Backend / Firebase:** Keine neuen Collections. `userAddStampCard`/`userRemoveStamp` schreiben `users/{uid}/stampProgress/{cardId}` via Admin SDK. earnedRewards unverändert (server-only, client-read). walletCards: +`merchantOrigin`, Code im neuen Format, Perks aus `featuresPublic`.
- **Current Bugs:** keine offenen (analyze 0/0, build web läuft, 8 neue + 40 Tests grün).
- **Open Decisions:** (a) Keine globale code→link-Reverse-Lookup-Collection (Auflösung über uid+mid). (b) Punkte = nur Placeholder (Logik später, eigener Sub-Switch reserviert). (c) Merchant-Profil-Stempelseite: per-Karte-Add folgt zusätzlich dem Laden (sonst taucht die Karte nicht in der Liste auf).
- **Next Steps:** `firebase deploy --only functions` (die 2 neuen Callables scharf schalten) — Rules/Storage unverändert. Danach Geräte-Smoke-Test (QR-Scan Merchant→Kunde, Add/Remove/Claim).

## Work Log
### 2026-06-23 — Claude (Opus 4.8)
**Prompt Summary:** User-Wallet (Liste + Store-Detail) auf premium Credit-Card-Niveau bauen: diktierbarer Code als Rückgrat, QR (Vollbild) + Merchant-Scan-Loop, Stempeln (Pager/Fortschritt/Add/Remove/Einlösen/Belohnungen), Punkte-Placeholder, Feature-Flag-Switch, Edge-Cases. Audit+Build, keine Stubs.
**Answer / Action Summary:**
- **Audit:** Wallet-Liste + Detail + Scanner-Backend existierten bereits (calm UI, 5-stelliger Hash-Code, QR uid+mid+code, server-authored Stamps). Lücken: kein diktierbares Code-Format/Kollisionsschutz, langweilige Liste (kein Credit-Card-Look), Detail ohne QR-Vollbild/System-Switch/per-Karte-Add/Remove/echten Fortschritt, kein Punkte-Placeholder.
- **Spine:** `WalletCode` (A123B456, ohne I/O, deterministisch+Salt) + `userWalletService.addToWallet` nutzt ihn (stabil bei Re-Follow, pro-User-Kollision). QR-Format bewusst gleich gelassen → Scanner unverändert.
- **Backend:** `userAddStampCard` + `userRemoveStamp` (shared.ts `ensureStampCard`/`removeOneStamp`), tsc grün.
- **UI:** Credit-Card-Liste (Name–Stadt · Kategorie·Herkunft · Code · Pfeil, einheitlicher Lokka-Deep-Green-Verlauf, Tiefe). Detail neu: QR oben (Tap→Vollbild schwarz, hoher Kontrast) → Switch (SegmentedButton, nur bei beidem) → `WalletStampSection` (PageView 1/3, `StampCardVisual` mit `filledStamps`, Add/Remove/Einlösen, „Verdiente Belohnungen") → `_PointsPlaceholder` (reservierter Sub-Switch, „Bald verfügbar"). Merchant-Profil-Stempelseite: per-Karte-Add.
- **Edge-Cases:** nur Stempel→kein Switch; nur Punkte→Placeholder direkt; beides→Switch; keins→freundlicher Hinweis (Code funktioniert trotzdem); Remove nie <0 (Button @0 disabled), Belohnungen nie zurückgeholt; voll→Einlösen+Reset; lange Namen→ellipsis; leere Wallet→designter Empty-State; Add idempotent.
**Files Changed:** siehe „Important Files".
**Important Decision:** walletCards = Link-Doc (kein userStoreLinks); Code diktierbar A123B456; Auflösung über uid+mid (kein Reverse-Lookup); 2 server-authored Callables statt Client-Writes; keine Rules-Änderung.
**Verification:** `flutter analyze lib` = 0 Errors/0 Warnings (50 vorbestehende `unnecessary_underscores`-Infos). `flutter test` = 40 grün (inkl. 7 neue `wallet_code_test`) + 1 vorbestehend rot (`widget_test.dart`, Firebase-init). `functions tsc --noEmit` = grün. `flutter build web --release` = läuft (Dart kompiliert, analyze 0 Errors).
**Important Note:** `lib/features/merchant/feedManager/pages/merchantStampAdCreatePage.dart` ist **untracked** und stammt aus der vorherigen Stamp-Ad-Session; analysiert sauber (frühere 2 „MerchantFormSection"-Errors waren stale Analyzer-State nach Datei-Löschung, beim Re-Run weg). Nicht von dieser Aufgabe berührt.
**Next Useful Step:** `firebase deploy --only functions` für die 2 neuen Callables; Smoke-Test des Scan→Add/Remove/Claim-Loops.

### 2026-06-23 (Forts.) — Claude (Opus 4.8) — Wallet-Redesign + Add-Bug
**Prompt Summary:** Karten-Design: Cover-Bild des Merchants als Hintergrund (stark verdunkelt), QR oben rechts statt „lokka"-Wort. Detailseite nach Klick: nur QR zentriert (vergrößerbar) + unten zwei Buttons „Stempeln" / „Punktesystem" (führen weiter). Bug: „Hat nicht geklappt" beim Hinzufügen.
**Answer / Action Summary:**
- **Bug-Ursache:** „Stempelkarte hinzufügen" rief `userAddStampCard` (NEUE, noch nicht deployte Cloud Function) → not-found → generischer Fehler. **Fix:** Add-Abhängigkeit entfernt — wer einem Laden **folgt**, sieht automatisch ALLE aktiven Stempelkarten des Ladens (Fortschritt 0, bis der Merchant scannt). Kein Function-Call mehr nur fürs Anzeigen. Remove/Claim bleiben server-authored (brauchen Functions-Deploy) → klarere Fehlermeldung „Server gerade nicht erreichbar" bei unavailable/not-found/internal.
- **Karten-Design (`walletCard.dart`):** Cover-Bild als Hintergrund (`merchantCoverUrl`, neu im Model + `addToWallet`, merge → Re-Follow aktualisiert), darüber starker Dunkel-Verlauf (≈0.55→0.85 schwarz) für Lesbarkeit; **scannbarer QR oben rechts** (weiße Platte) statt Wortmarke; Fallback-Grün-Verlauf wenn kein Cover. `uid` an die Karte durchgereicht (QR-Payload).
- **Detailseite (`userWalletDetailPage.dart`) neu:** QR als Held zentriert (Tap→Vollbild), Code-Chip darunter, unten zwei `_NavTile`-Buttons „Stempeln"/„Punktesystem" → eigene Sub-Pages (`_StampsPage` = `WalletStampSection`, `_PointsPage` = Placeholder). Nicht-verfügbares System = ausgegraut + Hinweis-Snackbar (grey-out statt verstecken).
- **`WalletStampSection`:** „Hinzufügen"-Button raus; jede Karte zeigt Fortschritt (0/X bis gestempelt); bei 0 freundlicher QR-Hinweis statt Remove; Remove (>0) + Einlösen (voll) bleiben. **`userPartnerStampsPage`:** per-Karte-Add zurückgebaut (redundant zum „Zur Wallet hinzufügen"=Folgen).
- `userAddStampCard` (Callable + `stampFunctionsService`-Methode) bleibt als gültiger, idempotenter Server-Endpoint bestehen, aktuell **nicht** an UI verdrahtet (kein Stub; mögliche Zukunft: Karte erneut hinzufügen).
**Files Changed:** ~ `walletCardModel.dart` (+merchantCoverUrl), `userWalletService.dart` (cover schreiben), `walletCard.dart` (Cover+QR-Redesign +uid), `userWalletPage.dart` (uid durchreichen), `userWalletDetailPage.dart` (QR-Hub + 2 Buttons + Sub-Pages), `walletStampSection.dart` (kein Add, bessere Fehler), `userPartnerStampsPage.dart` (per-Karte-Add zurück).
**Important Decision:** „Add to Wallet" = dem Laden folgen (Client-Write, kein Function nötig) → Karten erscheinen automatisch. Loyalty-Mutationen (Stempeln/Entfernen/Einlösen) bleiben server-authored.
**Verification:** `flutter analyze lib` = 0 Errors/0 Warnings (50 vorbestehende Infos). `wallet_code_test` 7/7 grün. `flutter build web --release` läuft.
**Next Useful Step:** `firebase deploy --only functions` (für Remove/Claim + die ganze Loyalty-Kette). Cover erscheint für bereits gefolgte Test-Läden erst nach Re-Follow (oder neuem Follow).

### 2026-06-23 (Forts.) — Cover-Fix
Wallet-Karte lud bei schon gefolgten Läden kein Cover (denorm. Feld leer). Fix: `WalletCard` ist jetzt stateful und liest das Cover live aus `publicMerchants/{merchantId}.coverUrl` (Session-Cache `_walletCoverCache`, Fast-Path = denorm. Wert, Fallback = Grün-Verlauf). Cover setzt sich synchron in initState (kein setState dort) bzw. via setState nach dem Fetch. Datei: `walletCard.dart`.

### 2026-06-23 (Forts.) — Detailseite zum Store-Hub ausgebaut
User-Feedback: Vollbild-QR zu groß/„quatsch", Buttons unklar (kein Klick-Affordance), Infos + Quick-Actions fehlen. Umgebaut (`userWalletDetailPage.dart`):
- **Store-Header** oben: Cover (verdunkelt) + Logo + Name–Stadt + Kategorie·Herkunft (Infos wie auf der Wallet-Karte).
- **QuickActionBar** (shared): Route / Zeiten / Anrufen / Social — Merchant via `UserWalletService.loadMerchant` (publicMerchants), Handler lokal (url_launcher + Bottom-Sheets `_HoursSheet`/`_SocialSheet`, Hours-Format wie Partner-Seite). Fehlende Daten = ausgegraut.
- **QR-Hero**: Inline 200px, „Zum Vergrößern antippen". Vollbild-QR jetzt `(width*0.62).clamp(200,300)` statt fix 320 → nie mehr riesig; „Zum Schließen tippen" kleiner (12px, alpha 0.55).
- **Section-Tiles** statt kleiner Icon-Buttons: volle Breite, Icon+Titel+Untertitel+Chevron, „Stempeln" akzentuiert (primaryContainer) → klar als tippbar/öffnet Infos erkennbar; führen auf `_StampsPage`/`_PointsPage`. Stempeln grau wenn keine Karten.
- `loadMerchant` neu im Service. analyze lib = 0/0 (50 vorbestehende Infos).

### 2026-06-24 — Apple-Wallet-Stapel + „nur hinzugefügte" Stempel + Add-on-Merchant
User-Wünsche: (1) Wallet zeigt NUR vom User hinzugefügte Stempelkarten, nicht alle des Ladens. (2) Hinzufügen NUR auf der Merchant-Seite; nichts da → Hinweis, dortige Seite zu besuchen. (3) Punkte nur wenn Merchant es anbietet UND User folgt. (4) Klick auf Wallet-Karte öffnet KEINE neue Seite, sondern „wächst" (Apple-Style) zu einem swipebaren Karten-Stapel; eine Karte pro Stempel + eine pro Punktesystem, leicht überlappend/peekend.
Umgesetzt:
- **Datenmodell:** `walletCardModel.addedStampCardIds` (clientseitig, kein Function-Deploy). `UserWalletService.addStampCardToWallet` (arrayUnion), `loadAddedStampCardIds`, `walletCardStream` (live).
- **Add nur auf Merchant-Seite** (`userPartnerStampsPage`): per-Karte „Zur Wallet hinzufügen" → `addStampCardToWallet` (+ folgt Laden), Zustand „In deiner Wallet" wenn schon hinzugefügt. Kein Cloud-Function-Call (kein Deploy nötig).
- **Neuer `walletCardStack.dart`:** `openWalletCardStack` pusht eine transparente Route mit Scale+Fade (wächst aus der Karte). `WalletCardExpanded` = horizontaler PageView (viewportFraction 0.88 → Karten peeken/„minimal aufeinander") mit: Store-Karte (Cover+Logo+Name·Stadt·Kategorie·Herkunft + QR(Vollbild) + QuickActionBar Route/Zeiten/Anrufen/Social), je eine Karte pro HINZUGEFÜGTE Stempelkarte (Fortschritt + Entfernen/Einlösen + Belohnungen pro Karte), Punktekarte (nur wenn Merchant bietet & gefolgt), sonst Hinweis-Karte „Zur Partner-Seite". Bottom-Dots + „Wische ← →"-Hinweis.
- **Horizontal** statt vertikal: vertikaler PageView + scrollbare Karten = Gesten-/Overflow-Konflikt; horizontal ist robust und passt zu „rechts weiter swipen".
- **`userWalletDetailPage.dart` gelöscht** (durch Stapel ersetzt); `userWalletPage` öffnet jetzt den Stapel.
- analyze lib = 0/0 (50 vorbestehende Infos). build web läuft.

---

# Merchant „Kunden": Follower sehen + Detail beim Antippen

### 2026-06-24 — Claude (Opus 4.8)
**Prompt:** Unter „Kunden" im Merchant-Dashboard soll der Merchant sehen, wer ihm folgt (aufgezählt) + beim Antippen ein bisschen Info zum User.
**Audit:** `merchant/customers/`-Seite existiert (Liste+Filter), liest `merchants/{mid}/customers/{uid}` — aber **nichts im Code schrieb je diese Collection** (Dashboard zählte sie nur → immer 0). „Folgen" = `addToWallet` schreibt nur privates `users/{uid}/walletCards/{mid}`; Merchant darf `users/*` nicht lesen → Follower-Info muss denormalisiert werden.
**Lösung:** Beim Folgen registriert sich der User selbst als Follower-Record unter `merchants/{mid}/customers/{uid}` (die Collection, die Seite+Dashboard-Count schon erwarten). Karten tappbar → Detail-Sheet.
**Files Changed:** `firestore.rules` (+`match /customers/{customerUid}`: Merchant read/write + eingeloggter Nutzer NUR eigener Eintrag `customerUid==auth.uid && resource.data.uid==auth.uid` — **DEPLOY nötig**, sonst Self-Register denied, Folgen bleibt aber funktionsfähig da non-fatal); `userWalletService.dart` (`addToWallet`→`_registerFollower`: liest eigenes Profil, schreibt {uid,name,profileImageUrl,postalCode,interests,isFollower,usedSystems arrayUnion['follower'],followedAt preserve}, KEINE sensiblen Felder, try/catch non-fatal); `merchantCustomerModel.dart` (+isFollower/followedAt/profileImageUrl/postalCode/interests; 'follower' aus Pills gestrippt; followedAt-Fallback joinedAt); `merchantCustomersProvider.dart` (+Filter `followers`); `merchantCustomersPage.dart` (Karte `onTap`→Detail-Sheet, Avatar+„Folgt dir"-Pill+„seit"-Zeile+Chevron, Follower-Chip, `_CustomerDetailSheet` mit Avatar/Folgt-seit/letzter-Besuch/PLZ/Programme/Interessen); `firebasePaths.dart` (+`merchantCustomer(mid,id)`); i18n de/en/ar (+7 Keys); `test/merchant_customer_follower_test.dart` (5 Tests).
**Decision:** Denormalisierung (Self-Register) statt collectionGroup auf walletCards — letztere gäbe nur uid+joinedAt ohne Profil (kein `users/*`-Read) → „Info zum User" unmöglich. Privacy: nur Basis-Infos, die der User durchs Folgen freiwillig teilt.
**Verification:** analyze lib 0/0 (53 vorbestehende Infos, 0 in geänderten Dateien); 16 Tests grün (5 neu + 11); build web √.
**GO:** Code-Merge GO; Produktion CONDITIONAL — Pflicht: `firebase deploy --only firestore:rules` (sonst Self-Register denied; Bestands-Follower erscheinen erst nach erneutem Folgen).

---

# User-Gamification (Level/Treue/„Meine Erfolge") ENTFERNT

### 2026-06-24 — Claude (Opus 4.8)
**Prompt:** Alles mit Level + Nutzer-Treue (Meine Erfolge usw.) entfernen.
**Action:** Komplettes User-Gamification-Feature entfernt: gelöscht `gamification/{pages/meineErfolgePage, providers/userGamificationProvider, services/userGamificationService, models/gamificationModel}.dart` (leere Ordner entfernt). Aus `userProfilePage.dart` den `_HeroGamification`-Block (Level-Badge/Streak/Fortschrittsbalken → öffnete „Meine Erfolge") + Imports raus. Aus `userShellPage.dart` die `UserGamificationProvider`-Registrierung + Imports raus.
**Behalten (bewusst):** `gamification/widgets/celebration.dart` (generisches Konfetti-Overlay) + `_CelebrationToggleCard` in den Einstellungen — wird von `userStampPage` für Stempel-Abschluss-Feier genutzt, ist KEIN Level/Erfolg. Per-Merchant Stempelkarten/Punkte-Kacheln (Partner-Detail) bleiben unangetastet (das ist die Merchant-Loyalty, nicht die User-Gamification).
**Verification:** `flutter analyze lib` = 0 Errors / 0 Warnings, keine `gamification`-Restreferenzen mehr.

---

# Stempelstift einrichten — Path A (Web NFC write) + Test-Tap + UI-Swap

### 2026-06-24 — Claude (Opus 4.8)
**Prompt:** „Stempelstift einrichten"-Flow: 1 Button → Link auf NFC-Stick schreiben, Kunde tippt → genau 1 Stamp. Audit+Build, keine Stubs. (Prompt sagte „Riverpod" — Codebase ist **Provider/ChangeNotifier**, also Provider beibehalten.)
**Audit:** Backend-Core + NTAG424-Pfad (Path B) + QR-Stick-Setup + `/stamp`-Tap-Page existierten bereits (verifiziert, tsc grün, 8/8 crypto). FEHLTE: Path A (statischer signierter Link + Web-NFC-Write), Test-Tap-Verifizierung + Badge-Flip, der Single-Button-UI-Swap.
**Gebaut (Delta, baut auf bestehendem Core auf):**
- **Backend (`functions/`):** neu `src/crypto/staticToken.ts` (HMAC-SHA256(master, stickId|mid|cardId), 128-bit trunc, `newStickId`/`sign`/`parse`/`verify`, constant-time). 3 neue Callables in `index.ts`: `createStaticStick(cardId)` → sticks/{id} {type:'static'} + Token (reuse vorhandenen static-Stick → selber Token), `redeemStaticStamp(token)` → parse+verify HMAC → `loadLiveCard`+`assertWithinStore`+`applyStamps('nfc-static')` (Cooldown = Haupt-Replay-Schutz, kein Counter), `verifyStickBinding({cardId, token|picc+cmac|tagUid+provToken})` → setzt `verifiedAt` + spiegelt `card.stickVerifiedAt`. `setupStick` ergänzt: `type:'ntag424'` + Card-Mirror `stickType`/`stickVerifiedAt:null` (Badge resettet bis Test-Tap). 7 neue Self-Test-Checks (15/15). **`/stamp`-Spine unverändert**; Path A/B hängen an derselben `applyStamps`-Logik.
- **Flutter:** Web-NFC-Interop via `dart:js_interop` — `nfcService.dart` (Interface + conditional `nfcServiceWeb.dart`/`nfcServiceStub.dart`), `NDEFReader.write`/`scan`+`onreading`, `TextDecoder`, `AbortController`, defensiv (alles → graceful `NfcError`). `stampFunctionsService` +createStaticStick/redeemStaticStamp/verifyStickBinding (+`StaticStick`). `stickSetupFlow.dart` KOMPLETT NEU: Sheet für die **sichtbare Karte** (Name angezeigt) → NFC-supported? Path A „Stift beschreiben" (createStaticStick→`${Uri.base.origin}/s/<token>`→`nfc.writeUrl`) + Path B; sonst nur Path B (QR-bind). **Test-Tap:** NFC-Read→URL→Token/picc+cmac→verify (Android) ODER QR-Re-Scan (iPhone/Desktop, via tagUid+provToken). Badge flippt NUR nach Erfolg. `stampTapPage` generisch: +`token` → `/s/:token`-Route → `redeemStaticStamp` (kein Offline-Queue für static, da kein Counter). `stampCardModel` +`stickType`/`stickVerifiedAt`/`stickVerified` (server-managed, NICHT in `toMap` → Merchant-Edit clobbert sie nie). `merchantStampCard` Badge 3-state (verbunden ✓ / Test-Tap nötig / kein Stift).
- **UI-Swap (`merchantStampsPage`):** „Einstellungen" RAUS (+`_showStampSettings`/`_SettingRow`), Row→**ein** full-width „Stempelstift einrichten"; View jetzt stateful, trackt sichtbaren Pager-Index → Setup zielt auf sichtbare Karte. `/s/:token`-Route in appRouter.
- i18n de/en/ar (+~26 `merchant.stick.*` inkl. `nfc.*`-Fehler + `wrong-card`).
**Important Decision:** Provider (kein Riverpod). Statischer Pfad = HMAC-Link, Sicherheit server-seitig (verify+login+geofence+silent cooldown), kein Chip-Counter. Badge-State server-authored (sticks server-only `read,write:if false`, gespiegelt auf öffentlich lesbare Card). **KEIN firestore.rules-Deploy nötig** (keine neue Collection/Zugriffsart). Test-Tap auch ohne Web-NFC (QR-Re-Scan-Fallback, provToken-verifiziert).
**Verification:** functions `tsc` √ + 15/15 self-test; `flutter analyze lib` 0/0 (51 vorbestehende Infos); 21 Dart-Tests grün; `flutter build web --release` √ (js_interop kompiliert).
**Deploy nötig (extern):** `firebase deploy --only functions` (3 neue Callables + setupStick-Update). Rules/Storage NICHT nötig. Master-Key-Secret schon gesetzt (NTAG-Pfad). Web-NFC nur Android-Chrome + HTTPS.

## GO / NO-GO — Stempelstift einrichten
**GO für Code-Merge; CONDITIONAL-GO Produktion** — einziger Pflicht-Schritt: `firebase deploy --only functions`.
Checkliste: UI-Button-Swap (Einstellungen raus, 1 Button, sichtbare Karte) ✅ · Setup Path A (Web-NFC-Write) ✅ · Path B (QR-bind vorprovisioniert) ✅ · statischer signierter Link + `/stamp`-Gate (verify+login+geofence+cooldown) ✅ · Test-Tap→Badge-Flip+`verifiedAt` ✅ · Edge-Cases (NFC-unsupported→Path B, write-fail/permission graceful, Test-fail→kein Flip, replay→cooldown, location-off→skip, re-bind→reuse/overwrite, paused/archived→friendly, voll→convert, Multi-Card→sichtbare) ✅ · NTAG-Pfad unverändert ✅.
Blocker: keine. Major: keine. Minor: iPhone-Test-Tap nutzt QR-Re-Scan (echtes SUN-Tap braucht NFC-Reader = Android); Path-A-Tap hat keinen Offline-Queue (bewusst — kein Counter).
