// Time zone arithmetic with the Intl database of Node: an RFC 3339 dateTime
// with or without an offset, an IANA time zone, milliseconds since the epoch.

const formats = new Map();

function format(tz) {
  if (!formats.has(tz)) {
    formats.set(
      tz,
      new Intl.DateTimeFormat('en-US', {
        timeZone: tz,
        hourCycle: 'h23',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      }),
    );
  }
  return formats.get(tz);
}

// Names Outlook and Exchange write in TZID, mapped to IANA names.
const windowsZones = {
  'W. Europe Standard Time': 'Europe/Berlin',
  'Romance Standard Time': 'Europe/Paris',
  'Central Europe Standard Time': 'Europe/Budapest',
  'Central European Standard Time': 'Europe/Warsaw',
  'GMT Standard Time': 'Europe/London',
  'FLE Standard Time': 'Europe/Helsinki',
  'E. Europe Standard Time': 'Europe/Bucharest',
  'Eastern Standard Time': 'America/New_York',
  'Central Standard Time': 'America/Chicago',
  'Mountain Standard Time': 'America/Denver',
  'Pacific Standard Time': 'America/Los_Angeles',
  'UTC': 'UTC',
  'Coordinated Universal Time': 'UTC',
};

export function zoneOrNull(tz) {
  if (!tz) return null;
  const name = windowsZones[tz] || tz;
  try {
    format(name);
    return name;
  } catch {
    return null;
  }
}

function parts(ms, tz) {
  const p = {};
  for (const { type, value } of format(tz).formatToParts(new Date(ms))) p[type] = value;
  return { y: +p.year, mo: +p.month, d: +p.day, h: +p.hour % 24, mi: +p.minute, s: +p.second };
}

export function offsetMinutes(ms, tz) {
  const p = parts(ms, tz);
  const wall = Date.UTC(p.y, p.mo - 1, p.d, p.h, p.mi, p.s);
  return Math.round((wall - Math.floor(ms / 1000) * 1000) / 60000);
}

// A wall-clock time in a zone; a time that does not exist (spring forward)
// moves forward by the jump, an ambiguous one (fall back) takes one of the two.
export function wallToMs(y, mo, d, h, mi, s, tz) {
  const guess = Date.UTC(y, mo - 1, d, h, mi, s);
  return guess - offsetMinutes(guess - offsetMinutes(guess, tz) * 60000, tz) * 60000;
}

const pad = (n, w = 2) => String(n).padStart(w, '0');

export function formatInZone(ms, tz) {
  const p = parts(ms, tz);
  const off = offsetMinutes(ms, tz);
  const sign = off < 0 ? '-' : '+';
  const a = Math.abs(off);
  return `${pad(p.y, 4)}-${pad(p.mo)}-${pad(p.d)}T${pad(p.h)}:${pad(p.mi)}:${pad(p.s)}${sign}${pad(Math.floor(a / 60))}:${pad(a % 60)}`;
}

export function dateInZone(ms, tz) {
  const p = parts(ms, tz);
  return `${pad(p.y, 4)}-${pad(p.mo)}-${pad(p.d)}`;
}

const dateTimePattern =
  /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d)(?::(\d\d)(?:\.\d+)?)?(Z|[+-]\d\d:?\d\d)?$/;

// { ms, hasOffset } for a dateTime, or null when it is not one.
export function parseDateTime(text, tz) {
  const m = dateTimePattern.exec(text || '');
  if (!m) return null;
  const [y, mo, d, h, mi, s] = [m[1], m[2], m[3], m[4], m[5], m[6] || '0'].map(Number);
  if (m[7]) {
    let off = 0;
    if (m[7] !== 'Z') {
      const sign = m[7][0] === '-' ? -1 : 1;
      const digits = m[7].slice(1).replace(':', '');
      off = sign * (Number(digits.slice(0, 2)) * 60 + Number(digits.slice(2)));
    }
    return { ms: Date.UTC(y, mo - 1, d, h, mi, s) - off * 60000, hasOffset: true };
  }
  return { ms: wallToMs(y, mo, d, h, mi, s, tz), hasOffset: false };
}

const datePattern = /^(\d{4})-(\d\d)-(\d\d)$/;

export function parseDate(text, tz) {
  const m = datePattern.exec(text || '');
  if (!m) return null;
  return wallToMs(Number(m[1]), Number(m[2]), Number(m[3]), 0, 0, 0, tz);
}

// The moment of an event's start or end ({ date } or { dateTime, timeZone }).
export function momentOf(time, fallbackZone) {
  if (!time) return null;
  const tz = zoneOrNull(time.timeZone) || fallbackZone;
  if (time.date) return parseDate(time.date, tz);
  const parsed = parseDateTime(time.dateTime, tz);
  return parsed ? parsed.ms : null;
}
