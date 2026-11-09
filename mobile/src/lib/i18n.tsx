import { getLocales } from 'expo-localization';
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';

import { readPreference, writePreference } from './preferences';

/**
 * App languages, same as the website: Indonesian (default) and English.
 *
 * The choice starts from the device language and is saved on the device
 * once the rider picks one. Content (post text, error messages) comes
 * from the API already translated: every request sends Accept-Language.
 */
export type Locale = 'id' | 'en';

const STORE_KEY = 'locale';

const id = {
  "login.password": "PASSWORD",
  "login.usePassword": "MASUK DENGAN PASSWORD",
  "login.useEmail": "KIRIM LINK EMAIL",
  "login.passwordHint": "Gunakan password akun website-mu. Belum punya password? Pilih link email.",
  "login.submit": "MASUK",
  "login.sent": "Cek email-mu",
  "login.sentNote": "Link berlaku 15 menit. Buka di HP ini, atau salin link dari email ke kolom di bawah.",
  "login.link": "LINK DARI EMAIL",
  "login.confirm": "LANJUTKAN",
  "login.failed": "Email atau password tidak cocok. Coba lagi atau gunakan link email.",
  "login.expired": "Link sudah kedaluwarsa atau dipakai. Minta link baru.",
  "login.unavailable": "Login aplikasi belum tersedia di server ini. Coba lagi setelah pembaruan server.",
  "login.resend": "KIRIM LINK BARU",
  "login.signingIn": "SEDANG MASUK…",
  "profile.title": "Profil",
  "profile.setup": "Kenalan dulu",
  "profile.setupNote": "Isi profil rider-mu. Profil baru menunggu persetujuan pengurus.",
  "profile.edit": "EDIT PROFIL",
  "profile.alias": "ALIAS RIDER",
  "profile.city": "KOTA",
  "profile.type": "JENIS PEV",
  "profile.ride": "KENDARAAN UTAMA",
  "profile.bio": "TENTANG KAMU",
  "profile.instagram": "INSTAGRAM",
  "profile.public": "Tampilkan profil saya di website",
  "profile.publicNote": "Alias, kota, kendaraan, bio, dan Instagram terlihat publik setelah disetujui. Email tetap privat.",
  "profile.save": "SIMPAN PROFIL",
  "profile.saving": "MENYIMPAN…",
  "profile.pending": "Profilmu menunggu persetujuan pengurus.",
  "profile.banned": "Profil ini dibatasi oleh pengurus. Hubungi PEV Squad untuk bantuan.",
  "profile.private": "Profilmu privat.",
  "profile.visible": "Profilmu boleh ditampilkan publik.",
  "profile.logout": "KELUAR",
  "profile.logoutConfirm": "Keluar dari akun di perangkat ini?",
  "profile.cancel": "BATAL",
  "profile.validation": "Periksa kolom yang ditandai.",
  "profile.logoutError": "Kamu sudah keluar di perangkat ini. Sesi server belum berhasil dicabut; sesi akan berakhir otomatis.",
  "menu.profile": "PROFIL SAYA",
  "menu.settings": "PENGATURAN",
  "menu.account": "Menu akun",
  "settings.account": "AKUN",
  "settings.languageAccount": "Disimpan di akunmu dan dipakai untuk email.",
  "settings.signedInAs": "MASUK SEBAGAI",
  "login.rateLimited": "Terlalu banyak percobaan. Tunggu satu menit lalu coba lagi.",
  "login.badLink": "Link tidak dikenali. Salin seluruh link dari email.",
  "profile.signIn": "Masuk dulu untuk mengisi profil rider-mu.",
  "profile.saved": "Profil disimpan.",
  "header.profile": "PROFIL",

  'tab.home': 'BERANDA',
  'tab.events': 'EVENT',
  'tab.news': 'BERITA',
  'tab.forSale': 'DIJUAL',
  'tab.community': 'KOMUNITAS',
  'header.login': 'MASUK',
  'header.tagline': 'PERSONAL ELECTRIC VEHICLE',
  'header.language': 'Ganti bahasa',
  'common.back': 'KEMBALI',
  'common.share': 'Bagikan',
  'common.retry': 'COBA LAGI',
  'common.error': 'Gagal memuat. Cek koneksi internetmu.',
  'common.empty': 'Belum ada apa-apa di sini.',
  'common.loadMore': 'MUAT LAGI',
  'common.seeAll': 'LIHAT SEMUA →',
  'common.all': 'SEMUA',
  'home.nextRide': 'RIDE BERIKUTNYA ——',
  'home.tag': 'gas bareng!',
  'home.latest': 'Terbaru',
  'home.allNews': 'SEMUA BERITA →',
  'home.gallery': 'Galeri',
  'home.allAlbums': 'SEMUA ALBUM →',
  'home.forSale': 'Dijual',
  'home.noRide': 'Belum ada ride terjadwal. Cek lagi nanti.',
  'events.eyebrow': '02 · RIDE, MEETUP, KOLABORASI ——',
  'events.title': 'Event',
  'events.tag': 'siapa cepat dia dapat',
  'events.official': 'RESMI',
  'events.groupRide': 'GROUP RIDE',
  'events.upcoming': 'MENDATANG',
  'events.past': 'EVENT SEBELUMNYA',
  'events.noUpcoming': 'Belum ada event mendatang.',
  'event.start': 'BERANGKAT',
  'event.end': 'SELESAI',
  'event.meetingPoint': 'TITIK KUMPUL',
  'event.rsvpBy': 'RSVP SEBELUM',
  'event.seats': 'KURSI',
  'event.seatsLeft': 'SISA %{n}',
  'event.full': 'PENUH',
  'event.unlimited': 'TANPA BATAS',
  'event.going': '%{going} IKUT · %{waitlist} WAITLIST',
  'event.calendar': 'CATAT DI KALENDER',
  'event.maps': 'BUKA DI MAPS',
  'event.with': 'BERSAMA',
  'event.hostedBy': 'GROUP RIDE · DIADAKAN @%{alias}',
  'event.rsvp': 'RSVP · AMANKAN KURSI',
  'event.rsvpHint': 'MASUK DULU UNTUK RSVP · BATAL KAPAN SAJA',
  'event.cancelled': 'DIBATALKAN',
  'event.recaps': 'RECAP',
  'event.daysLeft': '%{n} HARI LAGI',
  'event.today': 'HARI INI',
  'news.eyebrow': '03 · DARI SQUAD ——',
  'news.title': 'Berita',
  'news.tag': 'baca dulu',
  'news.news': 'BERITA',
  'news.articles': 'ARTIKEL',
  'news.minutes': '%{n} MENIT BACA',
  'post.machine': 'Diterjemahkan mesin dari bahasa lain.',
  'post.fallback': 'Tulisan ini belum ada dalam bahasamu.',
  'post.source': 'SUMBER',
  'post.recapOf': 'RECAP DARI',
  'forSale.eyebrow': '04 · DARI RIDER, UNTUK RIDER ——',
  'forSale.title': 'Dijual',
  'forSale.sell': '+ JUAL',
  'forSale.note': 'Kontak penjual (WhatsApp / Instagram) hanya terlihat oleh anggota yang sudah masuk. Tidak ada pembayaran di aplikasi.',
  'forSale.sold': 'TERJUAL',
  'forSale.recentlySold': 'BARU TERJUAL',
  'forSale.nego': 'NEGO',
  'listing.condition': 'KONDISI',
  'listing.distance': 'JARAK',
  'listing.city': 'KOTA',
  'listing.qty': 'JUMLAH',
  'listing.checked': 'DICEK %{when}',
  'listing.available': 'MASIH TERSEDIA',
  'listing.whatsapp': 'CHAT WHATSAPP',
  'listing.instagram': 'DM',
  'listing.loginToContact': 'MASUK UNTUK LIHAT KONTAK',
  'listing.report': 'LAPORKAN',
  'listing.member': 'ANGGOTA',
  'community.eyebrow': '05 · YANG RIDING BARENG KAMI ——',
  'community.title': 'Komunitas',
  'community.tag': 'datang aja',
  'community.riders': 'RIDER',
  'community.cities': 'KOTA',
  'community.meetups': 'MEETUP',
  'community.upcoming': 'RIDE MENDATANG',
  'community.squad': 'Squad',
  'community.roster': 'DAFTAR RIDER ——',
  'community.search': 'Cari alias, kota, atau kendaraan',
  'community.network': 'JARINGAN ——',
  'community.partners': 'Komunitas Partner',
  'community.backers': 'YANG MENDUKUNG RIDE KAMI ——',
  'community.brands': 'Brand Partner',
  'community.eventsTogether': '%{n} EVENT',
  'community.since': 'SEJAK %{year}',
  'community.noRiders': 'Tidak ada rider yang cocok.',
  'rider.rides': 'KENDARAAN UTAMA',
  'rider.crews': 'KOMUNITAS',
  'partner.events': 'EVENT BERSAMA',
  'album.photos': '%{n} FOTO',
  'login.title': 'Masuk',
  'login.tag': 'tanpa password',
  'login.lede': 'Masukkan email-mu. Kami kirim link masuk — buka di HP ini dan kamu langsung masuk ke aplikasi.',
  'login.email': 'EMAIL',
  'login.send': 'KIRIM LINK MASUK',
  'login.browse': 'LIHAT-LIHAT DULU →',
  'settings.title': 'Pengaturan',
  'settings.language': 'BAHASA',
  'settings.languageNote': 'Disimpan di perangkat ini.',
  'settings.privacy': 'KEBIJAKAN PRIVASI',
  'settings.version': 'VERSI',
  'kind.ride': 'RIDE', 'kind.night_ride': 'NIGHT RIDE', 'kind.trail_ride': 'TRAIL RIDE',
  'kind.tour': 'TUR', 'kind.getaway': 'GETAWAY', 'kind.expedition': 'EKSPEDISI', 'kind.race': 'BALAP',
  'kind.meetup': 'MEETUP', 'kind.clinic': 'KLINIK', 'kind.collab': 'KOLABORASI', 'kind.collab_ride': 'COLLAB RIDE',
  'kind.brand_invite': 'UNDANGAN BRAND', 'kind.brand_activation': 'AKTIVASI BRAND', 'kind.media': 'MEDIA',
  'kind.exhibition': 'PAMERAN', 'kind.marshal': 'MARSHAL',
  'topic.community': 'KOMUNITAS', 'topic.industry': 'INDUSTRI', 'topic.regulation': 'REGULASI',
  'topic.safety': 'SAFETY', 'topic.maintenance': 'PERAWATAN', 'topic.guide': 'PANDUAN',
  'topic.gear': 'GEAR', 'topic.story': 'CERITA',
  'cat.euc': 'EUC', 'cat.escooter': 'SKUTER', 'cat.esk8': 'ESK8', 'cat.ebike': 'E-BIKE',
  'cat.parts': 'PART', 'cat.gear': 'GEAR', 'cat.other': 'LAINNYA',
  'cond.new': 'BARU', 'cond.like_new': 'SEPERTI BARU', 'cond.used': 'BEKAS', 'cond.for_parts': 'UNTUK PART',
  'pev.euc': 'EUC', 'pev.escooter': 'SKUTER', 'pev.esk8': 'ESK8', 'pev.ebike': 'E-BIKE', 'pev.other': 'LAINNYA',
};

