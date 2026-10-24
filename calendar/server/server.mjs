// The calendar server: the application, people who sign in, and a subset of
// the Google Calendar API v3 (same paths, same JSON) kept in one JSON file.
//
//   node calendar/server/server.mjs [--demo] [--port 8080]
//
// Environment: PORT, CALENDAR_DATA (the JSON file), GOOGLE_CLIENT_ID (for the
// import from Google Calendar). No dependencies besides Node 18 or later.

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { zoneOrNull, momentOf, formatInZone, parseDateTime, dateInZone } from './time.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const appDir = path.resolve(here, '..');
const args = process.argv.slice(2);
const argValue = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const PORT = Number(argValue('--port') || process.env.PORT || 8080);
const DATA = process.env.CALENDAR_DATA || path.join(here, 'data.json');
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';

// ---------------------------------------------------------------- storage

let db = { users: [], sessions: {}, calendars: {}, prefs: {} };

function load() {
  if (fs.existsSync(DATA)) {
    db = JSON.parse(fs.readFileSync(DATA, 'utf8'));
    return true;
  }
  return false;
}

function save() {
  const tmp = DATA + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(db, null, 1));
  fs.renameSync(tmp, DATA);
}

const newId = () => crypto.randomBytes(12).toString('hex');
const now = () => new Date().toISOString();
const etag = () => `"${Date.now()}${crypto.randomBytes(2).toString('hex')}"`;

// The colors of Google Calendar (calendar colorId 1 to 24).
const calendarColors = [
  '#ac725e', '#d06b64', '#f83a22', '#fa573c', '#ff7537', '#ffad46', '#42d692', '#16a765',
  '#7bd148', '#b3dc6c', '#fbe983', '#fad165', '#92e1c0', '#9fe1e7', '#9fc6e7', '#4986e7',
  '#9a9cff', '#b99aff', '#c2c2c2', '#cabdbf', '#cca6ac', '#f691b2', '#cd74e6', '#a47ae2',
];
const defaultColorIds = [16, 8, 24, 5, 3, 14, 23, 10, 12, 1];

// ---------------------------------------------------------------- people

function hashPassword(password, salt) {
  return crypto.scryptSync(password, salt, 32).toString('hex');
}

function findUser(email) {
  const e = String(email || '').trim().toLowerCase();
  return db.users.find((u) => u.email === e);
}

function publicUser(u) {
  return { name: u.name, email: u.email };
}

function createUser({ name, email, password, timeZone }) {
  const salt = crypto.randomBytes(16).toString('hex');
  const user = {
    name: String(name).trim(),
    email: String(email).trim().toLowerCase(),
    salt,
    hash: hashPassword(password, salt),
    timeZone: zoneOrNull(timeZone) || 'UTC',
  };
  db.users.push(user);
  createCalendar(user, { id: user.email, summary: user.name, timeZone: user.timeZone });
  return user;
}

function startSession(res, user) {
  const token = crypto.randomBytes(24).toString('hex');
  db.sessions[token] = user.email;
  res.setHeader('Set-Cookie', `calendar_session=${token}; HttpOnly; SameSite=Lax; Path=/; Max-Age=2592000`);
}

function sessionUser(req) {
  const cookie = req.headers.cookie || '';
  const m = /(?:^|;\s*)calendar_session=([0-9a-f]+)/.exec(cookie);
  return m && db.sessions[m[1]] ? findUser(db.sessions[m[1]]) : null;
}

// ---------------------------------------------------------------- calendars and access

const roleRank = { none: 0, freeBusyReader: 1, reader: 2, writer: 3, owner: 4 };

function createCalendar(owner, { id, summary, description, timeZone }) {
  const cal = {
    id: id || `${newId()}@group.calendar.local`,
    etag: etag(),
    summary: String(summary || '').trim() || 'Untitled calendar',
    description: description || '',
    timeZone: zoneOrNull(timeZone) || owner.timeZone || 'UTC',
    acl: [{ id: `user:${owner.email}`, role: 'owner', scope: { type: 'user', value: owner.email } }],
    events: {},
  };
  db.calendars[cal.id] = cal;
  return cal;
}

function resolveCalendarId(user, id) {
  return id === 'primary' ? user.email : id;
}

function roleOf(cal, user) {
  const rule = cal.acl.find((r) => r.scope.type === 'user' && r.scope.value === user.email);
  const fromDefault = cal.acl.find((r) => r.scope.type === 'default');
  const roles = [rule && rule.role, fromDefault && fromDefault.role].filter(Boolean);
  return roles.reduce((best, r) => (roleRank[r] > roleRank[best] ? r : best), 'none');
}

