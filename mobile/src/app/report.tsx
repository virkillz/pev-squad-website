import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, Pressable, ScrollView, Switch, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BigButton, QueryState } from '@/components/chrome';
import type { TargetType } from '@/components/safety';
import { Body, Mono, Stencil } from '@/components/text';
import { api, ApiError, unwrap } from '@/lib/api';
import { useLocale } from '@/lib/i18n';
import { bw, colors, fonts, space } from '@/theme';

type Reason = 'spam' | 'offensive' | 'harassment' | 'dangerous' | 'private_info' | 'not_theirs' | 'other';

/**
 * Laporkan, as a modal. Params: type, id, name (owner's alias), canBlock,
 * leave (screens to pop if the rider also blocks, so they don't land back
 * on content that is now hidden).
 */
export default function ReportScreen() {
  const params = useLocalSearchParams<{ type: TargetType; id: string; name: string; canBlock?: string; leave?: string }>();
  const router = useRouter();
  const client = useQueryClient();
  const insets = useSafeAreaInsets();
  const { t, locale } = useLocale();

  const [reason, setReason] = useState<Reason | null>(null);
  const [notes, setNotes] = useState('');
  const [alsoBlock, setAlsoBlock] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const reasons = useQuery({
    queryKey: ['report-reasons', locale],
    staleTime: Infinity,
    queryFn: async () => unwrap(await api.GET('/api/v1/reports/reasons')).data,
  });

  const canBlock = params.canBlock === '1';
  const close = () => (router.canGoBack() ? router.back() : router.replace('/'));

  async function send() {
    if (!reason) return;
    setBusy(true);
    setError(null);
    try {
      const { blocked } = unwrap(
        await api.POST('/api/v1/reports', {
          body: { target_type: params.type, target_id: Number(params.id), reason, notes: notes.trim() || null, block: canBlock && alsoBlock },
        }),
      ).data;
      if (blocked) {
        await client.invalidateQueries();
        router.dismiss(Math.max(1, Number(params.leave) || 1));
      } else {
        close();
      }
      Alert.alert(t('report.title'), blocked ? `${t('report.thanks')}\n\n${t('safety.blocked', { name: params.name })}` : t('report.thanks'));
    } catch (e) {
      const field = e instanceof ApiError ? Object.values(e.fields ?? {})[0]?.[0] : undefined;
      setError(field ?? (e instanceof ApiError && e.status === 404 ? t('common.empty') : t('common.error')));
    } finally {
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1, backgroundColor: colors.white }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingTop: Platform.OS === 'ios' ? space.s : insets.top, borderBottomWidth: bw }}>
        <Stencil size={36} style={{ padding: space.l }} accessibilityRole="header">{t('report.title')}</Stencil>
        <Pressable accessibilityRole="button" onPress={close} style={{ padding: space.l }}>
          <Mono bold size={12}>{t('profile.cancel')}</Mono>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={{ padding: space.l, gap: space.l, paddingBottom: insets.bottom + space.xxl }} keyboardShouldPersistTaps="handled">
        <View style={{ gap: 4 }}>
          <Mono size={10} color={colors.mutedOnWhite}>{t('report.about')}</Mono>
          <Body weight="bold" size={17}>
            {t(`report.kind.${params.type}`)} · {params.name}
          </Body>
        </View>

        <View style={{ gap: space.s }}>
          <Mono bold size={11}>{t('report.reason')}</Mono>
          {reasons.data ? (
            <View accessibilityRole="radiogroup" style={{ borderWidth: bw }}>
              {reasons.data.map((r, i) => {
                const on = reason === r.value;
                return (
                  <Pressable
                    key={r.value}
                    accessibilityRole="radio"
                    accessibilityState={{ checked: on }}
                    onPress={() => setReason(r.value)}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: space.m, padding: space.m, minHeight: 48, borderTopWidth: i ? bw : 0, backgroundColor: on ? colors.orange : colors.white }}>
                    <View style={{ width: 18, height: 18, borderWidth: bw, backgroundColor: on ? colors.black : colors.white }} />
                    <Body weight={on ? 'bold' : 'regular'} style={{ flex: 1 }}>{r.label}</Body>
                  </Pressable>
                );
              })}
            </View>
          ) : (
            <QueryState loading={reasons.isPending} error={reasons.error} onRetry={reasons.refetch} />
          )}
        </View>

        <View style={{ gap: 6 }}>
          <Mono bold size={11}>{t('report.notes')}</Mono>
          <TextInput
            value={notes}
            onChangeText={setNotes}
            multiline
            maxLength={1000}
            placeholder={t('report.notesHint')}
            placeholderTextColor={colors.mutedOnWhite}
            accessibilityLabel={t('report.notes')}
            style={{ minHeight: 96, borderWidth: bw, padding: 12, fontFamily: fonts.body, fontSize: 16, textAlignVertical: 'top' }}
          />
        </View>

        {canBlock ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: space.m }}>
            <Body weight="bold" style={{ flex: 1 }}>{t('report.alsoBlock', { name: params.name })}</Body>
            <Switch value={alsoBlock} onValueChange={setAlsoBlock} trackColor={{ true: colors.orange, false: colors.placeholderLight }} accessibilityLabel={t('report.alsoBlock', { name: params.name })} />
          </View>
        ) : null}

        <Body size={12} color={colors.mutedOnWhite}>{t('report.private')}</Body>
        {error ? <Body weight="semi" color={colors.orange}>{error}</Body> : null}
        <BigButton tone="black" label={busy ? t('report.sending') : t('report.send')} disabled={busy || !reason} onPress={send} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
