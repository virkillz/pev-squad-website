# PEV Squad mobile

Expo SDK 58, React Native, Expo Router, and TypeScript. The app uses the Phoenix JSON API at `/api/v1`.

## Current milestone

The app supports public browsing in Indonesian and English:

- Home, upcoming and past events, event details, maps, and Google Calendar links.
- News and articles, topic filters, and post details.
- Live and recently sold listings, category filters, and listing photos.
- Community statistics, rider search, rider profiles, and partners.
- Albums and full-screen photos.
- Device language preference, pull to refresh on tabs, pagination, and retry buttons.

Members can log in with an email link or their website password. Sessions are kept in the secure store and refresh automatically.
New members set up a rider profile (alias, city, PEV, public consent), which waits for staff approval.
The avatar menu (top right) opens the profile, settings, language, and logout.
Signed in, the language choice is also saved to the account, so emails follow it.
RSVP, selling, avatars, and seller contacts still require the website.

### Testing the email link

The email contains a `pevsquad:///auth/confirm?token=…` link. Expo Go can't open the app's own scheme,
so on Expo Go copy the link from the email (in development, from `http://localhost:4000/dev/mailbox`) and paste it into the LINK FROM EMAIL field.
A development or store build opens the link directly.

## Run on a phone

Use Node.js 22.13+ (22.x), 24.3+ (24.x), or 26+. npm and PostgreSQL are required.
Use an Expo Go version that supports SDK 58.

1. Connect your phone and laptop to the same Wi-Fi network.
2. Find the laptop's Wi-Fi IPv4 address, such as `192.168.1.5`.
3. From `backend/`, install dependencies and prepare the local database with `mix setup`.
4. Start Phoenix with that address:

   ```sh
   PHX_DEV_HOST=192.168.1.5 mix phx.server
   ```

   `PHX_DEV_HOST` enables LAN access in development. It also sets the host for image and website URLs in API responses.
   Without this variable, Phoenix accepts connections only from the laptop.

5. From `mobile/`, install dependencies:

   ```sh
   npm ci
   cp .env.example .env.local
   ```

6. Set `EXPO_PUBLIC_API_URL` in `.env.local` to the same address:

   ```dotenv
   EXPO_PUBLIC_API_URL=http://192.168.1.5:4000
   ```

7. Check the API and start Expo:

   ```sh
   npm run check:api
   npm start
   ```

8. Open the QR code with Expo Go.

If the phone cannot connect, open `http://192.168.1.5:4000/api/v1/home` in its browser.
Check the Wi-Fi network, laptop firewall, and both host values.
An Expo tunnel exposes Metro only. It does not expose the Phoenix API.
After a change to `.env.local`, restart Expo.

For the iOS simulator, `localhost:4000` can reach the laptop. The Android emulator uses `10.0.2.2:4000`.
Use the emulator address for both `PHX_DEV_HOST` and `EXPO_PUBLIC_API_URL`.

`npm run web` starts a browser preview. API requests from a different origin need CORS or a local proxy.
The backend currently has no CORS configuration, so use Expo Go for the complete browsing check.

## Production API

Without `EXPO_PUBLIC_API_URL`, the app uses `https://pev-squad.org`.
On November 9, 2026, `/api/v1/home` on production returned HTTP 404. The public API changes still need deployment.
Use the local backend until those changes are deployed through the repository's normal deployment process.
See [the deployment runbook](../docs/DEPLOYMENT.md).

Variables with the `EXPO_PUBLIC_` prefix are included in the app bundle. Use them for public URLs only.

## Checks and API types

From `mobile/`:

```sh
npm run typecheck
npm run lint
npm run check:api
npx expo install --check
npx expo export --platform all
```

`check:api` reads public endpoints in both languages. It checks list responses, available detail pages, and pagination cursors.
It uses `.env.local`, or `http://localhost:4000` when no URL is set. It does not create or change data.

With Phoenix on port 4000, regenerate the API types:

```sh
npm run gen:api
```

For another spec URL:

```sh
API_SPEC_URL=http://192.168.1.5:4000/api/v1/openapi npm run gen:api
```

From `backend/`, run `mix precommit` before completion.

## Remaining work

App authentication is in place. Next up are the remaining member features, as described in [the platform roadmap](../docs/DESIGN.md).

1. ~~App login, refresh tokens, logout, onboarding, and profile editing.~~ Done.
2. Avatar upload, account deletion, and blocked members in Settings (store requirements).
3. Add and check deep-link handling on iOS and Android.
4. Add RSVP and member actions, including listing and photo uploads.
5. Add notifications and error tracking.
6. Configure Expo builds and test with squad members before store submission.

The current bundle checks do not replace tests on real devices. Cloud builds, signing, and store submission are not configured yet.
