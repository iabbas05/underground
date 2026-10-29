// UNDERGROUND admin API - Cloudflare Worker + D1
// Roles: admin (everything) and staff (check-in, register members, record payments, attendance, schedule).

import { BACKOFFICE_HTML } from './backoffice.js';
import { staticCode, dynamicCode, readCode, secondsLeftInWindow } from './gate.js';
import { PASS_PAGE_HTML } from './passpage.js';
import { ICONS } from './icons.js';
import * as bk from './booking.js';
import { buildPkpass } from './wallet.js';

const enc = new TextEncoder();
const METHODS = ['cash', 'card', 'benefit', 'transfer'];
const KINDS = ['subscription', 'trial', 'recovery', 'nutrition', 'other'];

/* ---------- helpers ---------- */
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization,Content-Type,X-Gate-Key',
};
const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json', ...CORS } });
class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const fail = (status, message) => { throw new HttpError(status, message); };

const toHex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
const fromHex = (hex) => new Uint8Array(hex.match(/.{2}/g).map((h) => parseInt(h, 16)));
const b64u = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const b64uToBytes = (s) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));

async function hashPassword(password, saltHex) {
  const salt = saltHex ? fromHex(saltHex) : crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations: 100000 }, key, 256);
  return `${toHex(salt)}:${toHex(bits)}`;
}
async function verifyPassword(password, stored) {
  const [saltHex] = stored.split(':');
  const again = await hashPassword(password, saltHex);
  return again === stored;
}
async function hmacKey(secret) {
  return crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}
async function signToken(payload, secret) {
  const body = b64u(enc.encode(JSON.stringify(payload)));
  const sig = await crypto.subtle.sign('HMAC', await hmacKey(secret), enc.encode(body));
  return `${body}.${b64u(sig)}`;
}
async function readToken(token, secret) {
  const [body, sig] = (token || '').split('.');
  if (!body || !sig) return null;
  const ok = await crypto.subtle.verify('HMAC', await hmacKey(secret), b64uToBytes(sig), enc.encode(body));
  if (!ok) return null;
  const payload = JSON.parse(new TextDecoder().decode(b64uToBytes(body)));
  return payload.exp > Date.now() / 1000 ? payload : null;
}

// Bahrain is UTC+3, no daylight saving.
const nowBH = () => new Date(Date.now() + 3 * 3600 * 1000);
const today = () => nowBH().toISOString().slice(0, 10);
const nowTime = () => nowBH().toISOString().slice(0, 16).replace('T', ' ');
const isDate = (s) => typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(s));
const isMonth = (s) => typeof s === 'string' && /^\d{4}-\d{2}$/.test(s);

function addMonths(dateStr, months) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const total = m - 1 + months;
  const ny = y + Math.floor(total / 12);
  const nm = total % 12;
  const dim = new Date(Date.UTC(ny, nm + 1, 0)).getUTCDate();
  const nd = Math.min(d, dim);
  return `${ny}-${String(nm + 1).padStart(2, '0')}-${String(nd).padStart(2, '0')}`;
}
function addDays(dateStr, days) {
  const dt = new Date(`${dateStr}T00:00:00Z`);
  dt.setUTCDate(dt.getUTCDate() + days);
  return dt.toISOString().slice(0, 10);
}
const daysBetween = (a, b) => Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86400000);

function withStatus(m) {
  const left = daysBetween(today(), m.end_date);
  return { ...m, days_left: left, status: m.blocked ? 'blocked' : left < 0 ? 'expired' : left <= 7 ? 'expiring' : 'active' };
}
const num = (v, name) => {
  const n = Number(v);
  if (!Number.isFinite(n)) fail(400, `${name} must be a number`);
  return n;
};
const str = (v, name, { required = true, max = 120 } = {}) => {
  const s = typeof v === 'string' ? v.trim() : '';
  if (required && !s) fail(400, `${name} is required`);
  if (s.length > max) fail(400, `${name} is too long`);
  return s;
};

