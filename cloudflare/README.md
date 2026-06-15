# Lokka Cloudflare Worker fuer KI-Vorschlaege

Dieser Worker schuetzt den OpenAI-Key vor Flutter Web. Der Key gehoert niemals in `.env` der App, weil Web-Bundles fuer Nutzer sichtbar sind.

## Worker Secrets

In Cloudflare setzen:

```text
OPENAI_API_KEY
OPENAI_MODEL
```

`OPENAI_MODEL` kann leer bleiben, dann nutzt der Worker seinen Fallback.

## Wrangler

Die Worker-Konfig liegt in `cloudflare/wrangler.toml` und ist auf deinen Cloudflare Account gesetzt.

Der Cloudflare API Token gehoert nicht in dieses Repository. Wenn du lokal per Wrangler deployen willst, setze ihn nur in deiner lokalen Umgebung:

```text
CLOUDFLARE_API_TOKEN=dein_cloudflare_api_token
```

## App Endpoint

Nach dem Deployment die Worker-URL in Lokka eintragen:

```text
AI_SUGGESTION_ENDPOINT=https://dein-worker.deine-zone.workers.dev
```

## Hinweis

Wenn ein API-Key einmal in Chat, Browser oder Logs sichtbar war, bitte im Anbieter-Dashboard neu erstellen und den alten Key sperren.
