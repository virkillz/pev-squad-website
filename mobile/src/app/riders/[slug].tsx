import { Image } from 'expo-image';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Linking, Pressable, ScrollView, View } from 'react-native';

import { BackBar, QueryState } from '@/components/chrome';
import { Icon } from '@/components/icon';
import { Body, Mono, Stencil } from '@/components/text';
import { useLocale } from '@/lib/i18n';
import { useRider } from '@/lib/queries';
import { bw, colors, space } from '@/theme';

export default function RiderScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const router = useRouter();
  const { t, label } = useLocale();
  const rider = useRider(slug);
  const r = rider.data;

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <BackBar shareUrl={r?.url} shareTitle={r?.alias} />
      <QueryState loading={rider.isPending} error={rider.error} onRetry={rider.refetch} />
      {r ? (
        <ScrollView contentContainerStyle={{ paddingBottom: space.xxl }}>
          <View style={{ backgroundColor: colors.orange, flexDirection: 'row', gap: 14, padding: space.l, borderBottomWidth: bw }}>
            {r.avatar_url ? (
              <Image source={r.avatar_url} style={{ width: 120, height: 150, borderWidth: bw }} contentFit="cover" accessibilityLabel={r.alias} />
            ) : null}
            <View style={{ flex: 1, justifyContent: 'flex-end' }}>
              <Mono bold size={10} color={colors.mutedOnOrange}>
                {label('pev', r.primary_pev_type)}
                {r.city ? ` · ${r.city.toUpperCase()}` : ''}
              </Mono>
              <Stencil size={44} style={{ marginTop: 4 }} accessibilityRole="header">{r.alias}</Stencil>
            </View>
          </View>

          {r.main_ride ? (
            <View style={{ padding: space.l, paddingVertical: 12, borderBottomWidth: bw }}>
              <Mono size={10} color={colors.mutedOnWhite}>{t('rider.rides')}</Mono>
              <Body weight="heavy" size={17} style={{ marginTop: 3 }}>{r.main_ride}</Body>
            </View>
          ) : null}

          {r.bio ? <Body size={15} style={{ padding: space.l, lineHeight: 22 }}>{r.bio}</Body> : null}

          {r.communities.length > 0 ? (
            <View style={{ paddingHorizontal: space.l, gap: 8 }}>
              <Mono size={10} color={colors.mutedOnWhite}>{t('rider.crews')}</Mono>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                {r.communities.map((c) => (
                  <Pressable key={c.slug} accessibilityRole="link" onPress={() => router.push({ pathname: '/partners/[slug]', params: { slug: c.slug } })} style={{ borderWidth: bw, paddingHorizontal: 10, paddingVertical: 6 }}>
                    <Body weight="bold" size={13}>{c.name}</Body>
                  </Pressable>
                ))}
              </View>
            </View>
          ) : null}

          {r.instagram ? (
            <Pressable
              accessibilityRole="link"
              onPress={() => Linking.openURL(`https://instagram.com/${r.instagram!.replace(/^@/, '')}`)}
              style={{ flexDirection: 'row', gap: 8, alignItems: 'center', margin: space.l, borderWidth: bw, padding: 12, alignSelf: 'flex-start' }}>
              <Icon name="instagram" size={18} />
              <Mono bold size={12}>@{r.instagram.replace(/^@/, '')}</Mono>
            </Pressable>
          ) : null}
        </ScrollView>
      ) : null}
    </View>
  );
}
