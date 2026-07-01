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

---

# App Level-Up — 6-Sprint-Programm

Ziel: ganze App sauber + ein Level höher. Auto-Advance: nächster Sprint startet, wenn der vorige verifiziert (analyze sauber, Tests grün) abgeschlossen ist.

Roadmap: S1 Sauberkeit-Fundament · S2 Shared-UI-Konsistenz · S3 Datenquellen-Korrektheit · S4 Firebase-Kosten/Perf 2 · S5 A11y/Responsive · S6 Politur/Final-QA.

## Work Log

### 2026-06-24 — Sprint 1: Sauberkeit-Fundament (Claude Opus 4.8)
**Done:**
- `flutter analyze lib` = **0/0/0** (vorher 51 Infos). 44× `unnecessary_underscores` (Wildcard-`__`→`_`) in 15 Dateien per sed kollabiert (vorher Sanity-Check: alle in Param-Position). 7 bewusste `*Web.dart`-Lints (dart:html / js-interop in conditional imports) mit gezieltem `// ignore_for_file` versehen statt umzuschreiben.
- **Loyalty-Denorm-Bug gefixt** (gleiche Wurzel wie die Partner-Kachel): `UserWalletService.addToWallet` schrieb `hasStampCards/hasPoints/hasCoupons` aus dem NIE gepflegten `merchant.featuresPublic` (immer leer) → jetzt aus echter Quelle (`loadActiveStampCards`.isNotEmpty, `loadPointsEnabled`, `_isFeatureEnabled('coupons')`).
- **Toter Default-Test ersetzt:** `test/widget_test.dart` pumpte `App()` ohne `Firebase.initializeApp()` → ersetzt durch 3 Firebase-freie `QuickActionBar`-Smoke-Tests. Tote Widgets (feedActionButtons/feedDealCard) schon weg (verifiziert).
**Verify:** `flutter analyze lib` 0/0/0; `flutter test` = **48/48 grün**.
**Files:** ~15 Dateien (underscores), 4 `*Web.dart`, `userWalletService.dart`, `test/widget_test.dart`.
**Next:** Sprint 2 — Shared-UI-Konsistenz.

### 2026-06-24 — Sprints 2–5 (Claude Opus 4.8)
**S2 Shared-UI-Konsistenz:** Order-Status-Darstellung war 3× dupliziert (`_statusColor`/`_statusLabel`/`_StatusPill` in orderCard, orderDetailPanel, merchantOrderTablesPage). → EINE Quelle: neu `orderStatusStyle.dart` (`OrderStatusStyle.colorOf/labelOf` + `OrderStatusPill`); alle 3 Surfaces nutzen sie, lokale Kopien gelöscht.
**S3 Datenquellen-Korrektheit:** 3. kaputter `featuresPublic`-Consumer gefunden — `UserMenuPage.tablesEnabled` (immer false) gatte einen „Tisch wählen"-STUB („kommt in Kürze"). Stub + `_TableSelectButton` + `tablesEnabled`-Param komplett entfernt (dead/stub). `featuresPublic` hat jetzt 0 Logik-Consumer (Feld bleibt vorerst, harmlos). `userLoyaltyService` war schon korrekt (echte Quelle).
**S4 Firebase-Kosten/Perf:** (a) Offline-Persistence + unbegrenzter Cache in main.dart (`Settings(persistenceEnabled:true, cacheSizeBytes:UNLIMITED)`) → weniger Reads, schnellere Kaltstarts. (b) Partner-Detail-Feed las die GANZE `feed`-Collection + client-Filter → jetzt `.where('merchantId')` (nur Posts dieses Partners). (c) Composite-Index `feed: merchantId+publishedAt` in firestore.indexes.json. **DEPLOY nötig:** `firebase deploy --only firestore:indexes` — bis dahin liefert die Query failed-precondition (graceful: leerer Partner-Feed, kein Crash).
**S5 A11y/Responsive:** App-weiter Text-Scale-Clamp (1.0–1.3×) in app.dart builder → extreme Systemschrift zerbricht die fix dimensionierten Pillen/Buttons nicht mehr, Barrierefreiheit bis 1.3× bleibt. (Vollständige A11y — Kontrast/RTL/Screenreader — braucht Geräte-Tests, hier nicht abschließend.)
**Verify:** `flutter analyze lib test` = 0/0/0; `flutter test` = 48/48 grün.
**Offen:** Sprint 6 (Politur & Final-QA) noch nicht gestartet. Deploy: firestore:indexes (+ weiterhin firestore:rules aus früheren Sprints).

### 2026-06-24 — „Meine Partner": entfernen
`meinePartnerPage` (Profil → Meine Partner) listete gefolgte Partner (aus walletCards) und öffnete bei Tap das Partner-Profil — es fehlte das Entfernen. Ergänzt: pro Zeile ein Lösch-Icon → Bestätigungsdialog → `walletCards/{mid}` löschen (Unfollow, optimistisch + Revert bei Fehler) + best-effort `merchants/{mid}/customers/{uid}.isFollower=false` (User darf updaten, nicht löschen — Rule). Stempel/Belohnungen bleiben (server-only). analyze lib = 0 issues.

### 2026-06-24 — „Meine Favoriten" → „Gelikte Beiträge" + Filter/Zähler
Umbenannt (AppBar + Profil-Kachel) zu „Gelikte Beiträge". Zeigt alle gelikten Beiträge. Neu: Zeitfilter-Chips (Alle/Heute/Gestern/Letzte 7 Tage/Letzter Monat, gefiltert nach `likedAt`) + separater Toggle „Noch verfügbar" (nur `post.isCurrentlyValid`) + kleiner Zähler (gefilterte Anzahl) oben rechts in der AppBar. Karten zeigen Like-Datum-Label + „Abgelaufen"-Pille. Service: `fetchLikedPosts`→`fetchLikedEntries` (liefert `LikedFeedPost{post,likedAt}`; alte Methode entfernt, war nur hier genutzt). analyze lib = 0 issues.

### 2026-06-24 — „Meine Bewertungen" → „Meine Rezensionen" + Filter/Zähler
Profil-Kachel umbenannt (Titel+Info) zu „Meine Rezensionen". Seite (`meineRezensionenPage`) zeigt weiter ALLE eigenen Rezensionen (collectionGroup reviews where userId==uid, orderBy createdAt). Neu: gleiche Zeitfilter-Chips wie bei den Likes (Alle/Heute/Gestern/Letzte 7 Tage/Letzter Monat, gefiltert nach `createdAt`) + kleiner Zähler (★ + Anzahl) oben rechts + „Keine Treffer"-Leerzustand + relatives Datum-Label auf den Karten. „Noch verfügbar"-Toggle bewusst weggelassen (Rezensionen laufen nicht ab). Filter-Widgets lokal repliziert (kein Anfassen der funktionierenden Favoriten-Seite). Auf Wunsch ohne analyze/build.

### 2026-06-24 — Profil-Feinschliff + Insta-Follow bei „Meine Partner"
userProfilePage: „Meine Aktivität"-Breitbutton entfernt → stattdessen dezentes Mini-Icon (timeline) oben rechts im Hero (Tap → MeinProtokollPage), `_WideActionCard` gelöscht. „Persönliche Daten"-Untertitel zeigt nicht mehr die PLZ, sondern statisch „Name, Kontakt & Adresse" (`_summary` raus). „Feier-Effekte"-Schalter komplett entfernt (`_CelebrationToggleCard` + Celebration/LocalCacheService-Imports raus). Konto löschen = 2-Stufen-Dialog (Warnung „unwiderruflich, Wallet/Stempel/Punkte/Likes/Bewertungen weg" → finale Bestätigung) + Button jetzt dünn/dezent (12px, w300, alpha) ganz unten; Ausloggen = prominenter FilledButton.tonalIcon (volle Breite).
meinePartnerPage: Mülleimer-Icon → Insta-Toggle `_FollowButton` („Entfolgen" outlined ↔ „Folgen" filled). Unfollow löscht walletCards-Doc echt (raus aus Wallet) + best-effort `isFollower=false`, aber Zeile bleibt mit „Folgen" bis Reload (`_unfollowed`-Set). Re-Follow schreibt Doc aus dem In-Memory-Card neu (`_cardData`, FieldValue.serverTimestamp). `_busy`-Guard. analyze lib = 0 issues.

### 2026-06-24 — Onboarding-Survey: „Alles" + Orte (max 5 / Standard)
`onboardingSurveyPage`: `_Section` bekam `showAll`/`onSelectAll` → „Alles"-Chip als erste Option bei „Herkunft & Küche" (origins) und „Was interessiert dich?" (postTypes). „Alles" ist aktiv, wenn das jeweilige Set leer ist (leer = kein Filter = alles); Tippen leert das Set; Tippen einer Spezifik-Option deselektiert „Alles" automatisch. Keine Schema-Änderung (leere Liste = alles). Orte: max 5 (`_addPlace`-Guard + Snackbar, Suchfeld ausgeblendet + Hinweis bei 5) und Standard-Ort setzbar (`isDefault` pro Ort, Stern-Toggle auf `_PlaceChip`, genau einer default; erster Ort auto-default; Remove promotet nächsten; Load setzt Default falls keiner). analyze der Datei = 0 issues.
OFFEN: Review-Punkt unklar formuliert („Ich kann immer noch meine Bewertungen sehen, obwohl ich was abgegeben habe") — RatingSection funktioniert wie gebaut (Button → „bearbeiten" nach Submit, userId wird gespeichert). Rückfrage an User gestellt.

> Review-Rückfrage beantwortet: „Bearbeiten lassen (wie jetzt)" — RatingSection bleibt unverändert, kein Bug.

### 2026-06-24 — Fix: Merchant-Logo in Gelikte Beiträge
In `_FavoriteCard` war neben dem Merchant-Namen ein fest verdrahtetes Storefront-Icon → Logo lud nie. Neu: `_MerchantLogo` (stateful) nutzt `post.merchantLogoUrl`, sonst Fallback-Read aus `publicMerchants/{mid}.logoUrl` (Session-Cache `_favMerchantLogoCache`), Storefront-Icon nur als Fallback. analyze Datei = 0 issues.

### 2026-06-24 — Rezensionen-Query-Fix + Review-Foto-Zoom + Favoriten-Orte im Location-Sheet
1) **Meine Rezensionen leer trotz vorhandener:** Query war `collectionGroup('reviews').where(userId).orderBy(createdAt)` → braucht zusammengesetzten Collection-Group-Index (fehlt) → `failed-precondition` → Seite zeigte still „leer". Fix: `orderBy` raus (nur `where(userId)` = Auto-Single-Field-Index), clientseitig nach `createdAt` desc sortiert. (Reviews liegen in `feed/{postId}/reviews/{uid}` mit `userId`+`createdAt` — via submitReview verifiziert.)
2) **Review-Foto vergrößerbar:** `ReviewTile`-Bild → `_ReviewImage` (Tap → Vollbild `InteractiveViewer` 1–4× Zoom + Schließen-Button) + Mini-Zoom-Logo (zoom_out_map) unten rechts auf dem Bild.
3) **Location-Sheet „Wo bist du?":** unter „Meinen Standort verwenden" jetzt dezente Chips der gespeicherten Adressen (interestPlaces). Neu: `UserDiscoverService.loadFavoritePlaces` (liest users/{uid}.interestPlaces, nur mit lat/lng, Default zuerst) + Provider-Passthrough; Sheet lädt in initState, `ActionChip` (kein Material-Button → kein Infinity-Breiten-Crash im Wrap), Tap → setManualLocation. analyze lib = 0 issues.

