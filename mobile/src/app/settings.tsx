import Constants from 'expo-constants';
import { openBrowserAsync } from 'expo-web-browser';
import { useRouter } from 'expo-router';
import { Pressable, ScrollView, View } from 'react-native';

import { BackBar, BigButton, confirmLogout } from '@/components/chrome';
import { Body, Mono, Stencil } from '@/components/text';
import { API_URL } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useLocale, type Locale } from '@/lib/i18n';
import { bw, colors, space } from '@/theme';

/**
 * Pengaturan. Language (saved to the account when signed in, so emails
 * follow it) and the account section, with account deletion.
 * Notifications and blocked members come next (DESIGN.md §10).
 */
export default function SettingsScreen() {
  const router = useRouter();
  const { t, locale, setLocale } = useLocale();
  const { signedIn, me, changeLocale } = useAuth();
  const pick = (value: Locale) => (signedIn ? changeLocale(value).catch(() => setLocale(value)) : setLocale(value));

  const option = (value: Locale, code: string, name: string, first: boolean) => {
    const on = locale === value;
    return (
      <Pressable
        accessibilityRole="radio"
        accessibilityState={{ checked: on }}
        onPress={() => pick(value)}
        style={{ flex: 1, padding: 14, backgroundColor: on ? colors.orange : colors.black, borderLeftWidth: first ? 0 : bw, borderColor: colors.white }}>
        <Mono bold size={12} color={on ? colors.black : colors.white}>{code}</Mono>
        <Body weight="bold" size={14} color={on ? colors.black : colors.white} style={{ marginTop: 2 }}>{name}</Body>
      </Pressable>
    );
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.black }}>
      <BackBar />
      <ScrollView contentContainerStyle={{ padding: space.l, gap: 6, paddingBottom: space.xxl }}>
        <Stencil size={56} color={colors.white} style={{ marginBottom: 14 }} accessibilityRole="header">{t('settings.title')}</Stencil>
        <Mono bold size={11} color={colors.mutedOnBlack}>{t('settings.language')}</Mono>
        <View accessibilityRole="radiogroup" style={{ flexDirection: 'row', borderWidth: bw, borderColor: colors.white }}>
          {option('id', 'ID', 'Bahasa Indonesia', true)}
          {option('en', 'EN', 'English', false)}
        </View>
        <Body size={12} color={colors.mutedOnBlack}>{signedIn ? t('settings.languageAccount') : t('settings.languageNote')}</Body>
        {signedIn ? (
          <View style={{ marginTop: space.xl, gap: space.m }}>
            <Mono bold size={11} color={colors.mutedOnBlack}>{t('settings.account')}</Mono>
            <View style={{ borderWidth: bw, borderColor: colors.white, padding: space.l, gap: 4 }}>
              <Mono size={10} color={colors.mutedOnBlack}>{t('settings.signedInAs')}</Mono>
              <Body weight="bold" color={colors.white}>{me.data?.email ?? '…'}</Body>
            </View>
            <BigButton tone="white" label={t('menu.profile')} onPress={() => router.push('/profile')} />
            <BigButton tone="white" label={t('settings.blocked')} onPress={() => router.push('/blocked')} />
            <BigButton tone="black" label={t('profile.logout')} onPress={() => confirmLogout(t)} />
            <Pressable accessibilityRole="link" onPress={() => router.push('/account/delete')} style={{ paddingVertical: space.m }}>
              <Mono bold size={12} color={colors.orange} style={{ textDecorationLine: 'underline' }}>{t('delete.open')}</Mono>
            </Pressable>
          </View>
        ) : null}
      </ScrollView>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', padding: space.l, paddingBottom: space.xxl }}>
        <Mono size={10} color={colors.mutedOnBlack}>
          PEV SQUAD · {t('settings.version')} {Constants.expoConfig?.version}
        </Mono>
        <Pressable accessibilityRole="link" onPress={() => openBrowserAsync(`${API_URL}/about`)}>
          <Mono size={10} color={colors.mutedOnBlack} style={{ textDecorationLine: 'underline' }}>{t('settings.privacy')}</Mono>
        </Pressable>
      </View>
    </View>
  );
}
