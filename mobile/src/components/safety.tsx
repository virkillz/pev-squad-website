import { useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'expo-router';
import { Alert, Platform, Pressable, View } from 'react-native';

import { api, ApiError, unwrap } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useLocale } from '@/lib/i18n';
import { bw, colors, space, touch } from '@/theme';

import { Icon } from './icon';
import { Mono } from './text';

export type TargetType = 'profile' | 'photo' | 'event' | 'review';

export type SafetyTarget = {
  type: TargetType;
  id: number;
  /** Who owns it, as shown in "Block @alias?" */
  name: string;
  /** False for unclaimed profiles and anything with no member behind it. */
  canBlock: boolean;
};

/**
 * Report / block row for member content (App Store 1.2). Logged out, both
 * go to login. `leave` is how many screens to pop after a block, because
 * the blocked content disappears (0 to stay, e.g. on a rider profile).
 */
export function SafetyActions({
  target,
  onDark = false,
  hideBlock = false,
  leave = 0,
  beforeNavigate,
}: {
  target: SafetyTarget;
  onDark?: boolean;
  hideBlock?: boolean;
  leave?: number;
  /** Close any RN <Modal> first: it would cover the pushed screen. */
  beforeNavigate?: () => void;
}) {
  const router = useRouter();
  const { t } = useLocale();
  const { signedIn } = useAuth();
  const block = useBlock();
  const fg = onDark ? colors.white : colors.black;

  const report = () => {
    beforeNavigate?.();
    if (!signedIn) return router.push('/login');
    router.push({
      pathname: '/report',
      params: { type: target.type, id: String(target.id), name: target.name, canBlock: target.canBlock ? '1' : '', leave: String(leave + 1) },
    });
  };

  const onBlock = () => {
    if (!signedIn) {
      beforeNavigate?.();
      return router.push('/login');
    }
    block(target, () => {
      beforeNavigate?.();
      if (leave > 0) router.dismiss(leave);
    });
  };

  const button = (label: string, icon: 'flag' | 'block', onPress: () => void) => (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={{ flexDirection: 'row', alignItems: 'center', gap: 6, minHeight: touch, paddingHorizontal: space.m, borderWidth: bw, borderColor: onDark ? colors.ruleOnBlack : colors.ruleOnWhite }}>
      <Icon name={icon} size={14} color={fg} />
      <Mono bold size={11} color={fg}>{label}</Mono>
    </Pressable>
  );

  return (
    <View style={{ flexDirection: 'row', gap: space.s, flexWrap: 'wrap' }}>
      {button(t('safety.report'), 'flag', report)}
      {target.canBlock && !hideBlock ? button(t('safety.block'), 'block', onBlock) : null}
    </View>
  );
}

/** Confirms, blocks, then refetches everything so their content disappears. */
export function useBlock() {
  const client = useQueryClient();
  const { t } = useLocale();

  return (target: SafetyTarget, after?: () => void) => {
    const run = async () => {
      try {
        unwrap(await api.POST('/api/v1/blocks', { body: { target_type: target.type, target_id: target.id } }));
        await client.invalidateQueries();
        after?.();
        Alert.alert(t('safety.block'), t('safety.blocked', { name: target.name }));
      } catch (e) {
        const field = e instanceof ApiError ? Object.values(e.fields ?? {})[0]?.[0] : undefined;
        Alert.alert(t('safety.block'), field ?? t('common.error'));
      }
    };
    if (Platform.OS === 'web') return void run();
    Alert.alert(t('safety.block'), t('safety.blockConfirm', { name: target.name }), [
      { text: t('profile.cancel'), style: 'cancel' },
      { text: t('safety.block'), style: 'destructive', onPress: run },
    ]);
  };
}
