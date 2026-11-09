import { useEffect, useState } from 'react';
import { RefreshControl, ScrollView, TextInput, View } from 'react-native';

import { BrandTile, PartnerRow, RiderCard } from '@/components/cards';
import { BigButton, Chips, PageHeader, QueryState } from '@/components/chrome';
import { Body, Mono, Stencil } from '@/components/text';
import type { Partner, Rider } from '@/lib/api';
import { useLocale } from '@/lib/i18n';
import { flatPages, useCommunity, useRiders } from '@/lib/queries';
import { bw, colors, fonts, space } from '@/theme';

const types = ['euc', 'escooter', 'esk8'] as const;

function pairs<T>(items: T[]): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += 2) out.push(items.slice(i, i + 2));
  return out;
}

/** Waits until typing stops before searching. */
function useDebounced(value: string, ms = 350) {
  const [v, setV] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setV(value), ms);
    return () => clearTimeout(id);
  }, [value, ms]);
  return v;
}

export default function CommunityScreen() {
  const { t, label } = useLocale();
  const community = useCommunity();
  const [type, setType] = useState<string>('all');
  const [query, setQuery] = useState('');
  const search = useDebounced(query.trim());
  const riders = useRiders(type === 'all' ? undefined : type, search);
  const roster = flatPages(riders.data);
  const c = community.data;

  const stat = (n: number | undefined, l: string, last = false) => (
    <View style={{ flex: 1, paddingVertical: space.m, paddingHorizontal: space.s, borderRightWidth: last ? 0 : bw }}>
      <Mono bold size={24} color={colors.orange}>{n ?? '–'}</Mono>
      <Mono size={9} color={colors.mutedOnWhite} style={{ marginTop: 4 }}>{l}</Mono>
    </View>
  );

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.white }}
      contentContainerStyle={{ paddingBottom: space.xxl }}
      keyboardShouldPersistTaps="handled"
      refreshControl={
        <RefreshControl
          refreshing={community.isRefetching}
          onRefresh={() => {
            community.refetch();
            riders.refetch();
          }}
          tintColor={colors.orange}
        />
      }>
      <PageHeader tone="black" title={t('community.title')} />

      <View style={{ flexDirection: 'row', backgroundColor: colors.white, borderBottomWidth: bw }}>
        {stat(c?.stats.riders, t('community.riders'))}
        {stat(c?.stats.cities, t('community.cities'))}
        {stat(c?.stats.meetups_held, t('community.meetups'))}
        {stat(c?.stats.rides_upcoming, t('community.upcoming'), true)}
      </View>

      <View style={{ padding: space.l, gap: 12 }}>
        <Stencil size={40}>{t('community.squad')}</Stencil>
        <TextInput
          value={query}
          onChangeText={setQuery}
          placeholder={t('community.search')}
          placeholderTextColor={colors.mutedOnWhite}
          accessibilityLabel={t('community.search')}
          returnKeyType="search"
          autoCorrect={false}
          style={{ height: 48, borderWidth: bw, paddingHorizontal: 12, fontFamily: fonts.body, fontSize: 15, color: colors.black }}
        />
        <Chips
          value={type}
          onChange={setType}
          options={[{ value: 'all', label: t('common.all') }, ...types.map((tp) => ({ value: tp, label: label('pev', tp) }))]}
        />
        <QueryState loading={riders.isPending} error={riders.error} onRetry={riders.refetch} />
        {riders.isSuccess && roster.length === 0 ? <Body color={colors.mutedOnWhite}>{t('community.noRiders')}</Body> : null}
        {pairs<Rider>(roster).map((row) => (
          <View key={row[0].slug} style={{ flexDirection: 'row', gap: 10 }}>
            {row.map((r) => <RiderCard key={r.slug} rider={r} />)}
            {row.length === 1 ? <View style={{ flex: 1 }} /> : null}
          </View>
        ))}
        {riders.hasNextPage ? (
          <BigButton tone="white" label={t('common.loadMore')} onPress={() => riders.fetchNextPage()} disabled={riders.isFetchingNextPage} />
        ) : null}
      </View>

      <QueryState loading={community.isPending} error={community.error} onRetry={community.refetch} />

      {c && c.communities.length > 0 ? (
        <View style={{ padding: space.l, borderTopWidth: bw }}>
          <Stencil size={40} style={{ marginBottom: 6 }}>{t('community.partners')}</Stencil>
          {c.communities.map((p) => <PartnerRow key={p.slug} partner={p} onDark={false} />)}
        </View>
      ) : null}

      {c && c.brands.length > 0 ? (
        <View style={{ padding: space.l, borderTopWidth: bw }}>
          <Stencil size={40} style={{ marginBottom: 12 }}>{t('community.brands')}</Stencil>
          <View style={{ gap: 10 }}>
            {pairs<Partner>(c.brands).map((row) => (
              <View key={row[0].slug} style={{ flexDirection: 'row', gap: 10 }}>
                {row.map((p) => <BrandTile key={p.slug} partner={p} />)}
                {row.length === 1 ? <View style={{ flex: 1 }} /> : null}
              </View>
            ))}
          </View>
        </View>
      ) : null}
    </ScrollView>
  );
}
