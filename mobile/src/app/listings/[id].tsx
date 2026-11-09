import { Image } from 'expo-image';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useState } from 'react';
import { Linking, ScrollView, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { priceFull } from '@/components/cards';
import { BackBar, BigButton, ImagePlaceholder, QueryState } from '@/components/chrome';
import { Body, Mono } from '@/components/text';
import { ago, thousands } from '@/lib/format';
import { useLocale } from '@/lib/i18n';
import { useListing } from '@/lib/queries';
import { bw, colors, space } from '@/theme';

export default function ListingScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const { t, label, locale } = useLocale();
  const listing = useListing(Number(id));
  const [photo, setPhoto] = useState(0);
  const l = listing.data;
  const sold = l?.state === 'sold';

  const fact = (title: string, value: string, last = false) => (
    <View style={{ flex: 1, padding: 10, paddingHorizontal: space.l, borderRightWidth: last ? 0 : bw }}>
      <Mono size={10} color={colors.mutedOnWhite}>{title}</Mono>
      <Mono bold size={13} style={{ marginTop: 3 }}>{value}</Mono>
    </View>
  );

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <BackBar shareUrl={l?.url} shareTitle={l?.title} />
      <QueryState loading={listing.isPending} error={listing.error} onRetry={listing.refetch} />
      {l ? (
        <>
          <ScrollView contentContainerStyle={{ paddingBottom: space.xxl }}>
            {l.photos.length > 0 ? (
              <View>
                <ScrollView
                  horizontal
                  pagingEnabled
                  showsHorizontalScrollIndicator={false}
                  onMomentumScrollEnd={(ev) => setPhoto(Math.round(ev.nativeEvent.contentOffset.x / width))}>
                  {l.photos.map((p) => (
                    <Image key={p.url} source={p.url} placeholder={p.thumb_url} style={{ width, height: 300 }} contentFit="cover" />
                  ))}
                </ScrollView>
                <Mono bold size={11} color={colors.white} style={{ position: 'absolute', right: 0, bottom: 0, backgroundColor: colors.black, paddingHorizontal: 9, paddingVertical: 6 }}>
                  {photo + 1} / {l.photos.length}
                </Mono>
              </View>
            ) : (
              <ImagePlaceholder light style={{ height: 200 }} />
            )}

            <View style={{ padding: space.l, paddingTop: 14, borderTopWidth: bw, borderBottomWidth: bw }}>
              <Mono bold size={10} color={colors.mutedOnWhite}>
                {label('cat', l.category)} · {sold ? t('forSale.sold') : t('listing.available')}
                {l.last_checked_at && !sold ? ` · ${t('listing.checked', { when: ago(l.last_checked_at, locale) })}` : ''}
              </Mono>
              <Body weight="black" size={26} style={{ marginTop: 6, lineHeight: 30 }} accessibilityRole="header">{l.title}</Body>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 8 }}>
                <Mono bold size={24} style={{ textDecorationLine: sold ? 'line-through' : 'none' }}>{priceFull(l.price_idr)}</Mono>
                {l.negotiable && !sold ? <Mono bold size={11} style={{ backgroundColor: colors.orange, paddingHorizontal: 6, paddingVertical: 3 }}>{t('forSale.nego')}</Mono> : null}
              </View>
            </View>

            <View style={{ flexDirection: 'row', borderBottomWidth: bw }}>
              {fact(t('listing.condition'), label('cond', l.condition))}
              {fact(t('listing.distance'), l.km ? `${thousands(l.km)} KM` : '—')}
              {fact(l.quantity > 1 ? t('listing.qty') : t('listing.city'), l.quantity > 1 ? String(l.quantity) : (l.city ?? '—').toUpperCase(), true)}
            </View>

            <View style={{ padding: space.l, gap: 14 }}>
              {(l.description ?? '').split(/\n{2,}/).filter((p) => p.trim()).map((p, i) => (
                <Body key={i} size={15} style={{ lineHeight: 22 }}>{p.trim()}</Body>
              ))}
              {l.seller ? (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, borderTopWidth: bw, borderColor: colors.ruleOnWhite, paddingTop: 12 }}>
                  {l.seller.avatar_url ? (
                    <Image source={l.seller.avatar_url} style={{ width: 40, height: 40 }} contentFit="cover" />
                  ) : (
                    <View style={{ width: 40, height: 40, backgroundColor: colors.black }} />
                  )}
                  <View style={{ flex: 1 }}>
                    <Body weight="heavy" size={14}>@{l.seller.alias}</Body>
                    {l.seller.slug ? (
                      <Mono size={10} color={colors.mutedOnWhite} onPress={() => router.push({ pathname: '/riders/[slug]', params: { slug: l.seller!.slug! } })}>
                        {t('listing.member')} →
                      </Mono>
                    ) : null}
                  </View>
                </View>
              ) : null}
              {l.city && l.quantity > 1 ? <Mono size={11} color={colors.mutedOnWhite}>{l.city.toUpperCase()}</Mono> : null}
            </View>
          </ScrollView>

          {!sold ? (
            <View style={{ borderTopWidth: bw, padding: space.m, paddingHorizontal: space.l, paddingBottom: insets.bottom + space.m, flexDirection: 'row', gap: 10, backgroundColor: colors.white }}>
              {l.contact ? (
                <>
                  {l.contact.whatsapp_url ? (
                    <View style={{ flex: 2 }}>
                      <BigButton icon="chat" label={t('listing.whatsapp')} onPress={() => Linking.openURL(l.contact!.whatsapp_url!)} />
                    </View>
                  ) : null}
                  {l.contact.instagram_url ? (
                    <View style={{ flex: 1 }}>
                      <BigButton tone="white" icon="instagram" label={t('listing.instagram')} onPress={() => Linking.openURL(l.contact!.instagram_url!)} />
                    </View>
                  ) : null}
                </>
              ) : (
                <View style={{ flex: 1 }}>
                  <BigButton label={t('listing.loginToContact')} onPress={() => router.push('/login')} />
                </View>
              )}
            </View>
          ) : null}
        </>
      ) : null}
    </View>
  );
}
