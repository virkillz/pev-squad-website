import { Image } from 'expo-image';
import { useLocalSearchParams } from 'expo-router';
import { openBrowserAsync } from 'expo-web-browser';
import { Pressable, ScrollView, View } from 'react-native';

import { EventRow } from '@/components/cards';
import { BackBar, QueryState } from '@/components/chrome';
import { Body, Mono, Stencil } from '@/components/text';
import { useLocale } from '@/lib/i18n';
import { usePartner } from '@/lib/queries';
import { bw, colors, space } from '@/theme';

export default function PartnerScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const { t } = useLocale();
  const partner = usePartner(slug);
  const p = partner.data;

  const links = p
    ? ([
        ['WEBSITE', p.links.website],
        ['INSTAGRAM', p.links.instagram && `https://instagram.com/${p.links.instagram.replace(/^@/, '')}`],
        ['TIKTOK', p.links.tiktok && `https://tiktok.com/@${p.links.tiktok.replace(/^@/, '')}`],
        ['YOUTUBE', p.links.youtube],
      ].filter(([, url]) => url) as [string, string][])
    : [];

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <BackBar />
      <QueryState loading={partner.isPending} error={partner.error} onRetry={partner.refetch} />
      {p ? (
        <ScrollView contentContainerStyle={{ paddingBottom: space.xxl }}>
          <View style={{ backgroundColor: colors.black, padding: space.l, gap: 12 }}>
            {p.logo_url ? <Image source={p.logo_url} style={{ width: 88, height: 88, backgroundColor: colors.white }} contentFit="contain" accessibilityLabel={p.name} /> : null}
            <Mono size={10} color={colors.orange}>
              {(p.kind === 'community' ? t('community.partners') : t('community.brands')).toUpperCase()}
              {p.region ? ` · ${p.region.toUpperCase()}` : ''}
            </Mono>
            <Stencil size={48} color={colors.white} accessibilityRole="header">{p.name}</Stencil>
            {p.tagline ? <Body size={15} color={colors.mutedOnBlack}>{p.tagline}</Body> : null}
          </View>

          {p.description ? <Body size={15} style={{ padding: space.l, lineHeight: 22 }}>{p.description}</Body> : null}
          {p.collaboration_note ? (
            <View style={{ marginHorizontal: space.l, borderLeftWidth: 4, borderColor: colors.orange, paddingLeft: 12 }}>
              <Body size={15} weight="semi">{p.collaboration_note}</Body>
            </View>
          ) : null}

          {links.length > 0 ? (
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, padding: space.l }}>
              {links.map(([name, url]) => (
                <Pressable key={name} accessibilityRole="link" onPress={() => openBrowserAsync(url)} style={{ borderWidth: bw, paddingHorizontal: 10, paddingVertical: 8 }}>
                  <Mono bold size={11}>{name} →</Mono>
                </Pressable>
              ))}
            </View>
          ) : null}

          {p.events.length > 0 ? (
            <View style={{ paddingHorizontal: space.l, marginTop: space.s }}>
              <Mono bold size={11} style={{ paddingBottom: 6 }}>
                {t('partner.events')} · {p.events.length}
              </Mono>
              <View style={{ borderTopWidth: bw }}>{p.events.map((e) => <EventRow key={e.id} event={e} />)}</View>
            </View>
          ) : null}
        </ScrollView>
      ) : null}
    </View>
  );
}
