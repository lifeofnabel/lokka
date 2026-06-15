# Geo Migration — Phase 1 Audit (Lokka)

> Status: **AUDIT ONLY**. No code changed, no key added/removed. Date: 2026-06-12.
> Scope note: the protocol was titled "QOUCHER" but the area/geo system lives in **Lokka**
> (this project). The Geoapify key `c2b55e47…` exists in **neither** Lokka nor qoucher —
> it is forward-looking infrastructure. Confirm target project before Phase 2.

---

## 0. Headline findings

1. **Every merchant is created with `lat: null, lng: null`** at registration
   (`features/auth/providers/authProvider.dart:408–409`). Coordinates are *never*
   auto-populated — distance discovery only works for merchants who manually add coords
   later. **This is the single most important gap.**
2. **`area` (district string) is the de-facto location signal** across models, filters,
   ranking and card display — but it's a manually maintained list (`chooser/areas`).
3. **The geo plumbing already exists** (geolocator, Haversine distance, radius presets,
   lat/lng fields) — it's just **starved of data** (null coords) and **not surfaced**
   (distance is computed for filtering but never shown on cards).
4. **Geoapify is not integrated anywhere** and the API key is present nowhere.

---

## 1. Geoapify key inventory (TEMPORARY infrastructure)

**Key `c2b55e47e79943cb910f3916df12086c`: found in 0 files** (searched `.dart/.yaml/.json/.env/.html/.js`, both Lokka and qoucher). It is not yet wired.

Recommended placement (mark TEMPORARY, do **not** commit the real key):
| Step | Location | Note |
|---|---|---|
| Add var | `.env` → `GEOAPIFY_API_KEY=…` | gitignored; `.env.example` gets a placeholder |
| Expose | `lib/core/config/environmentConfig.dart` → `static String get geoapifyApiKey => dotenv.env['GEOAPIFY_API_KEY'] ?? ''` | alongside existing Cloudinary getters |
| Build | production: `--dart-define GEOAPIFY_API_KEY=…` | keeps key out of the bundle where possible |
| **Final target** | **Backend proxy** (Cloudflare Worker, same pattern as the existing push sender) that calls Geoapify server-side | the client never holds the key in production |

> Action for the team: this stays **temporary** until the proxy exists. Add a
> `// TODO: move to backend-proxied geocoding before production` next to the getter.

---

## 2. Existing geo infrastructure — KEEP / REUSE

| Item | File | Verdict |
|---|---|---|
| `geolocator` (device GPS + permission) | `pubspec.yaml`, `userDiscoverService.resolveLocation()`, `userPartnersPage._requestLocation()` | **Keep** — system of record for user lat/lng |
| Haversine `_distanceKm()` ×2 | `userDiscoverProvider.dart:283`, `userPartnersProvider.dart:235` | **Keep**, but **extract to one shared `LocationUtils`** |
| Radius presets (1/3/5/10/25 km) | discover filter sheet, `userPartnersPage` | **Keep** |
| Merchant `lat`/`lng` fields | `merchantModel`, `publicMerchantModel`, `publicMerchantUserModel` | **Keep** — just need to be *populated* |
| `PostalCodeService` + `assets/data/frankfurtPostalCodes.json` | `core/services/postalCodeService.dart` | Keep as **offline fallback** (FFM-only today) |
| `flutter_map` (installed, **unused**) | `pubspec.yaml` | Reserve for Phase-2 map view, or remove |
| `latlong2` (installed) | `pubspec.yaml` | Verify usage; remove if dead |

---

## 3. LEGACY GEO SYSTEM — area report (MIGRATE)

Real geographic-area usages (table-seating "areas", `SafeArea`, `textarea` are **excluded** — not geographic).

### Data model
| Item | File:line | Purpose | Migration path | Complexity |
|---|---|---|---|---|
| `FirebasePaths.areas` | `core/constants/firebasePaths.dart:6` | path to manually maintained area list | remove; derive city/region from coords | low |
| `MerchantModel.area` (required) | `core/models/merchantModel.dart:27,61…` | district label | deprecate; populate `region` from reverse-geocode | medium |
| `PublicMerchantUserModel.area` | `…/discover/models/publicMerchantUserModel.dart:6,28…` | card display + filter | keep for compat, fill from reverse-geocode; filter by distance | low |
| `FeedPostModel.merchantArea` | `…/feed/models/feedPostModel.dart:7,47…` | denormalized on every post | drop or fill from coords; add `merchantLat/Lng` instead | low–med |
| `WalletCardModel.merchantArea` | `…/wallet/models/walletCardModel.dart:6,22…` | wallet status line | show reverse-geocoded city | low |
| `AppUserModel.interestAreas` | `core/models/appUserModel.dart:29,57…` | For-You boost | → `interestCities`/distance-pref; update survey | medium |

### Services / providers
| Item | File:line | Migration path | Complexity |
|---|---|---|---|
| `firestoreService.loadChooserAreas()` | `core/services/firestoreService.dart:123` | remove; address geocoding replaces the dropdown | medium |
| `merchantToolsService.loadChooserAreas()` | `…/tools/services/merchantToolsService.dart:41` | remove | low |
| `UserDiscoverProvider` area filter + `_personalScore` area boost | `…/discover/providers/userDiscoverProvider.dart:27,202,257…` | distance filter + distance/city boost | **high** |
| `UserPartnersProvider` area filter | `…/partners/providers/userPartnersProvider.dart:26,42…` | distance/city filter | medium |
| `UserFeedService.feedStream(area)` + `UserFeedProvider._selectedArea` | `…/feed/services/userFeedService.dart:18`, `…/feed/providers/userFeedProvider.dart:17` | radius/city filter | medium |
| `UserDiscoverService.loadInterests()` | `…/discover/services/userDiscoverService.dart:85` | return cities not areas | low |
| `merchantFeedCreateService` writes `merchantArea` | `…/feedManager/services/merchantFeedCreateService.dart:126` | denormalize coords/region at post time | low |
| `userWalletService` writes `merchantArea` | `…/wallet/services/userWalletService.dart:74` | use reverse-geocoded region | low |
| `publicShopService` `merchantArea` | `…/public/shop/services/publicShopService.dart:116` | reverse-geocoded region | low |

