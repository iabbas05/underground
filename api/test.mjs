// Smoke test for the API. Start the API first (npm run dev), then: npm test
// Needs the same SETUP_KEY the server was started with: SETUP_KEY=... node test.mjs
const BASE = process.env.API || 'http://127.0.0.1:8787';
const SETUP_KEY = process.env.SETUP_KEY || 'test-setup-key';
let failed = 0;

async function call(method, path, body, token) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = await res.json(); } catch { /* empty */ }
  return { status: res.status, data };
}
function check(name, cond, extra) {
  if (cond) console.log('  ok  ', name);
  else { failed++; console.log('  FAIL', name, extra !== undefined ? JSON.stringify(extra) : ''); }
}

const today = new Date(Date.now() + 3 * 3600e3).toISOString().slice(0, 10);
const month = today.slice(0, 7);

console.log('setup + login');
let r = await call('POST', '/api/setup', { key: 'wrong', name: 'A', username: 'admin', password: 'longpassword' });
check('wrong setup key rejected', r.status === 403, r);
r = await call('POST', '/api/setup', { key: SETUP_KEY, name: 'Owner', username: 'Admin', password: 'short' });
check('short password rejected', r.status === 400, r);
r = await call('POST', '/api/setup', { key: SETUP_KEY, name: 'Owner', username: 'Admin', password: 'owner-pass-123' });
check('first admin created', r.status === 200, r);
r = await call('POST', '/api/setup', { key: SETUP_KEY, name: 'Owner', username: 'second', password: 'owner-pass-123' });
check('setup only works once', r.status === 409, r);
r = await call('POST', '/api/login', { username: 'admin', password: 'nope-nope' });
check('wrong password rejected', r.status === 401, r);
r = await call('POST', '/api/login', { username: 'admin', password: 'owner-pass-123' });
check('admin login', r.status === 200 && r.data.token && r.data.user.role === 'admin', r);
const admin = r.data.token;
r = await call('GET', '/api/me');
check('no token rejected', r.status === 401, r);

console.log('lookups');
r = await call('GET', '/api/branches', null, admin);
check('7 branches', r.data.length === 7, r.data);
r = await call('GET', '/api/plans', null, admin);
check('19 plans', r.data.length === 19, r.data.length);

console.log('staff accounts');
r = await call('POST', '/api/users', { name: 'Ali', username: 'ali', password: 'staff-pass-123', role: 'staff', branch_id: 2, base_salary: 350 }, admin);
check('staff created', r.status === 200, r);
r = await call('POST', '/api/users', { name: 'Ali 2', username: 'ali', password: 'staff-pass-123', role: 'staff', branch_id: 2 }, admin);
check('duplicate username rejected', r.status === 409, r);
r = await call('POST', '/api/login', { username: 'ali', password: 'staff-pass-123' });
check('staff login', r.status === 200 && r.data.user.role === 'staff', r);
const staff = r.data.token;
const staffId = r.data.user.id;
r = await call('GET', '/api/users', null, staff);
check('staff cannot list users', r.status === 403, r);
r = await call('GET', '/api/reports/summary', null, staff);
check('staff cannot see reports', r.status === 403, r);

