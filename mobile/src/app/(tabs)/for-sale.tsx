import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Pressable, RefreshControl, ScrollView, View } from 'react-native';

import { ListingCard } from '@/components/cards';
import { BigButton, Chips, PageHeader, QueryState } from '@/components/chrome';
import { Body, Mono } from '@/components/text';
import type { Listing } from '@/lib/api';
import { useLocale } from '@/lib/i18n';
import { flatPages, useListings } from '@/lib/queries';
import { bw, colors, space } from '@/theme';

const categories = ['euc', 'escooter', 'esk8', 'ebike', 'parts', 'gear', 'other'] as const;

/** Two listings per row. */
function Grid({ items }: { items: Listing[] }) {
  const rows: Listing[][] = [];
  for (let i = 0; i < items.length; i += 2) rows.push(items.slice(i, i + 2));
  return (
    <View style={{ gap: 12 }}>
      {rows.map((row) => (
        <View key={row[0].id} style={{ flexDirection: 'row', gap: 12 }}>
          {row.map((l) => <ListingCard key={l.id} listing={l} />)}
          {row.length === 1 ? <View style={{ flex: 1 }} /> : null}
        </View>
      ))}
    </View>
  );
}

export default function ForSaleScreen() {
  const router = useRouter();
  const { t, label } = useLocale();
  const [category, setCategory] = useState<string>('all');
  const cat = category === 'all' ? undefined : category;
  const live = useListings(cat);
  const sold = useListings(cat, true);
  const liveList = flatPages(live.data);
  const soldList = flatPages(sold.data);

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <PageHeader
        tone="black"
        title={t('forSale.title')}
        right={
          <Pressable
            accessibilityRole="button"
            onPress={() => router.push('/login')}
            style={{ backgroundColor: colors.orange, borderWidth: bw, paddingHorizontal: 14, paddingVertical: 12, marginBottom: 4 }}>
            <Mono bold size={12}>{t('forSale.sell')}</Mono>
          </Pressable>
        }
      />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ flexGrow: 0, borderBottomWidth: bw }} contentContainerStyle={{ padding: space.m, paddingHorizontal: space.l }}>
        <Chips
          value={category}
          onChange={setCategory}
          options={[{ value: 'all', label: t('common.all') }, ...categories.map((c) => ({ value: c, label: label('cat', c) }))]}
        />
      </ScrollView>
      <ScrollView
        contentContainerStyle={{ padding: space.l, gap: 14, paddingBottom: space.xxl }}
        refreshControl={
          <RefreshControl
            refreshing={live.isRefetching}
            onRefresh={() => {
              live.refetch();
              sold.refetch();
            }}
            tintColor={colors.orange}
          />
        }>
        <QueryState loading={live.isPending} error={live.error} empty={live.isSuccess && liveList.length === 0} onRetry={live.refetch} />
        <Grid items={liveList} />
        {live.hasNextPage ? (
          <BigButton tone="white" label={t('common.loadMore')} onPress={() => live.fetchNextPage()} disabled={live.isFetchingNextPage} />
        ) : null}

        {soldList.length > 0 ? (
          <>
            <Mono bold size={11} color={colors.mutedOnWhite} style={{ marginTop: 10 }}>{t('forSale.recentlySold')}</Mono>
            <Grid items={soldList} />
            {sold.hasNextPage ? (
              <BigButton tone="white" label={t('common.loadMore')} onPress={() => sold.fetchNextPage()} disabled={sold.isFetchingNextPage} />
            ) : null}
          </>
        ) : null}

        <View style={{ borderWidth: bw, borderStyle: 'dashed', padding: space.m }}>
          <Body size={13}>{t('forSale.note')}</Body>
        </View>
      </ScrollView>
    </View>
  );
}
