import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'expo-router';
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { api, ApiError, unwrap } from './api';
import { useLocale, type Locale } from './i18n';
import { acceptSession, endSession, hasSession, restoreSession, subscribeSession, type SessionResponse } from './session';

function useAuthState() {
  const client = useQueryClient();
  const { locale, setLocale } = useLocale();
  const [ready, setReady] = useState(false);
  const [signedIn, setSignedIn] = useState(false);
  const [revision, setRevision] = useState(0);
  useEffect(() => {
    let active = true;
    const unsubscribe = subscribeSession(() => {
      client.clear();
      setSignedIn(hasSession());
      setRevision((v) => v + 1);
    });
    restoreSession().then(() => { if (active) { setSignedIn(hasSession()); setReady(true); } });
    return () => { active = false; unsubscribe(); };
  }, [client]);
  const me = useQuery({
    queryKey: ['me', revision, locale], enabled: ready && signedIn,
    queryFn: async () => unwrap(await api.GET('/api/v1/me')).data,
    retry: false,
  });
  async function signIn(value: SessionResponse) { await acceptSession(value); }
  async function changeLocale(next: Locale) {
    if (signedIn) unwrap(await api.PATCH('/api/v1/me', { body: { locale: next } }));
    setLocale(next);
  }
  return { ready, signedIn, me, signIn, signOut: endSession, changeLocale };
}
const AuthContext = createContext<ReturnType<typeof useAuthState> | null>(null);
export function AuthProvider({ children }: { children: ReactNode }) {
  const value = useAuthState();
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('AuthProvider is missing');
  return value;
}

/**
 * After a successful sign-in: riders without a rider profile go to the
 * profile setup, everyone else lands on Beranda.
 */
export function useFinishSignIn() {
  const router = useRouter();
  const { locale } = useLocale();
  return async () => {
    let needsProfile = false;
    try {
      const me = unwrap(await api.GET('/api/v1/me')).data;
      needsProfile = me.rider_profile === null;
      // First login in the app: keep the account's email language in step with the app.
      if (me.locale === null) await api.PATCH('/api/v1/me', { body: { locale } });
    } catch { /* The profile screen loads `me` again and shows its own error. */ }
    router.dismissTo('/');
    if (needsProfile) router.push('/profile');
  };
}

/** Pulls the login token out of a pasted email link, or accepts a bare token. */
export function tokenFromLink(text: string): string | null {
  const value = text.trim();
  const match = value.match(/[?&]token=([A-Za-z0-9_-]+)/);
  if (match) return match[1];
  return /^[A-Za-z0-9_-]{40,}$/.test(value) ? value : null;
}

type LoginErrorKey = 'login.failed' | 'login.expired' | 'login.rateLimited' | 'login.unavailable' | 'common.error';

/** Maps an auth API failure to the message riders see. */
export function loginErrorKey(error: unknown, expired = false): LoginErrorKey {
  if (!(error instanceof ApiError)) return 'common.error';
  if (error.status === 401) return expired ? 'login.expired' : 'login.failed';
  if (error.status === 429) return 'login.rateLimited';
  if (error.status === 404) return 'login.unavailable';
  return 'common.error';
}
