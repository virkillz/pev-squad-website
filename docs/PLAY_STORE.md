# Google Play listing

What to fill in Play Console for the PEV Squad app (`org.pevsquad.app`), and why. Update it when the app gains features (RSVP, push, posting from the app) or when a form answer changes.

How to build and upload the bundle: `mobile/README.md` and the EAS docs. In short: `eas build -p android --profile production`, upload the first `.aab` by hand under **Testing → Internal testing**, accept Play App Signing, then use `eas submit` for later builds.

---

## 1. Create app

| Field | Value |
|---|---|
| App name | `PEV Squad` |
| Default language | Indonesian – `id-ID` |
| App or game | App |
| Free or paid | Free (can't be changed to paid later) |

---

## 2. Main store listing

Add **English (United States) – en-US** as a translation under *Store presence → Main store listing → Manage translations*.

### App name (max 30)

`PEV Squad`

### Short description (max 80)

- **ID:** `Komunitas rider EUC, skuter listrik & esk8 Indonesia: event, berita, jual beli`
- **EN:** `Indonesia's EUC, e-scooter & esk8 rider community: rides, news, for sale`

### Full description (max 4000)

**ID**

```
PEV Squad adalah komunitas pengendara kendaraan listrik pribadi (PEV) di Indonesia: electric unicycle (EUC), skuter listrik performa, dan electric skateboard. Kami balapan, touring, dan pakai PEV untuk berangkat kerja. Aplikasi ini membawa semua kegiatan squad ke ponselmu.

SPEED. ADVENTURE. FREEDOM.

EVENT & GROUP RIDE
• Lihat jadwal ride berikutnya: night ride, touring, trail ride, balapan, dan event bersama komunitas lain
• Detail lengkap: waktu, titik kumpul, rute, dan perlengkapan yang wajib dibawa
• Riwayat event yang sudah lewat, lengkap dengan album fotonya

BERITA & ARTIKEL
• Kabar terbaru dari komunitas dan liputan media tentang PEV Squad
• Artikel tentang berkendara, perawatan, dan keselamatan
• Tersedia dalam Bahasa Indonesia dan English

JUAL BELI
• Cari EUC, skuter, esk8, dan perlengkapan bekas dari sesama rider
• Hubungi penjual langsung lewat WhatsApp atau Instagram

KOMUNITAS
• Kenalan dengan rider dari Jakarta, Bandung, Surabaya, Semarang, Yogyakarta, dan Bekasi
• Rider of the day, profil rider, dan PEV yang mereka pakai
• Komunitas dan brand partner yang bekerja sama dengan squad

GALERI
• Album foto dari setiap ride dan event

AKUN RIDER
• Masuk dengan email, tanpa perlu kata sandi
• Atur profil ridermu: alias, kota, PEV utama, dan foto
• Laporkan konten atau blokir member yang mengganggu
• Hapus akunmu kapan saja dari Pengaturan

Selalu pakai perlengkapan lengkap dan patuhi aturan lalu lintas. Ride safe, ride together.

Situs: https://pev-squad.org
```

**EN**

```
PEV Squad is a community of personal electric vehicle (PEV) riders across Indonesia: electric unicycles (EUCs), performance e-scooters and electric skateboards. We race, we tour, and we commute. This app puts everything the squad does in your pocket.

SPEED. ADVENTURE. FREEDOM.

EVENTS & GROUP RIDES
• See the next rides: night rides, tours, trail rides, races and events with partner communities
• Full details: time, meeting point, route and the gear you need
• Past events, each with its photo album

NEWS & ARTICLES
• Community news and media coverage of PEV Squad
• Articles on riding, maintenance and safety
• In Indonesian and English

FOR SALE
• Find used EUCs, scooters, esk8 and gear from fellow riders
• Contact sellers directly on WhatsApp or Instagram

COMMUNITY
• Meet riders from Jakarta, Bandung, Surabaya, Semarang, Yogyakarta and Bekasi
• Rider of the day, rider profiles and the PEVs they ride
• The communities and brands we partner with

GALLERY
• Photo albums from every ride and event

YOUR RIDER ACCOUNT
• Log in with your email, no password needed
• Set up your rider profile: alias, city, main PEV and photo
• Report content or block members who bother you
• Delete your account any time from Settings

Always wear full gear and follow traffic rules. Ride safe, ride together.

Website: https://pev-squad.org
```

**Lines to add once the features ship:**
- RSVP: "Daftar (RSVP) ride langsung dari aplikasi, termasuk daftar tunggu" / "RSVP to rides from the app, with a waitlist"
- Push: "Pengingat sebelum ride dimulai" / "Reminders before a ride starts"
- Posting listings and reviews from the app

### Graphics

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG, max 1 MB | Make from `mobile/assets/images/icon.png` (1024²): `sips -z 512 512 icon.png --out play-icon-512.png` |
| Feature graphic | 1024×500 PNG/JPG, no alpha | **To make.** Orange `#FF4800`, PEV SQUAD wordmark, "SPEED · ADVENTURE · FREEDOM" |
| Phone screenshots | 2–8, 16:9 or 9:16, each side 320–3840 px | **To make.** Suggested: Beranda, event detail, Berita, Jual beli, Komunitas, rider profile |

Play's guidelines: no "best", "#1", "free" or download counts in graphics or text. The icon must not have its own rounded corners or a drop shadow (Play adds the mask).

### Categorisation and contact

| Field | Value |
|---|---|
| App category | **Social** (alternative: Auto & Vehicles) |
| Tags | Community, Events, Motorcycles/Vehicles (pick what Play offers) |
| Email | `virkill@gmail.com` (shown publicly on the listing) |
| Website | `https://pev-squad.org` |
| Phone | Leave empty |

---

## 3. App content (Policy → App content)

### Privacy policy

`https://pev-squad.org/privacy` (Indonesian by default; `?locale=en` for English).

### App access

**All or some functionality is restricted.** Login is by email link, so the reviewer can't receive one. Before submitting, create a review account with a password on the website (`/users/settings`) and give:
- Name: `Play review`
- Username: the review account's email
- Password: its password
- Instructions: "Browsing works without logging in. To see the member features, tap MASUK (top right), choose the password option, and log in with the email and password above."

### Ads

**No**, the app doesn't contain ads.

### Content rating (IARC questionnaire)

- Category: **Social / Communication** (or "All other app types" if Social isn't offered)
- Violence, sexual content, profanity, drugs, gambling: **No**
- Users can interact or exchange content: **Yes** (member profiles, photos, listings, reports)
- Shares user's location with others: **No** (city only, typed by the user)
- Digital purchases: **No**
- Expected result: rated for everyone / 3+ with "Users Interact".

### Target audience

- Age groups: **18 and over** only (matches the privacy policy; avoids the Families policy)
- Could unintentionally appeal to children: **No**

### News app

**No.** It has community news, but isn't a news publisher.

### Government app / Financial features / Health

All **No**.

### Data safety

General questions:

| Question | Answer |
|---|---|
| Collects or shares required user data types? | **Yes** |
| All data encrypted in transit? | **Yes** (HTTPS only) |
| Users can request data deletion? | **Yes** |
| Account creation | "Users can create an account" with **email link / username & password** |
| Delete account URL | `https://pev-squad.org/privacy#delete-account` |

Data types. For each: **Collected: yes, Shared: no** (Brevo and DigitalOcean are service providers, which Play doesn't count as "sharing"). **Processed ephemerally: no.**

| Data type | Required or optional | Purposes |
|---|---|---|
| Personal info → Email address | Required (for an account) | Account management, App functionality |
| Personal info → Name | Optional | App functionality |
| Personal info → User IDs | Required | Account management, App functionality |
| Personal info → Phone number | Optional (sellers' WhatsApp on listings) | App functionality |
| Personal info → Other info (city, bio, Instagram, PEV) | Optional | App functionality |
| Photos and videos → Photos | Optional (avatar, listing photos) | App functionality |
| App activity → Other user-generated content (reviews, listings, reports) | Optional | App functionality, Fraud prevention / security |
| App activity → Other actions (RSVPs, blocks) | Optional | App functionality |

**Not collected:** location, financial info, health, messages, contacts, calendar, audio, files, web history, device IDs, crash logs, diagnostics. If Sentry or push notifications are added later, add **App info and performance → Crash logs / Diagnostics** and **Device or other IDs** (push token).

### Account deletion

Same URL: `https://pev-squad.org/privacy#delete-account`. It explains the in-app path (avatar → Pengaturan → Hapus akun) and the email route, and lists what gets deleted.

---

## 4. Testing before production

A **personal** developer account created after November 2023 needs a **closed test with at least 12 testers opted in for 14 days in a row** before you can apply for production. Plan the squad beta around that:

1. Internal testing: upload the first `.aab`, check it on your own phone.
2. Closed testing: add 12+ members' Google account emails (or a Google Group), share the opt-in link, keep them opted in for 14 days.
3. Apply for production access, answering the questions about the test.
4. Production release. Review usually takes a few days, longer for a new account.

An **organisation** account (needs a D-U-N-S number) skips the 12-tester rule.