function prefsOf(user) {
  db.prefs[user.email] = db.prefs[user.email] || {};
  return db.prefs[user.email];
}

function listEntry(cal, user) {
  const prefs = prefsOf(user);
  if (!prefs[cal.id]) {
    const used = Object.keys(prefs).length;
    const colorId = defaultColorIds[used % defaultColorIds.length];
    prefs[cal.id] = { selected: true, colorId: String(colorId), backgroundColor: calendarColors[colorId - 1] };
  }
  const p = prefs[cal.id];
  const entry = {
    kind: 'calendar#calendarListEntry',
    etag: cal.etag,
    id: cal.id,
    summary: cal.summary,
    description: cal.description,
    timeZone: cal.timeZone,
    colorId: p.colorId,
    backgroundColor: p.backgroundColor,
    foregroundColor: p.foregroundColor || '#000000',
    selected: p.selected !== false,
    accessRole: roleOf(cal, user),
    defaultReminders: [],
  };
  if (cal.id === user.email) entry.primary = true;
  if (p.summaryOverride) entry.summaryOverride = p.summaryOverride;
  return entry;
}

function calendarResource(cal) {
  return {
    kind: 'calendar#calendar',
    etag: cal.etag,
    id: cal.id,
    summary: cal.summary,
    description: cal.description,
    timeZone: cal.timeZone,
  };
}

// ---------------------------------------------------------------- events

class ApiError extends Error {
  constructor(code, reason, message) {
    super(message);
    this.code = code;
    this.reason = reason;
  }
}

function normalizeTime(time, calZone, which) {
  if (!time || typeof time !== 'object') throw new ApiError(400, 'required', `Missing ${which} time.`);
  if (time.date) {
    if (!/^\d{4}-\d\d-\d\d$/.test(time.date)) throw new ApiError(400, 'invalid', `Invalid ${which} date.`);
    return { date: time.date };
  }
  const zone = zoneOrNull(time.timeZone);
  const parsed = parseDateTime(time.dateTime, zone || calZone);
  if (!parsed) throw new ApiError(400, 'invalid', `Invalid ${which} time.`);
  const out = { dateTime: formatInZone(parsed.ms, zone || calZone) };
  if (zone) out.timeZone = zone;
  return out;
}

function normalizePerson(p) {
  const email = String(p.email || '').trim().toLowerCase();
  const out = { ...p, email };
  const known = findUser(email);
  if (!out.displayName && known) out.displayName = known.name;
  delete out.self;
  return out;
}

// Applies the fields of an insert, update or import onto an event.
function shapeEvent(cal, user, body, existing) {
  const event = existing ? { ...existing, ...body } : { ...body };
  for (const key of ['id', 'etag', 'kind', 'htmlLink', 'created', 'creator', 'organizer', 'self']) {
    if (existing) event[key] = existing[key];
  }
  event.start = normalizeTime(event.start, cal.timeZone, 'start');
  event.end = normalizeTime(event.end, cal.timeZone, 'end');
  if (!!event.start.date !== !!event.end.date) {
    throw new ApiError(400, 'invalid', 'The start and end times must both be dates or both be date-times.');
  }
  const s = momentOf(event.start, cal.timeZone);
  const e = momentOf(event.end, cal.timeZone);
  if (!(e > s)) throw new ApiError(400, 'timeRangeEmpty', 'The specified time range is empty.');
  event.summary = event.summary == null ? '' : String(event.summary);
  event.status = ['confirmed', 'tentative', 'cancelled'].includes(event.status) ? event.status : 'confirmed';
  if (event.recurrence && !Array.isArray(event.recurrence)) event.recurrence = [String(event.recurrence)];
  if (Array.isArray(event.recurrence) && event.recurrence.length === 0) delete event.recurrence;
  if (!existing) {
    event.kind = 'calendar#event';
    event.id = newId();
    event.created = now();
    event.creator = { email: user.email, displayName: user.name };
    if (!event.organizer || !event.organizer.email) {
      event.organizer = cal.id === user.email
        ? { email: user.email, displayName: user.name }
        : { email: cal.id, displayName: cal.summary };
    } else {
      event.organizer = normalizePerson(event.organizer);
    }
    event.iCalUID = event.iCalUID || `${event.id}@calendar.local`;
    event.sequence = Number(event.sequence) || 0;
  } else {
    event.sequence = (Number(existing.sequence) || 0) + 1;
  }
  if (Array.isArray(event.attendees) && event.attendees.length > 0) {
    const seen = new Set();
    event.attendees = event.attendees
      .filter((a) => a && a.email)
      .map(normalizePerson)
      .filter((a) => (seen.has(a.email) ? false : seen.add(a.email)))
      .map((a) => ({ ...a, responseStatus: a.responseStatus || 'needsAction' }));
    const organizer = event.organizer.email;
    const known = findUser(organizer);
    if (known && !event.attendees.some((a) => a.email === organizer)) {
      event.attendees.unshift({ email: organizer, displayName: known.name, organizer: true, responseStatus: 'accepted' });
    }
  } else {
    delete event.attendees;
  }
  event.updated = now();
  event.etag = etag();
  return event;
}

