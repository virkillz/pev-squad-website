import createClient from 'openapi-fetch';

import type { components, paths } from './api-types';
import { currentLocale } from './i18n';
import { API_URL } from './config';
import { authenticatedFetch } from './session';

/**
 * Typed client for the PEV Squad API (/api/v1). Types are generated from
 * the backend's OpenAPI spec: `npm run gen:api` (see README).
 *
 * EXPO_PUBLIC_API_URL picks the server, e.g. http://192.168.1.5:4000 to
 * use your laptop's dev server from a phone. Default: production.
 */
export { API_URL } from './config';

export const api = createClient<paths>({ baseUrl: API_URL, fetch: authenticatedFetch });

api.use({
  onRequest({ request }) {
    request.headers.set('Accept', 'application/json');
    request.headers.set('Accept-Language', currentLocale());
    return request;
  },
});

export type Schemas = components['schemas'];
export type Event = Schemas['Event'];
export type EventDetail = Schemas['EventDetail'];
export type Post = Schemas['Post'];
export type PostDetail = Schemas['PostDetail'];
export type Listing = Schemas['Listing'];
export type ListingDetail = Schemas['ListingDetail'];
export type Rider = Schemas['Rider'];
export type RiderDetail = Schemas['RiderDetail'];
export type RiderOfTheDay = Schemas['RiderOfTheDay'];
export type Partner = Schemas['Partner'];
export type PartnerDetail = Schemas['PartnerDetail'];
export type Album = Schemas['Album'];
export type AlbumDetail = Schemas['AlbumDetail'];
export type Photo = Schemas['Photo'];

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public fields?: Record<string, string[]>,
  ) {
    super(message);
  }
}

/** Unwraps an openapi-fetch result: returns `data` or throws an ApiError. */
export function unwrap<T>(result: { data?: T; error?: unknown; response: Response }): T {
  if (result.data !== undefined) return result.data;
  const err = (result.error as { error?: { code?: string; message?: string; fields?: Record<string, string[]> } } | undefined)?.error;
  throw new ApiError(result.response.status, err?.code ?? 'http_error', err?.message ?? 'Request failed', err?.fields);
}
