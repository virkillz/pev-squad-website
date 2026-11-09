import { useState } from 'react';
import { RefreshControl, ScrollView, View } from 'react-native';

import { PostFeature, PostRow } from '@/components/cards';
import { BigButton, Chips, PageHeader, QueryState, Segments } from '@/components/chrome';
import { useLocale } from '@/lib/i18n';
import { flatPages, usePosts } from '@/lib/queries';
import { bw, colors, space } from '@/theme';

const topics = ['community', 'industry', 'regulation', 'safety', 'maintenance', 'guide', 'gear', 'story'] as const;

export default function NewsScreen() {
  const { t, label } = useLocale();
  const [kind, setKind] = useState<'news' | 'article'>('news');
  const [topic, setTopic] = useState<string>('all');
  const posts = usePosts(kind, topic === 'all' ? undefined : topic);
  const list = flatPages(posts.data);
  const [first, ...rest] = list;

  return (
    <View style={{ flex: 1, backgroundColor: colors.black }}>
      <PageHeader tone="black" eyebrow={t('news.eyebrow')} title={t('news.title')} tag={t('news.tag')} />
      <Segments
        onDark
        activeColor={colors.orange}
        value={kind}
        onChange={(k) => {
          setKind(k);
          setTopic('all');
        }}
        options={[
          { value: 'news', label: t('news.news') },
          { value: 'article', label: t('news.articles') },
        ]}
      />
      <ScrollView
        contentContainerStyle={{ padding: space.l, gap: 14, paddingBottom: space.xxl }}
        refreshControl={<RefreshControl refreshing={posts.isRefetching} onRefresh={() => void posts.refetch()} tintColor={colors.orange} />}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginHorizontal: -space.l, borderBottomWidth: bw, borderColor: colors.ruleOnBlack, paddingBottom: 12 }} contentContainerStyle={{ paddingHorizontal: space.l }}>
          <Chips
            onDark
            value={topic}
            onChange={setTopic}
            options={[{ value: 'all', label: t('common.all') }, ...topics.map((tp) => ({ value: tp, label: label('topic', tp) }))]}
          />
        </ScrollView>
        <QueryState loading={posts.isPending} error={posts.error} empty={posts.isSuccess && list.length === 0} onRetry={posts.refetch} onDark />
        {first ? <PostFeature post={first} /> : null}
        <View>{rest.map((p) => <PostRow key={p.id} post={p} />)}</View>
        {posts.hasNextPage ? (
          <BigButton tone="white" label={t('common.loadMore')} onPress={() => posts.fetchNextPage()} disabled={posts.isFetchingNextPage} />
        ) : null}
      </ScrollView>
    </View>
  );
}
