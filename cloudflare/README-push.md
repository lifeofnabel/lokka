# Lokka Web-Push (Cloudflare Worker)

Kostenloser Sender für FCM-Web-Push. Ein Cron findet ungepushte Notifications in
Firestore (`users/{uid}/notifications` mit `pushed == false`) und verschickt sie
an die `fcmTokens` des Nutzers. Danach wird `pushed: true` gesetzt.

## Einrichtung
1. **Service-Account**: Firebase Console → Projekteinstellungen → *Dienstkonten*
   → „Neuen privaten Schlüssel generieren" (JSON herunterladen).
2. **Secret setzen**:
   ```
   wrangler secret put FIREBASE_SERVICE_ACCOUNT
   ```
   und den **kompletten JSON-Inhalt** einfügen.
3. **wrangler.toml**:
   ```toml
   name = "lokka-push"
   main = "lokka-push-worker.js"
   compatibility_date = "2024-01-01"

   [triggers]
   crons = ["*/5 * * * *"]   # alle 5 Minuten
   ```
4. **Deploy**: `wrangler deploy`
5. **Testen**: Worker-URL im Browser öffnen → führt sofort einen Lauf aus.

## Voraussetzungen im Client (bereits gebaut)
- `web/firebase-messaging-sw.js` mit eurer Firebase-Web-Config.
- `AppConfig.fcmVapidKey` gefüllt (Firebase Console → Cloud Messaging →
  *Web Push certificates*).
- Notifications werden mit `pushed: false` angelegt (erledigt der App-Client).
- Nutzer-Token liegen unter `users/{uid}.fcmTokens` (schreibt der App-Client).

Der Worker liest/schreibt serverseitig über den Service-Account und umgeht damit
die Firestore-Rules — es sind also keine zusätzlichen Rules nötig.