function isAttendee(event, user) {
  return (event.attendees || []).some((a) => a.email === user.email);
}

// The event as one person sees it: self flags, times in their zone, and only
// the busy time on a calendar they may only see free and busy times of.
function viewEvent(event, cal, user, zone, role) {
  const tz = zoneOrNull(zone);
  const asTime = (t) => {
    if (!tz || !t.dateTime) return t;
    const ms = momentOf(t, cal.timeZone);
    return { ...t, dateTime: formatInZone(ms, tz) };
  };
  if (role === 'freeBusyReader') {
    return { kind: event.kind, id: event.id, status: event.status, start: asTime(event.start), end: asTime(event.end), recurrence: event.recurrence };
  }
  const mark = (p) => (p && p.email === user.email ? { ...p, self: true } : p);
  const out = { ...event, start: asTime(event.start), end: asTime(event.end) };
  out.organizer = mark(event.organizer);
  out.creator = mark(event.creator);
  if (event.attendees) out.attendees = event.attendees.map(mark);
  return out;
}

function overlaps(event, cal, timeMin, timeMax) {
  const s = momentOf(event.start, cal.timeZone);
  const e = momentOf(event.end, cal.timeZone);
  if (event.recurrence && event.recurrence.some((r) => r.startsWith('RRULE'))) {
    return timeMax == null || s < timeMax;
  }
  return (timeMax == null || s < timeMax) && (timeMin == null || e > timeMin);
}

function textMatches(event, q) {
  if (!q) return true;
  const hay = [event.summary, event.description, event.location].join(' ').toLowerCase();
  return q.toLowerCase().split(/\s+/).every((w) => hay.includes(w));
}

// Every event the person can reach by its id from this calendar: its own,
// and on their primary calendar the events they are invited to.
function locateEvent(user, calId, eventId) {
  const cal = db.calendars[calId];
  if (!cal) throw new ApiError(404, 'notFound', 'Not Found');
  const role = roleOf(cal, user);
  if (cal.events[eventId] && roleRank[role] >= 1) return { cal, event: cal.events[eventId], role, invited: false };
  if (calId === user.email) {
    for (const other of Object.values(db.calendars)) {
      const ev = other.events[eventId];
      if (ev && isAttendee(ev, user)) {
        const r = roleOf(other, user);
        return { cal: other, event: ev, role: roleRank[r] >= roleRank.writer ? r : 'attendee', invited: true };
      }
    }
  }
  throw new ApiError(404, 'notFound', 'Not Found');
}

// The import of a whole Google Calendar (the items of events.list with
// singleEvents=false): a changed or cancelled instance of a recurring event
// becomes an EXDATE on the series, and a changed one an event of its own.
function importGoogle(user, cal, items) {
  const byOriginalId = new Map();
  let imported = 0;
  let skipped = 0;
  const masters = items.filter((it) => !it.recurringEventId);
  const instances = items.filter((it) => it.recurringEventId);
  for (const item of masters) {
    if (item.status === 'cancelled') {
      skipped++;
      continue;
    }
    try {
      const body = { ...item };
      delete body.id;
      const ev = upsertByUid(cal, user, body);
      byOriginalId.set(item.id, ev);
      imported++;
    } catch {
      skipped++;
    }
  }
  for (const item of instances) {
    const master = byOriginalId.get(item.recurringEventId);
    if (master && item.originalStartTime) {
      master.recurrence = [...(master.recurrence || []), exdateFor(item.originalStartTime, master, cal)];
    }
    if (item.status === 'cancelled') continue;
    try {
      const body = { ...item, iCalUID: `${item.iCalUID || item.id}-${item.id}` };
      for (const key of ['id', 'recurringEventId', 'originalStartTime', 'recurrence']) delete body[key];
      upsertByUid(cal, user, body);
      imported++;
    } catch {
      skipped++;
    }
  }
  return { imported, skipped };
}