console.log('members + payments');
r = await call('POST', '/api/members', { name: 'Hassan', phone: '33001122', plan_id: 2, method: 'cash', amount: 1 }, staff);
check('staff registers member (price from plan, amount ignored)', r.status === 200 && r.data.amount === 30, r);
const hassan = r.data.id;
r = await call('POST', '/api/members', { name: 'Trial Guy', phone: '33009988', plan_id: 1, method: 'cash' }, staff);
check('trial member created', r.status === 200 && r.data.end_date === today, r);
r = await call('POST', '/api/members', { name: 'Bad', phone: 'abc', plan_id: 2, method: 'cash' }, staff);
check('bad phone rejected', r.status === 400, r);
r = await call('POST', '/api/members', { name: 'Bad', phone: '33001111', plan_id: 2, method: 'gold' }, staff);
check('bad method rejected', r.status === 400, r);
r = await call('POST', '/api/members', { name: 'Fatema', phone: '33445566', plan_id: 7, method: 'benefit', branch_id: 1, amount: 80 }, admin);
check('admin can override amount and branch', r.status === 200 && r.data.amount === 80, r);
r = await call('GET', '/api/members?q=hass', null, staff);
check('search by name', r.data.length === 1 && r.data[0].status === 'active', r.data);
r = await call('GET', '/api/members?q=3344', null, staff);
check('search by phone', r.data.length === 1 && r.data[0].name === 'Fatema', r.data);
r = await call('GET', '/api/members/' + hassan, null, staff);
check('member detail has payment', r.data.payments.length === 1, r.data);
r = await call('POST', `/api/members/${hassan}/renew`, { plan_id: 6, method: 'card' }, staff);
check('renew continues from current end', r.status === 200 && r.data.end_date > today, r);
r = await call('POST', `/api/members/${hassan}/extend`, { days: 10, note: 'travel' }, staff);
check('staff cannot extend', r.status === 403, r);
r = await call('POST', `/api/members/${hassan}/extend`, { days: 10, note: 'travel' }, admin);
check('admin extends (freeze)', r.status === 200, r);
r = await call('POST', '/api/payments', { amount: 15, method: 'cash', kind: 'recovery', note: 'massage' }, staff);
check('staff records payment in own branch', r.status === 200, r);
r = await call('GET', '/api/payments', null, staff);
check('staff sees only today of own branch', r.status === 200 && r.data.items.every((p) => p.branch_id === 2 && p.date === today), r.data);

console.log('expenses + salaries');
r = await call('POST', '/api/expenses', { branch_id: 2, category: 'rent', amount: 500, note: 'Oct rent' }, admin);
check('expense added', r.status === 200, r);
r = await call('POST', '/api/expenses', { branch_id: 2, category: 'rent', amount: 500 }, staff);
check('staff cannot add expense', r.status === 403, r);
r = await call('POST', '/api/salaries', { user_id: staffId, month, amount: 350 }, admin);
check('salary paid', r.status === 200, r);
r = await call('POST', '/api/salaries', { user_id: staffId, month: 'oct', amount: 350 }, admin);
check('bad month rejected', r.status === 400, r);

console.log('attendance');
r = await call('POST', '/api/attendance/clock', { action: 'out' }, staff);
check('cannot clock out before in', r.status === 409, r);
r = await call('POST', '/api/attendance/clock', { action: 'in' }, staff);
check('clock in', r.status === 200 && r.data.clocked_in === true, r);
r = await call('POST', '/api/attendance/clock', { action: 'in' }, staff);
check('double clock in rejected', r.status === 409, r);
r = await call('GET', '/api/attendance/today', null, staff);
check('status shows clocked in', r.data.clocked_in === true, r);
r = await call('POST', '/api/attendance/clock', { action: 'out' }, staff);
check('clock out', r.status === 200 && r.data.clocked_in === false, r);
r = await call('GET', '/api/attendance?month=' + month, null, admin);
check('admin attendance summary', r.status === 200 && r.data.summary.length === 1 && r.data.summary[0].days === 1, r.data);

console.log('schedule');
r = await call('GET', '/api/schedule?branch_id=2&audience=men&day=0', null, staff);
check('Sunday men has 16 slots', r.data.items.length === 16, r.data.items.length);
r = await call('GET', '/api/schedule?branch_id=2&audience=ladies&day=0', null, staff);
check('Sunday ladies has 17 slots', r.data.items.length === 17, r.data.items.length);
r = await call('GET', '/api/schedule?branch_id=2&audience=men&day=5', null, staff);
check('Friday is rest day', r.data.rest_day === true && r.data.items.length === 0, r.data);
r = await call('GET', '/api/schedule?branch_id=2&audience=men&day=6', null, staff);
check('Saturday men has 9 slots', r.data.items.length === 9, r.data.items.length);

