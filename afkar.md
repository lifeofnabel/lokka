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
