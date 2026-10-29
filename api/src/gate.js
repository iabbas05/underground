// Gate access + member pass codes.
// Codes:  UGD.<memberId>.<passVer>.<window>.<sig>  rotating (30 s windows) - shown in the web pass page / app
//         UGS.<memberId>.<passVer>.<sig>            static - printed on the Wallet pass (can be revoked with passVer / block)
const enc = new TextEncoder();
const WINDOW = 30;

async function mac(secret, text) {
  const key = await crypto.subtle.importKey('raw', enc.encode(secret + ':pass'), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(text));
  return [...new Uint8Array(sig)].slice(0, 8).map((b) => b.toString(16).padStart(2, '0')).join('');
}
const winNow = () => Math.floor(Date.now() / 1000 / WINDOW);

export async function staticCode(secret, id, ver) {
  return `UGS.${id}.${ver}.${await mac(secret, `S.${id}.${ver}`)}`;
}
export async function dynamicCode(secret, id, ver, win = winNow()) {
  return `UGD.${id}.${ver}.${win}.${await mac(secret, `D.${id}.${ver}.${win}`)}`;
}
export const secondsLeftInWindow = () => WINDOW - (Math.floor(Date.now() / 1000) % WINDOW);

function same(a, b) {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

/** Returns { ok, id, ver, method } or { ok:false, reason } */
export async function readCode(secret, code) {
  const p = String(code || '').trim().split('.');
  if (p[0] === 'UGS' && p.length === 4) {
    const id = Number(p[1]), ver = Number(p[2]);
    if (!Number.isInteger(id) || !Number.isInteger(ver)) return { ok: false, reason: 'bad_code' };
    return same(p[3], await mac(secret, `S.${id}.${ver}`)) ? { ok: true, id, ver, method: 'wallet' } : { ok: false, reason: 'bad_code' };
  }
  if (p[0] === 'UGD' && p.length === 5) {
    const id = Number(p[1]), ver = Number(p[2]), win = Number(p[3]);
    if (![id, ver, win].every(Number.isInteger)) return { ok: false, reason: 'bad_code' };
    if (!same(p[4], await mac(secret, `D.${id}.${ver}.${win}`))) return { ok: false, reason: 'bad_code' };
    if (Math.abs(winNow() - win) > 2) return { ok: false, reason: 'old_code' }; // about 60-90 s tolerance
    return { ok: true, id, ver, method: 'app' };
  }
  return { ok: false, reason: 'bad_code' };
}
