// Universal links: iOS opens pev-squad.org pages in the app (the list is in
// the backend's WellKnownController). Website paths that differ from the
// app's screens are rewritten here; other links pass through unchanged.

const WEB_ORIGIN = /^https?:\/\/(?:www\.)?pev-squad\.org(?=\/|$|\?|#)/i;

const REWRITES: [RegExp, string][] = [
  [/^\/(?:news|articles)\/([^/]+)\/?$/, '/posts/$1'],
  [/^\/community\/([^/]+)\/?$/, '/riders/$1'],
  [/^\/gallery\/?$/, '/albums'],
  [/^\/gallery\/([^/]+)\/?$/, '/albums/$1'],
  [/^\/for-sale\/(?!new\/?$|mine\/?$)([^/]+)\/?$/, '/listings/$1'],
];

export function redirectSystemPath({ path }: { path: string; initial: boolean }): string {
  try {
    if (!WEB_ORIGIN.test(path)) return path;

    // Drop the origin, the query (?locale=…) and any fragment.
    const pathname = path.replace(WEB_ORIGIN, '').split(/[?#]/)[0] || '/';

    for (const [pattern, target] of REWRITES) {
      if (pattern.test(pathname)) return pathname.replace(pattern, target);
    }
    return pathname;
  } catch {
    return path;
  }
}
