import { ScrollView, useWindowDimensions, View } from 'react-native';

import { AlbumTile } from '@/components/cards';
import { BackBar, BigButton, QueryState } from '@/components/chrome';
import { Stencil } from '@/components/text';
import { useLocale } from '@/lib/i18n';
import { flatPages, useAlbums } from '@/lib/queries';
import { colors, space } from '@/theme';

export default function AlbumsScreen() {
  const { t } = useLocale();
  const { width } = useWindowDimensions();
  const albums = useAlbums();
  const list = flatPages(albums.data);
  const tile = (width - space.l * 2 - 10) / 2;

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <BackBar />
      <ScrollView contentContainerStyle={{ padding: space.l, gap: 14, paddingBottom: space.xxl }}>
        <Stencil size={56} color={colors.black} accessibilityRole="header">{t('home.gallery')}</Stencil>
        <QueryState loading={albums.isPending} error={albums.error} empty={albums.isSuccess && list.length === 0} onRetry={albums.refetch} />
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
          {list.map((a) => <AlbumTile key={a.slug} album={a} width={tile} />)}
        </View>
        {albums.hasNextPage ? (
          <BigButton tone="white" label={t('common.loadMore')} onPress={() => albums.fetchNextPage()} disabled={albums.isFetchingNextPage} />
        ) : null}
      </ScrollView>
    </View>
  );
}