### UI (area dropdowns, chips, labels)
| Item | File:line | Migration path | Complexity |
|---|---|---|---|
| Merchant register **area dropdown + fallback** | `…/auth/pages/merchantRegisterPage.dart:84–97,208–223` | replace with address → geocode (no area picker) | **high** |
| Shop settings **area selector** | `…/merchant/shopSettings/pages/merchantShopSettingsPage.dart:80,248…` | derive region from address; re-geocode on save | **high** |
| Onboarding survey **area checkboxes** | `…/user/onboarding/pages/onboardingSurveyPage.dart:40,142…` | city/region selection | medium |
| Discover filter sheet **area chip group** | `…/discover/pages/userDiscoverPage.dart:452–552` | distance-first filters; demote/remove area | medium |
| Partners filter sheet **area chips** | `…/partners/pages/userPartnersPage.dart:526–598` | distance/city filter | medium |
| Card area labels | `discoverCard.dart:84`, `partnerCard.dart:137,287`, `walletCard.dart:109`, `walletDetailHeader.dart:60`, `feedDealCard.dart:242`, `userFeedDetailPage.dart:285`, `meinePartnerPage.dart:176` | show distance ("~1.2 km") and/or reverse-geocoded city | low (each) |
| Search hint "…oder Area" | `userDiscoverPage` filter | → "…oder Stadt" | trivial |

### DO NOT TOUCH (correctly excluded false-positives)
`TableAreaModel` / table seating zones (`merchantTableAreas`, `MerchantTablesPage`, tools provider) — physical zones inside one shop, **not** geographic. `SafeArea`, `textarea`.

---

## 4. Address & coordinates model — current vs. target

**Current** (`MerchantModel`): `street`, `houseNumber`, `postalCode`, `city`, `country` (default "Deutschland"), **`address` and `fullAddress` are duplicated** (built identically), `area` (required), `lat?`/`lng?` (**null at registration**).

**Target**
```
merchant {
  address { street, houseNumber, postalCode, city, country, formattedAddress }
  location { lat, lng }            // ALWAYS populated via Geoapify
}
```
Gaps: (1) coords auto-populated on address submit; (2) collapse `address`+`fullAddress` → one `formattedAddress` (from Geoapify `formatted`); (3) `area` becomes display-only (reverse-geocoded) or removed; (4) `_shopProfileComplete()` should optionally **require** coords before `isPublic`.

---

## 5. Proposed target architecture

- **`GeoapifyService`** (new): `forwardGeocode(addressParts) → {lat,lng,formatted,city,postcode}` and `reverseGeocode(lat,lng) → {formatted,city,postcode}`. Endpoint `https://api.geoapify.com/v1/geocode/search`. Key via `EnvironmentConfig.geoapifyApiKey`.
- **`LocationUtils`** (new): single Haversine + a `distanceLabel(m)` formatter ("350 m", "1,2 km", "4,8 km"). Replaces the 2 duplicate `_distanceKm`.
- **Merchant onboarding/edit**: user types street/number/postal/city → Geoapify validates + returns coords + formatted address → saved silently. **No lat/lng fields, no GIS jargon** shown.
- **User location**: optional. Permission granted → geolocator → reverse-geocode for a friendly label. Permission denied → **manual address input** (geocoded) instead of forcing Frankfurt. App never unusable.
- **Discovery = distance-first**: distance labels on every card, **sort by proximity** when radius active, radius/distance filters replace area chips, For-You score blends proximity (`base + max(0, 1000 − dist_km·100)`).
- **Backfill**: one-time job forward-geocodes existing merchants' stored addresses → populate `lat/lng` + `formattedAddress` in both `merchants` and `publicMerchants`.

---

## 6. Migration plan (phased, low-risk)

- **Phase 1 — Audit** ✅ (this document).
- **Phase 2 — Infrastructure**: `GeoapifyService`, env key getter (TEMPORARY), `LocationUtils`, model consolidation (`formattedAddress`, `location`). No behavior change yet.
- **Phase 3 — Data migration**: backfill coords for existing merchants from addresses; validate; add coords to `_shopProfileComplete()`.
- **Phase 4 — Application migration**: onboarding + shop-settings geocoding; distance labels + sort; area→distance in discover/partners/feed filters; manual-address fallback; survey cities.
- **Phase 5 — Legacy removal**: delete `chooser/areas` + `loadChooserAreas`, area dropdowns/filters, dedupe `address`/`fullAddress`, retire interestAreas.

### Risks
- **Key security** — temporary in `.env`; move to backend proxy before launch.
- **Firestore scale** — client-side Haversine is fine now; add GeoHash index only if the dataset grows.
- **Backward compatibility** — keep `area` populated (reverse-geocoded) through Phases 2–4 so existing queries/UI don't break; remove only in Phase 5.
- **Geoapify quota/failures** — keep `PostalCodeService`/FFM JSON as offline fallback; cache geocode results.
- **Copy** — many "in deiner Nähe" / area labels become distance labels; update i18n.
