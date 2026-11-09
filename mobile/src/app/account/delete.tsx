import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, ScrollView, TextInput, View } from 'react-native';

import { BackBar, BigButton, QueryState } from '@/components/chrome';
import { Body, Mono, Stencil } from '@/components/text';
import { api, ApiError, unwrap } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useLocale } from '@/lib/i18n';
import { bw, colors, fonts, space } from '@/theme';

/**
 * Hapus akun (store requirement). Shows what goes, asks the rider to type
 * HAPUS / DELETE, then deletes. The server wants a login from the last 20
 * minutes; otherwise the rider logs in again and comes back.
 */
export default function DeleteAccountScreen() {
  const router = useRouter();
  const { t } = useLocale();
  const { signedIn, signOut } = useAuth();
  const [typed, setTyped] = useState('');
  const [busy, setBusy] = useState(false);
  const [problem, setProblem] = useState<'reauth' | 'admin' | 'error' | null>(null);

  const footprint = useQuery({
    queryKey: ['me', 'deletion'],
    enabled: signedIn,
    queryFn: async () => unwrap(await api.GET('/api/v1/me/deletion')).data,
  });

  const word = t('delete.word');

  async function remove() {
    setBusy(true);
    setProblem(null);
    try {
      const { response, error } = await api.DELETE('/api/v1/me');
      if (!response.ok) {
        const code = (error as { error?: { code?: string } } | undefined)?.error?.code;
        throw new ApiError(response.status, code ?? 'http_error', 'Delete failed');
      }
      // The server already revoked every session; this clears the device.
      await signOut().catch(() => {});
      router.dismissTo('/');
      Alert.alert(t('delete.title'), t('delete.done'));
    } catch (e) {
      const code = e instanceof ApiError ? e.code : null;
      setProblem(code === 'reauth_required' ? 'reauth' : code === 'forbidden' ? 'admin' : 'error');
    } finally {
      setBusy(false);
    }
  }

  async function reauth() {
    await signOut().catch(() => {});
    router.dismissTo('/');
    router.push('/login');
  }

  const f = footprint.data;
  const lines = f
    ? [
        f.profile_alias ? t('delete.profile', { alias: f.profile_alias }) : null,
        f.reviews ? t('delete.reviews', { n: f.reviews }) : null,
        f.photos ? t('delete.photos', { n: f.photos }) : null,
        f.listings ? t('delete.listings', { n: f.listings }) : null,
        f.hosted_rides ? t('delete.rides', { n: f.hosted_rides }) : null,
        f.upcoming_rsvps ? t('delete.rsvps', { n: f.upcoming_rsvps }) : null,
        t('delete.always'),
      ].filter((line): line is string => line !== null)
    : [];

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1, backgroundColor: colors.black }}>
      <BackBar />
      <ScrollView contentContainerStyle={{ padding: space.l, gap: space.l, paddingBottom: space.xxl }} keyboardShouldPersistTaps="handled">
        <Stencil size={56} color={colors.white} accessibilityRole="header">{t('delete.title')}</Stencil>
        <Body color={colors.white} size={16}>{t('delete.lede')}</Body>

        {!f ? (
          <QueryState onDark loading={footprint.isLoading} error={footprint.error} onRetry={() => footprint.refetch()} />
        ) : (
          <View style={{ borderWidth: bw, borderColor: colors.orange, padding: space.l, gap: space.s }}>
            {lines.map((line) => (
              <Body key={line} color={colors.white}>— {line}</Body>
            ))}
          </View>
        )}

        <View style={{ gap: 6 }}>
          <Mono bold size={11} color={colors.white}>{t('delete.type', { word })}</Mono>
          <TextInput
            value={typed}
            onChangeText={setTyped}
            autoCapitalize="characters"
            autoCorrect={false}
            placeholder={word}
            placeholderTextColor={colors.mutedOnWhite}
            accessibilityLabel={t('delete.type', { word })}
            style={{ height: 52, borderWidth: bw, borderColor: colors.white, backgroundColor: colors.white, paddingHorizontal: 12, fontFamily: fonts.monoBold, fontSize: 17 }}
          />
        </View>

        {problem === 'reauth' ? (
          <View style={{ gap: space.m }}>
            <Body weight="semi" color={colors.orange}>{t('delete.reauth')}</Body>
            <BigButton tone="white" label={t('delete.reauthButton')} onPress={reauth} />
          </View>
        ) : problem ? (
          <Body weight="semi" color={colors.orange}>{problem === 'admin' ? t('delete.admin') : t('common.error')}</Body>
        ) : null}

        <BigButton
          label={busy ? t('delete.deleting') : t('delete.confirm')}
          disabled={busy || !f || typed.trim().toUpperCase() !== word}
          onPress={remove}
        />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
