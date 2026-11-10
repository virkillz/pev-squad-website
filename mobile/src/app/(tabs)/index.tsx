import { useRouter } from 'expo-router';
import { RefreshControl, ScrollView, View } from 'react-native';

import { AlbumTile, ListingCard, NextRideCard, PostRow, RiderOfTheDayCard } from '@/components/cards';
import { Masthead, QueryState, SectionHead } from '@/components/chrome';
import { Body, Mono } from '@/components/text';
import { useLocale } from '@/lib/i18n';
import { useHome } from '@/lib/queries';
import { colors, space } from '@/theme';

/** Beranda: next ride, latest posts, rider of the day, gallery strip, For Sale. One API call. */
export default function HomeScreen() {
  const router = useRouter();
  const { t } = useLocale();
  const home = useHome();
  const d = home.data;

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <Masthead />
      <ScrollView
        contentContainerStyle={{ padding: space.l, paddingTop: 20, gap: 26, paddingBottom: space.xxl }}
        refreshControl={<RefreshControl refreshing={home.isRefetching} onRefresh={() => void home.refetch()} tintColor={colors.orange} />}>
        <QueryState loading={home.isPending} error={home.error} onRetry={home.refetch} />

        {d ? (
          <>
            <View style={{ gap: 10 }}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                <Mono size={11} color={colors.mutedOnWhite}>{t('home.nextRide')}</Mono>
                
              </View>
              {d.next_event ? (
                <NextRideCard event={d.next_event} />
              ) : (
                <Body color={colors.mutedOnWhite}>{t('home.noRide')}</Body>
              )}
            </View>

            {d.posts.length > 0 ? (
              <View>
                <SectionHead title={t('home.latest')} action={t('home.allNews')} onAction={() => router.navigate('/news')} />
                {d.posts.map((p) => <PostRow key={p.id} post={p} />)}
              </View>
            ) : null}

            {d.rider_of_the_day ? (
              <View style={{ gap: 10 }}>
                <Mono size={11} color={colors.mutedOnWhite}>{t('home.riderOfTheDay')}</Mono>
                <RiderOfTheDayCard rider={d.rider_of_the_day} />
              </View>
            ) : null}

            {d.albums.length > 0 ? (
              <View style={{ gap: 10 }}>
                <SectionHead title={t('home.gallery')} action={t('home.allAlbums')} onAction={() => router.push('/albums')} />
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10 }} style={{ marginRight: -space.l }}>
                  {d.albums.map((a) => <AlbumTile key={a.slug} album={a} />)}
                </ScrollView>
              </View>
            ) : null}

            {d.listings.length > 0 ? (
              <View style={{ gap: 10 }}>
                <SectionHead title={t('home.forSale')} action={t('common.seeAll')} onAction={() => router.navigate('/for-sale')} />
                <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
                  {d.listings.map((l) => (
                    <View key={l.id} style={{ width: '48%' }}>
                      <ListingCard listing={l} />
                    </View>
                  ))}
                </View>
              </View>
            ) : null}
          </>
        ) : null}
      </ScrollView>
    </View>
  );
}
