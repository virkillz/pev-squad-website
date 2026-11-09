import { useState } from 'react';
import { RefreshControl, ScrollView, View } from 'react-native';

import { EventRow, PastEventRow } from '@/components/cards';
import { BigButton, PageHeader, QueryState, Segments } from '@/components/chrome';
import { Body, Mono } from '@/components/text';
import { useLocale } from '@/lib/i18n';
import { flatPages, useEvents } from '@/lib/queries';
import { bw, colors, space } from '@/theme';

type Filter = 'all' | 'official' | 'group_ride';

export default function EventsScreen() {
  const { t } = useLocale();
  const [filter, setFilter] = useState<Filter>('all');
  const category = filter === 'all' ? undefined : filter;
  const upcoming = useEvents('upcoming', category);
  const past = useEvents('past', category);
  const up = flatPages(upcoming.data);
  const before = flatPages(past.data);

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <PageHeader tone="black" title={t('events.title')} />
      <Segments
        value={filter}
        onChange={setFilter}
        options={[
          { value: 'all', label: t('common.all') },
          { value: 'official', label: t('events.official') },
          { value: 'group_ride', label: t('events.groupRide') },
        ]}
      />
      <ScrollView
        contentContainerStyle={{ paddingBottom: space.xxl }}
        refreshControl={
          <RefreshControl
            refreshing={upcoming.isRefetching}
            onRefresh={() => {
              upcoming.refetch();
              past.refetch();
            }}
            tintColor={colors.orange}
          />
        }>
        <Mono bold size={11} style={{ paddingHorizontal: space.l, paddingTop: 14, paddingBottom: 6 }}>
          {t('events.upcoming')}
          {upcoming.data ? ` · ${up.length}` : ''}
        </Mono>
        <QueryState loading={upcoming.isPending} error={upcoming.error} onRetry={upcoming.refetch} />
        {upcoming.data && up.length === 0 ? (
          <Body color={colors.mutedOnWhite} style={{ paddingHorizontal: space.l }}>{t('events.noUpcoming')}</Body>
        ) : null}
        {up.length > 0 ? (
          <View style={{ marginHorizontal: space.l, borderTopWidth: bw }}>
            {up.map((e) => <EventRow key={e.id} event={e} />)}
          </View>
        ) : null}
        {upcoming.hasNextPage ? (
          <View style={{ padding: space.l }}>
            <BigButton tone="white" label={t('common.loadMore')} onPress={() => upcoming.fetchNextPage()} disabled={upcoming.isFetchingNextPage} />
          </View>
        ) : null}

        <Mono bold size={11} color={colors.mutedOnWhite} style={{ paddingHorizontal: space.l, paddingTop: 22, paddingBottom: 6 }}>
          {t('events.past')}
        </Mono>
        <QueryState loading={past.isPending} error={past.error} onRetry={past.refetch} />
        <View style={{ marginHorizontal: space.l, borderTopWidth: before.length ? bw : 0 }}>
          {before.map((e) => <PastEventRow key={e.id} event={e} />)}
        </View>
        {past.hasNextPage ? (
          <View style={{ padding: space.l }}>
            <BigButton tone="white" label={t('common.loadMore')} onPress={() => past.fetchNextPage()} disabled={past.isFetchingNextPage} />
          </View>
        ) : null}
      </ScrollView>
    </View>
  );
}
