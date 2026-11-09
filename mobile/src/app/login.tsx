import { Image } from 'expo-image';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BigButton, Hazard } from '@/components/chrome';
import { Body, Mono, Stencil, Tag } from '@/components/text';
import { api, unwrap } from '@/lib/api';
import { loginErrorKey, tokenFromLink, useAuth, useFinishSignIn } from '@/lib/auth';
import { useLocale } from '@/lib/i18n';
import { bw, colors, fonts, space } from '@/theme';

type Mode = 'link' | 'password' | 'sent';

/**
 * Masuk. Default is the email link (works for riders without a password);
 * website members can use their password instead. The link opens
 * /auth/confirm in the app; when it can't (Expo Go, some mail apps), the
 * rider pastes it into the field on the "sent" step.
 */
export default function LoginScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { t } = useLocale();
  const { signIn } = useAuth();
  const finish = useFinishSignIn();

  const [mode, setMode] = useState<Mode>('link');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [link, setLink] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(action: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (e) {
      setError(t(loginErrorKey(e)));
    } finally {
      setBusy(false);
    }
  }

  const sendLink = () =>
    run(async () => {
      unwrap(await api.POST('/api/v1/auth/magic-link', { body: { email: email.trim() } }));
      setMode('sent');
    });

  const withPassword = () =>
    run(async () => {
      const session = unwrap(await api.POST('/api/v1/auth/password', { body: { email: email.trim(), password } })).data;
      await signIn(session);
      await finish();
    });

  const submitLink = () => {
    const token = tokenFromLink(link);
    if (!token) return setError(t('login.badLink'));
    router.replace({ pathname: '/auth/confirm', params: { token } });
  };

  const input = {
    placeholderTextColor: 'rgba(0,0,0,0.5)',
    style: { height: 54, borderWidth: bw, backgroundColor: colors.white, paddingHorizontal: 14, fontFamily: fonts.body, fontSize: 17 },
  } as const;
  const emailOk = /.+@.+\..+/.test(email.trim());

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1, backgroundColor: colors.orange, paddingTop: insets.top }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Pressable accessibilityRole="link" onPress={() => router.push('/settings')} style={{ padding: space.l }}>
          <Mono bold size={12}>{t('settings.title').toUpperCase()}</Mono>
        </Pressable>
        <Pressable accessibilityRole="button" onPress={() => (router.canGoBack() ? router.back() : router.replace('/'))} style={{ padding: space.l }}>
          <Mono bold size={12}>{t('login.browse')}</Mono>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={{ padding: 20, paddingTop: space.xl, gap: 18 }} keyboardShouldPersistTaps="handled">
        <Image source={require('@/assets/images/logo.jpg')} style={{ width: 96, height: 96, borderWidth: bw }} accessibilityLabel="PEV Squad" />

        {mode === 'sent' ? (
          <>
            <Stencil size={64} accessibilityRole="header">{t('login.sent')}</Stencil>
            <Mono bold size={13}>{email.trim()}</Mono>
            <Body size={16} style={{ lineHeight: 23 }}>{t('login.sentNote')}</Body>
            <View style={{ gap: 10 }}>
              <Mono bold size={11}>{t('login.link')}</Mono>
              <TextInput
                {...input}
                value={link}
                onChangeText={setLink}
                autoCapitalize="none"
                autoCorrect={false}
                placeholder="pevsquad://…"
                accessibilityLabel={t('login.link')}
              />
              {error ? <Body weight="semi" size={14}>{error}</Body> : null}
              <BigButton tone="black" label={t('login.confirm')} disabled={!link.trim()} onPress={submitLink} />
            </View>
            <View style={{ borderTopWidth: bw, paddingTop: 14 }}>
              <BigButton tone="white" label={t('login.resend')} disabled={busy} onPress={sendLink} />
            </View>
          </>
        ) : (
          <>
            <View>
              <Stencil size={92} accessibilityRole="header">{t('login.title')}</Stencil>
              {mode === 'link' ? <Tag color={colors.black} size={24} style={{ alignSelf: 'flex-start', marginTop: 8 }}>{t('login.tag')}</Tag> : null}
            </View>
            <Body size={16} style={{ lineHeight: 23 }}>{mode === 'link' ? t('login.lede') : t('login.passwordHint')}</Body>
            <View style={{ gap: 10 }}>
              <Mono bold size={11}>{t('login.email')}</Mono>
              <TextInput
                {...input}
                value={email}
                onChangeText={setEmail}
                autoCapitalize="none"
                autoCorrect={false}
                autoComplete="email"
                keyboardType="email-address"
                textContentType="emailAddress"
                placeholder="kamu@email.com"
                accessibilityLabel={t('login.email')}
                returnKeyType={mode === 'link' ? 'send' : 'next'}
                onSubmitEditing={mode === 'link' && emailOk ? sendLink : undefined}
              />
              {mode === 'password' ? (
                <>
                  <Mono bold size={11}>{t('login.password')}</Mono>
                  <TextInput
                    {...input}
                    value={password}
                    onChangeText={setPassword}
                    secureTextEntry
                    autoComplete="current-password"
                    textContentType="password"
                    accessibilityLabel={t('login.password')}
                    returnKeyType="go"
                    onSubmitEditing={emailOk && password ? withPassword : undefined}
                  />
                </>
              ) : null}
              {error ? <Body weight="semi" size={14}>{error}</Body> : null}
              {mode === 'link' ? (
                <BigButton tone="black" label={busy ? t('login.signingIn') : t('login.send')} disabled={busy || !emailOk} onPress={sendLink} />
              ) : (
                <BigButton tone="black" label={busy ? t('login.signingIn') : t('login.submit')} disabled={busy || !emailOk || !password} onPress={withPassword} />
              )}
            </View>
            <View style={{ borderTopWidth: bw, paddingTop: 14 }}>
              <BigButton
                tone="white"
                label={mode === 'link' ? t('login.usePassword') : t('login.useEmail')}
                onPress={() => {
                  setError(null);
                  setMode(mode === 'link' ? 'password' : 'link');
                }}
              />
            </View>
          </>
        )}
      </ScrollView>
      <View style={{ paddingBottom: insets.bottom }}>
        <Hazard height={18} />
      </View>
    </KeyboardAvoidingView>
  );
}
