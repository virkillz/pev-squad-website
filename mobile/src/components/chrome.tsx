import { Image } from 'expo-image';
import { useRouter } from 'expo-router';
import { useState, type ReactNode } from 'react';
import { ActivityIndicator, Alert, Modal, Platform, Pressable, Share, StyleSheet, View, type ViewStyle } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useAuth } from '@/lib/auth';
import { useLocale } from '@/lib/i18n';
import { endSession } from '@/lib/session';
import { bw, colors, space, touch } from '@/theme';

import { Icon } from './icon';
import { Body, Mono, Stencil, Tag } from './text';

/** The orange/black hazard stripe from the site, as a row of slanted blocks. */
export function Hazard({ height = 10 }: { height?: number }) {
  return (
    <View style={{ height, flexDirection: 'row', overflow: 'hidden', borderBottomWidth: bw }} aria-hidden>
      {Array.from({ length: 30 }, (_, i) => (
        <View
          key={i}
          style={{
            width: 20,
            height: height * 3,
            marginTop: -height,
            backgroundColor: i % 2 ? colors.black : colors.orange,
            transform: [{ skewX: '-45deg' }],
          }}
        />
      ))}
    </View>
  );
}

/**
 * Account corner, top right of every tab. Logged out: the ID/EN switch plus
 * MASUK. Logged in: the avatar, which opens the account menu (profile,
 * settings, language, log out).
 */
