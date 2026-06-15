/**
 * Lokka Web-Push Sender — Cloudflare Worker (kostenlos).
 * Cron findet ungepushte Notifications in Firestore und sendet sie via FCM HTTP v1.
 *
 * Setup siehe README.md in diesem Ordner.
 * Voraussetzung: Notifications werden mit `pushed: false` angelegt (App-Client).
 */

const SCOPES = [
  'https://www.googleapis.com/auth/datastore',
  'https://www.googleapis.com/auth/firebase.messaging',
].join(' ');

export default {
  async scheduled(event, env) {
    await run(env);
  },
  async fetch(request, env) {
    await run(env);
    return new Response('Lokka push run complete');
  },
};

async function run(env) {
  const sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
  const projectId = sa.project_id;
  const accessToken = await getAccessToken(sa);

  const pending = await queryPending(projectId, accessToken);
  for (const item of pending) {
    const tokens = await getUserTokens(projectId, accessToken, item.uid);
    for (const token of tokens) {
      try {
        await sendFcm(projectId, accessToken, token, item);
      } catch (_) {
        // Einzelne Token-Fehler (z. B. abgelaufen) ignorieren.
      }
    }
    await markPushed(item.path, accessToken);
  }
}

// ── Firestore: ungepushte Notifications (collectionGroup) ──────────────────────
async function queryPending(projectId, accessToken) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId: 'notifications', allDescendants: true }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'pushed' },
          op: 'EQUAL',
          value: { booleanValue: false },
        },
      },
      limit: 200,
    },
  };
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const rows = await res.json();
  const out = [];
  for (const row of rows) {
    if (!row.document) continue;
    const path = row.document.name; // .../documents/users/{uid}/notifications/{id}
    const match = path.match(/users\/([^/]+)\/notifications\//);
    const f = row.document.fields || {};
    out.push({
      path,
      uid: match ? match[1] : '',
      title: (f.title && f.title.stringValue) || 'Lokka',
      body: (f.body && f.body.stringValue) || '',
      route: (f.route && f.route.stringValue) || '',
    });
  }
  return out;
}

async function getUserTokens(projectId, accessToken, uid) {
  if (!uid) return [];
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return [];
  const doc = await res.json();
  const values =
    (doc.fields &&
      doc.fields.fcmTokens &&
      doc.fields.fcmTokens.arrayValue &&
      doc.fields.fcmTokens.arrayValue.values) ||
    [];
  return values.map((v) => v.stringValue).filter(Boolean);
}

async function sendFcm(projectId, accessToken, token, item) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const message = {
    message: {
      token,
      notification: { title: item.title, body: item.body },
      data: item.route ? { route: item.route } : {},
      webpush: item.route ? { fcm_options: { link: item.route } } : {},
    },
  };
  await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(message),
  });
}

async function markPushed(path, accessToken) {
  const url = `https://firestore.googleapis.com/v1/${path}?updateMask.fieldPaths=pushed`;
  await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: { pushed: { booleanValue: true } } }),
  });
}

// ── OAuth: Service-Account-JWT → Access Token (Web Crypto, RS256) ──────────────
async function getAccessToken(sa) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: sa.client_email,
    scope: SCOPES,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const enc = (obj) => b64url(new TextEncoder().encode(JSON.stringify(obj)));
  const unsigned = `${enc(header)}.${enc(claim)}`;
  const key = await importKey(sa.private_key);
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(new Uint8Array(sig))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:
      'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt,
  });
  const json = await res.json();
  return json.access_token;
}

async function importKey(pem) {
  const body = pem
    .replace(/-----[^-]+-----/g, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

function b64url(bytes) {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
