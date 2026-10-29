// Apple Wallet pass (.pkpass) generator. Needs these Worker secrets once you have an Apple Developer account:
//   PASS_TYPE_ID  (e.g. pass.com.underground.member)   APPLE_TEAM_ID   (10 characters)
//   PASS_CERT     (Pass Type ID certificate, PEM)       PASS_KEY        (its private key, PEM)
//   PASS_WWDR     (Apple WWDR intermediate certificate, PEM)
// Without them the endpoint answers 501 and everything else keeps working.
import forge from 'node-forge';
import { zipSync, strToU8 } from 'fflate';
import { ICONS } from './icons.js';

const b64ToBytes = (b64) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
function sha1Bytes(u8) {
  const md = forge.md.sha1.create();
  let s = '';
  for (let i = 0; i < u8.length; i += 8192) s += String.fromCharCode(...u8.subarray(i, i + 8192));
  md.update(s, 'raw');
  return md.digest().toHex();
}

export function passJson(env, m, code) {
  const exp = `${m.end_date}T23:59:59+03:00`;
  return {
    formatVersion: 1,
    passTypeIdentifier: env.PASS_TYPE_ID,
    teamIdentifier: env.APPLE_TEAM_ID,
    serialNumber: `ug-${m.id}-v${m.pass_ver}`,
    organizationName: 'UNDERGROUND',
    description: 'UNDERGROUND membership',
    logoText: 'UNDERGROUND',
    foregroundColor: 'rgb(244,242,248)',
    backgroundColor: 'rgb(20,18,27)',
    labelColor: 'rgb(183,155,255)',
    expirationDate: exp,
    voided: !!m.blocked,
    barcodes: [{ format: 'PKBarcodeFormatQR', message: code, messageEncoding: 'iso-8859-1', altText: `ID ${m.id}` }],
    generic: {
      primaryFields: [{ key: 'name', label: 'MEMBER', value: m.name }],
      secondaryFields: [
        { key: 'plan', label: 'PLAN', value: m.plan_name || 'Membership' },
        { key: 'ends', label: 'VALID UNTIL', value: m.end_date },
      ],
      auxiliaryFields: [{ key: 'branch', label: 'HOME BRANCH', value: m.branch_name || '-' }],
      backFields: [{ key: 'info', label: 'How to enter', value: 'Show this pass at the gate and scan the code.' }],
    },
  };
}

export async function buildPkpass(env, m, code) {
  const need = ['PASS_TYPE_ID', 'APPLE_TEAM_ID', 'PASS_CERT', 'PASS_KEY', 'PASS_WWDR'];
  const missing = need.filter((k) => !env[k]);
  if (missing.length) {
    return new Response(JSON.stringify({ error: 'Apple Wallet is not set up yet', missing }), { status: 501, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } });
  }
  const files = { 'pass.json': strToU8(JSON.stringify(passJson(env, m, code))) };
  for (const [name, b64] of Object.entries(ICONS)) files[name] = b64ToBytes(b64);
  const manifest = {};
  for (const [name, data] of Object.entries(files)) manifest[name] = sha1Bytes(data);
  const manifestBytes = strToU8(JSON.stringify(manifest));

  const cert = forge.pki.certificateFromPem(env.PASS_CERT);
  const key = forge.pki.privateKeyFromPem(env.PASS_KEY);
  const wwdr = forge.pki.certificateFromPem(env.PASS_WWDR);
  const p7 = forge.pkcs7.createSignedData();
  p7.content = forge.util.createBuffer(String.fromCharCode(...manifestBytes), 'raw');
  p7.addCertificate(cert);
  p7.addCertificate(wwdr);
  p7.addSigner({
    key, certificate: cert, digestAlgorithm: forge.pki.oids.sha256,
    authenticatedAttributes: [
      { type: forge.pki.oids.contentType, value: forge.pki.oids.data },
      { type: forge.pki.oids.messageDigest },
      { type: forge.pki.oids.signingTime, value: new Date() },
    ],
  });
  p7.sign({ detached: true });
  const der = forge.asn1.toDer(p7.toAsn1()).getBytes();
  const signature = Uint8Array.from(der, (c) => c.charCodeAt(0));

  const zip = zipSync({ ...files, 'manifest.json': manifestBytes, signature }, { level: 6 });
  return new Response(zip, { headers: { 'Content-Type': 'application/vnd.apple.pkpass', 'Content-Disposition': `attachment; filename="underground-${m.id}.pkpass"`, 'Cache-Control': 'no-store' } });
}
