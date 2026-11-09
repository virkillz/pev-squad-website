import type { Locale } from './i18n';

/**
 * Dates and prices the way the website shows them. Event times arrive with
 * their own offset (`local.starts_at`, e.g. "2026-11-28T06:00:00+07:00"),
 * so they're read straight from the string: an event in WIB shows WIB on a
 * phone set to any timezone.
 */

const months = {
  id: ['JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN', 'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES'],
  en: ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'],
};
const days = {
  id: ['MIN', 'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB'],
  en: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'],
};
const zones: Record<string, string> = {
  'Asia/Jakarta': 'WIB',
  'Asia/Makassar': 'WITA',
  'Asia/Jayapura': 'WIT',
};

type Parts = { year: number; month: number; day: number; hour: string; minute: string; weekday: number };

/** Reads "YYYY-MM-DDTHH:MM…" as wall-clock time, ignoring the device zone. */
export function wallClock(iso: string): Parts {
  const [date, time = '00:00'] = iso.split('T');
  const [year, month, day] = date.split('-').map(Number);
  const [hour, minute] = time.slice(0, 5).split(':');
  // Weekday of a calendar date, computed in UTC so the device zone can't shift it.
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return { year, month, day, hour, minute, weekday };
}

export const zoneLabel = (tz: string) => zones[tz] ?? tz;

/** "SAB" */
export const weekday = (iso: string, l: Locale) => days[l][wallClock(iso).weekday];
/** "14" */
export const dayOfMonth = (iso: string) => String(wallClock(iso).day);
/** "NOV" */
export const monthShort = (iso: string, l: Locale) => months[l][wallClock(iso).month - 1];

/** "SAB 14 NOV" */
export function dayLabel(iso: string, l: Locale) {
  const p = wallClock(iso);
  return `${days[l][p.weekday]} ${p.day} ${months[l][p.month - 1]}`;
}

/** "20:00 WIB" */
export function timeLabel(iso: string, tz: string) {
  const p = wallClock(iso);
  return `${p.hour}:${p.minute} ${zoneLabel(tz)}`;
}

/** "14 NOV 2026" for UTC timestamps (posts, listings), in Jakarta time. */
export function dateLabel(isoUtc: string, l: Locale) {
  const d = new Date(new Date(isoUtc).getTime() + 7 * 3600 * 1000);
  return `${d.getUTCDate()} ${months[l][d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

/** Whole days from now until an event starts (0 = today). */
export function daysUntil(isoUtc: string) {
  return Math.max(0, Math.ceil((new Date(isoUtc).getTime() - Date.now()) / 86_400_000));
}

/** "2 HARI LALU" style relative time for "checked" stamps. */
export function ago(isoUtc: string, l: Locale) {
  const daysAgo = Math.floor((Date.now() - new Date(isoUtc).getTime()) / 86_400_000);
  if (daysAgo <= 0) return l === 'id' ? 'HARI INI' : 'TODAY';
  if (daysAgo === 1) return l === 'id' ? 'KEMARIN' : 'YESTERDAY';
  return l === 'id' ? `${daysAgo} HARI LALU` : `${daysAgo} DAYS AGO`;
}

/** "Rp 32.500.000" */
export function rupiah(n: number) {
  return 'Rp ' + n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

/** Short form for cards: "Rp 32,5 jt" / "Rp 850 rb". */
export function rupiahShort(n: number, l: Locale) {
  const trim = (x: number) => (l === 'id' ? x.toFixed(1).replace(/\.0$/, '').replace('.', ',') : x.toFixed(1).replace(/\.0$/, ''));
  if (n >= 1_000_000_000) return `Rp ${trim(n / 1_000_000_000)} ${l === 'id' ? 'M' : 'B'}`;
  if (n >= 1_000_000) return `Rp ${trim(n / 1_000_000)} ${l === 'id' ? 'jt' : 'M'}`;
  if (n >= 1_000) return `Rp ${trim(n / 1_000)} ${l === 'id' ? 'rb' : 'K'}`;
  return rupiah(n);
}

/** "2.100" */
export const thousands = (n: number) => n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
