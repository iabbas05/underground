// Class booking: 20 seats per class, waitlist with offers, cancel rules, no-show bans, in-app notifications.
// Customers can book today and tomorrow only (Bahrain time). Friday is the rest day.

export const MAX_STRIKES = 3;          // ban when consecutive cancels/no-shows go above this
export const BAN_DAYS = 7;
export const CANCEL_MIN_MINUTES = 60;  // cancel at least 1 hour before the class
export const OFFER_MINUTES = 15;       // how long a freed seat is held for the next person
const TAKEN = "('booked','offered','attended')";
const ACTIVE = "('booked','offered','waitlist','attended')";

let skew = 0; // only moved by the test clock (see setTestClock); 0 in production
export const setTestClock = (isoBahrain) => { skew = isoBahrain ? Date.parse(`${isoBahrain}:00Z`) - (Date.now() + 3 * 3600e3) : 0; };
const bh = () => new Date(Date.now() + skew + 3 * 3600e3);
export const bhDate = () => bh().toISOString().slice(0, 10);
const stamp = () => bh().toISOString().slice(0, 19).replace('T', ' ');
const stampOf = (ms) => new Date(ms).toISOString().slice(0, 19).replace('T', ' ');
const classMs = (date, time) => Date.parse(`${date}T${time}:00Z`);
const nowMs = () => bh().getTime();
const dow = (date) => new Date(`${date}T00:00:00Z`).getUTCDay();
const addDay = (date, n) => { const d = new Date(`${date}T00:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };

export class BookingError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const fail = (status, message) => { throw new BookingError(status, message); };

const LEVELS = { ba: ['مبتدئين ومتقدمين', 'Beginners & advanced'], beast: ['بيست', 'Beast'] };
function msg(kind, d) {
  const lv = LEVELS[d.level] || ['', ''];
  const dayAr = d.date === bhDate() ? 'اليوم' : 'غداً';
  const dayEn = d.date === bhDate() ? 'today' : 'tomorrow';
  const cls = (ar) => (ar ? `كلاس ${lv[0]} الساعة ${d.time} (${dayAr})` : `${lv[1]} class at ${d.time} (${dayEn})`);
  switch (kind) {
    case 'offer': return { title_ar: 'تحرّر مكان في الكلاس', title_en: 'A seat opened up', body_ar: `تحرّر مكان في ${cls(true)}. أكّد خلال ${OFFER_MINUTES} دقيقة وإلا ينتقل لغيرك.`, body_en: `A seat opened in the ${cls(false)}. Confirm within ${OFFER_MINUTES} minutes or it goes to the next person.` };
    case 'offer_expired': return { title_ar: 'انتهت مهلة المكان', title_en: 'Offer expired', body_ar: `انتهت مهلة تأكيد ${cls(true)}.`, body_en: `The time to confirm the ${cls(false)} ran out.` };
    case 'reminder': return { title_ar: 'تذكير بالكلاس', title_en: 'Class reminder', body_ar: `${cls(true)} يبدأ بعد ساعة تقريباً.`, body_en: `The ${cls(false)} starts in about an hour.` };
    case 'removed': return { title_ar: 'تم إلغاء حجزك', title_en: 'Booking cancelled', body_ar: `ألغى الموظف حجزك في ${cls(true)}.`, body_en: `Staff cancelled your booking for the ${cls(false)}.` };
    case 'banned': return { title_ar: 'إيقاف الحجز مؤقتاً', title_en: 'Booking paused', body_ar: `بسبب تكرار الإلغاء أو الغياب، الحجز موقوف حتى ${d.until}.`, body_en: `Because of repeated cancellations or no-shows, booking is paused until ${d.until}.` };
    default: return { title_ar: '', title_en: '', body_ar: '', body_en: '' };
  }
}

export async function notify(env, memberId, kind, data) {
  const m = msg(kind, data);
  await env.DB.prepare('INSERT INTO notifications (member_id,kind,title_ar,title_en,body_ar,body_en,data,created_at) VALUES (?,?,?,?,?,?,?,?)')
    .bind(memberId, kind, m.title_ar, m.title_en, m.body_ar, m.body_en, JSON.stringify(data), stamp()).run();
  // Push / WhatsApp adapters plug in here later (read env.WHATSAPP_* / FCM settings and send m.*).
}

export async function listNotifications(env, memberId) {
  const items = (await env.DB.prepare('SELECT id,kind,title_ar,title_en,body_ar,body_en,data,created_at,read_at FROM notifications WHERE member_id=? ORDER BY id DESC LIMIT 30').bind(memberId).all()).results;
  const unread = items.filter((n) => !n.read_at).length;
  return { unread, items: items.map((n) => ({ ...n, data: n.data ? JSON.parse(n.data) : null })) };
}
export async function markRead(env, memberId) {
  await env.DB.prepare('UPDATE notifications SET read_at=? WHERE member_id=? AND read_at IS NULL').bind(stamp(), memberId).run();
}

function banState(m) {
  const t = stamp().slice(0, 10);
  return m.ban_until && m.ban_until >= t ? m.ban_until : null;
}

// Classes the member can see: today and tomorrow, for their own branch.
export async function overview(env, m) {
  const dates = [bhDate(), addDay(bhDate(), 1)];
  const out = [];
  for (const date of dates) {
    const day = dow(date);
    if (day === 5) { out.push({ date, rest: true, items: [] }); continue; }
    const rows = (await env.DB.prepare('SELECT id,audience,time,level,capacity FROM schedule WHERE branch_id=? AND day=? ORDER BY time').bind(m.branch_id, day).all()).results;
    const counts = (await env.DB.prepare(`SELECT schedule_id, status, COUNT(*) AS n FROM class_bookings WHERE class_date=? AND schedule_id IN (SELECT id FROM schedule WHERE branch_id=? AND day=?) GROUP BY schedule_id, status`).bind(date, m.branch_id, day).all()).results;
    const mine = (await env.DB.prepare(`SELECT id,schedule_id,status,offer_expires_at FROM class_bookings WHERE member_id=? AND class_date=? AND status IN ${ACTIVE}`).bind(m.id, date).all()).results;
    const items = rows.map((r) => {
      const c = (s) => counts.filter((x) => x.schedule_id === r.id && x.status === s).reduce((a, x) => a + x.n, 0);
      const taken = c('booked') + c('offered') + c('attended');
      const my = mine.find((x) => x.schedule_id === r.id) || null;
      const startMs = classMs(date, r.time);
      const minutesLeft = Math.floor((startMs - nowMs()) / 60000);
      return {
        schedule_id: r.id, audience: r.audience, time: r.time, level: r.level, capacity: r.capacity,
        taken, free: Math.max(r.capacity - taken, 0), waitlist: c('waitlist'), full: taken >= r.capacity,
        closed: minutesLeft <= 0,
        my_booking_id: my?.id ?? null, my_status: my?.status ?? null, offer_expires_at: my?.offer_expires_at ?? null,
        can_cancel: !!my && (my.status === 'waitlist' || my.status === 'offered' || (my.status === 'booked' && minutesLeft >= CANCEL_MIN_MINUTES)),
      };
    });
    out.push({ date, rest: false, items });
  }
  return { dates: out, ban_until: banState(m), strikes: m.strike_count || 0, max_strikes: MAX_STRIKES, cancel_minutes: CANCEL_MIN_MINUTES };
}

export async function book(env, m, scheduleId, date) {
  if (m.blocked) fail(403, 'Your membership is blocked');
  const ban = banState(m);
  if (ban) fail(403, `Booking is paused until ${ban}`);
  const dates = [bhDate(), addDay(bhDate(), 1)];
  if (!dates.includes(date)) fail(400, 'You can only book today or tomorrow');
  if (m.end_date < date) fail(403, 'Your membership ends before this class');
  const s = await env.DB.prepare('SELECT id,branch_id,day,time,level,capacity FROM schedule WHERE id=?').bind(scheduleId).first();
  if (!s || s.branch_id !== m.branch_id || s.day !== dow(date)) fail(404, 'Class not found');
  if (dow(date) === 5) fail(400, 'Friday is a rest day');
  if (classMs(date, s.time) <= nowMs()) fail(400, 'This class already started');
  const dup = await env.DB.prepare(`SELECT id FROM class_bookings WHERE member_id=? AND class_date=? AND schedule_id=? AND status IN ${ACTIVE}`).bind(m.id, date, s.id).first();
  if (dup) fail(409, 'You already booked this class');
  const clash = await env.DB.prepare(`SELECT id FROM class_bookings WHERE member_id=? AND class_date=? AND class_time=? AND status IN ${ACTIVE}`).bind(m.id, date, s.time).first();
  if (clash) fail(409, 'You already have a class at this time');
  const res = await env.DB.prepare(`INSERT INTO class_bookings (member_id,schedule_id,class_date,class_time,status,created_at)
    SELECT ?,?,?,?,'booked',? WHERE (SELECT COUNT(*) FROM class_bookings WHERE schedule_id=? AND class_date=? AND status IN ${TAKEN}) < ?`)
    .bind(m.id, s.id, date, s.time, stamp(), s.id, date, s.capacity).run();
  if (res.meta.changes === 1) return { status: 'booked', booking_id: res.meta.last_row_id };
  const w = await env.DB.prepare("INSERT INTO class_bookings (member_id,schedule_id,class_date,class_time,status,created_at) VALUES (?,?,?,?,'waitlist',?)").bind(m.id, s.id, date, s.time, stamp()).run();
  const pos = (await env.DB.prepare("SELECT COUNT(*) AS n FROM class_bookings WHERE schedule_id=? AND class_date=? AND status='waitlist' AND id<=?").bind(s.id, date, w.meta.last_row_id).first()).n;
  return { status: 'waitlist', booking_id: w.meta.last_row_id, position: pos };
}

async function addStrike(env, memberId) {
  await env.DB.prepare('UPDATE members SET strike_count=strike_count+1 WHERE id=?').bind(memberId).run();
  const m = await env.DB.prepare('SELECT strike_count FROM members WHERE id=?').bind(memberId).first();
  if (m.strike_count > MAX_STRIKES) {
    const until = addDay(bhDate(), BAN_DAYS);
    await env.DB.prepare('UPDATE members SET ban_until=?, strike_count=0 WHERE id=?').bind(until, memberId).run();
    await notify(env, memberId, 'banned', { until });
    // Waiting / future bookings of a banned member are released.
    const rows = (await env.DB.prepare(`SELECT id,schedule_id,class_date FROM class_bookings WHERE member_id=? AND status IN ('booked','waitlist','offered') AND class_date>=?`).bind(memberId, bhDate()).all()).results;
    for (const r of rows) {
      await env.DB.prepare("UPDATE class_bookings SET status='cancelled', updated_at=? WHERE id=?").bind(stamp(), r.id).run();
      await promote(env, r.schedule_id, r.class_date);
    }
  }
}

// Offer free seats to the people waiting, in the order they joined.
export async function promote(env, scheduleId, date) {
  const s = await env.DB.prepare('SELECT time,level,capacity FROM schedule WHERE id=?').bind(scheduleId).first();
  if (!s) return;
  const startMs = classMs(date, s.time);
  if (startMs <= nowMs()) return;
  const taken = (await env.DB.prepare(`SELECT COUNT(*) AS n FROM class_bookings WHERE schedule_id=? AND class_date=? AND status IN ${TAKEN}`).bind(scheduleId, date).first()).n;
  const freeSeats = s.capacity - taken;
  if (freeSeats <= 0) return;
  const next = (await env.DB.prepare("SELECT id,member_id FROM class_bookings WHERE schedule_id=? AND class_date=? AND status='waitlist' ORDER BY id LIMIT ?").bind(scheduleId, date, freeSeats).all()).results;
  for (const w of next) {
    const expires = stampOf(Math.min(nowMs() + OFFER_MINUTES * 60000, startMs));
    await env.DB.prepare("UPDATE class_bookings SET status='offered', offer_expires_at=?, updated_at=? WHERE id=?").bind(expires, stamp(), w.id).run();
    await notify(env, w.member_id, 'offer', { booking_id: w.id, date, time: s.time, level: s.level, expires });
  }
}

export async function cancel(env, m, bookingId, { byStaff = false } = {}) {
  const b = await env.DB.prepare('SELECT * FROM class_bookings WHERE id=?').bind(bookingId).first();
  if (!b || (!byStaff && b.member_id !== m.id)) fail(404, 'Booking not found');
  if (!['booked', 'waitlist', 'offered'].includes(b.status)) fail(400, 'This booking is already closed');
  const minutesLeft = Math.floor((classMs(b.class_date, b.class_time) - nowMs()) / 60000);
  if (!byStaff && b.status === 'booked' && minutesLeft < CANCEL_MIN_MINUTES) fail(400, 'Too late to cancel: less than 1 hour before the class');
  await env.DB.prepare("UPDATE class_bookings SET status='cancelled', updated_at=? WHERE id=?").bind(stamp(), b.id).run();
  const freed = b.status === 'booked' || b.status === 'offered';
  if (!byStaff && b.status === 'booked') await addStrike(env, b.member_id);
  if (byStaff) {
    const s = await env.DB.prepare('SELECT level FROM schedule WHERE id=?').bind(b.schedule_id).first();
    await notify(env, b.member_id, 'removed', { date: b.class_date, time: b.class_time, level: s?.level });
  }
  if (freed) await promote(env, b.schedule_id, b.class_date);
  return { ok: true };
}

export async function respondOffer(env, m, bookingId, accept) {
  const b = await env.DB.prepare('SELECT * FROM class_bookings WHERE id=? AND member_id=?').bind(bookingId, m.id).first();
  if (!b) fail(404, 'Booking not found');
  if (b.status !== 'offered') fail(400, 'There is no open offer');
  if (b.offer_expires_at && b.offer_expires_at < stamp()) {
    await env.DB.prepare("UPDATE class_bookings SET status='expired', updated_at=? WHERE id=?").bind(stamp(), b.id).run();
    await promote(env, b.schedule_id, b.class_date);
    fail(410, 'The offer expired');
  }
  if (accept) {
    await env.DB.prepare("UPDATE class_bookings SET status='booked', offer_expires_at=NULL, updated_at=? WHERE id=?").bind(stamp(), b.id).run();
    return { status: 'booked' };
  }
  await env.DB.prepare("UPDATE class_bookings SET status='declined', updated_at=? WHERE id=?").bind(stamp(), b.id).run();
  await promote(env, b.schedule_id, b.class_date);
  return { status: 'declined' };
}

// Staff view of one class.
export async function roster(env, scheduleId, date) {
  const s = await env.DB.prepare('SELECT id,branch_id,audience,time,level,capacity FROM schedule WHERE id=?').bind(scheduleId).first();
  if (!s) fail(404, 'Class not found');
  const rows = (await env.DB.prepare(`SELECT c.id,c.status,c.offer_expires_at,c.created_at,m.id AS member_id,m.name,m.phone FROM class_bookings c JOIN members m ON m.id=c.member_id
    WHERE c.schedule_id=? AND c.class_date=? AND c.status IN ('booked','offered','waitlist','attended','no_show') ORDER BY CASE c.status WHEN 'waitlist' THEN 1 ELSE 0 END, c.id`).bind(scheduleId, date).all()).results;
  const taken = rows.filter((r) => ['booked', 'offered', 'attended'].includes(r.status)).length;
  return { schedule: s, date, taken, free: Math.max(s.capacity - taken, 0), items: rows };
}

export async function markAttended(env, bookingId) {
  const b = await env.DB.prepare('SELECT * FROM class_bookings WHERE id=?').bind(bookingId).first();
  if (!b || b.status !== 'booked') fail(400, 'Only a confirmed booking can be marked');
  await env.DB.prepare("UPDATE class_bookings SET status='attended', updated_at=? WHERE id=?").bind(stamp(), b.id).run();
  await env.DB.prepare('UPDATE members SET strike_count=0 WHERE id=?').bind(b.member_id).run();
  return { ok: true };
}

// Runs every few minutes: expire offers, remind, and settle finished classes (attended / no-show).
export async function runCron(env) {
  const now = stamp();
  const out = { expired: 0, reminded: 0, attended: 0, no_show: 0 };
  const stale = (await env.DB.prepare("SELECT id,member_id,schedule_id,class_date,class_time FROM class_bookings WHERE status='offered' AND offer_expires_at < ?").bind(now).all()).results;
  for (const b of stale) {
    await env.DB.prepare("UPDATE class_bookings SET status='expired', updated_at=? WHERE id=?").bind(now, b.id).run();
    const s = await env.DB.prepare('SELECT level FROM schedule WHERE id=?').bind(b.schedule_id).first();
    await notify(env, b.member_id, 'offer_expired', { date: b.class_date, time: b.class_time, level: s?.level });
    await promote(env, b.schedule_id, b.class_date);
    out.expired++;
  }
  const horizon = stampOf(nowMs() + 70 * 60000);
  const soon = (await env.DB.prepare("SELECT c.id,c.member_id,c.class_date,c.class_time,s.level FROM class_bookings c JOIN schedule s ON s.id=c.schedule_id WHERE c.status='booked' AND c.reminded=0 AND c.class_date>=?").bind(bhDate()).all()).results;
  for (const b of soon) {
    const diff = classMs(b.class_date, b.class_time) - nowMs();
    if (diff > 0 && diff <= 70 * 60000) {
      await env.DB.prepare('UPDATE class_bookings SET reminded=1 WHERE id=?').bind(b.id).run();
      await notify(env, b.member_id, 'reminder', { date: b.class_date, time: b.class_time, level: b.level });
      out.reminded++;
    }
  }
  void horizon;
  // 30 minutes after the start: a gate entry between 60 min before and 90 min after = attended, else no-show.
  const done = (await env.DB.prepare("SELECT id,member_id,class_date,class_time FROM class_bookings WHERE status='booked' AND class_date>=?").bind(addDay(bhDate(), -1)).all()).results;
  for (const b of done) {
    const start = classMs(b.class_date, b.class_time);
    if (nowMs() < start + 30 * 60000) continue;
    const from = stampOf(start - 60 * 60000).slice(0, 16);
    const to = stampOf(start + 90 * 60000).slice(0, 16);
    const hit = await env.DB.prepare("SELECT id FROM gate_logs WHERE member_id=? AND result='allowed' AND created_at>=? AND created_at<=? LIMIT 1").bind(b.member_id, from, to).first();
    if (hit) {
      await env.DB.prepare("UPDATE class_bookings SET status='attended', updated_at=? WHERE id=?").bind(now, b.id).run();
      await env.DB.prepare('UPDATE members SET strike_count=0 WHERE id=?').bind(b.member_id).run();
      out.attended++;
    } else {
      await env.DB.prepare("UPDATE class_bookings SET status='no_show', updated_at=? WHERE id=?").bind(now, b.id).run();
      await addStrike(env, b.member_id);
      out.no_show++;
    }
  }
  return out;
}
