import { useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, Switch, TextInput, View, type TextInputProps } from 'react-native';

import { BackBar, BigButton, Chips, QueryState } from '@/components/chrome';
import { Body, Mono, Stencil } from '@/components/text';
import { api, ApiError, unwrap } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useLocale } from '@/lib/i18n';
import { bw, colors, fonts, space } from '@/theme';

type PevType = 'euc' | 'escooter' | 'esk8' | 'ebike' | 'other';
const PEV_TYPES: PevType[] = ['euc', 'escooter', 'esk8', 'ebike', 'other'];

type Form = { alias: string; city: string; primary_pev_type: PevType; main_ride: string; bio: string; instagram: string; is_public: boolean };

/**
 * Profil saya. First visit (no rider profile yet) is the onboarding step:
 * alias, city, main PEV, then the "show me on the website" consent.
 * Avatars are uploaded on the website for now.
 */
type Me = NonNullable<ReturnType<typeof useAuth>['me']['data']>;

export default function ProfileScreen() {
  const router = useRouter();
  const { t } = useLocale();
  const { ready, signedIn, me } = useAuth();

  if (ready && !signedIn) {
    return (
      <View style={{ flex: 1, backgroundColor: colors.black }}>
        <BackBar />
        <View style={{ padding: space.l, gap: space.l }}>
          <Body color={colors.white}>{t('profile.signIn')}</Body>
          <BigButton label={t('header.login')} onPress={() => router.replace('/login')} />
        </View>
      </View>
    );
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1, backgroundColor: colors.black }}>
      <BackBar />
      {me.data ? (
        <ProfileForm me={me.data} />
      ) : (
        <QueryState onDark loading={!me.error} error={me.error} onRetry={() => me.refetch()} />
      )}
    </KeyboardAvoidingView>
  );
}

/** The form starts from `me` once; later refetches don't overwrite edits. */
function ProfileForm({ me }: { me: Me }) {
  const client = useQueryClient();
  const { t, label } = useLocale();
  const profile = me.rider_profile;

  const [form, setForm] = useState<Form>(() => ({
    alias: profile?.alias ?? '',
    city: profile?.city ?? '',
    primary_pev_type: profile?.primary_pev_type ?? 'euc',
    main_ride: profile?.main_ride ?? '',
    bio: profile?.bio ?? '',
    instagram: profile?.instagram ?? '',
    is_public: profile?.is_public ?? false,
  }));
  const [errors, setErrors] = useState<Record<string, string[]>>({});
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const set = <K extends keyof Form>(key: K, value: Form[K]) => setForm((f) => ({ ...f, [key]: value }));

  async function save() {
    setSaving(true);
    setErrors({});
    setMessage(null);
    try {
      unwrap(await api.PUT('/api/v1/me/profile', { body: { ...form, alias: form.alias.trim(), instagram: form.instagram.trim().replace(/^@/, '') } }));
      await client.invalidateQueries({ queryKey: ['me'] });
      setMessage(t('profile.saved'));
    } catch (e) {
      if (e instanceof ApiError && e.fields) {
        setErrors(e.fields);
        setMessage(t('profile.validation'));
      } else if (e instanceof ApiError && e.status === 403) {
        setMessage(t('profile.banned'));
      } else {
        setMessage(t('common.error'));
      }
    } finally {
      setSaving(false);
    }
  }

  const field = (key: keyof Form & string, title: string, props: TextInputProps = {}) => (
    <View style={{ gap: 6 }}>
      <Mono bold size={11} color={colors.white}>{title}</Mono>
      <TextInput
        value={String(form[key])}
        onChangeText={(v) => set(key, v as never)}
        accessibilityLabel={title}
        placeholderTextColor={colors.mutedOnWhite}
        {...props}
        style={{
          minHeight: 50,
          borderWidth: bw,
          borderColor: errors[key] ? colors.orange : colors.white,
          backgroundColor: colors.white,
          paddingHorizontal: 12,
          paddingVertical: 12,
          fontFamily: fonts.body,
          fontSize: 16,
          textAlignVertical: props.multiline ? 'top' : 'center',
        }}
      />
      {errors[key]?.map((m) => (
        <Body key={m} size={13} weight="semi" color={colors.orange}>{m}</Body>
      ))}
    </View>
  );

  const status = profile?.status;
  const banner =
    status === 'pending' ? t('profile.pending') : status === 'banned' ? t('profile.banned') : null;

  return (
    <ScrollView contentContainerStyle={{ padding: space.l, gap: space.l, paddingBottom: space.xxl }} keyboardShouldPersistTaps="handled">
      <View style={{ gap: 6 }}>
        <Stencil size={56} color={colors.white} accessibilityRole="header">
          {profile ? profile.alias : t('profile.setup')}
        </Stencil>
        <Mono size={12} color={colors.mutedOnBlack}>{me.email}</Mono>
        {!profile ? <Body color={colors.white}>{t('profile.setupNote')}</Body> : null}
      </View>
      {banner ? (
        <View style={{ backgroundColor: colors.orange, borderWidth: bw, padding: space.m }}>
          <Body weight="semi">{banner}</Body>
        </View>
      ) : null}

      {field('alias', t('profile.alias'), { autoCapitalize: 'none', autoCorrect: false, maxLength: 30 })}
      {field('city', t('profile.city'), { maxLength: 60, placeholder: 'Jakarta' })}
      <View style={{ gap: 6 }}>
        <Mono bold size={11} color={colors.white}>{t('profile.type')}</Mono>
        <Chips onDark options={PEV_TYPES.map((v) => ({ value: v, label: label('pev', v) }))} value={form.primary_pev_type} onChange={(v) => set('primary_pev_type', v)} />
      </View>
      {field('main_ride', t('profile.ride'), { maxLength: 80, placeholder: 'Begode Master' })}
      {field('bio', t('profile.bio'), { multiline: true, maxLength: 500 })}
      {field('instagram', t('profile.instagram'), { autoCapitalize: 'none', autoCorrect: false, placeholder: '@username' })}

      <View style={{ flexDirection: 'row', gap: space.m, alignItems: 'center', borderTopWidth: bw, borderColor: colors.white, paddingTop: space.l }}>
        <View style={{ flex: 1, gap: 4 }}>
          <Body weight="bold" color={colors.white}>{t('profile.public')}</Body>
          <Body size={12} color={colors.mutedOnBlack}>{t('profile.publicNote')}</Body>
        </View>
        <Switch
          value={form.is_public}
          onValueChange={(v) => set('is_public', v)}
          trackColor={{ true: colors.orange, false: colors.placeholder }}
          accessibilityLabel={t('profile.public')}
        />
      </View>

      {message ? <Body weight="semi" color={Object.keys(errors).length ? colors.orange : colors.white}>{message}</Body> : null}
      <BigButton label={saving ? t('profile.saving') : t('profile.save')} disabled={saving || status === 'banned' || !form.alias.trim()} onPress={save} />
    </ScrollView>
  );
}