function exdateFor(original, master, cal) {
  const compact = (s) => s.replace(/[-:]/g, '');
  if (original.date) return `EXDATE;VALUE=DATE:${compact(original.date)}`;
  const tz = zoneOrNull(master.start.timeZone) || cal.timeZone;
  const ms = momentOf(original, tz);
  const local = formatInZone(ms, tz).slice(0, 19);
  return `EXDATE;TZID=${tz}:${compact(local)}`;
}

function upsertByUid(cal, user, body) {
  const existing = body.iCalUID && Object.values(cal.events).find((e) => e.iCalUID === body.iCalUID);
  const ev = shapeEvent(cal, user, body, existing || null);
  cal.events[ev.id] = ev;
  return ev;
}

// ---------------------------------------------------------------- HTTP

function send(res, status, body, headers = {}) {
  const text = body == null ? '' : JSON.stringify(body);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...headers });
  res.end(text);
}

function sendError(res, err) {
  const code = err.code || 500;
  const message = err.message || 'Internal error';
  if (code === 500) console.error(err);
  send(res, code, { error: { code, message, errors: [{ domain: 'global', reason: err.reason || 'backendError', message }] } });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > 50 * 1024 * 1024) reject(new ApiError(413, 'tooLarge', 'The request is too large.'));
      else chunks.push(c);
    });
    req.on('end', () => {
      const text = Buffer.concat(chunks).toString('utf8');
      if (!text) return resolve({});
      try {
        resolve(JSON.parse(text));
      } catch {
        reject(new ApiError(400, 'parseError', 'Parse Error'));
      }
    });
    req.on('error', reject);
  });
}

function serveFile(res, file, type) {
  const full = path.join(appDir, file);
  if (!fs.existsSync(full)) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    return res.end(`${file} is missing: build the application first (npm run calendar:build).`);
  }
  res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-cache' });
  fs.createReadStream(full).pipe(res);
}

function requireRole(cal, user, minimum) {
  if (!cal) throw new ApiError(404, 'notFound', 'Not Found');
  const role = roleOf(cal, user);
  if (roleRank[role] < roleRank[minimum]) {
    throw new ApiError(roleRank[role] === 0 ? 404 : 403, roleRank[role] === 0 ? 'notFound' : 'forbidden', roleRank[role] === 0 ? 'Not Found' : 'Forbidden');
  }
  return role;
}

const routes = [];
const route = (method, pattern, handler, options = {}) => {
  const keys = [];
  const regex = new RegExp(
    '^' + pattern.replace(/:(\w+)/g, (_, k) => (keys.push(k), '([^/]+)')) + '$',
  );
  routes.push({ method, regex, keys, handler, options });
};

// ---- people

route('GET', '/config.json', async () => ({ googleClientId: GOOGLE_CLIENT_ID }));

route('POST', '/auth/register', async ({ body, res }) => {
  const { name, email, password, timeZone } = body;
  if (!name || !String(name).trim()) throw new ApiError(400, 'invalid', 'Write your name.');
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(email || '').trim())) throw new ApiError(400, 'invalid', 'Write a valid email address.');
  if (String(password || '').length < 8) throw new ApiError(400, 'invalid', 'The password needs at least 8 characters.');
  if (findUser(email)) throw new ApiError(409, 'duplicate', 'Someone is already registered with that email address.');
  const user = createUser({ name, email, password, timeZone });
  startSession(res, user);
  save();
  return publicUser(user);
});

route('POST', '/auth/login', async ({ body, res }) => {
  const user = findUser(body.email);
  if (!user || hashPassword(String(body.password || ''), user.salt) !== user.hash) {
    throw new ApiError(401, 'authError', 'The email address or the password is wrong.');
  }
  startSession(res, user);
  save();
  return publicUser(user);
});

route('POST', '/auth/logout', async ({ req, res }) => {
  const m = /(?:^|;\s*)calendar_session=([0-9a-f]+)/.exec(req.headers.cookie || '');
  if (m) delete db.sessions[m[1]];
  res.setHeader('Set-Cookie', 'calendar_session=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0');
  save();
  return {};
});

