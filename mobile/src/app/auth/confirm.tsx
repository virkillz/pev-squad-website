import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BigButton, Hazard } from '@/components/chrome';
import { Body, Stencil } from '@/components/text';
import { api, unwrap } from '@/lib/api';
import { loginErrorKey, useAuth, useFinishSignIn } from '@/lib/auth';
import { useLocale } from '@/lib/i18n';
import { colors, space } from '@/theme';

/**
 * Target of the email login link: pevsquad:///auth/confirm?token=…
 * The token is single use, so the exchange runs once per screen.
 */
export default function ConfirmScreen() {
  const { token } = useLocalSearchParams<{ token?: string }>();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { t } = useLocale();
  const { signIn } = useAuth();
  const finish = useFinishSignIn();
  const [error, setError] = useState<string | null>(null);
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    (async () => {
      try {
        if (!token) throw new Error('missing token');
        const session = unwrap(await api.POST('/api/v1/auth/exchange', { body: { token } })).data;
        await signIn(session);
        await finish();
      } catch (e) {
        setError(t(token ? loginErrorKey(e, true) : 'login.expired'));
      }
    })();
  }, [token, signIn, finish, t]);

  return (
    <View style={{ flex: 1, backgroundColor: colors.orange, paddingTop: insets.top }}>
      <View style={{ flex: 1, padding: 20, justifyContent: 'center', gap: space.xl }}>
        <Stencil size={64} accessibilityRole="header">{error ? t('login.title') : t('login.signingIn')}</Stencil>
        {error ? (
          <>
            <Body size={16} weight="semi">{error}</Body>
            <BigButton tone="black" label={t('login.resend')} onPress={() => router.replace('/login')} />
          </>
        ) : (
          <ActivityIndicator color={colors.black} size="large" style={{ alignSelf: 'flex-start' }} />
        )}
      </View>
      <View style={{ paddingBottom: insets.bottom }}>
        <Hazard height={18} />
      </View>
    </View>
  );
}
