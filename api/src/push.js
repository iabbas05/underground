// Firebase Cloud Messaging (HTTP v1) sender. Does nothing until the FCM_SERVICE_ACCOUNT secret
// (the JSON key of a Firebase service account) is set, so it is safe to call everywhere.
const enc = new TextEncoder();
const b64u = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
let cached = { token: null, exp: 0 };

async function accessToken(sa) {
  if (cached.token && cached.exp > Date.now() + 60000) return cached.token;
  const now = Math.floor(Date.now() / 1000);
  const head = b64u(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claim = b64u(enc.encode(JSON.stringify({ iss: sa.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 })));
  const pem = sa.private_key.replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, '');
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = b64u(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(`${head}.${claim}`)));
  const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${head}.${claim}.${sig}` });
  const j = await r.json();
  if (!j.access_token) throw new Error('FCM auth failed');
  cached = { token: j.access_token, exp: Date.now() + (j.expires_in || 3600) * 1000 };
  return cached.token;
}

export const pushEnabled = (env) => !!env.FCM_SERVICE_ACCOUNT;

// Sends one notification to a list of device tokens; returns the tokens FCM says are dead so callers can delete them.
export async function sendPush(env, tokens, title, body) {
  if (!pushEnabled(env) || !tokens.length) return [];
  let sa; try { sa = JSON.parse(env.FCM_SERVICE_ACCOUNT); } catch { return []; }
  let at; try { at = await accessToken(sa); } catch { return []; }
  const dead = [];
  for (let i = 0; i < tokens.length; i += 20) {
    await Promise.all(tokens.slice(i, i + 20).map(async (token) => {
      try {
        const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
          method: 'POST', headers: { Authorization: `Bearer ${at}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: { token, notification: { title, body }, android: { priority: 'HIGH' } } }),
        });
        if (r.status === 404 || r.status === 400) dead.push(token);
      } catch { /* network hiccup: skip */ }
    }));
  }
  return dead;
}

export async function pushToMembers(env, memberIds, title, body) {
  if (!pushEnabled(env) || !memberIds.length) return;
  const tokens = new Set();
  for (let i = 0; i < memberIds.length; i += 50) {
    const ids = memberIds.slice(i, i + 50); const ph = ids.map(() => '?').join(',');
    const rows = (await env.DB.prepare(`SELECT token FROM device_tokens WHERE member_id IN (${ph}) OR account_id IN (SELECT id FROM accounts WHERE member_id IN (${ph}))`).bind(...ids, ...ids).all()).results;
    rows.forEach((r) => tokens.add(r.token));
  }
  const dead = await sendPush(env, [...tokens], title, body);
  for (const t of dead) await env.DB.prepare('DELETE FROM device_tokens WHERE token=?').bind(t).run();
}

export async function pushToAccount(env, accountId, title, body) {
  if (!pushEnabled(env)) return;
  const tokens = (await env.DB.prepare('SELECT token FROM device_tokens WHERE account_id=?').bind(accountId).all()).results.map((r) => r.token);
  const dead = await sendPush(env, tokens, title, body);
  for (const t of dead) await env.DB.prepare('DELETE FROM device_tokens WHERE token=?').bind(t).run();
}