route('GET', '/auth/me', async ({ user }) => publicUser(user), { auth: true });

route('GET', '/api/users', async () => ({ items: db.users.map(publicUser) }), { auth: true });

// ---- calendar list

route('GET', '/calendar/v3/users/me/calendarList', async ({ user, query }) => {
  const showHidden = query.get('showHidden') === 'true';
  const prefs = prefsOf(user);
  const items = Object.values(db.calendars)
    .filter((cal) => roleRank[roleOf(cal, user)] >= 1)
    .filter((cal) => showHidden || !(prefs[cal.id] && prefs[cal.id].hidden))
    .map((cal) => listEntry(cal, user))
    .sort((a, b) => (b.primary ? 1 : 0) - (a.primary ? 1 : 0) || roleRank[b.accessRole] - roleRank[a.accessRole] || a.summary.localeCompare(b.summary));
  save();
  return { kind: 'calendar#calendarList', etag: etag(), items };
}, { auth: true });

route('POST', '/calendar/v3/users/me/calendarList', async ({ user, body }) => {
  const cal = db.calendars[body.id];
  requireRole(cal, user, 'freeBusyReader');
  const p = (prefsOf(user)[cal.id] = { ...(prefsOf(user)[cal.id] || {}), hidden: false });
  if (body.backgroundColor) p.backgroundColor = body.backgroundColor;
  save();
  return listEntry(cal, user);
}, { auth: true });

for (const method of ['PATCH', 'PUT']) {
  route(method, '/calendar/v3/users/me/calendarList/:calendarId', async ({ user, body, params }) => {
    const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
    requireRole(cal, user, 'freeBusyReader');
    listEntry(cal, user);
    const p = prefsOf(user)[cal.id];
    if (typeof body.selected === 'boolean') p.selected = body.selected;
    if (body.colorId && calendarColors[Number(body.colorId) - 1]) {
      p.colorId = String(body.colorId);
      p.backgroundColor = calendarColors[Number(body.colorId) - 1];
    }
    if (body.backgroundColor) p.backgroundColor = body.backgroundColor;
    if (body.foregroundColor) p.foregroundColor = body.foregroundColor;
    if ('summaryOverride' in body) p.summaryOverride = body.summaryOverride || undefined;
    save();
    return listEntry(cal, user);
  }, { auth: true });
}

route('DELETE', '/calendar/v3/users/me/calendarList/:calendarId', async ({ user, params }) => {
  const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
  requireRole(cal, user, 'freeBusyReader');
  if (cal.id === user.email) throw new ApiError(400, 'invalid', 'The primary calendar cannot be removed from the list.');
  listEntry(cal, user);
  prefsOf(user)[cal.id].hidden = true;
  save();
  return null;
}, { auth: true });

// ---- calendars

route('POST', '/calendar/v3/calendars', async ({ user, body }) => {
  if (!body.summary || !String(body.summary).trim()) throw new ApiError(400, 'required', 'Missing title.');
  const cal = createCalendar(user, body);
  listEntry(cal, user);
  save();
  return calendarResource(cal);
}, { auth: true });

route('GET', '/calendar/v3/calendars/:calendarId', async ({ user, params }) => {
  const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
  requireRole(cal, user, 'freeBusyReader');
  return calendarResource(cal);
}, { auth: true });

for (const method of ['PATCH', 'PUT']) {
  route(method, '/calendar/v3/calendars/:calendarId', async ({ user, body, params }) => {
    const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
    requireRole(cal, user, 'owner');
    if ('summary' in body) {
      if (!String(body.summary || '').trim()) throw new ApiError(400, 'required', 'Missing title.');
      cal.summary = String(body.summary).trim();
    }
    if ('description' in body) cal.description = body.description || '';
    if (body.timeZone) cal.timeZone = zoneOrNull(body.timeZone) || cal.timeZone;
    cal.etag = etag();
    save();
    return calendarResource(cal);
  }, { auth: true });
}

route('DELETE', '/calendar/v3/calendars/:calendarId', async ({ user, params }) => {
  const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
  requireRole(cal, user, 'owner');
  if (cal.id === user.email) throw new ApiError(400, 'cannotDeletePrimaryCalendar', 'The primary calendar cannot be deleted.');
  delete db.calendars[cal.id];
  for (const prefs of Object.values(db.prefs)) delete prefs[cal.id];
  save();
  return null;
}, { auth: true });

// ---- sharing