/* ---------- auth ---------- */
async function authenticate(request, env) {
  const header = request.headers.get('Authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  const payload = await readToken(token, env.JWT_SECRET);
  if (!payload) fail(401, 'Not signed in');
  const user = await env.DB.prepare('SELECT id,name,username,role,branch_id,base_salary,active FROM users WHERE id=?').bind(payload.uid).first();
  if (!user || !user.active) fail(401, 'Account disabled');
  return user;
}
const needAdmin = (user) => { if (user.role !== 'admin') fail(403, 'Admin only'); };

/* ---------- routes ---------- */
const routes = [];
const route = (method, pattern, handler, { auth = true, admin = false } = {}) => {
  const keys = [];
  const re = new RegExp('^' + pattern.replace(/:([a-z]+)/g, (_, k) => { keys.push(k); return '([^/]+)'; }) + '$');
  routes.push({ method, re, keys, handler, auth, admin });
};

route('GET', '/api/health', async () => ({ ok: true, today: today() }), { auth: false });

route('POST', '/api/setup', async ({ body, env }) => {
  if (!env.SETUP_KEY || body.key !== env.SETUP_KEY) fail(403, 'Wrong setup key');
  const row = await env.DB.prepare('SELECT COUNT(*) AS c FROM users').first();
  if (row.c > 0) fail(409, 'Setup already done');
  const name = str(body.name, 'name');
  const username = str(body.username, 'username').toLowerCase();
  const password = str(body.password, 'password', { max: 100 });
  if (password.length < 8) fail(400, 'Password must be at least 8 characters');
  await env.DB.prepare("INSERT INTO users (name,username,pass_hash,role) VALUES (?,?,?, 'admin')")
    .bind(name, username, await hashPassword(password)).run();
  return { ok: true };
}, { auth: false });

route('POST', '/api/login', async ({ body, env }) => {
  const username = str(body.username, 'username').toLowerCase();
  const password = str(body.password, 'password', { max: 100 });
  const user = await env.DB.prepare('SELECT * FROM users WHERE username=?').bind(username).first();
  if (!user || !user.active || !(await verifyPassword(password, user.pass_hash))) fail(401, 'Wrong username or password');
  const token = await signToken({ uid: user.id, exp: Math.floor(Date.now() / 1000) + 30 * 86400 }, env.JWT_SECRET);
  return { token, user: { id: user.id, name: user.name, username: user.username, role: user.role, branch_id: user.branch_id } };
}, { auth: false });

route('GET', '/api/me', async ({ user }) => user);

route('GET', '/api/branches', async ({ env }) => (await env.DB.prepare('SELECT * FROM branches ORDER BY id').all()).results);

/* plans */
route('GET', '/api/plans', async ({ env }) => (await env.DB.prepare('SELECT * FROM plans WHERE active=1 ORDER BY id').all()).results);
route('PUT', '/api/plans/:id', async ({ env, params, body }) => {
  const price = num(body.price, 'price');
  if (price < 0) fail(400, 'price must be 0 or more');
  await env.DB.prepare('UPDATE plans SET price=? WHERE id=?').bind(price, params.id).run();
  return { ok: true };
}, { admin: true });

/* members */
route('GET', '/api/members', async ({ env, query }) => {
  const q = (query.get('q') || '').trim();
  const branch = query.get('branch_id');
  const status = query.get('status');
  const limit = Math.min(Number(query.get('limit')) || 50, 200);
  const where = [];
  const args = [];
  if (q) { where.push('(m.name LIKE ? OR m.phone LIKE ?)'); args.push(`%${q}%`, `%${q}%`); }
  if (branch) { where.push('m.branch_id=?'); args.push(Number(branch)); }
  const t = today();
  if (status === 'active') { where.push('m.end_date>=?'); args.push(t); }
  if (status === 'expired') { where.push('m.end_date<?'); args.push(t); }
  if (status === 'expiring') { where.push('m.end_date BETWEEN ? AND ?'); args.push(t, addDays(t, 7)); }
  const sql = `SELECT m.*, p.name AS plan_name, p.name_ar AS plan_name_ar, b.name AS branch_name, b.name_ar AS branch_name_ar
    FROM members m LEFT JOIN plans p ON p.id=m.plan_id LEFT JOIN branches b ON b.id=m.branch_id
    ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY m.id DESC LIMIT ?`;
  const rows = (await env.DB.prepare(sql).bind(...args, limit).all()).results;
  return rows.map(withStatus);
});

route('GET', '/api/members/:id', async ({ env, params }) => {
  const m = await env.DB.prepare(`SELECT m.*, p.name AS plan_name, p.name_ar AS plan_name_ar, b.name AS branch_name, b.name_ar AS branch_name_ar
    FROM members m LEFT JOIN plans p ON p.id=m.plan_id LEFT JOIN branches b ON b.id=m.branch_id WHERE m.id=?`).bind(params.id).first();
  if (!m) fail(404, 'Member not found');
  const payments = (await env.DB.prepare('SELECT id,amount,method,kind,date,note FROM payments WHERE member_id=? ORDER BY id DESC LIMIT 20').bind(params.id).all()).results;
  return { ...withStatus(m), payments };
});

async function loadPlan(env, id) {
  const plan = await env.DB.prepare('SELECT * FROM plans WHERE id=? AND active=1').bind(Number(id)).first();
  if (!plan) fail(400, 'Unknown plan');
  return plan;
}
function pickMethod(v) {
  if (!METHODS.includes(v)) fail(400, `method must be one of ${METHODS.join(', ')}`);
  return v;
}

route('POST', '/api/members', async ({ env, user, body }) => {
  const name = str(body.name, 'name');
  const phone = str(body.phone, 'phone', { max: 20 }).replace(/[\s-]/g, '');
  if (!/^\+?\d{6,15}$/.test(phone)) fail(400, 'Phone number looks wrong');
  const plan = await loadPlan(env, body.plan_id);
  const method = pickMethod(body.method);
  const branchId = user.role === 'admin' ? Number(body.branch_id) : user.branch_id;
  if (!branchId) fail(400, 'branch_id is required');
  const start = user.role === 'admin' && isDate(body.start_date) ? body.start_date : today();
  const end = plan.months === 0 ? start : addDays(addMonths(start, plan.months), 0);
  const amount = user.role === 'admin' && body.amount !== undefined ? num(body.amount, 'amount') : plan.price;
  const res = await env.DB.prepare('INSERT INTO members (name,phone,branch_id,plan_id,start_date,end_date,notes,created_by) VALUES (?,?,?,?,?,?,?,?)')
    .bind(name, phone, branchId, plan.id, start, end, str(body.notes, 'notes', { required: false, max: 300 }), user.id).run();
  const id = res.meta.last_row_id;
  await env.DB.prepare('INSERT INTO payments (member_id,branch_id,amount,method,kind,note,date,created_by) VALUES (?,?,?,?,?,?,?,?)')
    .bind(id, branchId, amount, method, plan.months === 0 ? 'trial' : 'subscription', plan.name, today(), user.id).run();
  return { id, end_date: end, amount };
});

route('POST', '/api/members/:id/renew', async ({ env, user, params, body }) => {
  const m = await env.DB.prepare('SELECT * FROM members WHERE id=?').bind(params.id).first();
  if (!m) fail(404, 'Member not found');
  const plan = await loadPlan(env, body.plan_id);
  const method = pickMethod(body.method);
  const t = today();
  const start = m.end_date >= t ? addDays(m.end_date, 0) : t; // continue from the current end if still active
  const end = plan.months === 0 ? t : addMonths(start, plan.months);
  const amount = user.role === 'admin' && body.amount !== undefined ? num(body.amount, 'amount') : plan.price;
  const branchId = user.role === 'admin' ? (Number(body.branch_id) || m.branch_id) : user.branch_id || m.branch_id;
  await env.DB.prepare('UPDATE members SET plan_id=?, start_date=?, end_date=? WHERE id=?').bind(plan.id, start, end, m.id).run();
  await env.DB.prepare('INSERT INTO payments (member_id,branch_id,amount,method,kind,note,date,created_by) VALUES (?,?,?,?,?,?,?,?)')
    .bind(m.id, branchId, amount, method, plan.months === 0 ? 'trial' : 'subscription', `Renew: ${plan.name}`, t, user.id).run();
  return { id: m.id, end_date: end, amount };
});

// Freeze or extension: add days to the end date (admin).
route('POST', '/api/members/:id/extend', async ({ env, params, body }) => {
  const days = Math.trunc(num(body.days, 'days'));
  if (days < 1 || days > 400) fail(400, 'days must be between 1 and 400');
  const m = await env.DB.prepare('SELECT * FROM members WHERE id=?').bind(params.id).first();
  if (!m) fail(404, 'Member not found');
  const end = addDays(m.end_date, days);
  const note = str(body.note, 'note', { required: false, max: 200 });
  await env.DB.prepare('UPDATE members SET end_date=?, notes=? WHERE id=?')
    .bind(end, note ? `${m.notes ? m.notes + ' | ' : ''}+${days}d: ${note}` : m.notes, m.id).run();
  return { id: m.id, end_date: end };
}, { admin: true });

route('PUT', '/api/members/:id', async ({ env, params, body }) => {
  const name = str(body.name, 'name');
  const phone = str(body.phone, 'phone', { max: 20 });
  await env.DB.prepare('UPDATE members SET name=?, phone=?, notes=? WHERE id=?')
    .bind(name, phone, str(body.notes, 'notes', { required: false, max: 300 }), params.id).run();
  return { ok: true };
}, { admin: true });

/* payments */
route('GET', '/api/payments', async ({ env, user, query }) => {
  const where = [];
  const args = [];
  let from = query.get('from');
  let to = query.get('to');
  let branch = query.get('branch_id');
  if (user.role !== 'admin') { from = to = today(); branch = String(user.branch_id); }
  if (isDate(from)) { where.push('p.date>=?'); args.push(from); }
  if (isDate(to)) { where.push('p.date<=?'); args.push(to); }
  if (branch) { where.push('p.branch_id=?'); args.push(Number(branch)); }
  const rows = (await env.DB.prepare(`SELECT p.*, m.name AS member_name, b.name AS branch_name, b.name_ar AS branch_name_ar, u.name AS by_name
    FROM payments p LEFT JOIN members m ON m.id=p.member_id LEFT JOIN branches b ON b.id=p.branch_id LEFT JOIN users u ON u.id=p.created_by
    ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY p.id DESC LIMIT 300`).bind(...args).all()).results;
  return { total: rows.reduce((s, r) => s + r.amount, 0), items: rows };
});

route('POST', '/api/payments', async ({ env, user, body }) => {
  const amount = num(body.amount, 'amount');
  if (amount <= 0) fail(400, 'amount must be more than 0');
  const method = pickMethod(body.method);
  const kind = KINDS.includes(body.kind) ? body.kind : 'other';
  const branchId = user.role === 'admin' ? Number(body.branch_id) : user.branch_id;
  if (!branchId) fail(400, 'branch_id is required');
  const date = user.role === 'admin' && isDate(body.date) ? body.date : today();
  const res = await env.DB.prepare('INSERT INTO payments (member_id,branch_id,amount,method,kind,note,date,created_by) VALUES (?,?,?,?,?,?,?,?)')
    .bind(body.member_id ? Number(body.member_id) : null, branchId, amount, method, kind, str(body.note, 'note', { required: false, max: 200 }), date, user.id).run();
  return { id: res.meta.last_row_id };
});

route('DELETE', '/api/payments/:id', async ({ env, params }) => {
  await env.DB.prepare('DELETE FROM payments WHERE id=?').bind(params.id).run();
  return { ok: true };
}, { admin: true });

/* expenses (admin) */
route('GET', '/api/expenses', async ({ env, query }) => {
  const month = isMonth(query.get('month')) ? query.get('month') : today().slice(0, 7);
  const branch = query.get('branch_id');
  const rows = (await env.DB.prepare(`SELECT e.*, b.name AS branch_name, b.name_ar AS branch_name_ar FROM expenses e LEFT JOIN branches b ON b.id=e.branch_id
    WHERE substr(e.date,1,7)=? ${branch ? 'AND e.branch_id=?' : ''} ORDER BY e.date DESC, e.id DESC`).bind(...(branch ? [month, Number(branch)] : [month])).all()).results;
  return { total: rows.reduce((s, r) => s + r.amount, 0), items: rows };
}, { admin: true });

route('POST', '/api/expenses', async ({ env, user, body }) => {
  const amount = num(body.amount, 'amount');
  if (amount <= 0) fail(400, 'amount must be more than 0');
  const date = isDate(body.date) ? body.date : today();
  const res = await env.DB.prepare('INSERT INTO expenses (branch_id,category,amount,note,date,created_by) VALUES (?,?,?,?,?,?)')
    .bind(body.branch_id ? Number(body.branch_id) : null, str(body.category, 'category', { max: 40 }), amount, str(body.note, 'note', { required: false, max: 200 }), date, user.id).run();
  return { id: res.meta.last_row_id };
}, { admin: true });

route('DELETE', '/api/expenses/:id', async ({ env, params }) => {
  await env.DB.prepare('DELETE FROM expenses WHERE id=?').bind(params.id).run();
  return { ok: true };
}, { admin: true });

/* staff accounts (admin) */
route('GET', '/api/users', async ({ env }) =>
  (await env.DB.prepare('SELECT u.id,u.name,u.username,u.role,u.branch_id,u.base_salary,u.active,b.name AS branch_name,b.name_ar AS branch_name_ar FROM users u LEFT JOIN branches b ON b.id=u.branch_id ORDER BY u.role, u.name').all()).results,
{ admin: true });

route('POST', '/api/users', async ({ env, body }) => {
  const role = body.role === 'admin' ? 'admin' : 'staff';
  const username = str(body.username, 'username', { max: 40 }).toLowerCase();
  const password = str(body.password, 'password', { max: 100 });
  if (password.length < 8) fail(400, 'Password must be at least 8 characters');
  if (role === 'staff' && !body.branch_id) fail(400, 'branch_id is required for staff');
  try {
    const res = await env.DB.prepare('INSERT INTO users (name,username,pass_hash,role,branch_id,base_salary) VALUES (?,?,?,?,?,?)')
      .bind(str(body.name, 'name'), username, await hashPassword(password), role, body.branch_id ? Number(body.branch_id) : null, Number(body.base_salary) || 0).run();
    return { id: res.meta.last_row_id };
  } catch (e) {
    if (String(e).includes('UNIQUE')) fail(409, 'This username is already used');
    throw e;
  }
}, { admin: true });

route('PUT', '/api/users/:id', async ({ env, user, params, body }) => {
  const target = await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(params.id).first();
  if (!target) fail(404, 'User not found');
  const active = body.active === undefined ? target.active : body.active ? 1 : 0;
  if (target.id === user.id && !active) fail(400, 'You cannot disable your own account');
  await env.DB.prepare('UPDATE users SET name=?, branch_id=?, base_salary=?, active=? WHERE id=?')
    .bind(body.name ? str(body.name, 'name') : target.name, body.branch_id === undefined ? target.branch_id : (body.branch_id ? Number(body.branch_id) : null),
      body.base_salary === undefined ? target.base_salary : num(body.base_salary, 'base_salary'), active, target.id).run();
  if (body.password) {
    const pw = str(body.password, 'password', { max: 100 });
    if (pw.length < 8) fail(400, 'Password must be at least 8 characters');
    await env.DB.prepare('UPDATE users SET pass_hash=? WHERE id=?').bind(await hashPassword(pw), target.id).run();
  }
  return { ok: true };
}, { admin: true });

/* attendance */
route('GET', '/api/attendance/today', async ({ env, user }) => {
  const open = await env.DB.prepare('SELECT * FROM attendance WHERE user_id=? AND clock_out IS NULL ORDER BY id DESC LIMIT 1').bind(user.id).first();
  const last = await env.DB.prepare('SELECT * FROM attendance WHERE user_id=? AND date=? ORDER BY id DESC LIMIT 1').bind(user.id, today()).first();
  return { clocked_in: !!open, since: open ? open.clock_in : null, last };
});

route('POST', '/api/attendance/clock', async ({ env, user, body }) => {
  const open = await env.DB.prepare('SELECT * FROM attendance WHERE user_id=? AND clock_out IS NULL ORDER BY id DESC LIMIT 1').bind(user.id).first();
  if (body.action === 'in') {
    if (open) fail(409, 'Already clocked in');
    await env.DB.prepare('INSERT INTO attendance (user_id,branch_id,date,clock_in) VALUES (?,?,?,?)').bind(user.id, user.branch_id, today(), nowTime()).run();
    return { clocked_in: true };
  }
  if (body.action === 'out') {
    if (!open) fail(409, 'You are not clocked in');
    await env.DB.prepare('UPDATE attendance SET clock_out=? WHERE id=?').bind(nowTime(), open.id).run();
    return { clocked_in: false };
  }
  fail(400, "action must be 'in' or 'out'");
});

route('GET', '/api/attendance', async ({ env, query }) => {
  const month = isMonth(query.get('month')) ? query.get('month') : today().slice(0, 7);
  const rows = (await env.DB.prepare(`SELECT a.*, u.name AS user_name FROM attendance a JOIN users u ON u.id=a.user_id
    WHERE substr(a.date,1,7)=? ORDER BY a.id DESC`).bind(month).all()).results;
  const byUser = {};
  for (const r of rows) {
    const hours = r.clock_out ? (Date.parse(r.clock_out.replace(' ', 'T') + ':00Z') - Date.parse(r.clock_in.replace(' ', 'T') + ':00Z')) / 3600000 : 0;
    const u = (byUser[r.user_id] ||= { user_id: r.user_id, name: r.user_name, days: new Set(), hours: 0 });
    u.days.add(r.date);
    u.hours += hours;
  }
  return {
    month,
    summary: Object.values(byUser).map((u) => ({ user_id: u.user_id, name: u.name, days: u.days.size, hours: Math.round(u.hours * 10) / 10 })),
    items: rows,
  };
}, { admin: true });

/* salaries (admin) */
route('GET', '/api/salaries', async ({ env, query }) => {
  const month = isMonth(query.get('month')) ? query.get('month') : today().slice(0, 7);
  const rows = (await env.DB.prepare('SELECT s.*, u.name AS user_name FROM salaries s JOIN users u ON u.id=s.user_id WHERE s.month=? ORDER BY s.id DESC').bind(month).all()).results;
  return { month, total: rows.reduce((s, r) => s + r.amount, 0), items: rows };
}, { admin: true });

route('POST', '/api/salaries', async ({ env, user, body }) => {
  const amount = num(body.amount, 'amount');
  if (amount <= 0) fail(400, 'amount must be more than 0');
  if (!isMonth(body.month)) fail(400, 'month must look like 2026-10');
  const target = await env.DB.prepare('SELECT id FROM users WHERE id=?').bind(Number(body.user_id)).first();
  if (!target) fail(404, 'User not found');
  const res = await env.DB.prepare('INSERT INTO salaries (user_id,month,amount,note,date,created_by) VALUES (?,?,?,?,?,?)')
    .bind(target.id, body.month, amount, str(body.note, 'note', { required: false, max: 200 }), today(), user.id).run();
  return { id: res.meta.last_row_id };
}, { admin: true });

route('DELETE', '/api/salaries/:id', async ({ env, params }) => {
  await env.DB.prepare('DELETE FROM salaries WHERE id=?').bind(params.id).run();
  return { ok: true };
}, { admin: true });

/* schedule */
route('GET', '/api/schedule', async ({ env, user, query }) => {
  const branch = Number(query.get('branch_id')) || user.branch_id || 2;
  const audience = query.get('audience') === 'ladies' ? 'ladies' : 'men';
  const day = query.get('day') === null ? nowBH().getUTCDay() : Number(query.get('day'));
  const rows = (await env.DB.prepare('SELECT id,time,level,capacity FROM schedule WHERE branch_id=? AND audience=? AND day=? ORDER BY time').bind(branch, audience, day).all()).results;
  return { branch_id: branch, audience, day, rest_day: day === 5, items: rows };
});

/* reports (admin) */
route('GET', '/api/reports/summary', async ({ env, query }) => {
  const month = isMonth(query.get('month')) ? query.get('month') : today().slice(0, 7);
  const branch = query.get('branch_id') ? Number(query.get('branch_id')) : null;
  const db = env.DB;
  const b = branch; // null means all branches
  const income = await db.prepare('SELECT COALESCE(SUM(amount),0) AS v FROM payments WHERE substr(date,1,7)=?1 AND (?2 IS NULL OR branch_id=?2)').bind(month, b).first();
  const expenses = await db.prepare('SELECT COALESCE(SUM(amount),0) AS v FROM expenses WHERE substr(date,1,7)=?1 AND (?2 IS NULL OR branch_id=?2)').bind(month, b).first();
  const salaries = await db.prepare('SELECT COALESCE(SUM(s.amount),0) AS v FROM salaries s JOIN users u ON u.id=s.user_id WHERE s.month=?1 AND (?2 IS NULL OR u.branch_id=?2)').bind(month, b).first();
  const daily = (await db.prepare('SELECT date, SUM(amount) AS v FROM payments WHERE substr(date,1,7)=?1 AND (?2 IS NULL OR branch_id=?2) GROUP BY date ORDER BY date').bind(month, b).all()).results;
  const byKind = (await db.prepare('SELECT kind, SUM(amount) AS v FROM payments WHERE substr(date,1,7)=?1 AND (?2 IS NULL OR branch_id=?2) GROUP BY kind ORDER BY v DESC').bind(month, b).all()).results;
  const byMethod = (await db.prepare('SELECT method, SUM(amount) AS v FROM payments WHERE substr(date,1,7)=?1 AND (?2 IS NULL OR branch_id=?2) GROUP BY method ORDER BY v DESC').bind(month, b).all()).results;
  const branches = (await db.prepare(`SELECT br.id, br.name, br.name_ar,
      COALESCE((SELECT SUM(amount) FROM payments WHERE branch_id=br.id AND substr(date,1,7)=?1),0) AS income,
      COALESCE((SELECT SUM(amount) FROM expenses WHERE branch_id=br.id AND substr(date,1,7)=?1),0) AS expenses
    FROM branches br ORDER BY br.id`).bind(month).all()).results;
  const t = today();
  const active = await db.prepare('SELECT COUNT(*) AS c FROM members WHERE end_date>=?1 AND (?2 IS NULL OR branch_id=?2)').bind(t, b).first();
  const expiring = await db.prepare('SELECT COUNT(*) AS c FROM members WHERE end_date BETWEEN ?1 AND ?2 AND (?3 IS NULL OR branch_id=?3)').bind(t, addDays(t, 7), b).first();
  // "New" means first registered in that month (renewals move start_date, so use created_at).
  const fresh = await db.prepare('SELECT COUNT(*) AS c FROM members WHERE substr(created_at,1,7)=?1 AND (?2 IS NULL OR branch_id=?2)').bind(month, b).first();
  return {
    month, branch_id: branch,
    income: income.v, expenses: expenses.v, salaries: salaries.v,
    profit: income.v - expenses.v - salaries.v,
    daily, by_kind: byKind, by_method: byMethod, branches,
    members: { active: active.c, expiring_7d: expiring.c, new_this_month: fresh.c },
  };
}, { admin: true });


/* ---------- gate + member pass ---------- */
// A gate controller sends the secret header X-Gate-Key (the GATE_KEY secret). Staff/admin tokens work too (phone scanner).
async function gateCaller(request, env) {
  const k = request.headers.get('X-Gate-Key');
  if (k && env.GATE_KEY && k.length === env.GATE_KEY.length && k === env.GATE_KEY) return { gate: true, user: null };
  return { gate: false, user: await authenticate(request, env) };
}
async function logGate(env, row) {
  await env.DB.prepare('INSERT INTO gate_logs (member_id,branch_id,gate,result,reason,method,by_user,created_at) VALUES (?,?,?,?,?,?,?,?)')
    .bind(row.member_id ?? null, row.branch_id ?? null, row.gate || '', row.result, row.reason, row.method, row.by_user ?? null, nowTime()).run();
}

// NFC card number as sent by readers: hex only, upper case, no separators.
const normUid = (u) => String(u).replace(/[^0-9a-fA-F]/g, '').toUpperCase();
route('POST', '/api/gate/verify', async ({ request, env, body }) => {
  const caller = await gateCaller(request, env);
  const branchId = Number(body.branch_id) || caller.user?.branch_id || null;
  const gate = str(body.gate, 'gate', { required: false, max: 40 });
  const by = caller.user?.id ?? null;
  // The reader sends either a QR code ("code") or the NFC card number ("uid").
  const uid = body.uid ? normUid(body.uid) : null;
  let parsed;
  if (uid) parsed = { ok: true, method: 'card' };
  else parsed = await readCode(env.JWT_SECRET, body.code);
  if (!parsed.ok) {
    await logGate(env, { branch_id: branchId, gate, result: 'denied', reason: parsed.reason, method: 'app', by_user: by });
    return { allow: false, reason: parsed.reason };
  }
  const m = uid
    ? await env.DB.prepare('SELECT id,name,end_date,blocked,pass_ver,branch_id FROM members WHERE nfc_uid=?').bind(uid).first()
    : await env.DB.prepare('SELECT id,name,end_date,blocked,pass_ver,branch_id FROM members WHERE id=?').bind(parsed.id).first();
  if (uid) parsed.ver = m?.pass_ver;
  const deny = async (reason) => {
    await logGate(env, { member_id: m?.id, branch_id: branchId, gate, result: 'denied', reason, method: parsed.method, by_user: by });
    return { allow: false, reason, name: m?.name };
  };
  if (!m) return deny('unknown');
  if (m.pass_ver !== parsed.ver) return deny('old_pass');
  if (m.blocked) return deny('blocked');
  const left = daysBetween(today(), m.end_date);
  if (left < 0) return deny('expired');
  await logGate(env, { member_id: m.id, branch_id: branchId, gate, result: 'allowed', reason: 'ok', method: parsed.method, by_user: by });
  return { allow: true, reason: 'ok', name: m.name, days_left: left };
}, { auth: false });

// Staff opens the gate by hand. The gate controller picks the command up from /api/gate/poll.
route('POST', '/api/gate/open', async ({ env, user, body }) => {
  const branchId = user.role === 'admin' ? Number(body.branch_id) || user.branch_id : user.branch_id;
  if (!branchId) fail(400, 'branch_id is required');
  await env.DB.prepare('INSERT INTO gate_commands (branch_id,created_by,created_at) VALUES (?,?,?)').bind(branchId, user.id, nowTime()).run();
  await logGate(env, { branch_id: branchId, gate: 'manual', result: 'allowed', reason: 'ok', method: 'manual', by_user: user.id });
  return { ok: true };
});
route('GET', '/api/gate/poll', async ({ request, env, query }) => {
  const caller = await gateCaller(request, env);
  if (!caller.gate) fail(403, 'Gate key required');
  const branch = Number(query.get('branch_id'));
  const rows = (await env.DB.prepare('SELECT id FROM gate_commands WHERE branch_id=? AND done=0 ORDER BY id LIMIT 5').bind(branch).all()).results;
  for (const r of rows) await env.DB.prepare('UPDATE gate_commands SET done=1 WHERE id=?').bind(r.id).run();
  return { open: rows.length > 0, count: rows.length };
}, { auth: false });

// Entries (admin): today by default.
route('GET', '/api/gate/log', async ({ env, query }) => {
  const date = isDate(query.get('date')) ? query.get('date') : today();
  const branch = query.get('branch_id');
  const rows = (await env.DB.prepare(`SELECT g.id,g.created_at,g.gate,g.result,g.reason,g.method,g.branch_id,m.id AS member_id,m.name AS member_name,b.name AS branch_name,b.name_ar AS branch_name_ar
    FROM gate_logs g LEFT JOIN members m ON m.id=g.member_id LEFT JOIN branches b ON b.id=g.branch_id
    WHERE substr(g.created_at,1,10)=? ${branch ? 'AND g.branch_id=?' : ''} ORDER BY g.id DESC LIMIT 300`).bind(...(branch ? [date, Number(branch)] : [date])).all()).results;
  const allowed = rows.filter((r) => r.result === 'allowed').length;
  return { date, allowed, denied: rows.length - allowed, items: rows };
}, { admin: true });

// Member pass for staff/admin: codes + link to send on WhatsApp.
route('GET', '/api/members/:id/pass', async ({ request, env, params }) => {
  const m = await env.DB.prepare('SELECT id,name,pass_ver,blocked,nfc_uid,ban_until,strike_count FROM members WHERE id=?').bind(params.id).first();
  if (!m) fail(404, 'Member not found');
  const st = await staticCode(env.JWT_SECRET, m.id, m.pass_ver);
  const origin = new URL(request.url).origin;
  return { member_id: m.id, name: m.name, blocked: !!m.blocked, card: m.nfc_uid, ban_until: m.ban_until && m.ban_until >= today() ? m.ban_until : null, strikes: m.strike_count, static_code: st, link: `${origin}/m/${st}`, dynamic_code: await dynamicCode(env.JWT_SECRET, m.id, m.pass_ver), seconds_left: secondsLeftInWindow() };
});
// Link / unlink an NFC card to a member (staff at the desk or admin). Send {uid} or {uid:null}.
route('POST', '/api/members/:id/card', async ({ env, params, body }) => {
  const m = await env.DB.prepare('SELECT id FROM members WHERE id=?').bind(params.id).first();
  if (!m) fail(404, 'Member not found');
  let uid = null;
  if (body.uid) {
    uid = normUid(body.uid);
    if (uid.length < 8 || uid.length > 20) fail(400, 'Card number looks wrong');
    const other = await env.DB.prepare('SELECT id,name FROM members WHERE nfc_uid=? AND id<>?').bind(uid, m.id).first();
    if (other) fail(409, `Card already belongs to ${other.name}`);
  }
  await env.DB.prepare('UPDATE members SET nfc_uid=? WHERE id=?').bind(uid, m.id).run();
  return { ok: true, uid };
});
route('POST', '/api/members/:id/block', async ({ env, params, body }) => {
  const blocked = body.blocked === false ? 0 : 1;
  await env.DB.prepare('UPDATE members SET blocked=? WHERE id=?').bind(blocked, params.id).run();
  return { ok: true, blocked: !!blocked };
}, { admin: true });
// New pass: invalidates every old QR / Wallet pass of this member (lost phone, shared screenshot).
route('POST', '/api/members/:id/reissue', async ({ env, params }) => {
  await env.DB.prepare('UPDATE members SET pass_ver=pass_ver+1 WHERE id=?').bind(params.id).run();
  return { ok: true };
}, { admin: true });

// Public member pass: the link in WhatsApp contains the static code. No login.
async function passFromToken(env, token) {
  const parsed = await readCode(env.JWT_SECRET, token);
  if (!parsed.ok || parsed.method !== 'wallet') fail(404, 'Pass not found');
  const m = await env.DB.prepare('SELECT m.id,m.name,m.branch_id,m.end_date,m.blocked,m.pass_ver,m.ban_until,m.strike_count,p.name AS plan_name,p.name_ar AS plan_name_ar,b.name AS branch_name,b.name_ar AS branch_name_ar FROM members m LEFT JOIN plans p ON p.id=m.plan_id LEFT JOIN branches b ON b.id=m.branch_id WHERE m.id=?').bind(parsed.id).first();
  if (!m || m.pass_ver !== parsed.ver) fail(404, 'Pass not found');
  return m;
}
route('GET', '/api/pass/:token', async ({ env, params }) => {
  const m = await passFromToken(env, params.token);
  const left = daysBetween(today(), m.end_date);
  return { name: m.name, plan: m.plan_name, plan_ar: m.plan_name_ar, branch: m.branch_name, branch_ar: m.branch_name_ar, end_date: m.end_date, days_left: left,
    status: m.blocked ? 'blocked' : left < 0 ? 'expired' : left <= 7 ? 'expiring' : 'active',
    code: await dynamicCode(env.JWT_SECRET, m.id, m.pass_ver), seconds_left: secondsLeftInWindow() };
}, { auth: false });
// Class times of the member's own branch (all days, both audiences) for the customer web app.
route('GET', '/api/pass/:token/classes', async ({ env, params }) => {
  const m = await passFromToken(env, params.token);
  const rows = (await env.DB.prepare('SELECT audience,day,time,level FROM schedule WHERE branch_id=? ORDER BY day,time').bind(m.branch_id).all()).results;
  return { branch: m.branch_name, items: rows };
}, { auth: false });
route('GET', '/api/pass/:token/pkpass', async ({ env, params }) => {
  const m = await passFromToken(env, params.token);
  return { __raw: await buildPkpass(env, m, params.token) };
}, { auth: false });

// App updates: the release script uploads UNDERGROUND.apk + version.json to the R2 bucket.
route('GET', '/api/app/version', async ({ request, env, query }) => {
  if (!env.APK) return { build: 0 };
  const member = query.get('app') === 'member';
  const o = await env.APK.get(member ? 'member-version.json' : 'version.json');
  if (!o) return { build: 0 };
  let v = {};
  try { v = JSON.parse(await o.text()); } catch { return { build: 0 }; }
  return { build: Number(v.build) || 0, notes: String(v.notes || ''), url: `${new URL(request.url).origin.replace(/^http:\/\/(?!localhost|127\.)/, 'https://')}/app/${member ? 'UNDERGROUND-Member' : 'UNDERGROUND'}.apk` };
}, { auth: false });

// Public (no login): gym branches and class availability, so the customer app can open without a membership.
route('GET', '/api/public/branches', async ({ env }) => {
  const rows = (await env.DB.prepare("SELECT id,name,name_ar FROM branches WHERE kind='gym' ORDER BY id").all()).results;
  return { items: rows };
}, { auth: false });
route('GET', '/api/public/classes', async ({ env, query }) => {
  const b = await env.DB.prepare("SELECT id FROM branches WHERE id=? AND kind='gym'").bind(Number(query.get('branch_id'))).first();
  if (!b) fail(404, 'Branch not found');
  return bk.overview(env, { id: 0, branch_id: b.id, ban_until: null, strike_count: 0 });
}, { auth: false });

// Booking: customer side (pass link token) and staff side.
const bkRun = async (fn) => {
  try { return await fn(); } catch (e) { if (e instanceof bk.BookingError) fail(e.status, e.message); throw e; }
};
route('GET', '/api/pass/:token/booking', async ({ env, params }) => bkRun(async () => bk.overview(env, await passFromToken(env, params.token))), { auth: false });
route('POST', '/api/pass/:token/book', async ({ env, params, body }) => bkRun(async () => bk.book(env, await passFromToken(env, params.token), Number(body.schedule_id), String(body.date || ''))), { auth: false });
route('POST', '/api/pass/:token/cancel', async ({ env, params, body }) => bkRun(async () => bk.cancel(env, await passFromToken(env, params.token), Number(body.booking_id))), { auth: false });
route('POST', '/api/pass/:token/offer', async ({ env, params, body }) => bkRun(async () => bk.respondOffer(env, await passFromToken(env, params.token), Number(body.booking_id), body.accept !== false)), { auth: false });
route('GET', '/api/pass/:token/notifications', async ({ env, params }) => bk.listNotifications(env, (await passFromToken(env, params.token)).id), { auth: false });
route('POST', '/api/pass/:token/notifications/read', async ({ env, params }) => { await bk.markRead(env, (await passFromToken(env, params.token)).id); return { ok: true }; }, { auth: false });

async function classOfSchedule(env, user, scheduleId) {
  const sc = await env.DB.prepare('SELECT id,branch_id FROM schedule WHERE id=?').bind(scheduleId).first();
  if (!sc) fail(404, 'Class not found');
  if (user.role !== 'admin' && sc.branch_id !== user.branch_id) fail(403, 'Not your branch');
  return sc;
}
route('GET', '/api/classes/roster', async ({ env, user, query }) => {
  const id = Number(query.get('schedule_id'));
  const date = query.get('date');
  if (!isDate(date)) fail(400, 'date is required');
  await classOfSchedule(env, user, id);
  return bkRun(() => bk.roster(env, id, date));
});
route('POST', '/api/class-bookings/:id/cancel', async ({ env, user, params }) => {
  const b = await env.DB.prepare('SELECT schedule_id FROM class_bookings WHERE id=?').bind(params.id).first();
  if (!b) fail(404, 'Booking not found');
  await classOfSchedule(env, user, b.schedule_id);
  return bkRun(() => bk.cancel(env, null, Number(params.id), { byStaff: true }));
});
route('POST', '/api/class-bookings/:id/attend', async ({ env, user, params }) => {
  const b = await env.DB.prepare('SELECT schedule_id FROM class_bookings WHERE id=?').bind(params.id).first();
  if (!b) fail(404, 'Booking not found');
  await classOfSchedule(env, user, b.schedule_id);
  return bkRun(() => bk.markAttended(env, Number(params.id)));
});
route('PUT', '/api/schedule/:id', async ({ env, params, body }) => {
  const cap = Math.round(num(body.capacity, 'capacity'));
  if (cap < 1 || cap > 200) fail(400, 'capacity must be between 1 and 200');
  await env.DB.prepare('UPDATE schedule SET capacity=? WHERE id=?').bind(cap, params.id).run();
  return { ok: true, capacity: cap };
}, { admin: true });
route('POST', '/api/members/:id/unban', async ({ env, params }) => {
  await env.DB.prepare('UPDATE members SET ban_until=NULL, strike_count=0 WHERE id=?').bind(params.id).run();
  return { ok: true };
}, { admin: true });
// Timer job (also callable with the gate key, used by tests).
route('POST', '/api/cron/run', async ({ request, env }) => {
  const c = await gateCaller(request, env);
  if (!c.gate) fail(403, 'Gate key required');
  return bk.runCron(env);
}, { auth: false });
// Test clock: only when TEST_CLOCK=1 (never set in production).
route('POST', '/api/test/clock', async ({ env, body }) => {
  if (env.TEST_CLOCK !== '1') fail(404, 'Not found');
  bk.setTestClock(body.now || null);
  return { ok: true };
}, { auth: false });

/* ---------- entry ---------- */
export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(bk.runCron(env));
  },
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';
    if (request.method === 'GET' && (path === '/' || path === '/admin')) {
      return new Response(BACKOFFICE_HTML, { headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'X-Frame-Options': 'DENY' } });
    }
    if (request.method === 'GET' && path === '/get') {
      const page = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>UNDERGROUND</title><style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0a090e;color:#f4f2f8;font:16px system-ui,sans-serif;text-align:center;padding:20px}a.b{display:block;margin:12px auto;max-width:320px;padding:14px;border-radius:14px;background:#8a4dff;color:#fff;text-decoration:none;font-weight:700}small{color:#a29cb4}button{background:none;border:1px solid #2b2738;color:#f4f2f8;border-radius:20px;padding:4px 14px;cursor:pointer}</style></head><body><div><p><button id="l">EN</button></p><h1 style="letter-spacing:4px">UNDERGROUND</h1><a class="b" href="/app/UNDERGROUND-Member.apk" id="a"></a><small id="n"></small></div><script>const T={ar:{a:'تحميل التطبيق (Android)',n:'آيفون: افتح رابط بطاقتك من الموظف',o:'EN'},en:{a:'Download the app (Android)',n:'iPhone: open your pass link from the staff',o:'عربي'}};let L=localStorage.getItem('l')||((navigator.language||'').slice(0,2)==='ar'?'ar':'en');function r(){document.documentElement.lang=L;document.documentElement.dir=L==='ar'?'rtl':'ltr';a.textContent=T[L].a;n.textContent=T[L].n;l.textContent=T[L].o}l.onclick=()=>{L=L==='ar'?'en':'ar';localStorage.setItem('l',L);r()};r()</script></body></html>`;
      return new Response(page, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
    }
    if (request.method === 'GET' && (path === '/app/UNDERGROUND.apk' || path === '/app/UNDERGROUND-Member.apk')) {
      const member = path.includes('Member');
      const o = env.APK ? await env.APK.get(member ? 'UNDERGROUND-Member.apk' : 'UNDERGROUND.apk') : null;
      if (!o) return new Response('Not found', { status: 404 });
      return new Response(o.body, { headers: { 'Content-Type': 'application/vnd.android.package-archive', 'Content-Disposition': `attachment; filename="${member ? 'UNDERGROUND-Member' : 'UNDERGROUND'}.apk"`, 'Content-Length': String(o.size), 'Cache-Control': 'no-store' } });
    }
    if (request.method === 'GET' && path.startsWith('/mf/')) {
      const tk = path.split('/').pop();
      const mf = { name: 'UNDERGROUND', short_name: 'UNDERGROUND', start_url: `/m/${tk}`, scope: '/m/', display: 'standalone', background_color: '#0a090e', theme_color: '#0a090e', lang: 'ar', dir: 'rtl', icons: [{ src: '/icon.png', sizes: '58x58', type: 'image/png' }] };
      return new Response(JSON.stringify(mf), { headers: { 'Content-Type': 'application/manifest+json', 'Cache-Control': 'no-store' } });
    }
    if (request.method === 'GET' && path === '/icon.png' && ICONS['icon.png']) {
      const bin = Uint8Array.from(atob(ICONS['icon.png']), (c) => c.charCodeAt(0));
      return new Response(bin, { headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=86400' } });
    }
    if (request.method === 'GET' && path.startsWith('/m/')) {
      return new Response(PASS_PAGE_HTML, { headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' } });
    }
    try {
      if (!env.JWT_SECRET) fail(500, 'JWT_SECRET is not set');
      for (const r of routes) {
        if (r.method !== request.method) continue;
        const match = r.re.exec(path);
        if (!match) continue;
        const params = {};
        r.keys.forEach((k, i) => { params[k] = decodeURIComponent(match[i + 1]); });
        let body = {};
        if (request.method === 'POST' || request.method === 'PUT') {
          try { body = await request.json(); } catch { body = {}; }
          if (typeof body !== 'object' || body === null || Array.isArray(body)) body = {};
        }
        const user = r.auth ? await authenticate(request, env) : null;
        if (r.admin) needAdmin(user);
        const out = await r.handler({ request, env, user, params, body, query: url.searchParams });
        if (out && out.__raw) return out.__raw;
        return json(out);
      }
      return json({ error: 'Not found' }, 404);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message }, e.status);
      console.error(e);
      return json({ error: 'Server error' }, 500);
    }
  },
};