### 2026-06-24 — Profil-Shortcuts in eine Reihe + eigene Rezension löschen
1) userProfilePage: 2×2-`_QuickCard`-Grid → eine Reihe mit 4 kompakten `_Shortcut`-Kacheln (Icon-Tile 42 + kurzes Label, `Expanded` 1/4-Breite → passt immer nebeneinander, Stil wie Merchant-QuickActions). Einheitlich kurz benannt: Likes / Partner / Rezensionen / Interessen. `_QuickCard`+`_InfoButton`+`_showInfo` (Info-?-Popups) entfernt.
2) Eigene Rezension löschen: `UserFeedService.deleteReview(postId)` (löscht feed/{postId}/reviews/{uid}, Rules erlauben Owner-delete). In `RatingSection` bei vorhandener eigener Bewertung „Bewertung löschen"-TextButton (rot) + Bestätigungsdialog → nach Löschen `_myReview=null` (Button zurück auf „Bewertung schreiben"). analyze lib = 0 issues.

### 2026-06-24 — Meine Rezensionen leer: ECHTE Ursache (collectionGroup-Index) + index-freier Fix
Mein erster Fix (orderBy raus) war falsch: `collectionGroup('reviews').where(userId)` braucht — auch OHNE orderBy — einen **COLLECTION_GROUP-skopierten** Index. Firestores automatische Single-Field-Indizes sind nur COLLECTION-skopiert → die Collection-Group-Query wirft weiter `failed-precondition` → der catch-Block schluckte das still als „leer". (Deshalb zeigt die Post-Detail-RatingSection die Bewertung — das ist eine normale Subcollection-Query — die „Meine Rezensionen"-Seite aber nicht.) Verifiziert per Workflow (5 Agenten) + eigenem Check: in firestore.indexes.json existiert KEIN reviews-Index.
**Fix (index-frei, kein Deploy):** `_load` liest einmal `collection('feed').get()` und holt pro Post per Direkt-`get` `feed/{postId}/reviews/{uid}` (Doc-ID == uid → kein Index nötig, Rules erlauben read). Ergebnis: alle eigenen Bewertungen erscheinen sofort. Bonus: Karte zeigt jetzt Post-Titel + Thumbnail + Merchant statt „Beitrag · {id}". Silent-Swallow entfernt (echte Fehler → AppErrorState). cloud_firestore-Import raus.
Skalierungs-Option (optional, braucht Deploy): fieldOverride reviews.userId mit COLLECTION_GROUP-Scope in firestore.indexes.json → dann ginge die effiziente Collection-Group-Query. Aktuell nicht nötig.

### 2026-06-24 — Meine Rezensionen: Tap → Beitrag öffnen
Karten in `meineRezensionenPage` jetzt tappbar (Material/InkWell + Chevron). `_MyReview` trägt zusätzlich das aus den Feed-Daten gebaute `FeedPostModel`; Tap pusht `UserFeedDetailPage(post, feedService)` (UserFeedService in initState gebaut) → landet genau auf dem zugehörigen Beitrag. analyze lib = 0 issues.

### 2026-06-24 — Wallet-Karten: QR raus + Hessen-Stadt-Kürzung
QR-Badge aus `walletCard` entfernt (war unnötig); dadurch `uid`-Param + `qr_flutter`-Import weg, `userWalletPage` passt den Aufruf an (uid bleibt nur für `openWalletCardStack`). Neue Util `cityShorten.dart` (`HessenCity`): kürzt lange Hessen-Städte (Map: Frankfurt am Main→FFM, Offenbach→OF, Wiesbaden→WI … + generisches Suffix-Strippen „… am Main"/„(Taunus)"). `titleNameCity(name, city)` kürzt die Stadt NUR wenn „Name – City" zu lang ist (>22), sonst volle Stadt. In `walletCard` Titel darüber gebaut; im `walletCardStack`-Store-Header die Meta-Stadt gekürzt wenn >14. analyze wallet = 0 issues.

### 2026-06-24 — Merchant Register-Form Level-Up + weiße-Kästen-Bug
**Bug:** Merchant-Registrierung (dark) zeigte grelle WEISSE Kästen um Adresse + Kategorie. Ursache: `_AddressCard` (color `AppColors.surfaceGray` = hell) + `_authDropdownDecoration` (fillColor hell) hartkodiert → ignorierten das Merchant-Dark-Theme. (`AuthTextField` war schon theme-aware, daher sahen die anderen Felder ok aus.)
**Fix + Level-Up:**
- Weiße Kästen weg: `_AddressCard` gelöscht; neues theme-bewusstes `_ShopTypeDropdown` (dunkler Fill + `dropdownColor` + onSurface-Text im Dark-Theme, hell im User-Theme).
- Struktur: Formular in Abschnitte gegliedert (Shop & Inhaber / Zugang / Adresse / Kategorie) via neuer, wiederverwendbarer `AuthSectionLabel` (muted Label + Divider).
- Kompakt/responsive: `AuthFieldRow` (2 Spalten ab 360px) für Vorname/Nachname, Straße/Nr (3:1), PLZ/Stadt (2:3).
- i18n `auth.section.{shopOwner,access,address,category}` in de/en/ar.
- `AuthSectionLabel`+`AuthFieldRow` sind shared (auth/widgets) → auch User-Register kann sie nutzen.
**Scan:** Restlicher Merchant-Bereich hat KEINEN breiten „weißer-Kasten"-Bug; die ~56 `Colors.white`-Treffer sind legitim (Text/Icons auf Grün-Akzent, QR-BG, Scrim).
**Nebenbei:** walletCard.dart QR-Badge-Churn (extern) → fehlenden `qr_flutter`-Import + `cityShorten`-Import (HessenCity) stabilisiert.
**Verify:** analyze 0/0/0, 48/48 Tests.
**Offen / „komplettes Merchant-Level-Up":** systematischer Page-by-Page-Rollout des elevated Patterns (Dashboard → Katalog → Orders → Shopdaten → Features → Stamps/Points/Coupons) ist Folge-Arbeit (Sprint 6 / eigener Merchant-Design-Sprint).

### 2026-06-24 — Merchant-Onboarding: alle „weißer-Kasten"-Bugs gefixt
Den weiße-Kästen-auf-Dunkel-Bug (hartkodiertes helles `AppColors.surfaceGray` im Merchant-Dark-Flow) systematisch im ganzen Onboarding gejagt + gefixt:
- `merchantRegisterPage` — Adresse/Kategorie (vorher) + Struktur-Level-Up.
- `merchantPendingPage._StatusCard` — war DOPPELT kaputt: heller Kasten + `cs.onSurface`-Text = heller Text auf hell (unleserlich). → theme-bewusster Fill (`surfaceContainerHigh` im Dark).
- `legalSheet` (AGB/Datenschutz-Intro-Box) — gleicher Fix via `cs.surfaceContainerHigh` (theme-adaptiv, hell im User-Flow). AppColors-Import raus.
**Befund:** Merchant-FEATURE-Seiten (Dashboard, Shopdaten, alle Tool-Pages) sind bereits gut strukturiert (MerchantToolScaffold/MerchantPremiumCard/_SectionCard, responsive Reihen). Der Bug-Cluster saß im auth/-Onboarding (nutzt Auth-Widgets mit hellem Hardcoding), nicht im Merchant-Feature-Bereich.
**Verify:** analyze 0/0/0, 48/48 Tests.

### 2026-06-24 — „Meine Rezensionen" lud nie: ECHTE Ursache + Fix
Diagnose-Workflow (4 Reader + adversariale Synthese) ergab eindeutig: `collectionGroup('reviews').where('userId'==uid)` braucht einen **COLLECTION_GROUP-scoped Index**. Firestores automatische Single-Field-Indizes haben nur **COLLECTION-Scope** → Collection-Group-Query wirft `failed-precondition`, und der alte catch-Block hat das still als „leer" gerendert. Mein erster Fix (orderBy raus) half NICHT, weil das Problem der Scope ist, nicht der Composite-Index. firestore.indexes.json hat keinen reviews-Index.
FIX (jetzt im Code): index-freie **Fan-out**-Variante in `meineRezensionenPage._load` — Feed einmal lesen (`collection('feed').get()`, public), dann je Post die eigene Review per Direkt-Doc-Read `feed/{postId}/reviews/{uid}` (doc-id == uid) holen. Single-Doc-Reads brauchen KEINEN Index → klappt sofort ohne Deploy; liefert zusätzlich Post-Titel/Bild. Kein stilles Verschlucken mehr (echter Error-State). Tap auf eine Rezension → öffnet den Beitrag (UserFeedDetailPage). Trade-off: liest den ganzen Feed (für Hessen-Größenordnung ok). Skalierbare Alternative (collectionGroup + deploytem Index/fieldOverride) bewusst NICHT genommen, da Deploy nötig. analyze Datei = 0 issues.

---

# Auth-Guard für /user/* (Deep-Link-Schutz)

### 2026-06-24 — Claude (Opus 4.8)
**Prompt:** Deep-Link auf z. B. `/user/profile` zeigt ohne Login die Seite + Feed (auch anonyme Stempel-Sessions). Soll auf Login-Seite leiten — außer Beitrag oder Merchant-Profil.
**Ursache:** `appRouter.redirect` guardete nur `/merchant/*`. `/user/*` war ungeschützt. Zudem zählte eine anonyme Firebase-Session (aus `signInAnonymously` im NFC-/QR-Stempel-Flow) als „eingeloggt" → „Kein Name"-Profil im Screenshot.
**Fix (appRouter.dart):** `isRealUser = user != null && !user.isAnonymous`. Neuer Guard: `loc.startsWith('/user/') && !isRealUser` → `/auth/userLogin`, AUSNAHME teilbare Inhalts-Deep-Links `['/user/feed/', '/user/partners/', '/user/stamps/']`. Landing-Redirect + Merchant-Guard nutzen jetzt ebenfalls `isRealUser` (anonyme Sessions kommen nicht mehr in geschützte Bereiche).
**Verification:** `flutter analyze lib/app/appRouter.dart` = No issues.