route('GET', '/calendar/v3/calendars/:calendarId/acl', async ({ user, params }) => {
  const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
  requireRole(cal, user, 'owner');
  return { kind: 'calendar#acl', etag: cal.etag, items: cal.acl.map((r) => ({ kind: 'calendar#aclRule', etag: cal.etag, ...r })) };
}, { auth: true });

route('POST', '/calendar/v3/calendars/:calendarId/acl', async ({ user, body, params }) => {
  const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
  requireRole(cal, user, 'owner');
  const role = body.role;
  const scope = body.scope || {};
  if (!(role in roleRank) || role === 'none') throw new ApiError(400, 'invalid', 'Invalid role.');
  if (!['user', 'default'].includes(scope.type)) throw new ApiError(400, 'invalid', 'Only the scopes user and default are supported.');
  const value = scope.type === 'user' ? String(scope.value || '').trim().toLowerCase() : undefined;
  if (scope.type === 'user' && !/^[^@\s]+@[^@\s]+$/.test(value)) throw new ApiError(400, 'invalid', 'Invalid email address.');
  const id = scope.type === 'user' ? `user:${value}` : 'default';
  if (id === `user:${user.email}` && role !== 'owner') throw new ApiError(400, 'invalid', 'You cannot lower your own access.');
  const rule = { id, role, scope: scope.type === 'user' ? { type: 'user', value } : { type: 'default' } };
  cal.acl = [...cal.acl.filter((r) => r.id !== id), rule];
  cal.etag = etag();
  save();
  return { kind: 'calendar#aclRule', etag: cal.etag, ...rule };
}, { auth: true });

route('DELETE', '/calendar/v3/calendars/:calendarId/acl/:ruleId', async ({ user, params }) => {
  const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
  requireRole(cal, user, 'owner');
  if (params.ruleId === `user:${user.email}`) throw new ApiError(400, 'invalid', 'You cannot remove your own access.');
  if (!cal.acl.some((r) => r.id === params.ruleId)) throw new ApiError(404, 'notFound', 'Not Found');
  cal.acl = cal.acl.filter((r) => r.id !== params.ruleId);
  cal.etag = etag();
  save();
  return null;
}, { auth: true });

// ---- events

route('GET', '/calendar/v3/calendars/:calendarId/events', async ({ user, params, query }) => {
  const calId = resolveCalendarId(user, params.calendarId);
  const cal = db.calendars[calId];
  const role = requireRole(cal, user, 'freeBusyReader');
  const zone = query.get('timeZone') || cal.timeZone;
  const tMin = query.get('timeMin') ? (parseDateTime(query.get('timeMin'), 'UTC') || {}).ms : null;
  const tMax = query.get('timeMax') ? (parseDateTime(query.get('timeMax'), 'UTC') || {}).ms : null;
  const showDeleted = query.get('showDeleted') === 'true';
  const q = query.get('q');
  const uid = query.get('iCalUID');
  const keep = (ev, c) =>
    (showDeleted || ev.status !== 'cancelled') &&
    overlaps(ev, c, tMin, tMax) &&
    (!uid || ev.iCalUID === uid) &&
    textMatches(ev, role === 'freeBusyReader' ? '' : q);
  let items = Object.values(cal.events).filter((ev) => keep(ev, cal)).map((ev) => viewEvent(ev, cal, user, zone, role));
  if (calId === user.email) {
    for (const other of Object.values(db.calendars)) {
      if (other.id === calId) continue;
      for (const ev of Object.values(other.events)) {
        if (isAttendee(ev, user) && keep(ev, other)) items.push(viewEvent(ev, other, user, zone, 'reader'));
      }
    }
  }
  items.sort((a, b) => (momentOf(a.start, zone) || 0) - (momentOf(b.start, zone) || 0));
  return {
    kind: 'calendar#events',
    etag: cal.etag,
    summary: cal.summary,
    description: cal.description,
    updated: now(),
    timeZone: cal.timeZone,
    accessRole: role,
    defaultReminders: [],
    items,
  };
}, { auth: true });

route('POST', '/calendar/v3/calendars/:calendarId/events', async ({ user, params, body, query }) => {
  const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
  requireRole(cal, user, 'writer');
  const body2 = { ...body };
  delete body2.iCalUID;
  const ev = shapeEvent(cal, user, body2, null);
  cal.events[ev.id] = ev;
  save();
  return viewEvent(ev, cal, user, query.get('timeZone'), 'writer');
}, { auth: true });

