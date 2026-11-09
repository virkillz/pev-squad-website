import { API_URL } from './config';
import { readSession, writeSession } from './session-storage';

type Session = { access_token: string; refresh_token: string; expires_at: number };
export type SessionResponse = { access_token: string; refresh_token: string; expires_in: number };
let session: Session | null = null;
let version = 0;
let pendingRefresh: Promise<string | null> | null = null;
let pendingWrite: Promise<void> = Promise.resolve();
const listeners = new Set<() => void>();
export const hasSession = () => session !== null;
export function subscribeSession(listener: () => void) { listeners.add(listener); return () => { listeners.delete(listener); }; }
const emit = () => listeners.forEach((listener) => listener());
function persist(value: Session | null) {
  const text = value ? JSON.stringify(value) : null;
  pendingWrite = pendingWrite.catch(() => {}).then(() => writeSession(text));
  return pendingWrite;
}
export async function restoreSession() {
  const start = version;
  try {
    const stored = await readSession();
    const value = stored ? JSON.parse(stored) : null;
    if (start === version && value && typeof value.access_token === 'string' && typeof value.refresh_token === 'string' && typeof value.expires_at === 'number') session = value;
  } catch { /* An unavailable secure store leaves the app signed out. */ }
}
export async function acceptSession(value: SessionResponse) {
  const next = { access_token: value.access_token, refresh_token: value.refresh_token, expires_at: Date.now() + value.expires_in * 1000 };
  // A login succeeds only when its credentials can be saved securely.
  await persist(next);
  version++;
  session = next;
  emit();
}
async function clearSession() {
  version++;
  session = null;
  emit();
  await persist(null);
}
export async function refreshAccess(force = false): Promise<string | null> {
  if (!session) return null;
  if (!force && session.expires_at > Date.now() + 30_000) return session.access_token;
  if (pendingRefresh) return pendingRefresh;
  const before = session;
  const start = version;
  const operation = (async () => {
    const response = await fetch(`${API_URL}/api/v1/auth/refresh`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ refresh_token: before.refresh_token }), signal: AbortSignal.timeout(15_000),
    });
    if (start !== version) return session?.access_token ?? null;
    if (response.status === 401) { await clearSession(); return null; }
    if (!response.ok) throw new Error('Session refresh failed');
    const { data } = await response.json() as { data: SessionResponse };
    if (start !== version) return session?.access_token ?? null;
    session = { access_token: data.access_token, refresh_token: data.refresh_token, expires_at: Date.now() + data.expires_in * 1000 };
    await persist(session);
    return session.access_token;
  })();
  pendingRefresh = operation;
  try { return await operation; } finally { if (pendingRefresh === operation) pendingRefresh = null; }
}
export async function authenticatedFetch(request: Request): Promise<Response> {
  const original = request.clone();
  const token = await refreshAccess();
  if (token) request.headers.set('Authorization', `Bearer ${token}`);
  const response = await fetch(request);
  if (response.status !== 401 || !session) return response;
  // Another request may already have rotated the credentials.
  const next = session.access_token !== token ? session.access_token : await refreshAccess(true);
  if (!next) return response;
  original.headers.set('Authorization', `Bearer ${next}`);
  return fetch(original);
}
export async function endSession() {
  const previous = session;
  await clearSession();
  if (previous) {
    const response = await fetch(`${API_URL}/api/v1/auth/logout`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: previous.refresh_token }), signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) throw new Error('Remote logout failed');
  }
}