type Key = keyof typeof id;

const en: Record<Key, string> = {
  ...id,
  "login.password": "PASSWORD",
  "login.usePassword": "USE A PASSWORD",
  "login.useEmail": "EMAIL ME A LINK",
  "login.passwordHint": "Use your website account password. No password yet? Choose the email link.",
  "login.submit": "LOG IN",
  "login.sent": "Check your email",
  "login.sentNote": "The link lasts 15 minutes. Open it on this phone, or paste the link from your email below.",
  "login.link": "LINK FROM EMAIL",
  "login.confirm": "CONTINUE",
  "login.failed": "Email or password did not match. Try again or use an email link.",
  "login.expired": "This link expired or was already used. Request a new link.",
  "login.unavailable": "App login is not available on this server yet. Try again after the server update.",
  "login.resend": "SEND A NEW LINK",
  "login.signingIn": "SIGNING IN…",
  "profile.title": "Profile",
  "profile.setup": "Meet the squad",
  "profile.setupNote": "Set up your rider profile. New profiles wait for staff approval.",
  "profile.edit": "EDIT PROFILE",
  "profile.alias": "RIDER ALIAS",
  "profile.city": "CITY",
  "profile.type": "PEV TYPE",
  "profile.ride": "MAIN RIDE",
  "profile.bio": "ABOUT YOU",
  "profile.instagram": "INSTAGRAM",
  "profile.public": "Show my profile on the website",
  "profile.publicNote": "Your alias, city, ride, bio, and Instagram become public after approval. Your email stays private.",
  "profile.save": "SAVE PROFILE",
  "profile.saving": "SAVING…",
  "profile.pending": "Your profile is waiting for staff approval.",
  "profile.banned": "Staff have restricted this profile. Contact PEV Squad for help.",
  "profile.private": "Your profile is private.",
  "profile.visible": "Your profile can be shown publicly.",
  "profile.logout": "LOG OUT",
  "profile.logoutConfirm": "Log out of your account on this device?",
  "profile.cancel": "CANCEL",
  "profile.validation": "Check the marked fields.",
  "profile.logoutError": "You are logged out on this device. The server session could not be revoked; it will expire automatically.",
  "menu.profile": "MY PROFILE",
  "menu.settings": "SETTINGS",
  "menu.account": "Account menu",
  "settings.account": "ACCOUNT",
  "settings.languageAccount": "Saved to your account and used for emails.",
  "settings.signedInAs": "SIGNED IN AS",
  "login.rateLimited": "Too many attempts. Wait a minute and try again.",
  "login.badLink": "That link wasn't recognised. Copy the whole link from the email.",
  "profile.signIn": "Log in to set up your rider profile.",
  "profile.saved": "Profile saved.",
  "header.profile": "PROFILE",

  'tab.home': 'HOME',
  'tab.events': 'EVENTS',
  'tab.news': 'NEWS',
  'tab.forSale': 'FOR SALE',
  'tab.community': 'COMMUNITY',
  'header.login': 'LOG IN',
  'header.language': 'Change language',
  'common.back': 'BACK',
  'common.share': 'Share',
  'common.retry': 'TRY AGAIN',
  'common.error': "Couldn't load. Check your connection.",
  'common.empty': 'Nothing here yet.',
  'common.loadMore': 'LOAD MORE',
  'common.seeAll': 'SEE ALL →',
  'common.all': 'ALL',
  'home.nextRide': 'NEXT RIDE ——',
  'home.tag': "let's ride!",
  'home.latest': 'Latest',
  'home.allNews': 'ALL NEWS →',
  'home.gallery': 'Gallery',
  'home.allAlbums': 'ALL ALBUMS →',
  'home.forSale': 'For Sale',
  'home.noRide': 'No ride scheduled yet. Check back soon.',
  'events.eyebrow': '02 · RIDES, MEETUPS, COLLABS ——',
  'events.title': 'Events',
  'events.tag': 'first come, first served',
  'events.official': 'OFFICIAL',
  'events.upcoming': 'UPCOMING',
  'events.past': 'PAST EVENTS',
  'events.noUpcoming': 'No upcoming events yet.',
  'event.start': 'STARTS',
  'event.end': 'ENDS',
  'event.meetingPoint': 'MEETING POINT',
  'event.rsvpBy': 'RSVP BY',
  'event.seats': 'SEATS',
  'event.seatsLeft': '%{n} LEFT',
  'event.full': 'FULL',
  'event.unlimited': 'UNLIMITED',
  'event.going': '%{going} GOING · %{waitlist} WAITLIST',
  'event.calendar': 'ADD TO CALENDAR',
  'event.maps': 'OPEN IN MAPS',
  'event.with': 'WITH',
  'event.hostedBy': 'GROUP RIDE · HOSTED BY @%{alias}',
  'event.rsvp': 'RSVP · GRAB A SEAT',
  'event.rsvpHint': 'LOG IN TO RSVP · CANCEL ANY TIME',
  'event.cancelled': 'CANCELLED',
  'event.recaps': 'RECAPS',
  'event.daysLeft': 'IN %{n} DAYS',
  'event.today': 'TODAY',
  'news.eyebrow': '03 · FROM THE SQUAD ——',
  'news.title': 'News',
  'news.tag': 'read up',
  'news.news': 'NEWS',
  'news.articles': 'ARTICLES',
  'news.minutes': '%{n} MIN READ',
  'post.machine': 'Machine translated from another language.',
  'post.fallback': "This post isn't in your language yet.",
  'post.source': 'SOURCE',
  'post.recapOf': 'RECAP OF',
  'forSale.eyebrow': '04 · BY RIDERS, FOR RIDERS ——',
  'forSale.title': 'For Sale',
  'forSale.sell': '+ SELL',
  'forSale.note': 'Seller contacts (WhatsApp / Instagram) are only shown to logged-in members. No payments in the app.',
  'forSale.sold': 'SOLD',
  'forSale.recentlySold': 'RECENTLY SOLD',
  'listing.condition': 'CONDITION',
  'listing.distance': 'DISTANCE',
  'listing.city': 'CITY',
  'listing.qty': 'QTY',
  'listing.checked': 'CHECKED %{when}',
  'listing.available': 'STILL AVAILABLE',
  'listing.whatsapp': 'WHATSAPP',
  'listing.loginToContact': 'LOG IN TO SEE CONTACTS',
  'listing.report': 'REPORT',
  'listing.member': 'MEMBER',
  'community.eyebrow': '05 · WHO RIDES WITH US ——',
  'community.title': 'Community',
  'community.tag': 'show up',
  'community.riders': 'RIDERS',
  'community.cities': 'CITIES',
  'community.meetups': 'MEETUPS',
  'community.upcoming': 'RIDES COMING UP',
  'community.roster': 'RIDER ROSTER ——',
  'community.search': 'Search alias, city or ride',
  'community.network': 'THE NETWORK ——',
  'community.partners': 'Partner Communities',
  'community.backers': 'WHO BACKS THE RIDES ——',
  'community.brands': 'Brand Partners',
  'community.eventsTogether': '%{n} EVENTS',
  'community.since': 'SINCE %{year}',
  'community.noRiders': 'No riders match.',
  'rider.rides': 'MAIN RIDE',
  'rider.crews': 'CREWS',
  'partner.events': 'EVENTS TOGETHER',
  'album.photos': '%{n} PHOTOS',
  'login.title': 'Log in',
  'login.tag': 'no password',
  'login.lede': "Enter your email. We'll send a login link — open it on this phone and you're in.",
  'login.send': 'SEND LOGIN LINK',
  'login.browse': 'JUST BROWSE →',
  'settings.title': 'Settings',
  'settings.language': 'LANGUAGE',
  'settings.languageNote': 'Saved on this device.',
  'settings.privacy': 'PRIVACY POLICY',
  'settings.version': 'VERSION',
  'kind.tour': 'TOUR', 'kind.expedition': 'EXPEDITION', 'kind.race': 'RACE', 'kind.clinic': 'CLINIC',
  'kind.collab': 'COLLAB', 'kind.brand_invite': 'BRAND INVITE', 'kind.brand_activation': 'BRAND ACTIVATION',
  'kind.exhibition': 'EXHIBITION',
  'topic.community': 'COMMUNITY', 'topic.industry': 'INDUSTRY', 'topic.regulation': 'REGULATION',
  'topic.maintenance': 'MAINTENANCE', 'topic.guide': 'GUIDE', 'topic.story': 'STORY',
  'cat.escooter': 'SCOOTER', 'cat.parts': 'PARTS', 'cat.other': 'OTHER',
  'cond.new': 'NEW', 'cond.like_new': 'LIKE NEW', 'cond.used': 'USED', 'cond.for_parts': 'FOR PARTS',
  'pev.escooter': 'SCOOTER', 'pev.other': 'OTHER',
};