route('POST', '/calendar/v3/calendars/:calendarId/events/import', async ({ user, params, body, query }) => {
  const cal = db.calendars[resolveCalendarId(user, params.calendarId)];
  requireRole(cal, user, 'writer');
  if (!body.iCalUID) throw new ApiError(400, 'required', 'Missing iCalUID.');
  const ev = upsertByUid(cal, user, { ...body, id: undefined });
  save();
  return viewEvent(ev, cal, user, query.get('timeZone'), 'writer');
}, { auth: true });

route('GET', '/calendar/v3/calendars/:calendarId/events/:eventId', async ({ user, params, query }) => {
  const found = locateEvent(user, resolveCalendarId(user, params.calendarId), params.eventId);
  return viewEvent(found.event, found.cal, user, query.get('timeZone'), found.role === 'attendee' ? 'reader' : found.role);
}, { auth: true });

for (const method of ['PATCH', 'PUT']) {
  route(method, '/calendar/v3/calendars/:calendarId/events/:eventId', async ({ user, params, body, query }) => {
    const found = locateEvent(user, resolveCalendarId(user, params.calendarId), params.eventId);
    let ev;
    if (roleRank[found.role] >= roleRank.writer) {
      ev = shapeEvent(found.cal, user, body, method === 'PUT' ? pickFixed(found.event) : found.event);
    } else if (found.invited || isAttendee(found.event, user)) {
      // A guest may change only their own answer.
      const mine = (body.attendees || []).find((a) => String(a.email || '').toLowerCase() === user.email);
      if (!mine) throw new ApiError(403, 'forbidden', 'Only the organizer can change this event.');
      const allowed = ['accepted', 'tentative', 'declined', 'needsAction'];
      if (!allowed.includes(mine.responseStatus)) throw new ApiError(400, 'invalid', 'Invalid response.');
      ev = {
        ...found.event,
        attendees: found.event.attendees.map((a) => (a.email === user.email ? { ...a, responseStatus: mine.responseStatus, comment: mine.comment } : a)),
        updated: now(),
        etag: etag(),
      };
    } else {
      throw new ApiError(403, 'forbidden', 'Forbidden');
    }
    found.cal.events[ev.id] = ev;
    save();
    return viewEvent(ev, found.cal, user, query.get('timeZone'), 'writer');
  }, { auth: true });
}

function pickFixed(event) {
  const fixed = {};
  for (const key of ['id', 'iCalUID', 'created', 'creator', 'organizer', 'kind', 'sequence']) fixed[key] = event[key];
  return fixed;
}

route('DELETE', '/calendar/v3/calendars/:calendarId/events/:eventId', async ({ user, params }) => {
  const found = locateEvent(user, resolveCalendarId(user, params.calendarId), params.eventId);
  if (roleRank[found.role] >= roleRank.writer && !found.invited) {
    delete found.cal.events[found.event.id];
  } else if (isAttendee(found.event, user)) {
    // A guest who deletes an invitation declines it, as in Google Calendar.
    found.event.attendees = found.event.attendees.map((a) => (a.email === user.email ? { ...a, responseStatus: 'declined' } : a));
    found.event.updated = now();
  } else {
    throw new ApiError(403, 'forbidden', 'Forbidden');
  }
  save();
  return null;
}, { auth: true });

// ---- import of a whole Google calendar

route('POST', '/api/import/google', async ({ user, body }) => {
  const items = Array.isArray(body.items) ? body.items : [];
  let cal;
  if (body.calendarId) {
    cal = db.calendars[resolveCalendarId(user, body.calendarId)];
    requireRole(cal, user, 'writer');
  } else {
    const source = body.calendar || {};
    cal = createCalendar(user, { summary: source.summary, description: source.description, timeZone: source.timeZone });
    listEntry(cal, user);
    if (source.backgroundColor) prefsOf(user)[cal.id].backgroundColor = source.backgroundColor;
    if (source.foregroundColor) prefsOf(user)[cal.id].foregroundColor = source.foregroundColor;
  }
  const result = importGoogle(user, cal, items);
  save();
  return { calendarId: cal.id, summary: cal.summary, ...result };
}, { auth: true });