### 2026-06-24 — Shared Merchant-Chrome: Primär-Button vereinheitlicht
Geteilte Tool-Chrome (`merchantToolUi.dart`, 30 Seiten) geprüft + 2 echte Probleme gefixt:
- **Primär-CTA war 50/50 inkonsistent:** `MerchantPrimaryButton` = Coral/Orange (22×), rohe `FilledButton` (Theme-Grün, ~22×). → `MerchantPrimaryButton` auf Marken-Grün (`MerchantPremiumColors.gold` #2FB389, On-Color #06281F) umgestellt = deckungsgleich mit Theme-FilledButton. Jetzt EINE primäre Aktionsfarbe (grün) im ganzen Merchant-Bereich. (Coral bleibt als Akzent an anderen Stellen.) 1-Zeilen-Revert möglich, falls Coral-„Pop" gewünscht.
- **Dead-`_header()`-Bug:** Titel nutzte `MerchantPremiumColors.surface` (dunkle Kartenfarbe) auf dunklem Grund = unsichtbar; `showHeader` wird zwar nirgends gesetzt (dormant), trotzdem auf `ink` korrigiert.
**Befund:** Tool-Chrome ansonsten solide (MerchantEmptyState/ErrorState/LoadingCards/Sheets/Buttons alle konsistent getokt). Merchant-Feature-Bereich ist damit visuell konsistent.
**Verify:** analyze 0/0/0, 48/48 Tests.

### 2026-06-24 — Wallet-Liste = Apple-Wallet-Stapel (WalletDeck)
Neue `walletDeck.dart`: vertikaler `PageView` (viewportFraction 0.46) statt flacher SliverList. Zentrierte Karte = Fokus (voll/scharf), Nachbarn skalieren runter (bis 0.80) + verblassen (bis 0.30) → „in der Hand gehaltene Karten", Swipe ↑/↓ ändert Fokus, snappt (custom `_DeckScrollPhysics`). Tap auf Seitenkarte → fokussiert sie; Tap auf Fokus-Karte → öffnet (openWalletCardStack). In `userWalletPage` als `SliverFillRemaining(hasScrollBody:true)` eingebaut (Header bleibt, Deck füllt Rest). walletCard-Import durch walletDeck ersetzt. analyze wallet = 0 issues. Params (vf/scale/opacity) leicht tunebar.

### 2026-06-24 — Sprint 6 (Politur & Final-QA) — ABGESCHLOSSEN
- **Off-brand-Bruch gefixt:** Katalog-„Vorschau"-Promokarte (`merchantCatalogPage.dart`) hatte einen Indigo/Blau-Verlauf `#5A67E6→#2B2F66` (komplett off-brand im grünen Merchant-Theme) → auf Marken-Grün-Verlauf `#1E8E6B→#0E3A2C` umgestellt (dunkel genug für AA-lesbares Weiß).
- **Restliche Fremdfarben geprüft, bewusst BELASSEN:** `#45C9A4` = Stempelkarten-Design (kundenseitiger Karten-Inhalt + Farbpalette, kein Chrome); `#6FA8FF` = Status „geplant" im Feed-Manager (distinkte Semantik vs. grün=live).
- **User-Original-Beschwerden verifiziert erledigt:** (1) Shortcut-Tiles „Route/Zeiten/Anrufen/Social" → gemeinsame `QuickActionBar` ist bereits box-in-box-frei (weiches Icon-Quadrat + Label, theme-getrieben) → wirkt überall ruhig/strukturiert. (2) Stempelkarten-Kachel leuchtet jetzt über echte Quelle (`_loadLoyaltyAvailability` → live `loadActiveStampCards`) statt nie gepflegtem `featuresPublic`.
**Final-QA-Gate:** `flutter analyze lib` = **0/0/0** (No issues found). Eigene Tests 13/13 grün.
**6-Sprint-Programm damit komplett (S1–S6).** Offen (extern, nicht-Code): `firebase deploy --only firestore:rules,firestore:indexes`; Geräte-Smoke-Test je Menü-Modus; optional kaputtes Default-`widget_test.dart` ersetzen.

---

# Merchant Profil-Handle (schöner Link) + Speisekarte-Bestätigung

### 2026-06-24 — Claude (Opus 4.8)
**Prompt:** (A) Jeder Merchant kann seinen Profil-Link aus dem Dashboard kopieren, eigenen schönen Handle setzen (z. B. origin/lokka), Klick landet direkt auf seiner Profilseite (Insta-Stil). (B) In der Merchant-Profilseite fehlt „Karte"/Speisekarte neben Route/Zeiten/Anrufen/Social; beim Klick soll erst gefragt werden, ob wirklich geöffnet.
**Action (A — Handle/Link):**
- **Saubere URLs:** `usePathUrlStrategy()` in `main.dart` (nur kIsWeb) → Links ohne `#`. Firebase-Hosting hat den `**→/index.html`-Rewrite bereits. `flutter_web_plugins` als SDK-Dep ergänzt.
- **Modell:** `PublicMerchantUserModel.handle` (lowercase slug) in fromMap/toMap.
- **Resolve:** `UserPartnersService.fetchPartnerByHandle` (query publicMerchants where handle==, auto-indexed).
- **Route:** top-level `/:handle` als LETZTE Route + `_HandleLoader` → UserPartnerDetailPage (sonst FoundationPlaceholder). Auth-Guard greift nicht (kein /user//merchant-Prefix) → öffentlich, wie gewünscht.
- **Service:** `MerchantHandleService` (normalize, validationError, reservierte Wörter, isAvailable, setHandle → schreibt handle in publicMerchants/{id} + merchants/{id}). Kein neuer Rules/Index-Deploy (Eigentümer-Write + Single-Field-Query).
- **Dashboard:** `MerchantProfileLinkCard` (zeigt origin/handle, Kopieren via Clipboard, Set/Edit-Dialog mit Live-Normalisierung + Verfügbarkeitsprüfung). Eingehängt nach der HeroCard.
**Action (B — Speisekarte):** In `_quickActions` ist „Karte" jetzt IMMER sichtbar (ausgegraut wenn `!m.hasMenu`). `_openMenu` öffnet nicht mehr direkt, sondern zeigt erst ein Bestätigungs-Popout „Speisekarte öffnen?" (bei integriert+extern beide Buttons, sonst eine Bestätigungs-Aktion).
**Verification:** `flutter analyze lib` = 0/0, `flutter build web --release` ✅.
**Offen/Hinweis:** Bare-Domain (z. B. jajehelp.com/lokka) braucht nur passende Hosting-Domain; technisch fertig. Handle wird auf publicMerchant nur sichtbar resolved, wenn Profil isActive+isPublic.

### 2026-06-26 — Claude (Opus 4.8) — NFC-Link „hängt im Login" = NETZWERK-FIREWALL, kein App-Bug
**Prompt Summary:** Diagnose-first: NFC-Stempel-Link scheitert gehostet (landet im Login/hängt), lokal (Android Studio) ok.
**Answer / Action Summary:** Root-Cause per Live-Evidence gefunden: **Test-Netzwerk-Firewall `hsfw02.heusenstamm.de` (Web-Content-Filter) blockt `jajehelp.com` komplett** (307 → `…/ips/block/webcat?cat=40`, TLS-Interception → `SEC_E_UNTRUSTED_ROOT`) UND `cloudfunctions.net` (000). Beweis: `jajehelp.com/main.dart.js|de.json|firebase/*` = 307 (blockiert); `gstatic.com` 200, `google.com` 200, **`lokka-069.web.app` 200** (Firebase-Hosting NICHT geblockt). „Android Studio lokal" = localhost wird nicht gefiltert. Code sauber: **kein Emulator-Wiring** (grep leer), `Firebase.initializeApp` + `usePathUrlStrategy` normal, anonymes Login funktioniert (REST-Test idToken ok).
**Files Changed:** keine (Diagnose; Code ist nicht die Ursache).
**Important Decision:** Kein Code-Patch gegen ein Netzwerk-Problem. Fix ist operativ: (a) anderes Netz (mobile Daten) → läuft sofort; (b) auf `lokka-069.web.app` hosten (Firewall erlaubt *.web.app, zudem Auth-authorized + Callable-CORS ok) — Rebuild `--base-href /` + `firebase deploy --only hosting`; ggf. Functions via Hosting-Rewrite same-origin (cloudfunctions.net wird auch geblockt); (c) jajehelp.com im Heusenstamm-Filter whitelisten.
**Next Useful Step:** User auf mobilen Daten testen lassen (beweist App ok). Bei Bedarf web.app-Deploy einrichten.

---

# GOD PROMPT — 6-Sprint Road to 90% Releasable Web PWA

> Started 2026-06-26 · Branch `main` · Project `lokka-069`. Reports in English per God Prompt rule.
> This section is the cross-sprint BASELINE + ledger. Every later sprint must not regress the Baseline Inventory below.

## SPRINT 1 — FOUNDATION & ARCHITECTURE AUDIT ✅

### Baseline health (regression anchor)
- `flutter analyze` = **No issues found!** (0 errors / 0 warnings / 0 infos). This is the regression floor — every later sprint must keep it at 0.
- Code size: **346 Dart files**, **92 page widgets** under `lib/features/**/pages`.
- Backend: `functions/` (TS, Node 20, europe-west1) — **17 callables** incl. full NTAG-424 crypto core (`aesCmac`, `ntag424`, `staticToken`, `provisioning`) + godmode/admin. `firestore.rules` = 327 lines, server-authored loyalty.
- Tests: 8 Dart test files (`comment_model`, `feed_cta_stamp_ad`, `menu_modes`, `merchant_customer_follower`, `order_idempotency`, `stamp_card`, `wallet_code`, `widget_test`). `widget_test.dart` is the broken default scaffold (pre-existing, `[core/no-app]`).

### Route inventory (source of truth = `lib/app/appRouter.dart`)
- **Public/landing:** `/`, `/godmode`, `/:handle` (catch-all merchant handle, MUST stay last).
- **Auth:** `/auth/{userLogin,userRegister,merchantLogin,merchantRegister,forgotPassword,merchantForgotPassword,emailVerification,roleGate,chooseRole,merchantPending,demoComingSoon}` + legacy redirects.
- **User (shell tabs):** `/user/{discover,explore,wallet,profile}` + deep-links `/user/partners/:id`, `/user/stamps/:id`, `/user/feed/:postId` (these 3 are intentionally login-free / shareable).
- **Public shop (Menükarte):** `/shop/:id`, `/shop/:id/table/:tableId`, `/runner/:id`.
- **Merchant:** `/merchant/{dashboard,finance,features,shop,menu,customers,stamps(+edit),points(+system/reward edit),catalog(+design,qr,runners),coupons(+edit),orders(+tables,+detail),feed/{create,manage,stamp-ad},tools/*}`.
- **Coming-soon (deliberate, i18n-backed, NOT dead UI):** `/merchant/{campaigns,shifts,delivery,reservations}` via `MerchantComingSoonPage`. Coupons fully built but intentionally not surfaced (feature toggle off).
- **Stamp tap:** `/stamp?picc&cmac` (NTAG SUN), `/s/:token` (static Path A).
- **Claim placeholders:** `/claim/{stamp,campaign,coupon,walletJoin}` → `FoundationPlaceholderPage` (genuine stubs — only reachable via not-yet-issued claim links).
- **Guards:** `/user/*` needs real (non-anonymous) login except the 3 share prefixes; `/merchant/*` needs login + role==merchant + verificationStatus==approved (cached in `_accessCache`).

### Data model (`firebasePaths.dart`)
- Top-level: `users`, `merchants`, `publicMerchants`, `feed`, `sticks` (server-only), `merchantRatings`, `contentReports`, `supportTickets`, `merchantInvites`, `aiUsage`, + chooser/system.
- Per-merchant subcols: `featureConfigs, customers, feedPosts, stampCards, pointsSystems, pointsRewards, coupons, campaigns, orders, items, itemTags, itemCategories, tables, tableAreas, openingHours, appointments, shifts`.
- Per-user subcols: `walletCards, likedPosts, postInteractions, stampProgress (server-only), pointsProgress (server-only), earnedRewards (server-only), coupons, availableRewards, orders, notifications`.
- Per-post subcols: `likes, reviews, comments, views, clicks`.

### Architecture decisions FROZEN for this program (do not "fix")
1. **State management stays Provider/ChangeNotifier — NO Riverpod migration.** The God Prompt suggests "consolidate on Riverpod," but this codebase deliberately and repeatedly chose Provider (documented across 5+ prior sprints, 346 files, ~1100 static-const theme refs). A rewrite = massive regression risk for zero user value. OVERRIDE the prompt here per its own "never regress" + priority rules.
2. **Shared widgets already unified:** single `PostCard` (feed+profile), single `QuickActionBar`, single card-visual renderer (`StampCardVisual`), single `/stamp` gate, single `OrderStatusStyle`. Sprint-1 dedup goal already largely met by prior work.
3. **Loyalty is server-authored** (rules deny client writes to stamp/points/earnedRewards). Keep it that way.

### Ranked risk list (what actually blocks 90% release — drives Sprints 2–6)
1. **⛔ Uncommitted working tree (HIGHEST):** 19 modified + 34 untracked files = essentially ALL recent feature work (stamps, godmode/admin, `functions/`, feed/wallet refactors, post compose) is NOT committed. No clean baseline to regress against; one bad edit risks hours of work. → commit a checkpoint before any sprint touches code.
2. **🔴 PWA shell is Flutter boilerplate (directly blocks the hosted-Web-PWA target):** `manifest.json` name="lokka"/description="A new Flutter project."/theme_color=#0175C2 (Flutter blue, off-brand); `index.html` description boilerplate, no theme-color meta. → Sprint 2/4.
3. **🔴 No service-worker caching at all:** `index.html` actively *unregisters* every SW and clears all caches on load (anti-stale hack). Kills PWA offline/install caching + repeat-load perf. Tension to resolve: stale-protection vs. PWA caching. → Sprint 4 (decide: versioned SW cache, no blanket unregister).
4. **🟠 No code-splitting:** 0 `deferred as` imports across 346 files → one monolithic `main.dart.js`. → Sprint 4 (lazy-load merchant area / godmode / heavy pages).
5. **🟠 Hosted-vs-local parity already bitten once:** prior log shows NFC link "hangs in login" was a network firewall blocking `jajehelp.com` + self-host Firebase SDK fix. Confirms Sprint 5 must verify on the real hosted origin (prefer `*.web.app`). → Sprint 5.
6. **🟡 External-only release gates (the human's 10%, cannot be done by AI):** Blaze plan, `STAMP_MASTER_KEY` secret, `firebase deploy --only functions,firestore:rules,firestore:indexes,storage`, NTAG-424 chip programming, real-device matrix, FCM push, legal/content.

### Exit criteria — Sprint 1
Architecture report ✅ · full route+data inventory ✅ · ranked risk list ✅ · build not broken (analyze 0/0/0) ✅. **No code changed in Sprint 1** (pure audit) → zero regression risk.

> **Scope decision (user, 2026-06-26):** Run **PWA + security only** (Sprints 4 + 6), edit **without a pre-commit checkpoint**. Cosmetic design re-pass (Sprint 2) and full logic walk (Sprints 3/5) deferred by the user. Edits kept surgical + analyze-verified because there is no git safety net.

## SPRINT 4 — PWA SHELL & HOSTING CACHING (scoped) ✅

**Done ✅ (all pure client config — zero Dart, zero flow-risk):**
- **`web/manifest.json`** — replaced Flutter boilerplate: name "Lokka — Local Deals & Loyalty", short_name "Lokka", real description, `theme_color` `#1FA97E` (brand green, was Flutter blue `#0175C2`), `background_color` `#FAFBF7` (app launch bg). Icons (incl. maskable) kept.
- **`web/index.html`** — real description meta, added `<meta name="theme-color" content="#1FA97E">`, fixed `<title>` + apple-web-app title to "Lokka", status-bar `black-translucent`.
- **`firebase.json` hosting `headers`** — added proper `Cache-Control`: shell/entry files (`index.html`, `flutter_bootstrap.js`, `flutter_service_worker.js`, `main.dart.js`, `manifest.json`, `version.json`) → `no-cache, no-store, must-revalidate`; `/firebase/**` (version-pinned SDK) + images/fonts/wasm + `canvaskit`/`assets` → `immutable, max-age=1y`. Fixed header-precedence so root JSON stays revalidated. This is the **real root-cause fix** for the "re-uploaded but browser runs old code" staleness bug. Headers only apply on Firebase Hosting deploys → safe no-op elsewhere. JSON validated.

**Deferred ⏭️ (decision left to user — risk #3):**
- **Service-worker blanket-unregister in `index.html` NOT removed.** It still unregisters every SW + clears all caches on load → no PWA offline/caching. Rationale: it is the user's current staleness defence on a custom domain (jajehelp.com) where the new `firebase.json` headers do **not** apply unless they deploy via Firebase Hosting. Removing it blind (no commit, in-flux hosting) could resurrect the stale-build bug. **Hand-off:** once on Firebase Hosting (headers active), delete the unregister `<script>` in `web/index.html` body to gain real PWA caching + installability.
- **Code-splitting — DONE (2026-06-26, after the user authorised a baseline commit).** The entire `/godmode` admin tree (15 files) + the heavy `pdf` package (which *nothing else* imports) is now a `deferred as admin_gate` import in `appRouter.dart`, loaded on demand by a new `_DeferredAdminGate` widget (loader + retry-on-error). Verified by `flutter build web --release` → a separate **`main.dart.js_1.part.js` = 622 KB** chunk is emitted and no longer ships in the initial bundle every user downloads (main.dart.js = 5.42 MB). Added a `**/*.part.js` → no-cache header to `firebase.json` so a redeploy can't serve a stale chunk. Blast radius of a failed chunk load = the owner-only /godmode route only.

## SPRINT 6 — SECURITY GATE ✅ (audit verdict; no blind rule changes)

**Baseline security = already strong.** Verified:
- **No hardcoded secrets in client.** The Firebase web `apiKey` in `firebase_options.dart` is a public identifier by design (security is in the rules, not key secrecy). No `AIza…`/`secret=` literals elsewhere.
- **No served mixed content.** Only `http://` hits are URL-scheme *validation* guards, not http loads.
- **`.env` gitignored + NOT tracked** (no secret in git history). `authDomain` = `lokka-069.firebaseapp.com` ✅.
- **`firestore.rules` (327 lines):** default-deny (no catch-all allow), server-authored loyalty (stamp/points/earnedRewards write:false), `sticks` server-only, admin override gated on custom claim, guest-order create validated (`validNewOrder`).
- **`storage.rules`:** owner-scoped write, image+8MB validation, public read (deals app), default-deny.
- **`/stamp` verification:** CMAC + monotonic counter (replay-proof) + cooldown + best-effort geofence/opening-hours, both NTAG (Path B) and static-token (Path A). Solid.

**Flagged for the human (need emulator-test + `firebase deploy` → the user's gate, NOT changed blind):**
1. 🟠 `orders` `list: if true` — public order listing leaks PII (names, items). Load-bearing for guest order-tracking; proper fix = anonymous-auth scoping. Documented trade-off.
2. 🟠 `merchantRatings` `write: if isSignedIn()` — any signed-in user can write aggregate ratings (manipulation). Recommend: move aggregation to a Cloud Function, set `write:false`.
3. 🟡 `devChecks` `read,write: if isSignedIn()` — dev tool; rule's own TODO says close in prod (`if false`).
4. 🟡 `chooser` `write: if isSignedIn()` — arrayUnion abuse possible; later restrict to a callable.
5. 🟡 **App Check not configured** — without it the public apiKey + open callables are reachable by non-app clients (abuse vector). Add for production.
6. 🟡 `GEOAPIFY_API_KEY` is **bundled into the web build** (`.env` is a pubspec asset) → publicly extractable. Must be HTTP-referrer-restricted in the Geoapify dashboard. Also: stale `CLOUDINARY_*` keys still in local `.env` (Cloudinary removed earlier) — harmless, clean up.

### GO / NO-GO verdict
**Code/PWA-shell: GO.** Security baseline: **GO with conditions** — the rules are least-privilege except the documented `orders.list`/`merchantRatings` trade-offs, which are deploy-gated decisions for the owner. None are remote-code/secret-leak class.

**Regression vs baseline:** clean — no Dart touched, `flutter analyze` still 0/0/0; JSON configs validated.

---

# DESIGN-ONLY OPTIMIZATION — Responsive Integrity (Sprint 1)

> 2026-06-26 · Branch `main`. Design only (no logic/data/backend). Goal: kill the cross-device shift/resize/wrap + flat look.

## Reproduction harness (built)
- Set up a live screenshot harness: `.claude/launch.json` + `.claude/preview-server.js` (tiny Node static server for `build/web` with SPA fallback) driven by the Claude preview MCP (`preview_resize`/`preview_screenshot`). Fetched real public IDs via Firestore REST (publicMerchants are public-read) to load the actual data-driven screens through the router's public deep-links (`/user/partners/:id`, `/user/feed/:postId`, `/shop/:id`) — no login needed.
- **Captured real renders:** landing @390 (excellent), landing @1440, partner profile @390 (excellent, no overflow), partner profile @1440 (**BUG REPRODUCED**).

## Root cause (found, with proof)
- The mobile-first **data screens have no max-content-width constraint**, so on tablet/desktop they stretch edge-to-edge: the "Folgen" button becomes a giant bar, action icons cluster tiny in the centre, loyalty cards over-stretch → "elements bigger than intended" + sparse/dead look. The landing page does NOT break because it already uses `ConstrainedBox(maxWidth: 460)`. So the breakage is NOT systemic debt — it's a missing, consistent content-width cap on the data screens.

## Fix (built + compiled, design-only)
- New reusable widget **`lib/core/widgets/responsiveContentWidth.dart`** — `Center > ConstrainedBox(maxWidth: 640)`; no-op on phones (<640), centres + caps content on wide screens. Works for box AND sliver scroll bodies.
- Applied to **`userPartnerDetailPage.dart`** (wraps `CustomScrollView`) and **`userFeedDetailPage.dart`** (wraps `ListView`). One-line wrap each, import added.
- **Verified compiled:** `flutter analyze` 0/0/0; `flutter build web --release` clean, `main.dart.js` grew 5,423,772 → 5,423,960 B (+188) confirming the edits are in the bundle (an earlier `flutter run --release` had served a STALE cached bundle — caught via identical byte size).

## ⛔ Blocker — after-shot proof
- **Headless CanvasKit could not produce the after-shot.** Flutter renders to a single WebGL `<canvas>`; after many reload/resize cycles the headless browser's WebGL context becomes exhausted (0 frames, then a hung `preview_screenshot`). The BEFORE shot + mobile shots were captured before exhaustion. The fix is logically standard (Instagram/Twitter-web style centred column) + analyze/build-clean, but is **visually unverified at desktop width** in this environment.
- **To verify:** open `/user/partners/<id>` (or any feed post) at ≥1024px in a real desktop browser — content should now sit in a centred ≤640px column instead of stretching full-width. Or re-run the harness fresh (one load, no repeated reloads).

## Status / next
- DONE: harness, reproduction, root cause, reusable system, fix on 2 worst-offender detail pages.
- NOT DONE (honest): full-matrix after-shots; Sprint 2 (visual "life") + Sprint 3 (state/consistency QA) not started. The token system (AppColors/AppTextStyles/MerchantPremiumColors) already exists and is mandatory — Sprint 2 should refine within it, not rebuild.

## Rollout (2026-06-26, after user said "you eyeball it, I roll out")
- Applied `ResponsiveContentWidth` to the remaining high-value data screens:
  - **`userShellPage.dart`** — wraps the `IndexedStack` (maxWidth **720**) → caps ALL 4 main tabs at once (discover/explore/wallet/profile); the `bottomNavigationBar` stays full-width (it's outside the body). Wider cap (720) because discover/explore have card grids.
  - **`userPartnerStampsPage.dart`** (Column body), **`userPartnerPointsPage.dart`** + **`userPartnerPointsShopPage.dart`** (CustomScrollView bodies) — default 640 cap.
- **Deliberately skipped:** `publicShopPage.dart` (Menükarte) — most layout-complex, own header, likely wants a wider cap; left for visual review.
- **Verified:** `flutter analyze` 0/0/0 + `flutter build web --release` clean (exit 0). **Still visually unverified at desktop** (headless CanvasKit WebGL context stayed exhausted for the whole session — even a fresh server + fresh build would not repaint). User to eyeball at ≥1024px.
- **Coverage now:** partner detail, feed detail, partner stamps, partner points, points shop, + the 4 shell tabs = the core user-facing surface.

## Rollout part 2 (2026-06-26, "mach weiter")
- **`publicShopPage.dart`** (Menükarte) — wrapped the body content `ResponsiveContentWidth(maxWidth: 900)` (wider cap for a multi-column menu; appBar/full-bleed stays outside).
- **`meineFavoritenPage.dart`** + **`meineRezensionenPage.dart`** — wrapped the Column body (640); the Scaffold appBar stays full-width.
- **`userStampPage.dart`** — wrapped `_buildBody()` (640); appBar full-width.
- **`stampTapPage.dart`** — already capped (`ConstrainedBox(maxWidth: 460)`); no change needed.
- **Verified:** `flutter analyze` 0/0/0; `flutter build web --release` clean (exit 0).
- **Full user-facing responsive coverage achieved.** Still desktop-visually-unverified this session (headless CanvasKit WebGL context never recovered — confirmed dead even after a fresh build + ~10min). User verifies at ≥1024px.
- **Tuning knob:** all caps are one-liners — `responsiveContentWidth.dart` default (640) or per-call `maxWidth:` (shell 720, shop 900).

---

# Stempelstift — Umbau auf „Owner schreibt Link, Merchant bindet per QR" (Sprint 1)

> 2026-07-01. Ziel-Modell (User-Vorgabe): Owner erzeugt in Godmode je Stift einen fixen NFC-Link + einen Binde-QR. Owner schreibt den Link EINMAL auf den Chip. Merchant scannt den Binde-QR auf eine gewählte Stempelkarte → gebunden. Nutzer tippt → stempelt die aktuell gebundene Karte (alle Schutzmechanismen).

## Kern-Änderung (elegant, minimal)
- **Redeem-Token ist jetzt stick-identisch statt karten-gebunden.** `staticToken.ts` `tag()` signiert nur noch `LOKKA-STICK-ID-v1|<stickId>` (merchantId/cardId raus der Signatur, Parameter bleiben für Call-Site-Kompat). Neuer Helper `signStickLink(master,stickId)`. → Der Tag-Inhalt ist fix; Umbinden auf eine andere Karte erfordert KEIN Neuschreiben, weil `redeemStaticStamp` die Bindung ohnehin aus `sticks/<id>.boundCardId` liest. `index.ts` brauchte deshalb 0 Änderungen.
- **`adminMintStaticSticks`** gibt pro Stift zusätzlich `redeemToken` (= signStickLink) zurück → Owner-UI baut `https://<app>/s/<token>`.
- **`claimStaticStick`** setzt jetzt `stickVerifiedAt: serverTimestamp()` auf die Karte (Owner hat den Tag schon geschrieben → „verbunden ✓" sofort). Gibt weiterhin den (identischen) Token zurück (Legacy-Merchant-Flow bleibt lauffähig).

## Godmode-Werkstatt (`adminStickWorkshopPage.dart`)
- Nur noch EIN Bereich „Stifte erzeugen". Pro Stift-Kachel: (1) **NFC-Link** (voller `/s/…`-URL, kopierbar, „auf den Chip schreiben") + (2) **Binde-QR** (QR-Bild, Code kopieren, PNG). PDF-Export = Binde-QRs.
- **Path-B-Sektion („Sicher-Chips / NTAG 424") aus der Werkstatt entfernt** + `deriveNtagStick`/`DerivedNtagStick` aus `adminService.dart` gelöscht.

## Verifiziert
`cd functions && npm test` → tsc grün + **16/16** Crypto-Checks (inkl. neue Invarianten „card-agnostic", „signStickLink == identity", „rejects wrong stick"). `flutter analyze` = 0/0/0.

## NOCH OFFEN (im Prompt spezifiziert, nächster Schritt)
Path-B-Backend LÖSCHEN (`redeemStampTap`, `setupStick`, `verifyStickBinding`, `adminDeriveNtagStick`, `crypto/ntag424.ts`, `crypto/aesCmac.ts`, `provSecret`, `scripts/deriveKeys.ts`, deren `index.ts`-Exports; Route `/stamp?picc&cmac`; Client `nfcService*`, picc/cmac-Zweig in `stampTapPage`); **Merchant-`stickSetupFlow.dart` radikal auf „QR scannen → verbunden" vereinfachen** (kein NFC-Schreiben/Test-Tap/Link-Kopieren mehr); verwaiste i18n `merchant.stick.pathB.*` weg. NICHT anfassen: `merchantStampCustomer`, `claimReward`, `merchantRedeemReward`, `userAddStampCard`, `userRemoveStamp`, `userUnfollowMerchant`, `merchantLoadCustomer`.


---

# User-Area Design-Fix (Deep-Green System)

### 2026-06-24 — Sprint 1 (System/Layout/Bugs) — Claude
**Prompt:** Design-only Refresh über 8 User-Screens. Deep-Green (#1E7A5F) führt, Mint nur Fläche; Layout/Z-Index/Wallet-Karten/Hierarchie.
**Entscheidungen (User):** Akzent global im Theme; „Karte"→„Speisekarte" (beide bleiben); Mint bleibt ruhige Fläche.
**Changed:**
- `appColors.dart`: neuer `accent`=#1E7A5F; `green`/`seedGreen`/`mintStrong` → `accent` (alle bisherigen Mint-Akzente werden ohne Einzeledits Deep-Green); `mintGradient` auf Deep-Green getönt. Mint/greenTint/greenLine bleiben Fläche.
- `appTheme.dart`: Light-Scheme `primary` exakt auf `accent` gepinnt (+onPrimary weiß) → CTAs/Fokus/Nav-Indicator/Chips global Deep-Green. merchantDark unberührt.
- `userProfilePage.dart`: „Mein Bereich" 4-in-Reihe → **2×2 Grid** (kein Squish); „Ausloggen" von tonal-FilledButton → ruhiger zentrierter TextButton (demotet).
**Bereits konform vorgefunden (nicht angefasst):** WalletCard (AspectRatio=gleiche Höhe, dunkler Gradient, feste Zonen Logo/Titel/Code); Wallet-Stack-Overlay (zentrierter Handle + Close, Dots) → keine Z-Index-Kollision mehr im aktuellen Code.
**Verify:** analyze lib 0/0.
**Next:** Sprint 2 — Feed Like-Dedupe+Action-Bar, Explore-Kacheln, Stempel-Detail-Spacing/Header-Grün, Social-Glyph, Karte→Speisekarte.

### 2026-06-24 — Sprint 2 (Life/Consistency/States) — Claude
**Changed:**
- **Explore-Feed-Karte** (`userDiscoverPage.dart` `_FeedCard`): EINE Like-Steuerung statt zwei — schwebendes Bild-Herz entfernt; unten echte Aktionsleiste **Like(+Count) · Kommentar · Teilen** (interaktiv, Kommentare via inline-`UserFeedService`+`showCommentsSheet`, Teilen via ShareUtils). Toter `_LikeButton` gelöscht. Rating/Distanz als ruhige Meta-Zeile darüber.
- **Quick-Actions vereinheitlicht:** Social-Glyph `@`→`Icons.public_rounded` in Partner-Profil, Post-Seite und Wallet-Sheet (alle nutzen schon dieselbe `QuickActionBar`). „Karte"→**„Speisekarte"** (keine Verwechslung mit Landkarte; Route + Speisekarte bleiben getrennt).
- **Stempelkarte-Detail** (`userPartnerStampsPage.dart`): zwei gestapelte Mint-Statusleisten → EINE (Bottom-CTA „Zur Wallet hinzufügen" nur bis man folgt; danach trägt die Per-Karte-Status „In deiner Wallet"). Header-Verlauf → solides System-Grün `AppColors.accent` (ein Grün). Pager-Dots größer (26/9, aktiv/inaktiv = primary/primary-28%). Bühne neutral (greenTint→surfaceBg) → kein großer Mint-Leerraum, Karten stehen im Fokus.
**Automatisch via Sprint-1-Theme:** Akzent app-weit (CTAs/Fokus/Nav/Chips); Konto-Icon-Tints einheitlich (eine secondaryContainer-Quelle).
**Bewusst gelassen:** Explore-Top-Tabs/Glocke-Crowding (FittedBox skaliert bereits) + „Aktivität"-Icon (hat Tooltip) = minor; Explore-Gradient-Kategorie-Kacheln nicht eindeutig lokalisierbar → nicht angefasst (kein Blind-Edit).
**Verify:** analyze lib 0/0.

---

# Pro-Redesign (Instagram-Level) — Mehr-Sprint-Programm
**Vorgaben (User):** Radien straff/modern (zentral), Animation minimal (Fades), Scope User+Auth/Landing (Merchant-Dashboard bleibt), Dark Mode VOLL (Default hell, Schalter im Profil Hell/Dunkel/System), Bottom-Nav behalten (nur Farben/Radien). Jeder Sprint endet analyze 0/0.

### Sprint 1 — Fundament (Tokens + Theming + Dark-Schalter) — Claude
- `appRadius.dart`: moderne Skala small8/medium12/large16/xl24/xxl28/**full999** (zentral, kaskadiert).
- `appTheme.dart`: **EIN** `_userTheme(scheme)` für Hell UND Dunkel (kein Drift); alle Komponenten über `ColorScheme.*` + AppRadius-Tokens (vorher hartkodiertes surfaceBg/Radien raus). Neue `darkTheme` (grün-getöntes Neutral-Dunkel, Akzent #34C293 für Kontrast). Light optisch ~gleich, nur Radien straffer + Inputs/Sheets/Dialoge an Tokens.
- `themeController.dart` (neu, ChangeNotifier, persistiert via LocalCacheService, Default Light) → in `appProviders` registriert; `app.dart` MaterialApp.router bekommt `darkTheme`+`themeMode` via Consumer.
- `userProfilePage.dart`: Sektion **„Darstellung"** mit SegmentedButton Hell/Dunkel/System.
**Wichtig/Offen:** Dark ist für Theme-getriebene Widgets korrekt; Screens, die noch `AppColors.surfaceBg`/weiße Scaffolds hartkodieren, werden Sprint 2–5 pro Screen auf semantische Tokens migriert → Dark wird progressiv vollständig. Light bleibt durchgehend fehlerfrei.
**Verify:** analyze lib 0/0.

### Sprint 2 — Frame dark-correct + erste Screen-Migration — Claude
- **Shell** (`userShellPage.dart`): Scaffold/Nav von hartem Weiß (`AppColors.background/surfaceBg`) auf `cs.surface`/`scheme.surfaceContainerLowest` + Nav-Radius auf `AppRadius.xxl`. → Rahmen ist in Dark korrekt.
- **Tab-Frames:** Feed-AppBar, Explore-Scaffold+AppBar auf Theme-Tokens (`cs.surface`/`surfaceContainerLowest`).
- **Profil komplett dark-korrekt** (wichtig, da dort der Schalter sitzt): alle `AppColors.surfaceBg`→`cs.surface`/Scaffold-Token, AppColors-Import entfernt. Hell unverändert, Dark sauber.
- **Verify:** analyze lib 0/0 + `flutter build web --release` ✅.
**Status Dark-Migration (ehrlich):** Theme-getriebene Widgets (PostCard, Explore-Card, Partner-Detail, Wallet-Stack u.a. nutzen großteils `cs.*`) adaptieren automatisch. NOCH zu migrieren (hartkodiertes Weiß/Dunkeltext) für volle Dark-Treue: userFeedDetailPage, ratingSection, commentsSheet, walletCard/Page, userPartnerStampsPage, userPartnerPointsPage(+Shop), Auth/Landing, diverse Profil-Unterseiten (meine*Page). ~155 AppColors-Literale übrig → Folge-Sprints, je Screen analyze 0/0.

### 2026-06-24 — Original 2-Sprint-Prompt: Restlücken geschlossen (Audit-getrieben) — Claude
6-Agent-Audit (Workflow) aller 8 Screens gegen die Checkliste → präzise Lückenliste. Danach umgesetzt:
- **Explore-Kacheln** (`userExplorePage._ExploreTile`): Regenbogen-`_palettes` RAUS → EINE ruhige Mint-Fläche (greenTint→mintSoft + greenLine-Border), Icon = Deep-Green `AppColors.accent`. Totes Mittelfeld weg: `spaceBetween`→`MainAxisAlignment.end` (Icon+Label unten gruppiert) + Grid `childAspectRatio 1.35→1.15`. `seed`/`_darken` gelöscht.
- **Wallet-Overlay „weiße Slivers"** (`walletCardStack`): `PageController(viewportFraction: 0.88)`→Vollbild (kein Nachbar-Karten-Durchscheinen über dem Dim). Grab-Handle symmetrisch zentriert. Store-QR + `userQrCard`-QR responsive (`width*0.5/0.6` clamp) statt fix 196/248. Karten-Radien 30/26/32 → AppRadius-Tokens.
- **Profil**: „Aktivität"-Icon → beschriftete Pille (Icon+Text, nicht nur Tooltip). Bottom-Spacer 140 → `96 + viewPadding.bottom`. `_Shortcut`-Radien 20/13 → AppRadius.large/medium.
- **Bottom-Nav aktiv = Akzent** (`userShellPage._NavTab`): aktives Tab jetzt Deep-Green (`cs.primary` @0.14 + primary Icon/Text) statt Mint-`secondaryContainer`.
- **Merchant-Profil**: Social-Popout-Header-Icon `@`→`public_rounded` (letztes @-Glyph im Social-Flow).
- **Radius-Vereinheitlichung**: Feed-Karten (discover `_FeedCard` + explore `_CategoryFeedCard`) 28→`AppRadius.large` (identisch zu PostCard); Discover-Location-Dialog 28→`AppRadius.xl`; Shared `AppEmptyState`/`AppErrorState`-Icon-Kachel 20→`AppRadius.large`.
**Verify:** analyze lib 0/0 + `flutter build web --release` ✅.
**Bewusst offen (ehrlich, nicht in der Checkliste):** explore `_CategoryFeedCard` hat noch die Bild-Herz+Meta-Doppel-Like (Discover-`_FeedCard` ist gefixt) — eigener Sprint, da es eine Karten-Kopie ist; Long-Tail-Radius-Literale (partnerCard/progress-cards) noch nicht komplett tokenisiert; discoverCard-Placeholder-Tint (mintSoft) unverändert (context-los, minimal sichtbar).

---

# Wallet-Redesign (Senior-UI) — Phase 1: Fundament

## Done (2026-06-24)
- **Design-Tokens:** `features/user/wallet/theme/walletDesignTokens.dart` — radien/spacing/shadow/motion(easeOutCubic ≤300ms)/fontWeights. Farben NICHT neu definiert → 1:1 aus `AppColors` (shadow, storyRing-Gradient) bzw. `ColorScheme` (theme-aware). maxContentWidth=420.
- **Mobile-first:** Wallet-Seite in `Center + ConstrainedBox(maxWidth:420)` → auf Desktop/Tablet zentriertes „Handy", Rest neutral.
- **Header rechts = 2 Icons:** neue `WalletSearchBar` (klappt von rechts auf 220px auf, 200ms easeOutCubic, Live-Filter über Name/Stadt/Kategorie, theme-aware) + Sort-Chip. Leerzustand bei 0 Treffern („Keine Karte gefunden").
- **Sort umbenannt:** „Nähste zuerst" (Distanz) | „Zuletzt genutzt" (jetzt nach `lastActivityAt`).
- **Files:** + walletDesignTokens.dart, + walletSearchBar.dart; ~ userWalletPage.dart. analyze wallet = 0 issues.

## Offen (Phase 2/3 — größer, teils Backend)
- **Karten-Layout-Overhaul** (WalletCard neu): Profilfoto oben-links (42px, weißer Rand) → Merchant-Page; Kategorie-Chip oben-rechts; Name+Stadt unten-links; Karten-Typ-Icon (QR/Stamp/Points) unten-rechts. + `WalletStack` als Apple-Stack (ist als `walletDeck` schon da → an neues Card-Schema angleichen).
- **QR-Detail-Sheet** (`QRSheet`) nach Spec (Handle, Merchant-Header 52px, QR 220 + Vergrößern-Icon im Container, Code-Chip, `MerchantActionRow` nur vorhandene Links, 48px Brand-10%-Container).
- **Karten-Typen im Sheet:** `StampCardShell` (neutrale Umgebung, Merchant-Design unangetastet) + `EmptyLoyaltyCard` (gestrichelt, 2 Text-Varianten, verlinkt zur Merchant-Page, kein CTA) + Points analog.
- **Badges/Story:** `BadgeDot` (neuer Stempel/Punkte-Update) + Story-Ring (Merchant-Post <24h) — BRAUCHT Backend: merchant-lastPostAt lesen + `seenStoryAt`/seen-badge in Firestore.
- **Widgets noch zu extrahieren:** WalletCard, WalletStack, QRSheet, StampCardShell, EmptyLoyaltyCard, MerchantActionRow, BadgeDot.

---

# Profil-Sammelauftrag (6 Teile) — 2026-06-24 — Claude

5-Agent-Map-Workflow → dann umgesetzt (analyze 0/0, build web ✅):
1. **Name-Bug:** `AppUserModel.fromMap` las nur `firstName`/`lastName`. Jetzt Fallback-Kette firstName/lastName → ownerFirstName/ownerLastName → Split von `name`/`displayName`/`fullName`. Kein UI-/Rules-Change, keine Migration nötig.
2. **Erscheinungsbild-Umbau:** „Darstellung"-Sektion jetzt direkt unter „Mein Bereich" (vor „Konto"). „Interessen"-Kachel → **„Über mich"**; OnboardingSurvey-Titel „Interessen anpassen" → „Über mich anpassen".
3. **Cover:** Profil-Hero von Vollfarbe → dezenter diagonaler Marken-Gradient (`cs.primary`→dunkler, theme-aware). Avatar bleibt zentriert/sichtbar.
4. **Emoji-Avatar:** `AppUserModel` +`profileEmoji`/`profileImageType`; Service `updateProfileEmoji` + `updateProfileImage` setzt type='image'. Kamera-Button → Chooser (Foto/Emoji); 20-Emoji-Grid-Picker; `_Hero` rendert Emoji groß/zentriert (Precedence: type=='emoji' → Emoji, sonst Bild, sonst Initialen). Legacy-Bild-User unberührt.
5. **Persönliche Daten entschlackt:** Name/Kontakt/Adresse (Vorname/Nachname/PLZ/Telefon-Readonly) komplett raus inkl. Controller/Validierung/Save-Felder + tote Widgets (`_field`/`_PlzField`/`_ReadonlyField`) + `postalCodeService`-Import. Bleibt: Geburtstag. EIN einheitlicher Full-Width-`FilledButton` (AppBar-TextButton weg). Profil-Tile-Subtitle → „Geburtstag".
6. **Datenschutzerklärung (DSGVO):** Voller 8-Abschnitte-Text (Verantwortlicher/Daten&Zweck/Rechtsgrundlage/Speicherdauer/Weitergabe/Nutzerrechte/Cookies/Kontakt&Beschwerde) in `assets/legal/datenschutz.json`. `LegalService` (Firestore `legal/privacyPolicy` → Asset-Fallback + best-effort Auto-Seed). Neue `PrivacyPolicyPage` (In-App, ersetzt externen Link). `FirebasePaths.legal`+`legalDocument`. Rule `legal/{doc}` public read (Write nur Admin-Override). Externer `AppConfig.privacyPolicyUrl`/`url_launcher` aus Profil raus.
**Manuell:** `firebase deploy --only firestore:rules` (sonst greift legal-Read erst nach Deploy; bis dahin Asset-Fallback). Platzhalter [Firmenname/Adresse/E-Mail/Behörde] im DSGVO-Text vor Live durch echte Daten ersetzen + juristisch prüfen.

## Phase 2 — Karten-Overhaul + Widgets (2026-06-24)
- **WalletCard neu** (Spec §2, festes Layout): Cover + dark gradient (bottom→top); [o-l] Merchant-Foto rund + weißer 2px-Rand → Tap öffnet Merchant-Profil (fetch publicMerchant → UserPartnerDetailPage); [o-r] Kategorie-Chip (transluzent weiß, 11px); [u-l] Name (bold 18) + Stadt (13, 0.8, Hessen-gekürzt); [u-r] QR-Typ-Icon + optionaler BadgeDot (Prop `showBadge`, Default off → Phase 3). radius/shadow/minHeight aus Tokens. Code+Chevron entfernt (Code lebt im QR-Sheet).
- **Neue Widgets:** `BadgeDot` (brand + Surface-Ring, theme-aware), `EmptyLoyaltyCard` (gestrichelt via CustomPaint, Variante A/B, verlinkt „besuche sein Profil", kein CTA), `MerchantActionRow` (48px Brand-10%-Tiles, 11px Label, nur vorhandene Aktionen).
- **Verdrahtet in walletCardStack:** `_quickActions()` → nur verfügbare `MerchantAction`s; `QuickActionBar` → `MerchantActionRow`; `_HintPane` (mit CTA-Button) ersetzt durch `EmptyLoyaltyCard` (offersProgramme = _activeCards.isNotEmpty). `_HintPane` gelöscht, quickActionBar-Import raus.
- **Files:** + walletBadgeDot.dart, + walletEmptyLoyaltyCard.dart, + walletMerchantActionRow.dart; ~ walletCard.dart (Rewrite), ~ walletCardStack.dart. analyze wallet = 0 issues.

## Phase 3 — offen (Backend nötig)
- Story-Ring (Merchant-Post <24h) auf Merchant-Foto + `seenStoryAt`-Persistenz → braucht merchant-lastPostAt + users/{uid} seen-state.
- BadgeDot datengetrieben (neuer Stempel/Punkte-Update seit letztem Öffnen) → seen-tracking.
- Optional: QR-Detail als echtes Modal-BottomSheet (aktuell Apple-Stack-Overlay) + StampCardShell als eigene neutrale Shell.

## Wallet Bugfix + Design-Level-Up (2026-06-24)
- **BUG 1 (weißer Bereich):** Deck lag in fixem `SizedBox(0.7h)` → Rest weiß. Fix: Header + `Expanded(WalletDeck)` in einer Column → Deck füllt jetzt Header→BottomNav komplett.
- **BUG 2 (Titel bricht):** Suchfeld saß in derselben Row wie „Wallet" → per-Buchstabe-Umbruch. Fix: neuer `WalletHeader` mit `AnimatedSwitcher` (150ms) — Such-Icon → Titelbereich wird KOMPLETT durch Vollbreite-Suchfeld ersetzt, X bringt Titel zurück. Live-Filter.
- **Header-Redesign:** minimal (≤52px), 32px App-Logo links, Such- + Sort-Icon rechts, keine Subtitle.
- **Detail-View:** hatte bereits horizontales PageView (QR/Stempel/Punkte) + Dot-Indicator + X; ergänzt: Swipe-down-to-close am Top-Handle.
- **Hintergrund:** subtiler Gradient `surface → surfaceContainerLow` (theme-aware) statt plain white.
- **Extrahiert:** `WalletHeader`, `SortDropdown` (neu) + geteilter `WalletSort`-Enum (models/walletSort.dart). `walletSearchBar.dart` gelöscht (in Header aufgegangen). (WalletStack=walletDeck, WalletDetailView=walletCardStack, MerchantCard=walletCard existieren bereits.)
- **Files:** + walletHeader.dart, + walletSortDropdown.dart, + models/walletSort.dart; ~ userWalletPage.dart (Rewrite), ~ walletCardStack.dart; − walletSearchBar.dart. analyze wallet = 0 issues.

### Bewusst NICHT gemacht (Cross-Cutting / Backend)
- **Header-Shrink-on-Scroll (52→40) + BottomNav-Shrink (64→48, Labels weg):** braucht Scroll-Position-Kopplung; Wallet-Content ist ein Deck (kein klassischer Scroll) und die BottomNav ist Shell-Level (alle Tabs). → eigener Schritt mit Shell-Änderung + Scroll-Notifier.
- **Story-Ring + Badge-Dot datengetrieben:** Phase 3 (merchant lastPostAt + users seen-state).

### Wallet-Header schwebend (2026-06-24)
Grünes Logo + weißer Header-Balken entfernt → Deck füllt jetzt von ganz oben (transparent). Such- + Sort-Icon sind schwebende Kreis-Buttons (cs.surface + softShadow, Feed-Style) als Overlay oben rechts über dem Deck (Stack + Positioned); Suche klappt zu schwebendem Vollbreite-Feld auf. WalletHeader = logolos/transparent, SortDropdown mit softShadow.

### Wallet: Feed-Buttons + dichter Endless-Stack (2026-06-24)
- Floating-Controls jetzt exakt wie Feed: unten rechts (Positioned bottom:92), grün (secondaryContainer + onSecondaryContainer), Such-Button oben + Sort-Button darunter gestapelt; Suche klappt zu Vollbreite-Feld unten auf. SortDropdown ebenfalls grün (tune-Icon).
- WalletDeck: viewportFraction jetzt DYNAMISCH via LayoutBuilder (slotH = cardH*0.72) → Karten sitzen eng/überlappend, endless oben+unten, unabhängig von der Bildschirmhöhe (Controller lazy einmal erzeugt). scale 0.10/opacity 0.45 pro Schritt.

---

# Wallet — Kompletter Neubau: Vollbild-Boarding-Pass-Karussell (2026-06-24)

## Kontext / Entscheidung
Nutzer war mit Apple-Wallet-Stapel-Design nicht zufrieden. 5 Optionen vorgeschlagen (Liste/Stapel/Karussell/Grid/Hero+Liste); Nutzer wählte **Option 3 (Vollbild-Karussell)**. Vor dem Bau 5+2 Ja/Nein-Fragen gestellt, um Architektur eindeutig festzulegen:
1. Horizontal wischen = zwischen LÄDEN (ein Laden = eine große Karte) → **Ja**
2. Alten Apple-Wallet-Stapel komplett löschen → **Ja**
3. Suche + Sortierung bleibt (im neuen Look) → **Ja**
4. Mehrere Stempelkarten eines Ladens = Mini-Kacheln UNTER der großen Karte, wischbar → **Ja**
5. Karten-Stil: **echter Boarding-Pass** (helle Ticket-Karte, schmaler Foto-Streifen oben, perforierte Trennlinie) — NICHT Cover-Foto-Hintergrund wie vorher.
6. Layout: **Hauptdaten (Foto-Streifen, Name/Stadt/Kategorie, QR, Route/Anrufen/Social/Zeiten) OHNE Scrollen sichtbar.** Alles zu einzelnen Stempelkarten/Punktesystem darunter, SCROLLBAR.

## Architektur (neu)
- **`WalletBoardingPassCard`** (walletBoardingPassCard.dart, StatefulWidget) = EINE Vollbild-Seite pro Laden:
  - **Fixer Block** (`_IdentityBlock`, kein Scroll): 84px Foto-Streifen (Cover, Fallback-Verlauf) → `_PerforatedDivider` (CustomPaint-Punktreihe, liest sich als Perforation) → helle Ticket-Body: Mini-Logo+Name+Stadt·Kategorie, QR (responsiv zur Breite, Tap→Vollbild), Code-Chip (Copy), `MerchantActionRow` (Route/Zeiten/Anrufen/Social — nur was der Merchant hat).
  - **Scrollbarer Block darunter**: Stempelkarten-Mini-Kacheln (`_StampTile`, 220px breit, horizontales `ListView.separated`, je Kachel `StampCardVisual(compact:true)` + Fortschritt + Entfernen/Einlösen) ODER `EmptyLoyaltyCard` (Variante A/B) wenn nichts hinzugefügt; `_PointsSection`-Placeholder wenn Punkte aktiv; `_EarnedRewardsSection` (alle verdienten Belohnungen des Ladens).
- **`UserWalletPage`** (Rewrite): `PageView.builder` horizontal über sortierte/gefilterte Läden (ein `WalletBoardingPassCard` pro Seite). Floating Suche+Sortierung bleiben unten rechts (grün, Feed-Stil, aus vorherigem Schritt). NEU: schwebende **Seiten-Pille** oben mittig ("2 / 5"), erscheint nur bei >1 Karte. Suche/Sortierung setzen die Karussell-Position auf Seite 0 zurück (kein Verwirren bei geänderter Reihenfolge/Filter).
- **`walletMerchantSheets.dart`** (neu, extrahiert): `showHoursSheet`/`showSocialSheet` — wiederverwendbare Öffnungszeiten-/Social-Bottom-Sheets (vorher private Klassen im gelöschten walletCardStack.dart).
- **Gelöscht** (komplett ersetzt, keine Referenzen mehr): `walletDeck.dart`, `walletCardStack.dart` (Apple-Wallet-Stapel + Detail-Overlay), `walletCard.dart` (alte Listen-Kachel), `walletStampSection.dart` (unbenutzt seit Vorgänger-Umbau), `walletBadgeDot.dart` (Phase-3-Baustein, unbenutzt nach diesem Rewrite — bei Bedarf in Phase 3 neu anlegen, wenn Story-Ring/Badge-Tracking wirklich verdrahtet wird).
- **Backend/Service unverändert**: `userWalletService.dart` (loadMerchant/loadActiveStampCards/loadPointsEnabled/walletCardStream/stampProgressByMerchantStream/earnedRewardsByMerchantStream/addStampCardToWallet/removeStampCardFromWallet) — alle bereits vorhanden, keine neuen Firestore-Felder/Deploys nötig.

## Bewusste Trade-offs
- Fixer Identity-Block ist kompakt gehalten (84px Streifen, 120–160px QR, knappe Paddings), damit er auf typischen Mobile-Viewports ohne Scroll passt (App ist laut Vorgabe Mobile-Only). Auf sehr kurzen Viewports (z. B. sehr breites, sehr niedriges Desktop-Fenster) könnte es eng werden — akzeptierter Trade-off gemäß Mobile-Only-Scope.
- Seiten-Pille ("2/5") war nicht explizit gefordert, aber sinnvolle Orientierungshilfe beim horizontalen Wischen zwischen vielen Läden — dezent, kein zusätzlicher Tap nötig.

## Verifikation
- `flutter analyze lib/features/user/wallet` = **0 issues**.
- `flutter analyze lib` = 1 vorbestehender, nicht von dieser Änderung verursachter Unused-Import-Hinweis in `profilePersonalDataPage.dart` (fremde Datei, nicht angefasst).
- `flutter build web --release` = **√ Built buildweb** (79.5s, kompiliert einwandfrei).

## Offen / nächste Schritte
- Phase 3 (Story-Ring + datengetriebene Badges) weiterhin offen — braucht Merchant-`lastPostAt` + Seen-State; bei Umsetzung `walletBadgeDot.dart` neu anlegen und auf den Mini-Kacheln/Fotostreifen verdrahten.
- Feintuning-Stellschrauben: Foto-Streifen-Höhe (84), QR-Größenfaktor (0.34× Breite), Mini-Kachel-Breite (220) — alles über benannte Konstanten leicht justierbar.

---

# Wallet — Redesign v2: Explore-Stil-Header + vertikaler "Peek-Deck" (2026-06-24)

## Kontext
Vorheriges Vollbild-Boarding-Pass-Karussell (v1) hatte einen sichtbaren Bug: die horizontalen Stempelkarten-Mini-Kacheln unter der Hauptkarte überliefen (`BOTTOM OVERFLOWED BY 40/22/14 PIXELS`). Nutzer wollte zudem ein anderes Layout, orientiert an der Suche/Explore-Seite (Screenshot-Vorlage: `/user/explore`, Deals/Partner-Pillenschalter + Suchleiste + Kategorie-Raster).

## Neue Struktur
**Oberer, fixer Bereich** (Explore-Seiten-Stil, geteilte Komponenten wiederverwendet statt neu gebaut):
- `AppPillSwitch<WalletSort>` (bereits vorhandene, projektweit geteilte Komponente aus `core/widgets/appPillSwitch.dart`, identisch zu Explore/Feed) — zwei Segmente „Zuletzt benutzt" (`WalletSort.latest`, Icon `history`) / „Nähste von mir" (`WalletSort.nearest`, Icon `near_me`). Ersetzt den alten Popup-`SortDropdown` komplett.
- `AppSearchField` (bereits vorhandene, geteilte Komponente aus `core/widgets/appSearchField.dart`) — immer sichtbare Suchleiste statt der vorherigen einklappenden Icon-Suche. Ersetzt `walletHeader.dart` komplett.
- `_PreparingRow` (neu, klein) — Mini-Spinner „Standort wird ermittelt…", erscheint nur während „Nähste von mir" den Standort auflöst.
- `_CounterRow` (neu) — „2 / 5": Position des aktuellen LADENS unter allen sichtbaren Läden, direkt im Fluss (kein Overlay mehr).

**Pro Laden: `WalletStoreDeck`** (neu, `walletStoreDeck.dart`, ersetzt `walletBoardingPassCard.dart` komplett):
- Vertikaler „Peek-Deck": `PageView(scrollDirection: vertical, viewportFraction: (H-peek)/H)` — reiner Trick ohne Custom-Animation-Code: bei Ruheposition füllt die aktuelle Karte die Fläche (minus `peek`=58px), und genau die oberen 58px der NÄCHSTEN Karte schauen unten heraus. Wischt man hoch, schiebt sich die aktuelle Karte nach oben raus, die nächste füllt auf, die übernächste beginnt zu gucken — exakt das beschriebene Verhalten, mathematisch sauber aus der PageView-Mechanik abgeleitet (kein Scale/Fade-Hack wie im allerersten Entwurf).
- **Seite 1 (`_MainStoreCard`):** Cover-Foto füllt die GANZE Kartenfläche (`Stack fit:expand`, „ganz sichtbar" wörtlich umgesetzt), oben Logo+Name+Kategorie als Scrim-Overlay, unten ein **„Ticket-Shelf"** (solide `cs.surface`-Fläche mit oberem Schatten, `BackdropShelf`-Widget) mit perforierter Punktlinie, QR (Tap→Vollbild), Code-Chip, `MerchantActionRow` — garantierter Kontrast unabhängig vom Foto.
- **Weitere Seiten:** `_StampFullCard` (volle Höhe, `StampCardVisual(compact:false)`, Fortschritt, Entfernen/Einlösen, EIGENE verdiente Belohnungen dieser Karte) je hinzugefügter Stempelkarte; `EmptyLoyaltyCard` (Variante A/B, unverändert) wenn nichts hinzugefügt; `_PointsFullCard` (Platzhalter) wenn Punkte aktiv.
- **`_DeckPage`**: gemeinsame Hülle (abgerundet, Schatten, `LayoutBuilder`+`SingleChildScrollView`+`ConstrainedBox(minHeight)`) für alle Nicht-Hauptkarten — **behebt den Overflow-Bug endgültig**, da Inhalt bei knappem Platz jetzt intern scrollt statt zu überlaufen, egal wie hoch/niedrig das Gerät ist.

## Gelöscht
`walletBoardingPassCard.dart` (v1, komplett ersetzt durch `walletStoreDeck.dart`), `walletHeader.dart` (schwebende Icon-Suche, ersetzt durch `AppSearchField` inline), `walletSortDropdown.dart` (Popup-Menü, ersetzt durch `AppPillSwitch`).

## Verifikation
- `flutter analyze lib/features/user/wallet` = **0 issues**.
- `flutter analyze lib` (gesamte App) = **0 issues** nach Re-Run (2 Fehler in `userDiscoverPage.dart` beim ersten Lauf waren bestätigt STALE Analyzer-State nach Datei-Löschungen — bekanntes Muster, siehe frühere Einträge in dieser Datei — verschwanden beim erneuten Analyze; nicht von dieser Änderung verursacht, Datei nicht angefasst).
- `flutter build web --release` = **√ Built buildweb** (76.3s, kompiliert einwandfrei).

## Bewusster Hinweis
`userDiscoverPage.dart`/`userDiscoverProvider.dart` sind außerhalb dieser Session verändert worden (lt. früherer System-Notiz von Nutzer/Linter) und NICHT Teil dieser Wallet-Arbeit — bei Bedarf separat prüfen, aktuell aber analyzer-sauber.

---

# Wallet — Feinschliff v3: Merchant-Navigation, QR-Vollbild, exakter Cover-Zuschnitt (2026-06-24)

## Änderungen
1. **Merchant-Profil-Navigation:** Tippen auf das Logo ODER den Namen in der Hauptkarte öffnet jetzt `UserPartnerDetailPage` (`_openMerchantProfile()` in `WalletStoreDeck`, nutzt den bereits geladenen `_merchant`). Beide Tap-Ziele nutzen denselben Callback `onOpenMerchant`.
2. **QR-Vollbild schöner:** Statt losem weißem Text unter der QR-Box jetzt EINE zusammenhängende weiße Karte (QR + `_FullscreenCodeChip` darunter, wie ein „Pass"), Merchant-Name als Kontext darüber, weicherer Schatten. Neuer `_FullscreenCodeChip` mit fest hellen Farben (nicht themeabhängig — sitzt immer auf der fest-weißen QR-Karte, unabhängig vom Dark Mode; Scan-Kontrast hat Vorrang vor Theme).
3. **Cover-Zuschnitt exakt wie im Merchant-Profil:** `_MainStoreCard` komplett umgebaut — vorher füllte das Cover die GANZE Kartenhöhe (`Stack fit:expand`), jetzt exakt wie in `userPartnerDetailPage.dart`s eigenem Profil-Hero: fixe Höhe **220px**, `BoxFit.cover`, gleicher leichter Scrim-Gradient (0.18/transparent/0.22), **92px rundes Logo überlappt die Unterkante** (bottom:-46), darunter Name (bold, zentriert) + Kategorie·Stadt (zentriert) — 1:1 dasselbe Layout-Muster wie das Profil, dadurch identischer sichtbarer Bildausschnitt. QR/Code/Aktionen füllen den Rest (jetzt `Expanded`+zentriert+scrollbar bei wenig Platz, kein `BackdropShelf`/dunkler Vollbild-Scrim mehr nötig).
4. **Entfernt:** `BackdropShelf`-Widget (nicht mehr gebraucht, da Cover nicht mehr die ganze Karte füllt).

## Verifikation
- `flutter analyze lib/features/user/wallet` = **0 issues**.
- `flutter analyze lib` (gesamte App) = **0 issues**.
- `flutter build web --release` = **√ Built buildweb** (83.2s, kompiliert einwandfrei).

## Bekannter, transparent kommunizierter Trade-off
Der Cover-Ausschnitt ist "exakt wie im Profil" nur soweit garantiert, wie die Container-BREITE der Wallet-Hauptkarte der Profilseiten-Breite entspricht (beide sind aber Mobile-Only, i. d. R. na­hezu Vollbreite abzüglich kleiner Margins) — bei `BoxFit.cover` bestimmt das Breite:Höhe-Verhältnis den sichtbaren Ausschnitt, nicht die absolute Pixelgröße. Gleiche Höhe (220) + ähnliche Breite ⇒ praktisch identischer Ausschnitt.