console.log('report');
r = await call('GET', `/api/reports/summary?month=${month}`, null, admin);
const income = 30 + 5 + 80 + 99 + 15;
check('income adds up', r.status === 200 && r.data.income === income, r.data);
check('profit = income - expenses - salaries', r.data.profit === income - 500 - 350, r.data);
check('members counted (3 active, 3 new, trial ends today)', r.data.members.active === 3 && r.data.members.new_this_month === 3 && r.data.members.expiring_7d === 1, r.data.members);
check('daily series present', r.data.daily.length >= 1);
r = await call('GET', `/api/reports/summary?month=${month}&branch_id=1`, null, admin);
check('branch filter works (Riffa income 80)', r.data.income === 80 && r.data.expenses === 0, r.data);

console.log('gate + pass');
const GATE_KEY = process.env.GATE_KEY || 'test-gate-key';
const gcall = (path, body) => fetch(BASE + path, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Gate-Key': GATE_KEY }, body: JSON.stringify(body) }).then(async (x) => ({ status: x.status, data: await x.json().catch(() => null) }));
r = await call('GET', '/api/members?status=active', null, admin);
const active = r.data[0];
r = await call('POST', '/api/members', { name: 'Old Timer', phone: '97311111111', plan_id: 2, method: 'cash', branch_id: 1, start_date: '2020-01-01' }, admin);
const oldId = r.data.id;
r = await call('GET', `/api/members/${active.id}/pass`, null, staff);
check('pass codes issued', r.status === 200 && r.data.static_code.startsWith('UGS.') && r.data.dynamic_code.startsWith('UGD.') && r.data.link.includes('/m/UGS.'), r);
const pass = r.data;
r = await gcall('/api/gate/verify', { code: pass.dynamic_code, branch_id: 2, gate: 'main' });
check('rotating code opens for active member', r.status === 200 && r.data.allow === true && r.data.name === active.name, r);
r = await gcall('/api/gate/verify', { code: pass.static_code, branch_id: 2 });
check('wallet (static) code opens', r.data.allow === true, r);
r = await gcall('/api/gate/verify', { code: pass.dynamic_code.slice(0, -3) + 'abc', branch_id: 2 });
check('tampered code denied', r.data.allow === false && r.data.reason === 'bad_code', r);
r = await gcall('/api/gate/verify', { code: 'hello', branch_id: 2 });
check('garbage denied', r.data.allow === false, r);
r = await fetch(BASE + '/api/gate/verify', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Gate-Key': 'wrong' }, body: JSON.stringify({ code: pass.static_code }) });
check('wrong gate key and no login rejected', r.status === 401, r.status);
r = await call('GET', `/api/members/${oldId}/pass`, null, admin);
r = await gcall('/api/gate/verify', { code: r.data.static_code, branch_id: 1 });
check('expired member denied', r.data.allow === false && r.data.reason === 'expired', r);
r = await call('POST', `/api/members/${active.id}/block`, { blocked: true }, staff);
check('staff cannot block', r.status === 403, r);
r = await call('POST', `/api/members/${active.id}/block`, { blocked: true }, admin);
r = await gcall('/api/gate/verify', { code: pass.static_code, branch_id: 2 });
check('blocked member denied', r.data.allow === false && r.data.reason === 'blocked', r);
r = await call('GET', `/api/members/${active.id}`, null, admin);
check('status shows blocked', r.data.status === 'blocked', r.data.status);
await call('POST', `/api/members/${active.id}/block`, { blocked: false }, admin);
r = await call('POST', `/api/members/${active.id}/reissue`, {}, admin);
r = await gcall('/api/gate/verify', { code: pass.static_code, branch_id: 2 });
check('old pass denied after reissue', r.data.allow === false && r.data.reason === 'old_pass', r);
r = await call('GET', `/api/members/${active.id}/pass`, null, admin);
const fresh = r.data;
r = await gcall('/api/gate/verify', { code: fresh.static_code, branch_id: 2 });
check('new pass works', r.data.allow === true, r);
r = await call('POST', '/api/gate/verify', { code: fresh.dynamic_code, branch_id: 2 }, staff);
check('staff phone can verify too', r.data.allow === true, r);
console.log('public pass page');
const token = fresh.static_code;
r = await fetch(BASE + '/api/pass/' + token); const pj = await r.json();
check('public pass JSON', r.status === 200 && pj.name === active.name && pj.code.startsWith('UGD.') && pj.status, pj);
r = await fetch(BASE + '/api/pass/UGS.1.1.0000000000000000');
check('bad pass token 404', r.status === 404, r.status);
r = await fetch(BASE + '/m/' + token); const html = await r.text();
check('pass web page served', r.status === 200 && html.includes('qrcode') && html.includes('UNDERGROUND'));
r = await fetch(BASE + '/api/pass/' + token + '/pkpass');
check('wallet pass says not set up yet (no Apple certs)', r.status === 501, r.status);
r = await fetch(BASE + '/api/pass/' + token + '/classes'); const cj = await r.json();
check('customer app classes for own branch', r.status === 200 && Array.isArray(cj.items), cj);
r = await fetch(BASE + '/api/pass/UGS.1.1.0000000000000000/classes');
check('classes need a valid pass', r.status === 404, r.status);
r = await fetch(BASE + '/mf/' + token); const mfj = await r.json();
check('web app manifest', r.status === 200 && mfj.start_url === '/m/' + token && mfj.display === 'standalone', mfj);
r = await fetch(BASE + '/icon.png');
check('app icon', r.status === 200 && (r.headers.get('content-type') || '').includes('png'), r.status);
console.log('app update');
r = await fetch(BASE + '/api/app/version'); const av = await r.json();
check('app version endpoint works without a release', r.status === 200 && av.build === 0, av);
r = await fetch(BASE + '/app/UNDERGROUND.apk');
check('no apk yet is 404', r.status === 404, r.status);
r = await fetch(BASE + '/api/app/version?app=member'); const mv = await r.json();
check('member app version endpoint', r.status === 200 && mv.build === 0, mv);
r = await fetch(BASE + '/get'); const gp = await r.text();
check('download page', r.status === 200 && gp.includes('UNDERGROUND-Member.apk'));
console.log('nfc card');
const gk = { 'X-Gate-Key': GATE_KEY, 'Content-Type': 'application/json' };
r = await call('POST', '/api/members/' + fresh.member_id + '/card', { uid: '04:a3:2b:1c' }, staff);
check('staff links NFC card', r.status === 200 && r.data.uid === '04A32B1C', r);
r = await call('POST', '/api/members/' + fresh.member_id + '/card', { uid: 'zz' }, staff);
check('bad card number rejected', r.status === 400, r);
r = await fetch(BASE + '/api/gate/verify', { method: 'POST', headers: gk, body: JSON.stringify({ uid: '04-A3-2B-1C', branch_id: 2 }) }); const nv = await r.json();
check('card opens gate', nv.allow === true, nv);
r = await fetch(BASE + '/api/gate/verify', { method: 'POST', headers: gk, body: JSON.stringify({ uid: 'DEADBEEF', branch_id: 2 }) }); const nu = await r.json();
check('unknown card denied', nu.allow === false && nu.reason === 'unknown', nu);
r = await call('POST', '/api/members/' + fresh.member_id + '/block', { blocked: true }, admin);
r = await fetch(BASE + '/api/gate/verify', { method: 'POST', headers: gk, body: JSON.stringify({ uid: '04A32B1C', branch_id: 2 }) }); const nb = await r.json();
check('blocked member card denied', nb.allow === false && nb.reason === 'blocked', nb);
await call('POST', '/api/members/' + fresh.member_id + '/block', { blocked: false }, admin);
console.log('manual open + log');
r = await call('POST', '/api/gate/open', {}, staff);
check('staff opens gate', r.status === 200, r);
r = await fetch(BASE + '/api/gate/poll?branch_id=2', { headers: { 'X-Gate-Key': GATE_KEY } }); const poll = await r.json();
check('gate controller receives open command once', poll.open === true && poll.count === 1, poll);
r = await fetch(BASE + '/api/gate/poll?branch_id=2', { headers: { 'X-Gate-Key': GATE_KEY } });
check('command not repeated', (await r.json()).open === false);
r = await call('GET', '/api/gate/log', null, staff);
check('staff cannot read gate log', r.status === 403, r);
r = await call('GET', '/api/gate/log', null, admin);
check('gate log has allowed and denied', r.status === 200 && r.data.allowed >= 4 && r.data.denied >= 5, { a: r.data.allowed, d: r.data.denied });


r = await fetch(BASE + '/api/public/branches'); const pb = await r.json();
check('public branches without login', r.status === 200 && pb.items.length === 5, pb);
r = await fetch(BASE + '/api/public/classes?branch_id=2'); const pc = await r.json();
check('public class availability without login', r.status === 200 && pc.dates.length === 2 && pc.ban_until === null, pc);
r = await fetch(BASE + '/api/public/classes?branch_id=6');
check('recovery branch is not a gym branch', r.status === 404, r.status);
console.log('class booking');
const clock = (iso) => fetch(BASE + '/api/test/clock', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ now: iso }) });
const plusDays = (d, n) => new Date(Date.parse(d + 'T00:00:00Z') + n * 86400e3).toISOString().slice(0, 10);
let sun = new Date(Date.now() + 3 * 3600e3); while (sun.getUTCDay() !== 0) sun = new Date(sun.getTime() + 86400e3);
sun = sun.toISOString().slice(0, 10);
await clock(`${sun}T00:10`);
const mk = async (name, phone) => {
  const c = await call('POST', '/api/members', { name, phone, plan_id: 2, method: 'cash' }, staff);
  const p = await call('GET', `/api/members/${c.data.id}/pass`, null, admin);
  return { id: c.data.id, tok: p.data.static_code };
};
const P = async (m, method, path, body) => {
  const rr = await fetch(`${BASE}/api/pass/${m.tok}${path}`, { method, headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  let d = null; try { d = await rr.json(); } catch { /* empty */ }
  return { status: rr.status, data: d };
};
const A = await mk('Book A', '33100001'), B = await mk('Book B', '33100002'), C = await mk('Book C', '33100003');
let ov = await P(A, 'GET', '/booking');
check('booking overview has today and tomorrow', ov.status === 200 && ov.data.dates.length === 2 && ov.data.dates[0].date === sun && ov.data.dates[0].items.length > 0, ov.data && ov.data.dates && ov.data.dates.map((x) => x.date));
const k1 = ov.data.dates[0].items.filter((i) => i.audience === 'men')[0];
const k2 = ov.data.dates[0].items.filter((i) => i.audience === 'men')[1];
check('default capacity is 20', k1.capacity === 20 && k1.free === 20, k1);
r = await call('PUT', `/api/schedule/${k1.schedule_id}`, { capacity: 2 }, staff);
check('staff cannot change capacity', r.status === 403, r.status);
r = await call('PUT', `/api/schedule/${k1.schedule_id}`, { capacity: 2 }, admin);
check('admin sets capacity 2', r.status === 200, r);
r = await P(A, 'POST', '/book', { schedule_id: k1.schedule_id, date: sun });
check('A books', r.status === 200 && r.data.status === 'booked', r);
const aBooking = r.data.booking_id;
r = await P(A, 'POST', '/book', { schedule_id: k1.schedule_id, date: sun });
check('double booking refused', r.status === 409, r);
r = await P(B, 'POST', '/book', { schedule_id: k1.schedule_id, date: sun });
check('B books', r.data.status === 'booked', r);
const bBooking = r.data.booking_id;
r = await P(C, 'POST', '/book', { schedule_id: k1.schedule_id, date: sun });
check('full class puts C on the waitlist', r.data.status === 'waitlist' && r.data.position === 1, r);
const cBooking = r.data.booking_id;
r = await P(C, 'POST', '/book', { schedule_id: k2.schedule_id, date: plusDays(sun, 2) });
check('cannot book beyond tomorrow', r.status === 400, r);
r = await call('GET', `/api/classes/roster?schedule_id=${k1.schedule_id}&date=${sun}`, null, staff);
check('staff roster shows 2 booked + 1 waiting', r.status === 200 && r.data.taken === 2 && r.data.items.length === 3, r.data);
r = await P(A, 'POST', '/cancel', { booking_id: aBooking });
check('A cancels (more than 1 hour before)', r.status === 200, r);
r = await P(C, 'GET', '/notifications');
check('C gets a seat-opened notification', r.data.unread === 1 && r.data.items[0].kind === 'offer' && r.data.items[0].body_ar.length > 5, r.data);
r = await P(C, 'POST', '/offer', { booking_id: cBooking, accept: true });
check('C accepts the offer', r.status === 200 && r.data.status === 'booked', r);
await P(C, 'POST', '/notifications/read');
r = await P(C, 'GET', '/notifications');
check('notifications marked read', r.data.unread === 0);
r = await P(A, 'POST', '/book', { schedule_id: k1.schedule_id, date: sun });
check('A is waitlisted again', r.data.status === 'waitlist', r);
const aBooking2 = r.data.booking_id;
r = await P(B, 'POST', '/cancel', { booking_id: bBooking });
check('B cancels', r.status === 200, r);
r = await P(A, 'GET', '/booking');
const mine = r.data.dates[0].items.find((i) => i.schedule_id === k1.schedule_id);
check('A now has an open offer', mine.my_status === 'offered', mine);
await clock(`${sun}T00:40`);
r = await fetch(BASE + '/api/cron/run', { method: 'POST', headers: { 'X-Gate-Key': GATE_KEY, 'Content-Type': 'application/json' }, body: '{}' }); const cr = await r.json();
check('cron expires the unanswered offer', cr.expired === 1, cr);
r = await P(A, 'POST', '/offer', { booking_id: aBooking2, accept: true });
check('late acceptance refused', r.status === 400, r);
r = await P(A, 'GET', '/notifications');
check('A told the offer expired', r.data.items.some((n) => n.kind === 'offer_expired'), r.data);
// late cancel: 30 minutes before the class
const [hh, mm] = k1.time.split(':').map(Number);
const t0 = hh * 60 + mm - 30;
await clock(`${sun}T${String(Math.floor(t0 / 60)).padStart(2, '0')}:${String(t0 % 60).padStart(2, '0')}`);
r = await P(C, 'POST', '/cancel', { booking_id: cBooking });
check('cancelling less than 1 hour before is refused', r.status === 400, r);
// no-show after the class starts
const t1 = hh * 60 + mm + 40;
await clock(`${sun}T${String(Math.floor(t1 / 60)).padStart(2, '0')}:${String(t1 % 60).padStart(2, '0')}`);
r = await fetch(BASE + '/api/cron/run', { method: 'POST', headers: { 'X-Gate-Key': GATE_KEY, 'Content-Type': 'application/json' }, body: '{}' }); const cr2 = await r.json();
check('cron marks the absent member as no-show', cr2.no_show >= 1, cr2);
r = await call('GET', `/api/classes/roster?schedule_id=${k1.schedule_id}&date=${sun}`, null, staff);
check('roster shows no_show', r.data.items.some((x) => x.status === 'no_show'), r.data.items);
// bans: 4 cancels in a row
await clock(`${sun}T00:10`);
const E = await mk('Ban E', '33100005');
let banned = null;
for (let i = 1; i <= 4; i++) {
  r = await P(E, 'POST', '/book', { schedule_id: k2.schedule_id, date: sun });
  if (r.status !== 200) { banned = r; break; }
  await P(E, 'POST', '/cancel', { booking_id: r.data.booking_id });
}
check('three cancels in a row are still allowed', banned === null);
r = await P(E, 'POST', '/book', { schedule_id: k2.schedule_id, date: sun });
check('fourth cancel in a row bans for a week', r.status === 403 && r.data.error.includes(plusDays(sun, 7)), r);
r = await P(E, 'GET', '/booking');
check('overview shows the ban', r.data.ban_until === plusDays(sun, 7), r.data.ban_until);
r = await call('POST', `/api/members/${E.id}/unban`, {}, staff);
check('staff cannot unban', r.status === 403, r.status);
r = await call('POST', `/api/members/${E.id}/unban`, {}, admin);
r = await P(E, 'POST', '/book', { schedule_id: k2.schedule_id, date: sun });
check('admin unban lets E book again', r.status === 200, r);
r = await call('POST', `/api/class-bookings/${r.data.booking_id}/attend`, {}, staff);
check('staff marks attended', r.status === 200, r);
await clock(null);

console.log(failed ? `\n${failed} check(s) FAILED` : '\nAll checks passed');
process.exit(failed ? 1 : 0);