// ---------------------------------------------------------------- server

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  try {
    if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')) {
      return serveFile(res, 'index.html', 'text/html; charset=utf-8');
    }
    if (req.method === 'GET' && url.pathname === '/main.js') {
      return serveFile(res, 'main.js', 'text/javascript; charset=utf-8');
    }
    for (const r of routes) {
      if (r.method !== req.method) continue;
      const m = r.regex.exec(url.pathname);
      if (!m) continue;
      const params = {};
      r.keys.forEach((k, i) => (params[k] = decodeURIComponent(m[i + 1])));
      const user = sessionUser(req);
      if (r.options && r.options.auth && !user) throw new ApiError(401, 'authError', 'Sign in first.');
      const body = ['POST', 'PATCH', 'PUT'].includes(req.method) ? await readBody(req) : {};
      const result = await r.handler({ req, res, user, params, body, query: url.searchParams });
      return result === null ? (res.writeHead(204), res.end()) : send(res, 200, result);
    }
    throw new ApiError(404, 'notFound', 'Not Found');
  } catch (err) {
    sendError(res, err);
  }
});

// ---------------------------------------------------------------- demo data

function demo() {
  const zone = 'Europe/Oslo';
  const ada = createUser({ name: 'Ada Lovelace', email: 'ada@example.com', password: 'calendar123', timeZone: zone });
  const bob = createUser({ name: 'Bob Hansen', email: 'bob@example.com', password: 'calendar123', timeZone: zone });
  createUser({ name: 'Cleo Berg', email: 'cleo@example.com', password: 'calendar123', timeZone: zone });
  const today = dateInZone(Date.now(), zone);
  const day = (offset) => {
    const d = new Date(`${today}T12:00:00Z`);
    d.setUTCDate(d.getUTCDate() + offset);
    return d.toISOString().slice(0, 10);
  };
  const monday = (() => {
    const wd = (new Date(`${today}T12:00:00Z`).getUTCDay() + 6) % 7;
    return -wd;
  })();
  const at = (offset, hhmm) => ({ dateTime: `${day(offset)}T${hhmm}:00`, timeZone: zone });
  const add = (cal, user, body) => {
    const ev = shapeEvent(cal, user, body, null);
    cal.events[ev.id] = ev;
  };
  const adaCal = db.calendars[ada.email];
  const bobCal = db.calendars[bob.email];
  add(adaCal, ada, {
    summary: 'Stand-up',
    start: at(monday, '09:00'),
    end: at(monday, '09:15'),
    recurrence: ['RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'],
  });
  add(adaCal, ada, { summary: 'Lunch with Cleo', location: 'Fjord Café', start: at(1, '11:30'), end: at(1, '12:30') });
  add(adaCal, ada, { summary: 'Quarterly planning', description: 'Orders, warehouses and the new product line.', start: at(2, '13:00'), end: at(2, '15:30'), attendees: [{ email: 'bob@example.com' }, { email: 'cleo@example.com' }] });
  add(adaCal, ada, { summary: 'Conference', start: { date: day(monday + 10) }, end: { date: day(monday + 12) } });
  const team = createCalendar(ada, { summary: 'Warehouse team', description: 'Shifts and deliveries', timeZone: zone });
  team.acl.push({ id: 'user:bob@example.com', role: 'writer', scope: { type: 'user', value: 'bob@example.com' } });
  team.acl.push({ id: 'user:cleo@example.com', role: 'reader', scope: { type: 'user', value: 'cleo@example.com' } });
  add(team, ada, { summary: 'Delivery from Aurora Logistics', start: at(0, '07:00'), end: at(0, '08:00') });
  add(team, ada, { summary: 'Stock count', start: at(3, '14:00'), end: at(3, '17:00') });
  add(team, ada, { summary: 'Inventory day', start: { date: day(monday + 4) }, end: { date: day(monday + 5) } });
  add(bobCal, bob, { summary: 'Customer visit: Fjord Foods', location: 'Bergen', start: at(1, '10:00'), end: at(1, '11:00'), attendees: [{ email: 'ada@example.com' }] });
  add(bobCal, bob, { summary: 'Dentist', start: at(2, '08:00'), end: at(2, '09:00') });
  bobCal.acl.push({ id: 'user:ada@example.com', role: 'freeBusyReader', scope: { type: 'user', value: 'ada@example.com' } });
  db.sessions = {};
}

if (!load()) {
  if (args.includes('--demo')) demo();
  save();
}

server.listen(PORT, () => {
  console.log(`Calendar on http://localhost:${PORT}/  (data: ${DATA})`);
  if (args.includes('--demo')) console.log('Demo people: ada@example.com, bob@example.com, cleo@example.com (password calendar123)');
});