export function AccountCorner({ onDark = true }: { onDark?: boolean }) {
  const router = useRouter();
  const { locale, setLocale, t } = useLocale();
  const { signedIn, me, changeLocale } = useAuth();
  const [open, setOpen] = useState(false);
  const fg = onDark ? colors.white : colors.black;

  const toggleLocale = () => {
    const next = locale === 'id' ? 'en' : 'id';
    if (signedIn) changeLocale(next).catch(() => setLocale(next));
    else setLocale(next);
  };

  const localeSwitch = (color: string, muted: string) => (
    <Mono bold size={12} color={color}>
      {locale === 'id' ? 'ID' : 'EN'}
      <Mono size={12} color={muted}>{locale === 'id' ? ' / EN' : ' / ID'}</Mono>
    </Mono>
  );

  if (signedIn) {
    const profile = me.data?.rider_profile;
    const initial = (profile?.alias ?? me.data?.email ?? '?').slice(0, 1).toUpperCase();
    const go = (path: '/profile' | '/settings') => {
      setOpen(false);
      router.push(path);
    };
    const item = (text: string, onPress: () => void, right?: ReactNode) => (
      <Pressable
        accessibilityRole="menuitem"
        onPress={onPress}
        style={({ pressed }) => ({ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', minHeight: touch + 4, paddingHorizontal: space.l, borderTopWidth: bw, backgroundColor: pressed ? colors.orange : colors.white })}>
        <Mono bold size={12}>{text}</Mono>
        {right}
      </Pressable>
    );
    return (
      <>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={t('menu.account')}
          onPress={() => setOpen(true)}
          style={{ width: touch, height: touch, borderWidth: bw, borderColor: fg, backgroundColor: colors.orange, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
          {profile?.avatar_url ? (
            <Image source={profile.avatar_url} style={{ width: '100%', height: '100%' }} contentFit="cover" />
          ) : (
            <Stencil size={24}>{initial}</Stencil>
          )}
        </Pressable>
        <Modal transparent visible={open} animationType="fade" onRequestClose={() => setOpen(false)}>
          <Pressable style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.5)' }} onPress={() => setOpen(false)} accessibilityLabel={t('common.back')}>
            <AccountMenu>
              <View style={{ padding: space.l, gap: 2 }}>
                <Body weight="black" size={17}>{profile?.alias ?? t('profile.setup')}</Body>
                <Mono size={11} color={colors.mutedOnWhite}>{me.data?.email}</Mono>
              </View>
              {item(t('menu.profile'), () => go('/profile'))}
              {item(t('menu.settings'), () => go('/settings'))}
              {item(t('settings.language'), toggleLocale, localeSwitch(colors.black, colors.mutedOnWhite))}
              {item(t('profile.logout'), () => {
                setOpen(false);
                confirmLogout(t);
              })}
            </AccountMenu>
          </Pressable>
        </Modal>
      </>
    );
  }

  return (
    <View style={{ flexDirection: 'row', alignItems: 'stretch', borderWidth: bw, borderColor: fg }}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={t('header.language')}
        onPress={toggleLocale}
        style={{ paddingHorizontal: 10, minHeight: touch - 4, justifyContent: 'center' }}>
        {localeSwitch(fg, onDark ? colors.mutedOnBlack : colors.mutedOnWhite)}
      </Pressable>
      <Pressable
        accessibilityRole="button"
        onPress={() => router.push('/login')}
        style={{ backgroundColor: colors.orange, paddingHorizontal: 12, justifyContent: 'center', borderLeftWidth: bw, borderColor: fg }}>
        <Mono bold size={12} color={colors.black}>
          {t('header.login')}
        </Mono>
      </Pressable>
    </View>
  );
}

function AccountMenu({ children }: { children: ReactNode }) {
  const insets = useSafeAreaInsets();
  return (
    <View
      accessibilityRole="menu"
      onStartShouldSetResponder={() => true}
      style={{ position: 'absolute', top: insets.top + 56, right: space.l, width: 260, backgroundColor: colors.white, borderWidth: bw, shadowColor: colors.black, shadowOffset: { width: 4, height: 4 }, shadowOpacity: 1, shadowRadius: 0 }}>
      {children}
    </View>
  );
}

/** "Keluar?" confirmation, then ends the session on this device and the server. */
export function confirmLogout(t: ReturnType<typeof useLocale>['t']) {
  const logout = () =>
    endSession().catch(() => Alert.alert(t('profile.logout'), t('profile.logoutError')));
  if (Platform.OS === 'web') {
    logout();
    return;
  }
  Alert.alert(t('profile.logout'), t('profile.logoutConfirm'), [
    { text: t('profile.cancel'), style: 'cancel' },
    { text: t('profile.logout'), style: 'destructive', onPress: logout },
  ]);
}

/** Home's masthead: logo, name, account corner, hazard stripe. */
export function Masthead() {
  const insets = useSafeAreaInsets();
  const { t } = useLocale();
  return (
    <View style={{ backgroundColor: colors.black, paddingTop: insets.top }}>
      <View style={{ flexDirection: 'row', borderBottomWidth: bw, borderColor: colors.white }}>
        <View style={styles.brand}>
          <Image source={require('@/assets/images/logo.jpg')} style={{ width: 34, height: 34 }} accessibilityLabel="PEV Squad" />
          <View>
            <Body weight="black" size={17} color={colors.white} style={{ textTransform: 'uppercase', letterSpacing: -0.5, lineHeight: 18 }}>
              PEV Squad
            </Body>
            <Mono size={9} color={colors.orange}>{t('header.tagline')}</Mono>
          </View>
        </View>
        <View style={{ justifyContent: 'center', paddingHorizontal: space.m }}>
          <AccountCorner />
        </View>
      </View>
      <Hazard />
    </View>
  );
}

/**
 * The big band at the top of each tab: eyebrow, stencil title, one marker
 * tag, account corner. `tone` picks the band color.
 */
export function PageHeader({
  eyebrow,
  title,
  tag,
  tone = 'black',
  right,
  children,
}: {
  eyebrow: string;
  title: string;
  tag?: string;
  tone?: 'black' | 'white' | 'orange';
  right?: ReactNode;
  children?: ReactNode;
}) {
  const insets = useSafeAreaInsets();
  const bg = { black: colors.black, white: colors.white, orange: colors.orange }[tone];
  const fg = tone === 'black' ? colors.white : colors.black;
  const muted = { black: colors.mutedOnBlack, white: colors.mutedOnWhite, orange: colors.mutedOnOrange }[tone];
  const tagColor = tone === 'orange' ? colors.black : colors.orange;

  return (
    <View style={{ backgroundColor: bg, paddingTop: insets.top + space.s, borderBottomWidth: bw, borderColor: tone === 'black' ? colors.white : colors.black }}>
      <View style={{ flexDirection: 'row', justifyContent: 'flex-end', paddingHorizontal: space.l }}>
        <AccountCorner onDark={tone === 'black'} />
      </View>
      <View style={{ paddingHorizontal: space.l, paddingBottom: 14, paddingTop: space.s }}>
        <Mono size={11} color={muted}>{eyebrow}</Mono>
        <View style={{ flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between', marginTop: 6 }}>
          <Stencil size={64} color={fg} accessibilityRole="header">{title}</Stencil>
          {right ?? (tag ? <Tag color={tagColor} style={{ marginBottom: 8 }}>{tag}</Tag> : null)}
        </View>
        {children}
      </View>
    </View>
  );
}

/** Black top bar for pushed screens: back, and an optional share button. */
export function BackBar({ shareUrl, shareTitle }: { shareUrl?: string; shareTitle?: string }) {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { t } = useLocale();
  return (
    <View style={{ backgroundColor: colors.black, paddingTop: insets.top, flexDirection: 'row', justifyContent: 'space-between', borderBottomWidth: bw, borderColor: colors.white }}>
      <Pressable
        accessibilityRole="button"
        onPress={() => (router.canGoBack() ? router.back() : router.replace('/'))}
        style={{ flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: space.l, minHeight: touch + 4, borderRightWidth: bw, borderColor: colors.white }}>
        <Icon name="back" size={18} color={colors.white} />
        <Mono bold size={12} color={colors.white}>{t('common.back')}</Mono>
      </Pressable>
      {shareUrl ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={t('common.share')}
          onPress={() => Share.share({ message: shareTitle ? `${shareTitle}\n${shareUrl}` : shareUrl, url: shareUrl })}
          style={{ width: 56, alignItems: 'center', justifyContent: 'center', borderLeftWidth: bw, borderColor: colors.white }}>
          <Icon name="share" size={20} color={colors.white} />
        </Pressable>
      ) : null}
    </View>
  );
}

/** "TERBARU ———— SEMUA BERITA →" section header used on Home. */
export function SectionHead({ title, action, onAction, onDark = true }: { title: string; action?: string; onAction?: () => void; onDark?: boolean }) {
  const fg = onDark ? colors.white : colors.black;
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', paddingBottom: 8, borderBottomWidth: bw, borderColor: fg }}>
      <Stencil size={28} color={fg}>{title}</Stencil>
      {action ? (
        <Pressable accessibilityRole="link" onPress={onAction} style={{ paddingVertical: 8 }} hitSlop={8}>
          <Mono bold size={11} color={colors.orange}>{action}</Mono>
        </Pressable>
      ) : null}
    </View>
  );
}

/** A row of filter chips. Selected = solid. */
export function Chips<T extends string>({
  options,
  value,
  onChange,
  onDark = false,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
  onDark?: boolean;
}) {
  const fg = onDark ? colors.white : colors.black;
  const bg = onDark ? colors.black : colors.white;
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
      {options.map((o) => {
        const on = o.value === value;
        return (
          <Pressable
            key={o.value}
            accessibilityRole="button"
            accessibilityState={{ selected: on }}
            onPress={() => onChange(o.value)}
            style={{ backgroundColor: on ? fg : bg, borderWidth: bw, borderColor: on ? fg : onDark ? colors.ruleOnBlack : fg, paddingHorizontal: 10, paddingVertical: 7 }}>
            <Mono bold size={11} color={on ? bg : fg}>{o.label}</Mono>
          </Pressable>
        );
      })}
    </View>
  );
}

/** Equal-width segmented control (Semua / Resmi / Group ride). */
export function Segments<T extends string>({
  options,
  value,
  onChange,
  activeColor = colors.black,
  onDark = false,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
  activeColor?: string;
  onDark?: boolean;
}) {
  const fg = onDark ? colors.white : colors.black;
  return (
    <View accessibilityRole="tablist" style={{ flexDirection: 'row', borderBottomWidth: bw, borderColor: fg }}>
      {options.map((o, i) => {
        const on = o.value === value;
        const activeFg = activeColor === colors.orange ? colors.black : colors.white;
        return (
          <Pressable
            key={o.value}
            accessibilityRole="tab"
            accessibilityState={{ selected: on }}
            onPress={() => onChange(o.value)}
            style={{ flex: 1, alignItems: 'center', paddingVertical: 14, backgroundColor: on ? activeColor : onDark ? colors.black : colors.white, borderLeftWidth: i ? bw : 0, borderColor: fg }}>
            <Mono bold size={11} color={on ? activeFg : fg}>{o.label}</Mono>
          </Pressable>
        );
      })}
    </View>
  );
}

/** Loading / error / empty states for a query. */
export function QueryState({
  loading,
  error,
  empty,
  onRetry,
  onDark = false,
  style,
}: {
  loading?: boolean;
  error?: unknown;
  empty?: boolean;
  onRetry?: () => void;
  onDark?: boolean;
  style?: ViewStyle;
}) {
  const { t } = useLocale();
  const fg = onDark ? colors.white : colors.black;
  if (loading) {
    return (
      <View style={[{ padding: space.xxl, alignItems: 'center' }, style]}>
        <ActivityIndicator color={colors.orange} />
      </View>
    );
  }
  if (error) {
    return (
      <View style={[{ padding: space.l, gap: space.m }, style]}>
        <Body color={fg}>{t('common.error')}</Body>
        {onRetry ? (
          <Pressable accessibilityRole="button" onPress={onRetry} style={{ alignSelf: 'flex-start', borderWidth: bw, borderColor: fg, paddingHorizontal: 14, paddingVertical: 10 }}>
            <Mono bold size={12} color={fg}>{t('common.retry')}</Mono>
          </Pressable>
        ) : null}
      </View>
    );
  }
  if (empty) {
    return (
      <View style={[{ padding: space.l }, style]}>
        <Body color={onDark ? colors.mutedOnBlack : colors.mutedOnWhite}>{t('common.empty')}</Body>
      </View>
    );
  }
  return null;
}

/** Big bordered button. `tone` orange (primary) or black / white. */
export function BigButton({
  label,
  onPress,
  tone = 'orange',
  icon,
  disabled,
}: {
  label: string;
  onPress?: () => void;
  tone?: 'orange' | 'black' | 'white';
  icon?: Parameters<typeof Icon>[0]['name'];
  disabled?: boolean;
}) {
  const bg = { orange: colors.orange, black: colors.black, white: colors.white }[tone];
  const fg = tone === 'black' ? colors.white : colors.black;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => ({
        backgroundColor: bg,
        borderWidth: bw,
        borderColor: colors.black,
        minHeight: 52,
        flexDirection: 'row',
        gap: 8,
        alignItems: 'center',
        justifyContent: 'center',
        opacity: disabled ? 0.5 : 1,
        transform: [{ translateX: pressed ? 2 : 0 }, { translateY: pressed ? 2 : 0 }],
        shadowColor: colors.black,
        shadowOffset: { width: tone === 'orange' ? 4 : 0, height: tone === 'orange' ? 4 : 0 },
        shadowOpacity: 1,
        shadowRadius: 0,
        elevation: 0,
      })}>
      {icon ? <Icon name={icon} size={18} color={fg} /> : null}
      <Mono bold size={13} color={fg}>{label}</Mono>
    </Pressable>
  );
}

/** Striped placeholder for an image that's missing. */
export function ImagePlaceholder({ style, light = false }: { style?: ViewStyle; light?: boolean }) {
  return <View aria-hidden style={[{ backgroundColor: light ? colors.placeholderLight : colors.placeholder }, style]} />;
}

const styles = StyleSheet.create({
  brand: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: space.l,
    paddingVertical: 10,
    borderRightWidth: bw,
    borderColor: colors.white,
  },
});