const dictionaries: Record<Locale, Record<Key, string>> = { id, en };

export type TFunction = (key: Key, vars?: Record<string, string | number>) => string;

function translate(locale: Locale, key: Key, vars?: Record<string, string | number>) {
  let text = dictionaries[locale][key] ?? key;
  if (vars) {
    for (const [name, value] of Object.entries(vars)) text = text.replace(`%{${name}}`, String(value));
  }
  return text;
}

/** Labels for API enums: `label('kind', 'night_ride')`. Unknown values show as-is. */
function makeLabel(locale: Locale) {
  return (group: 'kind' | 'topic' | 'cat' | 'cond' | 'pev', value: string | null | undefined) => {
    if (!value) return '';
    const key = `${group}.${value}` as Key;
    return key in id ? translate(locale, key) : value.toUpperCase();
  };
}

function deviceLocale(): Locale {
  const code = getLocales()[0]?.languageCode;
  return code === 'en' ? 'en' : 'id';
}

/** The current language, readable outside React (the API client uses it). */
let current: Locale = deviceLocale();
export const currentLocale = () => current;

type LocaleContext = {
  locale: Locale;
  setLocale: (l: Locale) => void;
  t: TFunction;
  label: ReturnType<typeof makeLabel>;
};

const Ctx = createContext<LocaleContext | null>(null);

export function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(current);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let active = true;
    readPreference(STORE_KEY)
      .then((saved) => {
        if (active && (saved === 'id' || saved === 'en')) {
          current = saved;
          setLocaleState(saved);
        }
      })
      .catch(() => {})
      .finally(() => { if (active) setReady(true); });
    return () => { active = false; };
  }, []);

  const setLocale = (l: Locale) => {
    current = l;
    setLocaleState(l);
    writePreference(STORE_KEY, l).catch(() => {});
  };

  // Start queries only after restoring the saved language.
  if (!ready) return null;

  return (
    <Ctx.Provider
      value={{
        locale,
        setLocale,
        t: (key, vars) => translate(locale, key, vars),
        label: makeLabel(locale),
      }}>
      {children}
    </Ctx.Provider>
  );
}

export function useLocale() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useLocale must be used inside <LocaleProvider>');
  return ctx;
}
